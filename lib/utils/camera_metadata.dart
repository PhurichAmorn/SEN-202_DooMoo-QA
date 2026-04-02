import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'dart:ui' as ui;
import 'package:exif/exif.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:math' as math;

/// Camera metadata model
class CameraMetadata {
  final double? sensorWidth; // in mm
  final double? sensorHeight; // in mm
  final double? focalLength; // in mm
  final int? imageWidth; // in pixels
  final int? imageHeight; // in pixels
  final double? fNumber; // aperture
  final int? iso; // ISO sensitivity

  CameraMetadata({
    this.sensorWidth,
    this.sensorHeight,
    this.focalLength,
    this.imageWidth,
    this.imageHeight,
    this.fNumber,
    this.iso,
  });

  /// Convert to JSON map for storage
  Map<String, dynamic> toJson() {
    return {
      'sensorWidth': sensorWidth,
      'sensorHeight': sensorHeight,
      'focalLength': focalLength,
      'imageWidth': imageWidth,
      'imageHeight': imageHeight,
      'fNumber': fNumber,
      'iso': iso,
    };
  }

  /// Create from JSON map
  factory CameraMetadata.fromJson(Map<String, dynamic> json) {
    return CameraMetadata(
      sensorWidth: json['sensorWidth']?.toDouble(),
      sensorHeight: json['sensorHeight']?.toDouble(),
      focalLength: json['focalLength']?.toDouble(),
      imageWidth: json['imageWidth']?.toInt(),
      imageHeight: json['imageHeight']?.toInt(),
      fNumber: json['fNumber']?.toDouble(),
      iso: json['iso']?.toInt(),
    );
  }

  @override
  String toString() {
    return 'CameraMetadata('
        'sensorWidth: $sensorWidth mm, '
        'sensorHeight: $sensorHeight mm, '
        'focalLength: $focalLength mm, '
        'imageSize: ${imageWidth}x$imageHeight, '
        'fNumber: $fNumber, '
        'iso: $iso'
        ')';
  }
}

/// Utility class to extract camera metadata from images
class CameraMetadataExtractor {
  static const MethodChannel _channel = MethodChannel('camera_info');

  /// Static flag to disable platform/hardware calls during tests.
  static bool skipHardwareInTests = false;

  /// Extract metadata from image file using EXIF data
  static Future<CameraMetadata> extractFromImage(String imagePath) async {
    double? focalLength;
    int? imageWidth;
    int? imageHeight;
    double? fNumber;
    int? iso;

    final file = File(imagePath);
    late final List<int> bytes;

    try {
      bytes = await file.readAsBytes();
    } catch (e) {
      debugPrint('Error reading file: $e');
      return await _getHardwareMetadata();
    }

    // PRIMARY METHOD: Get image dimensions by decoding the actual image
    try {
      final codec = await ui.instantiateImageCodec(Uint8List.fromList(bytes));
      final frame = await codec.getNextFrame();
      final decodedImage = frame.image;
      imageWidth = decodedImage.width;
      imageHeight = decodedImage.height;
      decodedImage.dispose();
    } catch (e) {
      debugPrint('Could not decode image for dimensions: $e');
    }

    // SECONDARY: Try to extract additional metadata from EXIF data
    try {
      final data = await readExifFromBytes(bytes);

      if (data.isNotEmpty) {
        // Extract focal length
        try {
          if (data.containsKey('EXIF FocalLength')) {
            focalLength = _parseRational(data['EXIF FocalLength']);
          }
        } catch (e) {
          debugPrint('Error extracting focal length: $e');
        }

        // Extract f-number (aperture)
        try {
          if (data.containsKey('EXIF FNumber')) {
            fNumber = _parseRational(data['EXIF FNumber']);
          }
        } catch (e) {
          debugPrint('Error extracting f-number: $e');
        }

        // Extract ISO
        try {
          if (data.containsKey('EXIF ISOSpeedRatings')) {
            final isoTag = data['EXIF ISOSpeedRatings'];
            if (isoTag != null) {
              final values = isoTag.values.toList();
              if (values.isNotEmpty) {
                iso = int.tryParse(values[0].toString());
              }
            }
          }
        } catch (e) {
          debugPrint('Error extracting ISO: $e');
        }

        // If dart:ui decoding failed, try EXIF dimension tags as fallback
        if (imageWidth == null || imageHeight == null) {
          try {
            imageWidth ??= _extractExifInt(data, [
              'EXIF ExifImageWidth',
              'Image ImageWidth',
              'EXIF PixelXDimension',
            ]);
            imageHeight ??= _extractExifInt(data, [
              'EXIF ExifImageLength',
              'Image ImageLength',
              'EXIF PixelYDimension',
            ]);
          } catch (e) {
            debugPrint('Error extracting dimensions from EXIF: $e');
          }
        }
      }
    } catch (e) {
      debugPrint('Error reading EXIF data: $e');
    }

    // Get sensor dimensions from hardware
    final hardwareMetadata = await _getHardwareMetadata();

    return CameraMetadata(
      sensorWidth: hardwareMetadata.sensorWidth,
      sensorHeight: hardwareMetadata.sensorHeight,
      focalLength: focalLength ?? hardwareMetadata.focalLength,
      imageWidth: imageWidth,
      imageHeight: imageHeight,
      fNumber: fNumber,
      iso: iso,
    );
  }

