import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:doomoo/pages/details.dart';
import 'package:doomoo/models/detection_result.dart';
import 'package:doomoo/utils/camera_metadata.dart';
import 'package:doomoo/utils/config.dart';
import 'package:doomoo/components/DetailsPage/camera_metadata_info.dart';
import 'package:doomoo/components/DetailsPage/pig_image_with_overlay.dart';
import 'package:doomoo/services/pig_detector.dart';

void main() {
  setUpAll(() {
    // Enable bypass for ONNX and Hardware calls during tests
    PigDetector.skipInTests = true;
    CameraMetadataExtractor.skipHardwareInTests = true;
  });

  group('test details page ui', () {
    Future<void> setupPage(WidgetTester tester,
        {DetectionResult? result}) async {
      tester.view.physicalSize = const Size(1000, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final metadata = CameraMetadata(
        sensorWidth: 6.17,
        sensorHeight: 4.55,
        focalLength: 4.25,
        imageWidth: 1000,
        imageHeight: 1000,
      );

      final detectionResult = result ??
          DetectionResult(
            imageWidth: 1000,
            imageHeight: 1000,
            detections: [
              PigDetection(
                boundingBox: const Rect.fromLTRB(100, 100, 500, 500),
                confidence: 0.9,
                classId: 0,
                mask: List.generate(50, (y) => List.generate(50, (x) => 1.0)),
                maskRect: const Rect.fromLTRB(100, 100, 500, 500),
              ),
            ],
          );

      await tester.pumpWidget(
        MaterialApp(
          home: DetailsPage(
            imagePath: 'test_assets/pig.jpg',
            cameraMetadata: metadata,
            detectionResult: detectionResult,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump();
    }

    testWidgets('where page loads then it displays basic info',
        (WidgetTester tester) async {
      await setupPage(tester);
      expect(find.text('รายละเอียด'), findsOneWidget);
      expect(find.textContaining('ตรวจพบหมู'), findsWidgets);
    });

    testWidgets('where no pigs are detected then it shows empty state',
        (WidgetTester tester) async {
      final emptyResult =
          DetectionResult(imageWidth: 1000, imageHeight: 1000, detections: []);
      await setupPage(tester, result: emptyResult);

      expect(find.textContaining('ไม่พบ'), findsWidgets);
    });

    testWidgets('where title is long pressed then debug mode toggles',
        (WidgetTester tester) async {
      await setupPage(tester);
      final initialDebugMode = AppConfig.debugMode;

      await tester.longPress(find.text('รายละเอียด'));
      await tester.pump();

      expect(AppConfig.debugMode, !initialDebugMode);
      expect(find.byType(SnackBar), findsOneWidget);

      if (AppConfig.debugMode) {
        expect(find.byType(CameraMetadataInfo), findsOneWidget);
      } else {
        expect(find.byType(CameraMetadataInfo), findsNothing);
      }

      await tester.longPress(find.text('รายละเอียด'));
      await tester.pump();
      expect(AppConfig.debugMode, initialDebugMode);
    });

    testWidgets('where a pig is selected then it shows details and allow reset',
        (WidgetTester tester) async {
      await setupPage(tester);

      final overlay =
          tester.widget<PigImageWithOverlay>(find.byType(PigImageWithOverlay));
      overlay.onPigSelected?.call(0);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.textContaining('หมูตัวที่ 1'), findsOneWidget);

      final resetButton = find.text('เลือกตัวอื่น');
      await tester.tap(resetButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.textContaining('ตรวจพบหมู: 1 ตัว'), findsOneWidget);
    });

    testWidgets('where multiple pigs exist then it can select different pigs',
        (WidgetTester tester) async {
      final multipleResult = DetectionResult(
        imageWidth: 1000,
        imageHeight: 1000,
        detections: [
          PigDetection(
              boundingBox: const Rect.fromLTWH(0, 0, 100, 100),
              confidence: 0.9,
              classId: 0,
              mask: List.generate(10, (y) => List.generate(10, (x) => 1.0))),
          PigDetection(
              boundingBox: const Rect.fromLTWH(200, 200, 100, 100),
              confidence: 0.8,
              classId: 0,
              mask: List.generate(10, (y) => List.generate(10, (x) => 1.0))),
        ],
      );
      await setupPage(tester, result: multipleResult);

      final overlay =
          tester.widget<PigImageWithOverlay>(find.byType(PigImageWithOverlay));
      overlay.onPigSelected?.call(1);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.textContaining('หมูตัวที่ 2'), findsOneWidget);
    });

    testWidgets('where a distance is entered then weight is calculated',
        (WidgetTester tester) async {
      await setupPage(tester);

      final overlay =
          tester.widget<PigImageWithOverlay>(find.byType(PigImageWithOverlay));
      overlay.onPigSelected?.call(0);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      final textField = find.byType(TextField);
      await tester.enterText(textField, '0.5');
      await tester.pump();

      final calcButton = find.text('คำนวณ');
      await tester.ensureVisible(calcButton);
      await tester.tap(calcButton, warnIfMissed: false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.textContaining('น้ำหนัก:'), findsOneWidget);
      expect(find.textContaining('น้ำหนัก: -'), findsNothing);
    });

    testWidgets('where invalid distance is entered then it shows error',
        (WidgetTester tester) async {
      await setupPage(tester);

      final overlay =
          tester.widget<PigImageWithOverlay>(find.byType(PigImageWithOverlay));
      overlay.onPigSelected?.call(0);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      await tester.enterText(find.byType(TextField), 'abc');
      final calcButton = find.text('คำนวณ');
      await tester.ensureVisible(calcButton);
      await tester.tap(calcButton, warnIfMissed: false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('ความสูงไม่ถูกต้อง'), findsOneWidget);
    });

    testWidgets(
        'where pig without mask is selected then it triggers loading state',
        (WidgetTester tester) async {
      final noMaskResult = DetectionResult(
        imageWidth: 1000,
        imageHeight: 1000,
        detections: [
          PigDetection(
              boundingBox: const Rect.fromLTRB(100, 100, 500, 500),
              confidence: 0.9,
              classId: 0),
        ],
      );
      await setupPage(tester, result: noMaskResult);

      final overlay =
          tester.widget<PigImageWithOverlay>(find.byType(PigImageWithOverlay));

      // Trigger selection
      overlay.onPigSelected?.call(0);

      // Verify loading indicator is shown
      await tester.pump();
      expect(find.text('กำลังวิเคราะห์ส่วนต่าง ๆ...'), findsOneWidget);

      // Target the CircularProgressIndicator that is a sibling of the loading text
      expect(
          find.descendant(
            of: find.ancestor(
                of: find.text('กำลังวิเคราะห์ส่วนต่าง ๆ...'),
                matching: find.byType(Column)),
            matching: find.byType(CircularProgressIndicator),
          ),
          findsOneWidget);

      // Wait for bypass mock processing to finish (it uses Future.delayed(50ms) + service call)
      // Since skipInTests is true, service call is immediate.
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();

      // Verify loading indicator is gone
      expect(find.text('กำลังวิเคราะห์ส่วนต่าง ๆ...'), findsNothing);
      expect(find.textContaining('หมูตัวที่ 1'), findsOneWidget);
    });

    testWidgets('where back button is present then it can be tapped',
        (WidgetTester tester) async {
      await setupPage(tester);
      final backButton = find.byType(GestureDetector).first;
      expect(backButton, findsOneWidget);
      await tester.tap(backButton, warnIfMissed: false);
      await tester.pump();
    });
  });
}
