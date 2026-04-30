import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:DooMoo/utils/pig_math.dart';
import 'package:DooMoo/utils/pig_measurements.dart';

// ─── Helpers ────────────────────────────────────────────────────────────────

/// Camera metadata representative of a Xiaomi Note 14 (used in app development)
const _focalLength = 5.24;
const _sensorWidth = 7.68;
const _sensorHeight = 5.76;
const _imageWidth = 3000;
const _imageHeight = 4000;
const _distanceMm = 1500.0;

/// Renders a filled ellipse into a [rows × cols] mask (1.0 inside, 0.0 outside).
List<List<double>> _makeEllipseMask(int cols, int rows) {
  final cx = cols / 2.0;
  final cy = rows / 2.0;
  final a = cols * 0.40; // half-width
  final b = rows * 0.35; // half-height
  return List.generate(rows, (y) {
    return List.generate(cols, (x) {
      final dx = (x - cx) / a;
      final dy = (y - cy) / b;
      return (dx * dx + dy * dy) <= 1.0 ? 1.0 : 0.0;
    });
  });
}

String _bar(double fraction, {int width = 30}) {
  final filled = (fraction.clamp(0.0, 1.0) * width).round();
  return '[' + '█' * filled + '░' * (width - filled) + ']';
}

// ─── Tests ───────────────────────────────────────────────────────────────────

