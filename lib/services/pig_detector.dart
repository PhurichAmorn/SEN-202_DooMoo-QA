import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:onnxruntime_v2/onnxruntime_v2.dart';
import 'package:doomoo/models/detection_result.dart';
import 'package:doomoo/utils/image_preprocessing.dart';

/// RF-DETR segmentation detector.
class PigDetector {
  /// Static flag to disable ONNX and return mock data during tests.
  static bool skipInTests = false;

  static PigDetector? _instance;
  OrtSession? _session;
  bool _isReady = false;
  static bool _envInitialized = false;

  // ---- Model constants ----
  static const String _modelAsset = 'assets/models/rf_detr_pig.onnx';
  static const int inputSize = 432;
  static const String _inputName = 'input';
  static const double _confidenceThreshold = 0.5;
  static const double _maskThreshold = 0.0;
  static const int _maxDetections = 10;

  static Future<PigDetector> getInstance() async {
    _instance ??= PigDetector._internal();
    return _instance!;
  }

  PigDetector._internal();

  @visibleForTesting
  static void setMockInstance(dynamic mock) {
    // Keep for test compatibility if needed, but we'll use skipInTests mostly
  }

  Future<void> _loadModel() async {
    if (skipInTests) return;
    try {
      if (!_envInitialized) {
        OrtEnv.instance.init();
        _envInitialized = true;
      }

      final rawAssetData = await rootBundle.load(_modelAsset);
      final modelBytes = rawAssetData.buffer.asUint8List();

      final sessionOptions = OrtSessionOptions();
      _session = OrtSession.fromBuffer(modelBytes, sessionOptions);
      sessionOptions.release();

      _isReady = true;
    } catch (e) {
      debugPrint('Failed to load ONNX model: $e');
      rethrow;
    }
  }

  Future<DetectionResult> detect(String imagePath, {Rect? cropRect}) async {
    if (skipInTests) {
      return DetectionResult(
        detections: [
          PigDetection(
            boundingBox: cropRect ?? const Rect.fromLTWH(100, 100, 200, 200),
            confidence: 0.99,
            classId: 0,
            mask: List.generate(10, (y) => List.generate(10, (x) => 1.0)),
            maskRect: cropRect ?? const Rect.fromLTWH(100, 100, 200, 200),
          ),
        ],
        imageWidth: 1000,
        imageHeight: 1000,
      );
    }

    if (!_isReady || _session == null) {
      await _loadModel();
    }

    try {
      final preprocessed = cropRect != null
          ? ImagePreprocessor.cropAndPreprocess(imagePath, cropRect, inputSize)
          : ImagePreprocessor.preprocess(imagePath, inputSize);

      final inputTensor = OrtValueTensor.createTensorWithDataList(
        preprocessed.data,
        [1, 3, inputSize, inputSize],
      );

      final runOptions = OrtRunOptions();
      final outputs = await _session!.runAsync(
        runOptions,
        {_inputName: inputTensor},
      );

      final outputList = outputs ?? [];
      final detections = _postprocess(outputList, preprocessed);

      inputTensor.release();
      runOptions.release();
      for (final output in outputList) {
        output?.release();
      }

      return DetectionResult(
        detections: detections,
        imageWidth: preprocessed.originalWidth,
        imageHeight: preprocessed.originalHeight,
      );
    } catch (e) {
      debugPrint('Segmentation inference failed: $e');
      return DetectionResult(
        detections: [],
        imageWidth: 0,
        imageHeight: 0,
      );
    }
  }

