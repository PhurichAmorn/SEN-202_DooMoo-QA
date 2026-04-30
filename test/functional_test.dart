import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:doomoo/pages/details.dart';
import 'package:doomoo/models/detection_result.dart';
import 'package:doomoo/utils/camera_metadata.dart';
import 'package:doomoo/utils/config.dart';
import 'package:doomoo/services/pig_detector.dart';
import 'package:doomoo/services/yolo_detector.dart';
import 'package:doomoo/components/DetailsPage/pig_image_with_overlay.dart';
import 'package:doomoo/components/DetailsPage/camera_metadata_info.dart';

// ── Navigator observer ────────────────────────────────────────────────────────

class _ReplaceObserver extends NavigatorObserver {
  final VoidCallback onReplace;
  _ReplaceObserver({required this.onReplace});

  @override
  void didReplace({Route? newRoute, Route? oldRoute}) {
    onReplace();
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
  }
}

// ── Fixtures ──────────────────────────────────────────────────────────────────

// Camera: sensorWidth=6.17mm, sensorHeight=4.55mm, focalLength=4.25mm, 1000×1000px
final _meta = CameraMetadata(
  sensorWidth: 6.17,
  sensorHeight: 4.55,
  focalLength: 4.25,
  imageWidth: 1000,
  imageHeight: 1000,
);

// Pig with a 50×50 fully-filled mask inside a 400×400 bounding box.
// PCA on the square boundary gives: length = widthTop = widthMiddle = widthBottom = 392 px.
// At 1.0 m → all real-world measurements ≈ 494.38 mm → weight ≈ 59.6 kg.
// At 2.0 m → all measurements ≈ 988.76 mm → weight ≈ 141.1 kg.
DetectionResult _makeResult({int count = 1}) => DetectionResult(
  imageWidth: 1000,
  imageHeight: 1000,
  detections: List.generate(count, (i) {
    final offset = i * 50.0;
    return PigDetection(
      boundingBox: Rect.fromLTRB(100 + offset, 100, 500 + offset, 500),
      confidence: 0.9 - i * 0.05,
      classId: 0,
      mask: List.generate(50, (_) => List.generate(50, (_) => 1.0)),
      maskRect: Rect.fromLTRB(100 + offset, 100, 500 + offset, 500),
    );
  }),
);

// ── Helpers ───────────────────────────────────────────────────────────────────