  /// Safely extract an integer value from EXIF data, trying multiple tag names
  static int? _extractExifInt(Map<String, IfdTag> data, List<String> tagNames) {
    for (final tagName in tagNames) {
      if (data.containsKey(tagName)) {
        final tag = data[tagName];
        if (tag != null) {
          final values = tag.values.toList();
          if (values.isNotEmpty) {
            final parsed = int.tryParse(values[0].toString());
            if (parsed != null) return parsed;
          }
        }
      }
    }
    return null;
  }

  /// Get camera hardware metadata directly from device
  static Future<CameraMetadata> _getHardwareMetadata() async {
    if (skipHardwareInTests) return CameraMetadata();
    try {
      final Map<String, dynamic>? cameraInfo =
          await _channel.invokeMapMethod<String, dynamic>('getCameraInfo');

      if (cameraInfo != null) {
        return CameraMetadata(
          sensorWidth: cameraInfo['sensorWidth']?.toDouble(),
          sensorHeight: cameraInfo['sensorHeight']?.toDouble(),
          focalLength: cameraInfo['focalLength']?.toDouble(),
        );
      }
    } catch (e) {
      // Platform channel not implemented or failed
    }

    return CameraMetadata();
  }

  /// Parse EXIF rational number format
  static double? _parseRational(dynamic value) {
    if (value == null) return null;

    if (value is IfdTag) {
      final values = value.values.toList();
      if (values.isNotEmpty) {
        final parts = values[0].toString().split('/');
        if (parts.length == 2) {
          final n = double.tryParse(parts[0]);
          final d = double.tryParse(parts[1]);
          if (n != null && d != null && d != 0) return n / d;
        }
        return double.tryParse(values[0].toString());
      }
    } else if (value is num) {
      return value.toDouble();
    }

    return null;
  }

  /// Calculate sensor dimensions from focal length and field of view
  static CameraMetadata calculateSensorDimensions({
    required double focalLength,
    required double imageWidth,
    required double imageHeight,
    required double fieldOfViewWidth,
    required double fieldOfViewHeight,
  }) {
    final fovWidthRad = fieldOfViewWidth * 3.14159 / 180;
    final fovHeightRad = fieldOfViewHeight * 3.14159 / 180;

    final sensorWidth = 2 * focalLength * math.tan(fovWidthRad / 2);
    final sensorHeight = 2 * focalLength * math.tan(fovHeightRad / 2);

    return CameraMetadata(
      sensorWidth: sensorWidth,
      sensorHeight: sensorHeight,
      focalLength: focalLength,
      imageWidth: imageWidth.toInt(),
      imageHeight: imageHeight.toInt(),
    );
  }
}

/// Cache manager for camera hardware metadata
class CameraMetadataCache {
  static const String _cacheFileName = 'camera_hardware_metadata.json';
  static CameraMetadata? _cachedMetadata;

  /// Get the cache file path
  static Future<String> _getCacheFilePath() async {
    final directory = await getApplicationDocumentsDirectory();
    return '${directory.path}/$_cacheFileName';
  }

  /// Check if cached hardware metadata exists
  static Future<bool> hasCachedMetadata() async {
    try {
      final filePath = await _getCacheFilePath();
      final file = File(filePath);
      return await file.exists();
    } catch (e) {
      return false;
    }
  }

  /// Initialize hardware metadata on first app launch
  static Future<void> initializeHardwareMetadata() async {
    if (CameraMetadataExtractor.skipHardwareInTests) {
      _cachedMetadata = CameraMetadata();
      return;
    }
    if (_cachedMetadata != null) return;

    try {
      final filePath = await _getCacheFilePath();
      final file = File(filePath);

      if (await file.exists()) {
        final jsonString = await file.readAsString();
        final jsonMap = json.decode(jsonString) as Map<String, dynamic>;
        _cachedMetadata = CameraMetadata.fromJson(jsonMap);
        debugPrint('Camera metadata loaded from cache: $_cachedMetadata');
      } else {
        _cachedMetadata = await CameraMetadataExtractor._getHardwareMetadata();
        await _saveToCache(_cachedMetadata!);
        debugPrint(
            'Camera metadata fetched from hardware and cached: $_cachedMetadata');
      }
    } catch (e) {
      debugPrint('Error initializing camera metadata cache: $e');
      _cachedMetadata = CameraMetadata();
    }
  }

  /// Save metadata to cache file
  static Future<void> _saveToCache(CameraMetadata metadata) async {
    if (CameraMetadataExtractor.skipHardwareInTests) return;
    try {
      final filePath = await _getCacheFilePath();
      final file = File(filePath);
      final jsonString = json.encode(metadata.toJson());
      await file.writeAsString(jsonString);
    } catch (e) {
      debugPrint('Error saving camera metadata to cache: $e');
    }
  }

  /// Get the cached hardware metadata
  static CameraMetadata? getCachedMetadata() {
    return _cachedMetadata;
  }

  /// Force refresh the hardware metadata from device
  static Future<CameraMetadata> refreshHardwareMetadata() async {
    _cachedMetadata = await CameraMetadataExtractor._getHardwareMetadata();
    await _saveToCache(_cachedMetadata!);
    return _cachedMetadata!;
  }

  /// Clear the cached metadata
  static Future<void> clearCache() async {
    try {
      final filePath = await _getCacheFilePath();
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }
      _cachedMetadata = null;
    } catch (e) {
      debugPrint('Error clearing camera metadata cache: $e');
    }
  }
}
