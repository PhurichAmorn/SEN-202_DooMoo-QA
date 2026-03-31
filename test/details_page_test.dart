import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:doomoo/pages/details.dart';
import 'package:doomoo/models/detection_result.dart';
import 'package:doomoo/utils/camera_metadata.dart';

void main() {
  testWidgets('DetailsPage displays basic info', (WidgetTester tester) async {
    // Set a massive surface size to avoid any possible overflow
    tester.view.physicalSize = const Size(5000, 5000);
    tester.view.devicePixelRatio = 1.0;

    final metadata = CameraMetadata(
      sensorWidth: 6.17,
      sensorHeight: 4.55,
      focalLength: 4.25,
      imageWidth: 1000,
      imageHeight: 1000,
    );

    final detectionResult = DetectionResult(
      imageWidth: 1000,
      imageHeight: 1000,
      detections: [
        PigDetection(
          boundingBox: const Rect.fromLTRB(100, 100, 500, 500),
          confidence: 0.9,
          classId: 0,
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DetailsPage(
            imagePath: 'test_assets/pig.jpg',
            cameraMetadata: metadata,
            detectionResult: detectionResult,
          ),
        ),
      ),
    );

    // Verify page title exists
    expect(find.text('รายละเอียด'), findsOneWidget);

    // Reset view
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}