Future<void> _pumpDetails(
  WidgetTester tester, {
  DetectionResult? result,
}) async {
  tester.view.physicalSize = const Size(1000, 2000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      home: DetailsPage(
        imagePath: 'test_assets/pig.jpg',
        cameraMetadata: _meta,
        detectionResult: result ?? _makeResult(),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump();
}

Future<void> _selectPig(WidgetTester tester, int index) async {
  final overlay = tester.widget<PigImageWithOverlay>(
    find.byType(PigImageWithOverlay),
  );
  overlay.onPigSelected?.call(index);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _calculate(WidgetTester tester, String distance) async {
  await tester.enterText(find.byType(TextField), distance);
  final btn = find.text('คำนวณ');
  await tester.ensureVisible(btn);
  await tester.tap(btn, warnIfMissed: false);
  await tester.pump();
}

String? _weightText(WidgetTester tester) {
  for (final w in tester.widgetList<Text>(find.byType(Text))) {
    if (w.data?.startsWith('น้ำหนัก:') ?? false) return w.data;
  }
  return null;
}

double? _parseWeight(String? text) {
  if (text == null) return null;
  final m = RegExp(r'น้ำหนัก: (\d+\.?\d*) kg').firstMatch(text);
  return m == null ? null : double.tryParse(m.group(1)!);
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  setUpAll(() {
    PigDetector.skipInTests = true;
    YoloDetector.skipInTests = true;
    CameraMetadataExtractor.skipHardwareInTests = true;
  });

  setUp(() => AppConfig.debugMode = false);
  tearDown(() => AppConfig.debugMode = false);

  // ── 1. Weight calculation pipeline ─────────────────────────────────────────

  group('functional: weight calculation pipeline', () {
    testWidgets(
      'when pig selected and no distance entered then weight shows dash',
      (tester) async {
        await _pumpDetails(tester);
        await _selectPig(tester, 0);

        expect(find.text('น้ำหนัก: -'), findsOneWidget);
      },
    );

    testWidgets(
      'when valid distance entered then weight shown in kg format with positive value',
      (tester) async {
        await _pumpDetails(tester);
        await _selectPig(tester, 0);
        await _calculate(tester, '1.0');

        final text = _weightText(tester);
        expect(text, isNotNull);
        expect(text, matches(RegExp(r'น้ำหนัก: \d+\.?\d* kg')));
        final kg = _parseWeight(text);
        expect(kg, isNotNull);
        expect(kg! > 0, isTrue);
      },
    );

    testWidgets(
      'when distance is 1.0 m then weight matches pinhole model calculation',
      (tester) async {
        // Precomputed: 50×50 mask, 400×400 box, camera above → all dims 392 px
        // → realMm ≈ 494.38 mm each → weight ≈ 59.6 kg
        await _pumpDetails(tester);
        await _selectPig(tester, 0);
        await _calculate(tester, '1.0');

        expect(_weightText(tester), 'น้ำหนัก: 59.6 kg');
      },
    );

    testWidgets(
      'when distance is doubled to 2.0 m then weight is larger and updates',
      (tester) async {
        // At 2.0 m → all dims ≈ 988.76 mm → weight ≈ 141.1 kg
        await _pumpDetails(tester);
        await _selectPig(tester, 0);

        await _calculate(tester, '1.0');
        final w1 = _parseWeight(_weightText(tester));

        await _calculate(tester, '2.0');
        final w2 = _parseWeight(_weightText(tester));

        expect(w1, isNotNull);
        expect(w2, isNotNull);
        expect(w2! > w1!, isTrue);
        expect(_weightText(tester), 'น้ำหนัก: 141.1 kg');
      },
    );

    testWidgets(
      'when distance input is replaced then weight reflects the latest value',
      (tester) async {
        await _pumpDetails(tester);
        await _selectPig(tester, 0);

        await _calculate(tester, '2.0');
        final before = _weightText(tester);

        await _calculate(tester, '1.0');
        final after = _weightText(tester);

        expect(before, isNot(equals(after)));
        expect(after, 'น้ำหนัก: 59.6 kg');
      },
    );
  });

  // ── 2. Distance input error recovery ───────────────────────────────────────

  group('functional: distance input error recovery', () {
    testWidgets(
      'when invalid text entered then corrected then error clears and weight shown',
      (tester) async {
        await _pumpDetails(tester);
        await _selectPig(tester, 0);

        // Bad input → error visible, no weight
        await _calculate(tester, 'abc');
        expect(find.text('ความสูงไม่ถูกต้อง'), findsOneWidget);
        expect(find.text('น้ำหนัก: -'), findsOneWidget);

        // Fix → error gone, weight shown
        await _calculate(tester, '1.0');
        expect(find.text('ความสูงไม่ถูกต้อง'), findsNothing);
        expect(_weightText(tester), 'น้ำหนัก: 59.6 kg');
      },
    );

    testWidgets('when negative distance entered then error is shown', (
      tester,
    ) async {
      await _pumpDetails(tester);
      await _selectPig(tester, 0);

      await _calculate(tester, '-1.0');

      expect(find.text('ความสูงไม่ถูกต้อง'), findsOneWidget);
      expect(find.text('น้ำหนัก: -'), findsOneWidget);
    });

    testWidgets('when zero distance entered then error is shown', (
      tester,
    ) async {
      await _pumpDetails(tester);
      await _selectPig(tester, 0);

      await _calculate(tester, '0');

      expect(find.text('ความสูงไม่ถูกต้อง'), findsOneWidget);
      expect(find.text('น้ำหนัก: -'), findsOneWidget);
    });

    testWidgets('when empty field submitted then error is shown not a crash', (
      tester,
    ) async {
      await _pumpDetails(tester);
      await _selectPig(tester, 0);

      await _calculate(tester, '');

      expect(tester.takeException(), isNull);
      expect(find.text('ความสูงไม่ถูกต้อง'), findsOneWidget);
    });
  });

  // ── 3. Debug mode lifecycle ─────────────────────────────────────────────────

  group('functional: debug mode lifecycle', () {
    testWidgets(
      'when title long pressed twice then metadata panel appears then disappears',
      (tester) async {
        AppConfig.debugMode = false;
        await _pumpDetails(tester);

        // Off → panel hidden
        expect(find.byType(CameraMetadataInfo), findsNothing);

        // First long press → on
        await tester.longPress(find.text('รายละเอียด'));
        await tester.pump();
        expect(AppConfig.debugMode, isTrue);
        expect(find.byType(CameraMetadataInfo), findsOneWidget);
        expect(find.byType(SnackBar), findsOneWidget);

        // Second long press → off
        await tester.longPress(find.text('รายละเอียด'));
        await tester.pump();
        expect(AppConfig.debugMode, isFalse);
        expect(find.byType(CameraMetadataInfo), findsNothing);
      },
    );

    testWidgets('when debug mode is on then snackbar text reflects state', (
      tester,
    ) async {
      AppConfig.debugMode = false;
      await _pumpDetails(tester);

      await tester.longPress(find.text('รายละเอียด'));
      await tester.pump();
      expect(find.textContaining('Enabled'), findsOneWidget);

      // Dismiss the first snackbar so the second one appears immediately.
      ScaffoldMessenger.of(
        tester.element(find.byType(Scaffold)),
      ).hideCurrentSnackBar();
      await tester.pump();

      await tester.longPress(find.text('รายละเอียด'));
      await tester.pump();
      expect(find.textContaining('Disabled'), findsOneWidget);
    });
  });

  // ── 4. Navigation: Details → Home ──────────────────────────────────────────

  group('functional: navigation', () {
    testWidgets(
      'when back button tapped from details page then home page shown',
      (tester) async {
        tester.view.physicalSize = const Size(1000, 2000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        bool didNavigate = false;
        final observer = _ReplaceObserver(onReplace: () => didNavigate = true);

        await tester.pumpWidget(
          MaterialApp(
            home: DetailsPage(
              imagePath: 'test_assets/pig.jpg',
              cameraMetadata: _meta,
              detectionResult: _makeResult(),
            ),
            navigatorObservers: [observer],
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump();

        expect(find.text('รายละเอียด'), findsOneWidget);

        // Tap the keyed back button.
        final backButton = find.byKey(const Key('details_back_button'));
        expect(backButton, findsOneWidget);
        await tester.tap(backButton);
        await tester.pump(); // process tap → pushReplacement fires

        // NavigatorObserver.didReplace fires synchronously on route replacement.
        expect(
          didNavigate,
          isTrue,
          reason: 'Back button should have called Navigator.pushReplacement',
        );

        // Advance past the 300 ms route transition animation.
        await tester.pump(const Duration(milliseconds: 350));

        // DetailsPage title is gone; HomePage title is visible.
        expect(find.text('รายละเอียด'), findsNothing);
        expect(find.text('DooMoo'), findsOneWidget);
      },
    );
  });

  // ── 5. Multi-pig selection cycle ───────────────────────────────────────────

  group('functional: multi-pig selection cycle', () {
    testWidgets(
      'when two pigs exist then selecting each shows correct pig label',
      (tester) async {
        await _pumpDetails(tester, result: _makeResult(count: 2));

        // Initially shows count
        expect(find.textContaining('ตรวจพบหมู: 2 ตัว'), findsOneWidget);

        // Select pig 1
        await _selectPig(tester, 0);
        expect(find.textContaining('หมูตัวที่ 1'), findsOneWidget);
        expect(find.textContaining('หมูตัวที่ 2'), findsNothing);

        // Reset
        await tester.tap(find.text('เลือกตัวอื่น'));
        await tester.pump();
        expect(find.textContaining('ตรวจพบหมู: 2 ตัว'), findsOneWidget);

        // Select pig 2
        await _selectPig(tester, 1);
        expect(find.textContaining('หมูตัวที่ 2'), findsOneWidget);
        expect(find.textContaining('หมูตัวที่ 1'), findsNothing);
      },
    );

    testWidgets(
      'when pig selected with distance then reset then weight panel is gone',
      (tester) async {
        await _pumpDetails(tester);
        await _selectPig(tester, 0);
        await _calculate(tester, '1.0');

        // Weight is visible
        expect(_weightText(tester), isNotNull);

        // Reset clears selection → weight panel gone
        await tester.tap(find.text('เลือกตัวอื่น'));
        await tester.pump();

        expect(find.textContaining('น้ำหนัก:'), findsNothing);
      },
    );

    testWidgets('when three pigs detected then count label shows 3', (
      tester,
    ) async {
      await _pumpDetails(tester, result: _makeResult(count: 3));

      expect(find.textContaining('ตรวจพบหมู: 3 ตัว'), findsOneWidget);
    });
  });
}
