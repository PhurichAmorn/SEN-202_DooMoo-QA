import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:doomoo/models/detection_result.dart';

void main() {
  group('test detection result', () {
    test(
        'where detection result is created then it correctly reports count and isEmpty',
        () {
      final detection = PigDetection(
        boundingBox: const Rect.fromLTWH(0, 0, 10, 10),
        confidence: 0.9,
        classId: 0,
      );

      final result = DetectionResult(
        detections: [detection],
        imageWidth: 100,
        imageHeight: 100,
      );

      expect(result.count, 1);
      expect(result.isEmpty, isFalse);
    });

    test('where detection result has no detections then it is empty', () {
      const result = DetectionResult(
        detections: [],
        imageWidth: 100,
        imageHeight: 100,
      );

      expect(result.count, 0);
      expect(result.isEmpty, isTrue);
    });

    test(
        'where pig detection copyWith is called then it returns updated object',
        () {
      final original = PigDetection(
        boundingBox: const Rect.fromLTWH(0, 0, 10, 10),
        confidence: 0.5,
        classId: 0,
      );

      final updated = original.copyWith(confidence: 0.99);

      expect(updated.confidence, 0.99);
      expect(updated.boundingBox, original.boundingBox);
    });

    test(
        'where detection result copyWith is called then it returns updated object',
        () {
      const original = DetectionResult(
        detections: [],
        imageWidth: 100,
        imageHeight: 100,
      );

      final updated = original.copyWith(imageWidth: 200);

      expect(updated.imageWidth, 200);
      expect(updated.imageHeight, 100);
    });

    test('where toString is called then it returns expected format', () {
      final detection = PigDetection(
        boundingBox: const Rect.fromLTWH(10, 20, 30, 40),
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
