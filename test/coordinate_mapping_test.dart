import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:DooMoo/utils/coordinate_utils.dart';

void main() {
  group('test YOLO coordinate mapping', () {
    test('where center box scales correctly', () {
      // Bounding box at center (320, 320) with size (100, 100) in a 640x640 model
      // Original image is 4000x3000
      final result = CoordinateUtils.mapYoloToImagePixels(
        cx: 320.0,
        cy: 320.0,
        w: 100.0,
        h: 100.0,
        inputSize: 640,
        imgW: 4000,
        imgH: 3000,
      );

      // Scaled cx = 320 * 4000 / 640 = 2000
      // Scaled cy = 320 * 3000 / 640 = 1500
      // Scaled w = 100 * 4000 / 640 = 625
      // Scaled h = 100 * 3000 / 640 = 468.75
      // Left = 2000 - 625/2 = 1687.5
      // Top = 1500 - 468.75/2 = 1265.625
      expect(result.left, 1687.5);
      expect(result.top, 1265.625);
      expect(result.width, 625.0);
      expect(result.height, 468.75);
    });

    test('where coordinates at limits (center 320 with full size 640)', () {
      final result = CoordinateUtils.mapYoloToImagePixels(
        cx: 320.0,
        cy: 320.0,
        w: 640.0,
        h: 640.0,
        inputSize: 640,
        imgW: 1000,
        imgH: 1000,
      );

      // Entire image should be covered
      expect(result.left, 0.0);
      expect(result.top, 0.0);
      expect(result.right, 1000.0);
      expect(result.bottom, 1000.0);
    });

    test('where coordinates are clamped when out of bounds', () {
      final result = CoordinateUtils.mapYoloToImagePixels(
        cx: -100.0,
        cy: 1000.0,
        w: 100.0,
        h: 100.0,
        inputSize: 640,
        imgW: 1000,
        imgH: 1000,
      );

      expect(result.left, 0.0);
      expect(result.bottom, 1000.0);
    });

    test('where zero dimensions result in zero rectangle', () {
      final result = CoordinateUtils.mapYoloToImagePixels(
        cx: 100.0,
        cy: 100.0,
        w: 50.0,
        h: 50.0,
        inputSize: 0,
        imgW: 1000,
        imgH: 1000,
      );

      expect(result, Rect.zero);
    });
  });
}