void main() {
  // ===========================================================================
  // 1. LOAD TESTING — PigMath.pixelToMm
  //    Simulates the normal per-frame computation rate when a user holds the
  //    camera over a pig and the app continuously measures pixel distances.
  //    "Load" here = sustained stream of conversion requests.
  // ===========================================================================
  group('Load Test · PigMath.pixelToMm', () {
    test('1,000 calls at normal camera params → throughput & avg latency', () {
      const n = 1000;
      final sw = Stopwatch()..start();

      for (int i = 0; i < n; i++) {
        PigMath.pixelToMm(
          pixelLength: 800.0 + i * 0.4,
          distanceMm: _distanceMm,
          focalLength: _focalLength,
          sensorWidth: _sensorWidth,
          sensorHeight: _sensorHeight,
          imageWidth: _imageWidth,
          imageHeight: _imageHeight,
        );
      }

      sw.stop();
      final totalUs = sw.elapsedMicroseconds;
      final avgUs = totalUs / n;
      final throughput = n / (totalUs / 1e6);

      print('\n══════════════════════════════════════════════════');
      print(' Load Test · pixelToMm · $n calls');
      print('══════════════════════════════════════════════════');
      print(
        ' Total time   : ${totalUs} µs  (${(totalUs / 1000).toStringAsFixed(2)} ms)',
      );
      print(' Avg per call : ${avgUs.toStringAsFixed(3)} µs');
      print(' Throughput   : ${throughput.toStringAsFixed(0)} calls / sec');
      print('══════════════════════════════════════════════════\n');

      expect(
        avgUs,
        lessThan(1000),
        reason: 'Each pixel-to-mm conversion must complete under 1 ms',
      );
    });

    test(
      '10,000 calls with varied pixel lengths → stability under sustained load',
      () {
        const n = 10000;
        final sw = Stopwatch()..start();
        int nullResults = 0;

        for (int i = 0; i < n; i++) {
          final result = PigMath.pixelToMm(
            pixelLength: 200.0 + (i % 2400) * 0.5,
            distanceMm: 800.0 + (i % 1200),
            focalLength: _focalLength,
            sensorWidth: _sensorWidth,
            sensorHeight: _sensorHeight,
            imageWidth: _imageWidth,
            imageHeight: _imageHeight,
          );
          if (result == null) nullResults++;
        }

        sw.stop();
        final totalUs = sw.elapsedMicroseconds;
        final avgUs = totalUs / n;
        final throughput = n / (totalUs / 1e6);

        print('\n══════════════════════════════════════════════════');
        print(' Load Test · pixelToMm · $n calls (varied inputs)');
        print('══════════════════════════════════════════════════');
        print(' Total time   : ${(totalUs / 1000).toStringAsFixed(2)} ms');
        print(' Avg per call : ${avgUs.toStringAsFixed(3)} µs');
        print(' Throughput   : ${throughput.toStringAsFixed(0)} calls / sec');
        print(' Null results : $nullResults / $n');
        print('══════════════════════════════════════════════════\n');

        expect(nullResults, 0);
        expect(avgUs, lessThan(1000));
      },
    );
  });

  // ===========================================================================
  // 2. LOAD TESTING — PigMath.estimateWeight
  //    Every time the user taps a pig and enters a distance, the regression
  //    model runs once.  "Load" = many users triggering weight estimates.
  // ===========================================================================
  group('Load Test · PigMath.estimateWeight', () {
    test(
      '1,000 calls with realistic pig dimensions → throughput & avg latency',
      () {
        const n = 1000;
        final sw = Stopwatch()..start();

        for (int i = 0; i < n; i++) {
          PigMath.estimateWeight(
            bodyLengthMm: 380.0 + (i % 200),
            chestWidthMm: 120.0 + (i % 80),
            abdominalWidthMm: 140.0 + (i % 80),
            hipWidthMm: 130.0 + (i % 80),
          );
        }

        sw.stop();
        final totalUs = sw.elapsedMicroseconds;
        final avgUs = totalUs / n;
        final throughput = n / (totalUs / 1e6);

        print('\n══════════════════════════════════════════════════');
        print(' Load Test · estimateWeight · $n calls');
        print('══════════════════════════════════════════════════');
        print(
          ' Total time   : ${totalUs} µs  (${(totalUs / 1000).toStringAsFixed(2)} ms)',
        );
        print(' Avg per call : ${avgUs.toStringAsFixed(3)} µs');
        print(' Throughput   : ${throughput.toStringAsFixed(0)} calls / sec');
        print('══════════════════════════════════════════════════\n');

        expect(avgUs, lessThan(1000));
      },
    );

    test('10,000 calls with full value range → measures error rate', () {
      const n = 10000;
      final sw = Stopwatch()..start();
      int dashCount = 0;

      for (int i = 0; i < n; i++) {
        // Sweep through physically realistic pig dimensions (cm range once divided by 10)
        final result = PigMath.estimateWeight(
          bodyLengthMm: 300.0 + (i % 400).toDouble(),
          chestWidthMm: 80.0 + (i % 160).toDouble(),
          abdominalWidthMm: 90.0 + (i % 160).toDouble(),
          hipWidthMm: 85.0 + (i % 160).toDouble(),
        );
        if (result == '-') dashCount++;
      }

      sw.stop();
      final totalUs = sw.elapsedMicroseconds;
      final avgUs = totalUs / n;
      final throughput = n / (totalUs / 1e6);
      final errorRate = dashCount / n * 100;

      print('\n══════════════════════════════════════════════════');
      print(' Load Test · estimateWeight · $n calls (full range)');
      print('══════════════════════════════════════════════════');
      print(' Total time   : ${(totalUs / 1000).toStringAsFixed(2)} ms');
      print(' Avg per call : ${avgUs.toStringAsFixed(3)} µs');
      print(' Throughput   : ${throughput.toStringAsFixed(0)} calls / sec');
      print(
        ' "-" (invalid): $dashCount / $n  (${errorRate.toStringAsFixed(1)} %)',
      );
      print('══════════════════════════════════════════════════\n');

      expect(avgUs, lessThan(1000));
    });
  });

  // ===========================================================================
  // 3. STRESS TESTING — Full measurement pipeline
  //    pixelToMm (×4 body parts) → estimateWeight, run until the system is
  //    exhausted or a performance threshold is breached.
  // ===========================================================================
  group('Stress Test · Full Measurement Pipeline', () {
    test('100,000 full pipeline cycles → finds throughput ceiling', () {
      const n = 100000;
      final sw = Stopwatch()..start();
      int successCount = 0;

      for (int i = 0; i < n; i++) {
        final bodyLength = PigMath.pixelToMm(
          pixelLength: 1200.0 + (i % 800) * 0.5,
          distanceMm: 1200.0 + (i % 600),
          focalLength: _focalLength,
          sensorWidth: _sensorWidth,
          sensorHeight: _sensorHeight,
          imageWidth: _imageWidth,
          imageHeight: _imageHeight,
        );
        final chestWidth = PigMath.pixelToMm(
          pixelLength: 350.0 + (i % 200) * 0.3,
          distanceMm: 1200.0 + (i % 600),
          focalLength: _focalLength,
          sensorWidth: _sensorWidth,
          sensorHeight: _sensorHeight,
          imageWidth: _imageWidth,
          imageHeight: _imageHeight,
        );
        final abdominalWidth = PigMath.pixelToMm(
          pixelLength: 420.0 + (i % 200) * 0.3,
          distanceMm: 1200.0 + (i % 600),
          focalLength: _focalLength,
          sensorWidth: _sensorWidth,
          sensorHeight: _sensorHeight,
          imageWidth: _imageWidth,
          imageHeight: _imageHeight,
        );
        final hipWidth = PigMath.pixelToMm(
          pixelLength: 380.0 + (i % 200) * 0.3,
          distanceMm: 1200.0 + (i % 600),
          focalLength: _focalLength,
          sensorWidth: _sensorWidth,
          sensorHeight: _sensorHeight,
          imageWidth: _imageWidth,
          imageHeight: _imageHeight,
        );
        final result = PigMath.estimateWeight(
          bodyLengthMm: bodyLength,
          chestWidthMm: chestWidth,
          abdominalWidthMm: abdominalWidth,
          hipWidthMm: hipWidth,
        );
        if (result != '-') successCount++;
      }

      sw.stop();
      final totalMs = sw.elapsedMilliseconds;
      final avgUs = sw.elapsedMicroseconds / n;
      final throughput = n / (totalMs / 1000.0);
      final successRate = successCount / n * 100;

      print('\n══════════════════════════════════════════════════');
      print(' Stress Test · Full Pipeline · $n cycles');
      print('══════════════════════════════════════════════════');
      print(
        ' Total time    : ${totalMs} ms  (${(totalMs / 1000).toStringAsFixed(2)} s)',
      );
      print(' Avg per cycle : ${avgUs.toStringAsFixed(3)} µs');
      print(' Throughput    : ${throughput.toStringAsFixed(0)} cycles / sec');
      print(
        ' Success rate  : $successCount / $n  (${successRate.toStringAsFixed(1)} %)',
      );
      print('══════════════════════════════════════════════════\n');

      expect(
        avgUs,
        lessThan(2000),
        reason:
            'Full pipeline (4× pixelToMm + estimateWeight) must stay under 2 ms per cycle',
      );
      expect(
        successRate,
        greaterThan(95.0),
        reason: 'At least 95 % of realistic inputs should yield a valid weight',
      );
    });
  });

  // ===========================================================================
  // 4. STRESS TESTING — invalid / edge-case inputs at high volume
  //    Ensures the validation guard clauses don't degrade under load.
  // ===========================================================================
  group('Stress Test · Input Validation Under Load', () {
    test(
      '50,000 mixed valid/invalid calls → correct error handling at speed',
      () {
        const n = 50000;
        final sw = Stopwatch()..start();
        int nullCount = 0;
        int validCount = 0;

        for (int i = 0; i < n; i++) {
          final useInvalid = i % 5 == 0; // 20 % invalid
          final result = PigMath.pixelToMm(
            pixelLength: useInvalid ? -1.0 : 800.0,
            distanceMm: useInvalid ? 0.0 : _distanceMm,
            focalLength: useInvalid ? -5.0 : _focalLength,
            sensorWidth: _sensorWidth,
            sensorHeight: _sensorHeight,
            imageWidth: _imageWidth,
            imageHeight: _imageHeight,
          );
          if (result == null) {
            nullCount++;
          } else {
            validCount++;
          }
        }

        sw.stop();
        final totalUs = sw.elapsedMicroseconds;
        final avgUs = totalUs / n;
        final expectedInvalid = n ~/ 5;

        print('\n══════════════════════════════════════════════════');
        print(' Stress Test · Input Validation · $n mixed calls');
        print('══════════════════════════════════════════════════');
        print(' Avg per call  : ${avgUs.toStringAsFixed(3)} µs');
        print(' Valid results : $validCount');
        print(' Null results  : $nullCount  (expected ≥ $expectedInvalid)');
        print('══════════════════════════════════════════════════\n');

        expect(nullCount, greaterThanOrEqualTo(expectedInvalid));
        expect(validCount, greaterThan(0));
        expect(avgUs, lessThan(1000));
      },
    );
  });

  // ===========================================================================
  // 5. SCALABILITY TESTING — PigMeasurements.fromMask (PCA algorithm)
  //    The ONNX model outputs a binary segmentation mask.  PCA runs over all
  //    edge pixels of that mask to find the pig's main axis and width lines.
  //    This test measures how computation time scales with mask resolution.
  //    Masks tested: 50×50, 100×100, 200×200, 400×400
  // ===========================================================================
  group('Scalability Test · PigMeasurements.fromMask (PCA)', () {
    const maskSizes = [50, 100, 200, 400];
    const runsPerSize = 5;

    for (final size in maskSizes) {
      test(
        '$size × $size mask → avg PCA time, edge-pixel count, measurements',
        () {
          final mask = _makeEllipseMask(size, size);
          final bbox = Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble());

          // Count edge pixels for reference
          int edgePixels = 0;
          for (int y = 0; y < size; y++) {
            for (int x = 0; x < size; x++) {
              if (mask[y][x] > 0.5) {
                final isEdge =
                    x == 0 ||
                    x == size - 1 ||
                    y == 0 ||
                    y == size - 1 ||
                    mask[y - 1][x] <= 0.5 ||
                    mask[y + 1][x] <= 0.5 ||
                    mask[y][x - 1] <= 0.5 ||
                    mask[y][x + 1] <= 0.5;
                if (isEdge) edgePixels++;
              }
            }
          }

          // Warm-up
          PigMeasurements.fromMask(
            mask,
            bbox,
            imageWidth: size,
            imageHeight: size,
          );

          final sw = Stopwatch()..start();
          for (int i = 0; i < runsPerSize; i++) {
            PigMeasurements.fromMask(
              mask,
              bbox,
              imageWidth: size,
              imageHeight: size,
            );
          }
          sw.stop();

          final avgMs = sw.elapsedMilliseconds / runsPerSize;
          final result = PigMeasurements.fromMask(
            mask,
            bbox,
            imageWidth: size,
            imageHeight: size,
          );

          // Normalise bar chart to 400×400 worst-case (≈ expected max)
          final fraction = avgMs / 200.0;
          print('\n══════════════════════════════════════════════════');
          print(' Scalability Test · PCA · ${size}×${size} mask');
          print('══════════════════════════════════════════════════');
          print(' Edge pixels  : $edgePixels');
          print(
            ' Avg time     : ${avgMs.toStringAsFixed(2)} ms  ${_bar(fraction)}',
          );
          if (result != null) {
            print(' Body length  : ${result.length.toStringAsFixed(1)} px');
            print(' Chest width  : ${result.widthTop.toStringAsFixed(1)} px');
            print(
              ' Abdom. width : ${result.widthMiddle.toStringAsFixed(1)} px',
            );
            print(
              ' Hip width    : ${result.widthBottom.toStringAsFixed(1)} px',
            );
          } else {
            print(' ⚠  fromMask returned null');
          }
          print('══════════════════════════════════════════════════\n');

          expect(
            result,
            isNotNull,
            reason:
                'A clear elliptical mask must always produce a valid measurement',
          );
          // 400×400 should still be interactive (< 500 ms on any host)
          expect(
            avgMs,
            lessThan(500),
            reason: 'PCA on a ${size}×${size} mask must complete within 500 ms',
          );
        },
      );
    }

    test('Scalability summary — prints how time grows with mask area', () {
      final results = <String, double>{};

      for (final size in maskSizes) {
        final mask = _makeEllipseMask(size, size);
        final bbox = Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble());

        // Warm-up
        PigMeasurements.fromMask(
          mask,
          bbox,
          imageWidth: size,
          imageHeight: size,
        );

        final sw = Stopwatch()..start();
        for (int i = 0; i < runsPerSize; i++) {
          PigMeasurements.fromMask(
            mask,
            bbox,
            imageWidth: size,
            imageHeight: size,
          );
        }
        sw.stop();

        results['${size}x$size'] = sw.elapsedMilliseconds / runsPerSize;
      }

      final maxMs = results.values.reduce((a, b) => a > b ? a : b);
      print('\n╔══════════════════════════════════════════════════╗');
      print('║  Scalability Summary · PCA fromMask               ║');
      print('╠══════════════════════════════════════════════════╣');
      results.forEach((label, ms) {
        final bar = _bar(ms / maxMs);
        print('║  $label   ${ms.toStringAsFixed(2).padLeft(7)} ms  $bar ║');
      });
      print('╚══════════════════════════════════════════════════╝\n');

      // Rough linearity check: time should not grow faster than O(n²) i.e.
      // going from 100→200 (4× area) should not take more than 20× longer.
      final t100 = results['100x100']!;
      final t400 = results['400x400']!;
      if (t100 > 0) {
        final growthFactor = t400 / t100;
        print(' Growth factor 100→400: ${growthFactor.toStringAsFixed(1)}×');
        expect(
          growthFactor,
          lessThan(100),
          reason: 'PCA should not exhibit worse-than-O(n²) scaling',
        );
      }
    });
  });
}
