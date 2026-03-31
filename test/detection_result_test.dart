import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:DooMoo/models/detection_result.dart';

void main() {
  group('test pig detection model and detection result', () {
    test('where detection result correctly reports count and isEmpty', () {
      final detection = PigDetection(
        boundingBox: Rect.fromLTWH(0, 0, 10, 10),
        confidence: 0.9,
        classId: 0,
      );

      final result = DetectionResult(
        detections: [detection],
        imageWidth: 100,
        imageHeight: 100,
      );

      expect(result.count, 1);
      expect(result.isEmpty, isFalse); // result is not empty
    });

    test('where detection result handles empty detection', () {
      final result = DetectionResult(
        detections: [],
        imageWidth: 100,
        imageHeight: 100,
      );

      expect(result.count, 0);
      expect(result.isEmpty, isTrue); // result is empty
    });

    test('where pig detection copyWith method works correctly', () {
      final original = PigDetection(
        boundingBox: Rect.fromLTWH(0, 0, 10, 10),
        confidence: 0.5,
        classId: 0,
      );

      final updated = original.copyWith(confidence: 0.99);

      expect(updated.confidence, 0.99);
      expect(updated.boundingBox, original.boundingBox);
      expect(updated.classId, original.classId);
    });

    test('where toString methods return expected format', () {
      final detection = PigDetection(
        boundingBox: Rect.fromLTWH(10, 20, 30, 40),
        confidence: 0.85,
        classId: 0,
      );
      final result = DetectionResult(
        detections: [detection],
        imageWidth: 1920,
        imageHeight: 1080,
      );

      expect(detection.toString(), contains('0.85'));
      expect(result.toString(), contains('1920x1080'));
    });
  });
}