  List<PigDetection> _postprocess(
    List<OrtValue?> outputs,
    PreprocessedImage preprocessed,
  ) {
    if (outputs.isEmpty || outputs[0] == null || outputs[1] == null) {
      return [];
    }

    final originalWidth = preprocessed.originalWidth;
    final originalHeight = preprocessed.originalHeight;
    final cropRect = preprocessed.cropRect;

    final detsRaw = outputs[0]!.value;
    final labelsRaw = outputs[1]!.value;
    final masksRaw = outputs.length > 2 ? outputs[2]?.value : null;

    final List<List<double>> dets = _parseDets(detsRaw);
    final List<double> scores = _parseLabels(labelsRaw);
    final int numDetections = dets.length;

    final List<PigDetection> detections = [];

    bool isNormalized = true;
    for (int i = 0; i < math.min(10, dets.length); i++) {
      if (dets[i].any((v) => v.abs() > 1.5)) {
        isNormalized = false;
        break;
      }
    }

    final double currentWidth = cropRect?.width ?? originalWidth.toDouble();
    final double currentHeight = cropRect?.height ?? originalHeight.toDouble();
    final double offsetX = cropRect?.left ?? 0;
    final double offsetY = cropRect?.top ?? 0;

    final double scaleToCurrentX = currentWidth / inputSize;
    final double scaleToCurrentY = currentHeight / inputSize;

    for (int i = 0;
        i < numDetections && detections.length < _maxDetections;
        i++) {
      final score = scores[i];
      if (score < _confidenceThreshold) continue;

      double cx, cy, w, h;
      if (isNormalized) {
        cx = dets[i][0] * currentWidth + offsetX;
        cy = dets[i][1] * currentHeight + offsetY;
        w = dets[i][2] * currentWidth;
        h = dets[i][3] * currentHeight;
      } else {
        cx = dets[i][0] * scaleToCurrentX + offsetX;
        cy = dets[i][1] * scaleToCurrentY + offsetY;
        w = dets[i][2] * scaleToCurrentX;
        h = dets[i][3] * scaleToCurrentY;
      }

      final left = (cx - w / 2).clamp(0.0, originalWidth.toDouble());
      final top = (cy - h / 2).clamp(0.0, originalHeight.toDouble());
      final right = (cx + w / 2).clamp(0.0, originalWidth.toDouble());
      final bottom = (cy + h / 2).clamp(0.0, originalHeight.toDouble());

      List<List<double>>? mask;
      if (masksRaw != null) {
        mask = _parseMask(masksRaw, i, preprocessed);
      }

      detections.add(PigDetection(
        boundingBox: Rect.fromLTRB(left, top, right, bottom),
        confidence: score,
        classId: 0,
        mask: mask,
        maskRect: cropRect ??
            Rect.fromLTRB(
                0, 0, originalWidth.toDouble(), originalHeight.toDouble()),
      ));
    }

    detections.sort((a, b) => b.confidence.compareTo(a.confidence));
    return detections;
  }

  List<List<double>> _parseDets(dynamic raw) {
    if (raw is List && raw.isNotEmpty && raw[0] is List) {
      final batch = raw[0] as List;
      return batch.map<List<double>>((det) {
        if (det is List) {
          return det.map<double>((v) => (v as num).toDouble()).toList();
        }
        return <double>[];
      }).toList();
    }
    return [];
  }

  List<double> _parseLabels(dynamic raw) {
    if (raw is List && raw.isNotEmpty && raw[0] is List) {
      final batch = raw[0] as List;
      return batch.map<double>((v) {
        if (v is num) return _sigmoid(v.toDouble());
        if (v is List) {
          double maxVal = double.negativeInfinity;
          for (final s in v) {
            final sv = (s as num).toDouble();
            if (sv > maxVal) maxVal = sv;
          }
          return _sigmoid(maxVal);
        }
        return 0.0;
      }).toList();
    }
    return [];
  }

  List<List<double>>? _parseMask(
    dynamic masksRaw,
    int detectionIndex,
    PreprocessedImage preprocessed,
  ) {
    try {
      dynamic maskData;
      if (masksRaw is List && masksRaw.isNotEmpty && masksRaw[0] is List) {
        final batch = masksRaw[0] as List;
        if (detectionIndex < batch.length) {
          maskData = batch[detectionIndex];
        }
      }

      if (maskData == null) return null;

      if (maskData is List && maskData.isNotEmpty && maskData[0] is List) {
        return maskData.map<List<double>>((row) {
          return (row as List).map<double>((v) {
            final val = (v as num).toDouble();
            return val > _maskThreshold ? val : 0.0;
          }).toList();
        }).toList();
      }
    } catch (e) {
      debugPrint('Mask parsing failed: $e');
    }
    return null;
  }

  static double _sigmoid(double x) => 1.0 / (1.0 + math.exp(-x));

  void dispose() {
    _session?.release();
    _session = null;
    _isReady = false;
  }
}
