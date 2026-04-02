import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:doomoo/utils/camera_metadata.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('test camera metadata', () {
    test('where toJson and fromJson are called then they are consistent', () {
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

    test('where fromJson handles null values then it returns empty metadata',
        () {
      final json = <String, dynamic>{};

      final fromJson = CameraMetadata.fromJson(json);

      expect(fromJson.sensorWidth, isNull);
      expect(fromJson.sensorHeight, isNull);
      expect(fromJson.focalLength, isNull);
      expect(fromJson.imageWidth, isNull);
      expect(fromJson.imageHeight, isNull);
    });

    test('where toString is called then it returns formatted string', () {
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

  group('test camera metadata extractor calculation', () {
    test(
        'where calculateSensorDimensions uses FOV then it computes correct values',
        () {
      const focalLength = 5.0;
      const fovWidth = 60.0;
      const fovHeight = 40.0;

      final result = CameraMetadataExtractor.calculateSensorDimensions(
        focalLength: focalLength,
        imageWidth: 1000,
        imageHeight: 800,
        fieldOfViewWidth: fovWidth,
        fieldOfViewHeight: fovHeight,
      );

      expect(result.sensorWidth, closeTo(5.7735, 0.001));
      expect(result.sensorHeight, closeTo(3.6397, 0.001));
      expect(result.imageWidth, 1000);
      expect(result.imageHeight, 800);
    });

    test('where focal length is zero then dimensions are zero', () {
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

    test('where FOV is extreme then it still computes dimensions', () {
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

  group('test camera metadata failure modes', () {
    const channel = MethodChannel('camera_info');

    test('where image path is invalid then it falls back to hardware info',
        () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (methodCall) async {
        if (methodCall.method == 'getCameraInfo') {
          return {'sensorWidth': 6.0, 'sensorHeight': 4.0, 'focalLength': 5.0};
        }
        return null;
      });

      final result =
          await CameraMetadataExtractor.extractFromImage('invalid.jpg');

      expect(result.sensorWidth, 6.0);
      expect(result.sensorHeight, 4.0);
      expect(result.focalLength, 5.0);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('where both file and hardware fail then it returns empty metadata',
        () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (methodCall) async => null);

      final result = await CameraMetadataExtractor.extractFromImage('none.png');

      expect(result.sensorWidth, isNull);
      expect(result.focalLength, isNull);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('where platform channel throws then it handles exception gracefully',
        () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (methodCall) async {
        throw PlatformException(code: 'ERROR', message: 'Failed');
      });

      final result = await CameraMetadataExtractor.extractFromImage('none.png');

      expect(result.sensorWidth, isNull);
      expect(result.focalLength, isNull);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });
  });

  group('test camera metadata cache error handling', () {
    const channel = MethodChannel('plugins.flutter.io/path_provider');

    setUp(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (methodCall) async {
        if (methodCall.method == 'getApplicationDocumentsDirectory') return '.';
        return null;
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('where path provider fails then hasCachedMetadata returns false',
        () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (methodCall) async {
        throw Exception('Path provider failed');
      });

      final hasCache = await CameraMetadataCache.hasCachedMetadata();

      expect(hasCache, isFalse);
    });

    test('where file read fails then initializeHardwareMetadata handles it',
        () async {
      await CameraMetadataCache.initializeHardwareMetadata();

      expect(CameraMetadataCache.getCachedMetadata(), isNotNull);
    });

    test('where clearCache is called then it handles errors gracefully',
        () async {
      await CameraMetadataCache.clearCache();

      expect(CameraMetadataCache.getCachedMetadata(), isNull);
    });
  });
}
