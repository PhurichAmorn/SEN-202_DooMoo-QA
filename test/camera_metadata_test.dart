import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:doomoo/utils/camera_metadata.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('test camera metadata', () {
    test('where toJson and fromJson should be consistent', () {
      final original = CameraMetadata(
        sensorWidth: 6.17,
        sensorHeight: 4.55,
        focalLength: 4.25,
        imageWidth: 4000,
        imageHeight: 3000,
        fNumber: 1.8,
        iso: 100,
      );

      final json = original.toJson();
      final fromJson = CameraMetadata.fromJson(json);

      expect(fromJson.sensorWidth, original.sensorWidth);
      expect(fromJson.sensorHeight, original.sensorHeight);
      expect(fromJson.focalLength, original.focalLength);
      expect(fromJson.imageWidth, original.imageWidth);
      expect(fromJson.imageHeight, original.imageHeight);
      expect(fromJson.fNumber, original.fNumber);
      expect(fromJson.iso, original.iso);
    });

    test('where fromJson handles null values gracefully', () {
      final json = <String, dynamic>{};

      final fromJson = CameraMetadata.fromJson(json);

      expect(fromJson.sensorWidth, isNull);
      expect(fromJson.sensorHeight, isNull);
      expect(fromJson.focalLength, isNull);
      expect(fromJson.imageWidth, isNull);
      expect(fromJson.imageHeight, isNull);
    });

    test('where toString returns formatted string', () {
      final metadata = CameraMetadata(
        sensorWidth: 5.0,
        sensorHeight: 4.0,
        imageWidth: 100,
        imageHeight: 100,
      );

      final result = metadata.toString();

      expect(result, contains('5.0 mm'));
      expect(result, contains('100x100'));
    });
  });

  group('test CameraMetadataExtractor calculation', () {
    test('where calculateSensorDimensions computes correct values using FOV',
        () {
      final focalLength = 5.0;
      final fovWidth = 60.0;
      final fovHeight = 40.0;

      final result = CameraMetadataExtractor.calculateSensorDimensions(
        focalLength: focalLength,
        imageWidth: 1000,
        imageHeight: 800,
        fieldOfViewWidth: fovWidth,
        fieldOfViewHeight: fovHeight,
      );

      // sensor_size = 2 * focal_length * tan(FOV/2)
      // 2 * 5 * tan(30 deg) = 10 * 0.57735 = 5.7735
      // 2 * 5 * tan(20 deg) = 10 * 0.36397 = 3.6397
      expect(result.sensorWidth, closeTo(5.7735, 0.001));
      expect(result.sensorHeight, closeTo(3.6397, 0.001));
      expect(result.imageWidth, 1000);
      expect(result.imageHeight, 800);
    });

    test('where calculateSensorDimensions handles zero focal length gracefully',
        () {
      final result = CameraMetadataExtractor.calculateSensorDimensions(
        focalLength: 0.0,
        imageWidth: 1000,
        imageHeight: 800,
        fieldOfViewWidth: 60.0,
        fieldOfViewHeight: 40.0,
      );

      expect(result.sensorWidth, 0.0);
      expect(result.sensorHeight, 0.0);
    });

    test('where calculateSensorDimensions handles extreme FOV', () {
      // 179 degrees FOV (fisheye-like)
      final result = CameraMetadataExtractor.calculateSensorDimensions(
        focalLength: 5.0,
        imageWidth: 1000,
        imageHeight: 800,
        fieldOfViewWidth: 179.0,
        fieldOfViewHeight: 10.0,
      );

      expect(result.sensorWidth, closeTo(1145, 10));
      expect(result.sensorHeight, closeTo(0.874, 0.1));
    });
  });

  group('test failure modes and fallback', () {
    const channel = MethodChannel('camera_info');

    test('where extractFromImage falls back to hardware info on invalid path',
        () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (methodCall) async {
        if (methodCall.method == 'getCameraInfo') {
          return {
            'sensorWidth': 6.0,
            'sensorHeight': 4.0,
            'focalLength': 5.0,
          };
        }
        return null;
      });

      final result = await CameraMetadataExtractor.extractFromImage(
          'invalid/path/image.jpg');

      expect(result.sensorWidth, 6.0);
      expect(result.sensorHeight, 4.0);
      expect(result.focalLength, 5.0);
      expect(result.imageWidth, isNull);

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test(
        'where extractFromImage returns empty metadata if both file and hardware fail',
        () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (methodCall) async {
        return null; // Simulate hardware info unavailable
      });

      final result =
          await CameraMetadataExtractor.extractFromImage('nonexistent.png');

      expect(result.sensorWidth, isNull);
      expect(result.focalLength, isNull);
      expect(result.imageWidth, isNull);

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('where extractFromImage handles platform channel exception', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (methodCall) async {
        throw PlatformException(code: 'ERROR', message: 'Failed');
      });

      final result =
          await CameraMetadataExtractor.extractFromImage('nonexistent.png');

      expect(result.sensorWidth, isNull);
      expect(result.focalLength, isNull);

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });
  });

  group('test CameraMetadataCache error handling', () {
    const channel = MethodChannel('plugins.flutter.io/path_provider');

    setUp(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (methodCall) async {
        if (methodCall.method == 'getApplicationDocumentsDirectory') {
          return '.';
        }
        return null;
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('where hasCachedMetadata returns false on error', () async {
      // Simulate an error by setting path provider handler to throw
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (methodCall) async {
        throw Exception('Path provider failed');
      });

      final hasCache = await CameraMetadataCache.hasCachedMetadata();
      expect(hasCache, isFalse);
    });

    test('where initializeHardwareMetadata handles file read error', () async {
      // If we don't mock the file system, it might throw or just not find the file.
      // The current implementation has a broad try-catch.
      await CameraMetadataCache.initializeHardwareMetadata();
      expect(CameraMetadataCache.getCachedMetadata(), isNotNull);
    });

    test('where clearCache handles error', () async {
      // This should not throw even if file operations fail
      await CameraMetadataCache.clearCache();
      expect(CameraMetadataCache.getCachedMetadata(), isNull);
    });
  });
}
