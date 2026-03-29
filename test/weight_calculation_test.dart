import 'package:flutter_test/flutter_test.dart';
import 'package:DooMoo/utils/pig_math.dart';

void main() {
  group('test weight regression model', () {
    test('when input is null then output is dash', () {
      final bodyLength = 100.0;
      final chestWidth = 100.0;
      final abdominalWidth = 100.0;
      final hipWidth = 100.0;

      expect(
          PigMath.estimateWeight(
              bodyLengthMm: null,
              chestWidthMm: chestWidth,
              abdominalWidthMm: abdominalWidth,
              hipWidthMm: hipWidth),
          '-',
          reason: 'Should return "-" if bodyLengthMm is null');

      expect(
          PigMath.estimateWeight(
              bodyLengthMm: bodyLength,
              chestWidthMm: null,
              abdominalWidthMm: abdominalWidth,
              hipWidthMm: hipWidth),
          '-',
          reason: 'Should return "-" if chestWidthMm is null');

      expect(
          PigMath.estimateWeight(
              bodyLengthMm: bodyLength,
              chestWidthMm: chestWidth,
              abdominalWidthMm: null,
              hipWidthMm: hipWidth),
          '-',
          reason: 'Should return "-" if abdominalWidthMm is null');

      expect(
          PigMath.estimateWeight(
              bodyLengthMm: bodyLength,
              chestWidthMm: chestWidth,
              abdominalWidthMm: abdominalWidth,
              hipWidthMm: null),
          '-',
          reason: 'Should return "-" if hipWidthMm is null');
    });

    test('when input is zero then output is dash', () {
      final zero = 0.0;

      final result = PigMath.estimateWeight(
          bodyLengthMm: zero,
          chestWidthMm: zero,
          abdominalWidthMm: zero,
          hipWidthMm: zero);

      expect(result, '-');
    });

    test('boundary case: very tiny pig resulting in negative weight', () {
      final tiny = 10.0;

      final result = PigMath.estimateWeight(
          bodyLengthMm: tiny,
          chestWidthMm: tiny,
          abdominalWidthMm: tiny,
          hipWidthMm: tiny);

      expect(result, '-');
    });

    test('weight scales correctly for different pig sizes', () {
      final testCases = [
        {
          'len': 450.0,
          'chest': 150.0,
          'abd': 180.0,
          'hip': 160.0,
          'expected': '14.0 kg'
        },
        {
          'len': 800.0,
          'chest': 300.0,
          'abd': 350.0,
          'hip': 320.0,
          'expected': '46.3 kg'
        },
        {
          'len': 1200.0,
          'chest': 600.0,
          'abd': 650.0,
          'hip': 620.0,
          'expected': '98.9 kg'
        },
      ];

      for (var c in testCases) {
        final result = PigMath.estimateWeight(
            bodyLengthMm: c['len'] as double?,
            chestWidthMm: c['chest'] as double?,
            abdominalWidthMm: c['abd'] as double?,
            hipWidthMm: c['hip'] as double?);

        expect(result, c['expected'], reason: 'Failed for inputs: $c');
      }
    });

    test('when inputs are valid then calculates correct weight', () {
      final bodyLength = 450.0;
      final chestWidth = 150.0;
      final abdominalWidth = 180.0;
      final hipWidth = 160.0;

      final result = PigMath.estimateWeight(
          bodyLengthMm: bodyLength,
          chestWidthMm: chestWidth,
          abdominalWidthMm: abdominalWidth,
          hipWidthMm: hipWidth);

      expect(result, '14.0 kg');
    });

    test('when inputs are not valid (too small) then output is dash', () {
      final bodyLength = 450.0;
      final chestWidth = 150.0;
      final abdominalWidth = 1.0;
      final hipWidth = 1.0;

      final result = PigMath.estimateWeight(
          bodyLengthMm: bodyLength,
          chestWidthMm: chestWidth,
          abdominalWidthMm: abdominalWidth,
          hipWidthMm: hipWidth);

      expect(result, '-');
    });
  });
}
