import 'package:flutter_test/flutter_test.dart';
import 'package:DooMoo/utils/pig_math.dart';

void main() {
  group('test pixel to metric conversion', () {
    const focalLength = 5.24;
    const sensorWidth = 7.68;
    const sensorHeight = 5.76;
    const imageWidth = 3000;
    const imageHeight = 4000;
    const distanceMm = 1000.0;

    test('when inputs are valid then calculates correct metric value', () {
      final pixelLength = 1000.0;

      final resultMm = PigMath.pixelToMm(
        pixelLength: pixelLength,
        distanceMm: distanceMm,
        focalLength: focalLength,
        sensorWidth: sensorWidth,
        sensorHeight: sensorHeight,
        imageWidth: imageWidth,
        imageHeight: imageHeight,
      );

      expect(resultMm, closeTo(381.679, 0.001));
    });

    test('when pixel length changes then result scales proportionally', () {
      final pixelLength = 500.0;

      final resultMm = PigMath.pixelToMm(
        pixelLength: pixelLength,
        distanceMm: distanceMm,
        focalLength: focalLength,
        sensorWidth: sensorWidth,
        sensorHeight: sensorHeight,
        imageWidth: imageWidth,
        imageHeight: imageHeight,
      );

      expect(resultMm, closeTo(190.8395, 0.001));
    });

    test('when pixel length is zero then returns zero', () {
      final pixelLength = 0.0;

      final resultMm = PigMath.pixelToMm(
        pixelLength: pixelLength,
        distanceMm: distanceMm,
        focalLength: focalLength,
        sensorWidth: sensorWidth,
        sensorHeight: sensorHeight,
        imageWidth: imageWidth,
        imageHeight: imageHeight,
      );

      expect(resultMm, 0);
    });

    test('when distance increases then real world size increases', () {
      final distanceMmIncrease = 2000.0;
      final pixelLength = 1000.0;

      final resultMm = PigMath.pixelToMm(
        pixelLength: pixelLength,
        distanceMm: distanceMmIncrease,
        focalLength: focalLength,
        sensorWidth: sensorWidth,
        sensorHeight: sensorHeight,
        imageWidth: imageWidth,
        imageHeight: imageHeight,
      );

      expect(resultMm, closeTo(763.3587, 0.001));
    });

    test('when pixel length is very small then still computes value', () {
      final pixelLength = 0.0001;

      final resultMm = PigMath.pixelToMm(
        pixelLength: pixelLength,
        distanceMm: distanceMm,
        focalLength: focalLength,
        sensorWidth: sensorWidth,
        sensorHeight: sensorHeight,
        imageWidth: imageWidth,
        imageHeight: imageHeight,
      );

      expect(resultMm, closeTo(0.0000381679, 0.0000000001));
    });

    test('when pixel length is extremely large then still returns value', () {
      final pixelLength = 1000000.0;

      final resultMm = PigMath.pixelToMm(
        pixelLength: pixelLength,
        distanceMm: distanceMm,
        focalLength: focalLength,
        sensorWidth: sensorWidth,
        sensorHeight: sensorHeight,
        imageWidth: imageWidth,
        imageHeight: imageHeight,
      );

      expect(resultMm, closeTo(381679.389, 0.001));
    });

    test('edge case: 1x1 image', () {
      final px = 1.0;
      final dist = 1000.0;
      final f = 5.0;
      final sw = 5.0;
      final sh = 5.0;
      final iw = 1;
      final ih = 1;

      final resultMm = PigMath.pixelToMm(
        pixelLength: px,
        distanceMm: dist,
        focalLength: f,
        sensorWidth: sw,
        sensorHeight: sh,
        imageWidth: iw,
        imageHeight: ih,
      );

      expect(resultMm, closeTo(1000.0, 0.001));
    });

    test('when focal length is zero then returns null', () {
      final f = 0.0;

      final resultMm = PigMath.pixelToMm(
        pixelLength: 1000.0,
        distanceMm: 1000.0,
        focalLength: f,
        sensorWidth: sensorWidth,
        sensorHeight: sensorHeight,
        imageWidth: imageWidth,
        imageHeight: imageHeight,
      );

      expect(resultMm, isNull);
    });

    test('when image width is zero then returns null', () {
      final iw = 0;

      final resultMm = PigMath.pixelToMm(
        pixelLength: 1000.0,
        distanceMm: 1000.0,
        focalLength: focalLength,
        sensorWidth: sensorWidth,
        sensorHeight: sensorHeight,
        imageWidth: iw,
        imageHeight: imageHeight,
      );

      expect(resultMm, isNull);
    });

    test('when sensor width is zero then returns null', () {
      final sw = 0.0;

      final resultMm = PigMath.pixelToMm(
        pixelLength: 1000.0,
        distanceMm: 1000.0,
        focalLength: focalLength,
        sensorWidth: sw,
        sensorHeight: sensorHeight,
        imageWidth: imageWidth,
        imageHeight: imageHeight,
      );

      expect(resultMm, isNull);
    });

    test('when sensor height is zero then returns null', () {
      final sh = 0.0;

      final resultMm = PigMath.pixelToMm(
        pixelLength: 1000.0,
        distanceMm: 1000.0,
        focalLength: focalLength,
        sensorWidth: sensorWidth,
        sensorHeight: sh,
        imageWidth: imageWidth,
        imageHeight: imageHeight,
      );

      expect(resultMm, isNull);
    });

    test('when distance is zero then returns null', () {
      final dist = 0.0;

      final resultMm = PigMath.pixelToMm(
        pixelLength: 1000.0,
        distanceMm: dist,
        focalLength: focalLength,
        sensorWidth: sensorWidth,
        sensorHeight: sensorHeight,
        imageWidth: imageWidth,
        imageHeight: imageHeight,
      );

      expect(resultMm, isNull);
    });

    test('when distance is negative then returns null', () {
      final dist = -1.0;

      final resultMm = PigMath.pixelToMm(
        pixelLength: 1000.0,
        distanceMm: dist,
        focalLength: focalLength,
        sensorWidth: sensorWidth,
        sensorHeight: sensorHeight,
        imageWidth: imageWidth,
        imageHeight: imageHeight,
      );

      expect(resultMm, isNull);
    });

    test('when focal length is negative then returns null', () {
      final f = -5.24;

      final resultMm = PigMath.pixelToMm(
        pixelLength: 1000.0,
        distanceMm: 1000.0,
        focalLength: f,
        sensorWidth: sensorWidth,
        sensorHeight: sensorHeight,
        imageWidth: imageWidth,
        imageHeight: imageHeight,
      );

      expect(resultMm, isNull);
    });

    test('when multiple parameters are invalid then returns null', () {
      final pl = -50.0;
      final d = -100.0;
      final f = 0.0;

      final resultMm = PigMath.pixelToMm(
        pixelLength: pl,
        distanceMm: d,
        focalLength: f,
        sensorWidth: 0.0,
        sensorHeight: 5.76,
        imageWidth: 0,
        imageHeight: 4000,
      );

      expect(resultMm, isNull);
    });
  });
}
