import 'package:flutter_test/flutter_test.dart';
import 'package:doomoo/utils/camera_metadata.dart';

void main() {
  group('CameraMetadata Model Tests', () {
    test('toJson and fromJson should be consistent', () {
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

    test('fromJson handles null values gracefully', () {
      final json = <String, dynamic>{};

      final fromJson = CameraMetadata.fromJson(json);

      expect(fromJson.sensorWidth, isNull);
      expect(fromJson.sensorHeight, isNull);
      expect(fromJson.focalLength, isNull);
      expect(fromJson.imageWidth, isNull);
      expect(fromJson.imageHeight, isNull);
    });

    test('toString returns formatted string', () {
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

  group('CameraMetadataExtractor Calculation Tests', () {
    test('calculateSensorDimensions computes correct values using FOV', () {
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

    test('calculateSensorDimensions handles zero focal length gracefully', () {
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

    test('calculateSensorDimensions handles extreme FOV (edge case)', () {
      // 179 degrees FOV (fisheye-like)
      final result = CameraMetadataExtractor.calculateSensorDimensions(
        focalLength: 5.0,
        imageWidth: 1000,
        imageHeight: 800,
        fieldOfViewWidth: 179.0,
        fieldOfViewHeight: 10.0,
      );

      expect(result.sensorWidth, greaterThan(500.0)); // tan(89.5) is very large
      expect(result.sensorHeight, closeTo(0.874, 0.1));
    });
  });
}
