import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:doomoo/utils/pig_measurements.dart';

void main() {
  group('test PCA measurements', () {
    test('when the mask is a 10x20 rectangle', () {
      final mask = List.generate(
          50,
          (y) => List.generate(
              50, (x) => (x >= 15 && x < 25 && y >= 15 && y < 35) ? 1.0 : 0.0));
      final boundingBox = Rect.fromLTWH(15, 15, 10, 20);

      final measurements = PigMeasurements.fromMask(
        mask,
        boundingBox,
      );

      expect(measurements, isNotNull);
      expect(measurements!.length, closeTo(19.0, 1.0));
      expect(measurements.widthTop, closeTo(9.0, 1.0));
      expect(measurements.widthMiddle, closeTo(9.0, 1.0));
      expect(measurements.widthBottom, closeTo(9.0, 1.0));
    });

    test('when the mask is a single pixel', () {
      final mask = List.generate(50,
          (y) => List.generate(50, (x) => (x == 25 && y == 25) ? 1.0 : 0.0));
      final boundingBox = Rect.fromLTWH(20, 20, 10, 10);

      final measurements = PigMeasurements.fromMask(
        mask,
        boundingBox,
      );

      expect(measurements, isNull);
    });

    test('when the mask has no pixels above the threshold', () {
      final mask = List.generate(50, (y) => List.generate(50, (x) => 0.0));
      final boundingBox = Rect.fromLTWH(0, 0, 50, 50);

      final measurements = PigMeasurements.fromMask(
        mask,
        boundingBox,
      );

      expect(measurements, isNull);
    });

    test('when the mask is a trapezoid-like shape', () {
      // Create a trapezoid-like shape (tapered rectangle)
      // Top (y=10) width is 10, Bottom (y=30) width is 20
      final mask = List.generate(50, (y) => List.generate(50, (x) => 0.0));
      for (int y = 10; y <= 30; y++) {
        double widthAtY = 10 + (y - 10) * (10 / 20); // 10 at y=10, 20 at y=30
        int startX = (25 - widthAtY / 2).round();
        int endX = (25 + widthAtY / 2).round();
        for (int x = startX; x <= endX; x++) {
          mask[y][x] = 1.0;
        }
      }
      final boundingBox = Rect.fromLTWH(10, 10, 30, 20);

      final measurementsShift1 = PigMeasurements.fromMask(
        mask,
        boundingBox,
        fracShift: 0.1,
      );
      final measurementsShift2 = PigMeasurements.fromMask(
        mask,
        boundingBox,
        fracShift: 0.4,
      );

      expect(measurementsShift1, isNotNull);
      expect(measurementsShift2, isNotNull);

      // Verify that changing fracShift actually changes where we measure
      expect(measurementsShift1!.widthTop,
          isNot(closeTo(measurementsShift2!.widthTop, 0.001)));
      expect(measurementsShift1.widthBottom,
          isNot(closeTo(measurementsShift2.widthBottom, 0.001)));

      expect(measurementsShift1.widthTop,
          isNot(closeTo(measurementsShift1.widthBottom, 0.001)));
    });
    test('when the mask is a rotated rectangle', () {
      final mask = List.generate(50, (y) => List.generate(50, (x) => 0.0));

      // Create a diagonal (rotated) rectangle
      for (int i = 10; i < 30; i++) {
        for (int w = -3; w <= 3; w++) {
          int x = i;
          int y = i + w; // diagonal
          if (x >= 0 && x < 50 && y >= 0 && y < 50) {
            mask[y][x] = 1.0;
          }
        }
      }

      final boundingBox = Rect.fromLTWH(10, 10, 30, 30);

      final measurements = PigMeasurements.fromMask(mask, boundingBox);

      expect(measurements, isNotNull);

      expect(measurements!.length, closeTo(28.28, 1.0));
    });
    test('mask with noise still produces stable measurement', () {
      final mask = List.generate(
          50,
          (y) => List.generate(
              50, (x) => (x >= 15 && x < 25 && y >= 15 && y < 35) ? 1.0 : 0.0));

      // Add noise
      mask[10][10] = 1.0;
      mask[40][40] = 1.0;

      final boundingBox = Rect.fromLTWH(15, 15, 10, 20);

      final measurements = PigMeasurements.fromMask(mask, boundingBox);

      expect(measurements, isNotNull);
      expect(measurements!.length, closeTo(20.0, 2.0));
    });
  });
}
