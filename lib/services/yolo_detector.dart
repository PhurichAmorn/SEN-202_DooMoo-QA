import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:onnxruntime_v2/onnxruntime_v2.dart';
import 'package:image/image.dart' as img;
import 'package:doomoo/models/detection_result.dart';
import 'package:doomoo/utils/coordinate_utils.dart';
import 'dart:io';

/// YOLOv8 object detector.
class YoloDetector {
  /// Static flag to disable ONNX and return mock data during tests.
  static bool skipInTests = false;

  static YoloDetector? _instance;
  OrtSession? _session;
  bool _isReady = false;
  static bool _envInitialized = false;

  static const String _modelAsset = 'assets/models/yolov8_pig.onnx';
  static const int _inputSize = 640;
  static const double _confidenceThreshold = 0.25;
  static const double _iouThreshold = 0.45;

  static Future<YoloDetector> getInstance() async {
    _instance ??= YoloDetector._internal();
    return _instance!;
  }

  YoloDetector._internal();

  @visibleForTesting
  static void setMockInstance(dynamic mock) {
    // Keep for test compatibility
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
      debugPrint('Failed to load YOLO model: $e');
      rethrow;
    }
  }

  Future<List<PigDetection>> detect(String imagePath) async {
    if (skipInTests) {
      return [
        const PigDetection(
          boundingBox: Rect.fromLTRB(100, 100, 500, 500),
          confidence: 0.9,
          classId: 0,
        ),
      ];
    }

    if (!_isReady || _session == null) {
      await _loadModel();
    }

    try {
      final bytes = File(imagePath).readAsBytesSync();
      final image = img.decodeImage(bytes);
      if (image == null) return [];

      final originalWidth = image.width;
      final originalHeight = image.height;

      final resized =
          img.copyResize(image, width: _inputSize, height: _inputSize);

      final channelSize = _inputSize * _inputSize;
      final inputData = Float32List(1 * 3 * channelSize);
      for (int y = 0; y < _inputSize; y++) {
        for (int x = 0; x < _inputSize; x++) {
          final pixel = resized.getPixel(x, y);
          final idx = y * _inputSize + x;
          inputData[0 * channelSize + idx] = pixel.r / 255.0;
          inputData[1 * channelSize + idx] = pixel.g / 255.0;
          inputData[2 * channelSize + idx] = pixel.b / 255.0;
        }
      }

      final inputTensor = OrtValueTensor.createTensorWithDataList(
        inputData,
        [1, 3, _inputSize, _inputSize],
      );

      final runOptions = OrtRunOptions();
      final outputs = await _session!.runAsync(
        runOptions,
        {'images': inputTensor},
      );

      if (outputs == null || outputs.isEmpty || outputs[0] == null) {
        inputTensor.release();
        runOptions.release();
        return [];
      }

      final outputValue = outputs[0]!.value as List<List<List<double>>>;
      final result =
          _postprocess(outputValue[0], originalWidth, originalHeight);

      inputTensor.release();
      runOptions.release();
      for (var out in outputs) {
        out?.release();
      }

      return result;
    } catch (e) {
      debugPrint('Object detection failed: $e');
      return [];
    }
  }

  List<PigDetection> _postprocess(
      List<List<double>> output, int imgW, int imgH) {
    List<PigDetection> candidates = [];
    final int numBoxes = output[0].length;

    for (int i = 0; i < numBoxes; i++) {
      final score = output[4][i];
      if (score < _confidenceThreshold) continue;

      final rect = CoordinateUtils.mapYoloToImagePixels(
        cx: output[0][i],
        cy: output[1][i],
        w: output[2][i],
        h: output[3][i],
        inputSize: _inputSize,
        imgW: imgW,
        imgH: imgH,
      );

      candidates.add(PigDetection(
        boundingBox: rect,
        confidence: score,
        classId: 0,
      ));
    }

    return _nms(candidates);
  }

  List<PigDetection> _nms(List<PigDetection> boxes) {
    if (boxes.isEmpty) return [];
    boxes.sort((a, b) => b.confidence.compareTo(a.confidence));

    List<PigDetection> selected = [];
    List<bool> active = List.filled(boxes.length, true);

    for (int i = 0; i < boxes.length; i++) {
      if (!active[i]) continue;
      selected.add(boxes[i]);
      for (int j = i + 1; j < boxes.length; j++) {
        if (!active[j]) continue;
        if (_iou(boxes[i].boundingBox, boxes[j].boundingBox) > _iouThreshold) {
          active[j] = false;
        }
      }
    }
    return selected;
  }

  double _iou(Rect a, Rect b) {
    final intersection = a.intersect(b);
    if (intersection.width <= 0 || intersection.height <= 0) return 0.0;
    final intersectionArea = intersection.width * intersection.height;
    final unionArea =
        a.width * a.height + b.width * b.height - intersectionArea;
    return intersectionArea / unionArea;
  }

  void dispose() {
    _session?.release();
    _session = null;
    _isReady = false;
  }
}
