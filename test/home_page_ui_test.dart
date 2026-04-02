import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:doomoo/components/HomePage/camera.dart';
import 'package:doomoo/components/HomePage/upload.dart';
import 'package:doomoo/pages/camera.dart';
import 'package:doomoo/pages/home.dart';
import 'package:doomoo/services/yolo_detector.dart';

class MockNavigatorObserver extends NavigatorObserver {
  final List<Route<dynamic>> pushedRoutes = [];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushedRoutes.add(route);
    super.didPush(route, previousRoute);
  }
}

void main() {
  setUpAll(() {
    YoloDetector.skipInTests = true;
  });

  group('test home page ui buttons', () {
    Future<void> setupTest(
      WidgetTester tester,
      Widget child, {
      List<NavigatorObserver> observers = const [],
    }) async {
      tester.view.physicalSize = const Size(400 * 3, 2000 * 3);
      tester.view.devicePixelRatio = 3.0;

      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: child),
          navigatorObservers: observers,
        ),
      );

      await tester.pumpAndSettle();
    }

    testWidgets('where Camera button is displayed then it navigates correctly',
        (WidgetTester tester) async {
      final mockObserver = MockNavigatorObserver();
      await setupTest(tester, const Camera(), observers: [mockObserver]);

      final cameraButton = find.byKey(const Key('home_camera_button'));
      expect(find.text('ถ่ายรูปหมู'), findsOneWidget);
      expect(cameraButton, findsOneWidget);

      await tester.tap(cameraButton);
      await tester.pumpAndSettle();

      expect(find.byType(CameraPage), findsOneWidget);
    });

    testWidgets('where Upload button is displayed then it triggers action',
        (WidgetTester tester) async {
      await setupTest(tester, const Upload());

      final uploadButton = find.byKey(const Key('home_upload_button'));
      expect(find.text('อัพโหลดรูปหมู'), findsOneWidget);
      expect(uploadButton, findsOneWidget);

      await tester.tap(uploadButton);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('where Upload is processing then Camera button is disabled',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(400 * 3, 2000 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final mockObserver = MockNavigatorObserver();
      await tester.pumpWidget(
        MaterialApp(
          home: const HomePage(),
          navigatorObservers: [mockObserver],
        ),
      );
      await tester.pumpAndSettle();

      final cameraFinder = find.byType(Camera);
      final uploadFinder = find.byType(Upload);
      Camera cameraWidget = tester.widget(cameraFinder);
      expect(cameraWidget.isDisabled, isFalse);

      final Upload uploadWidget = tester.widget(uploadFinder);
      uploadWidget.onProcessingChanged!(true);
      await tester.pump();
      cameraWidget = tester.widget(cameraFinder);
      expect(cameraWidget.isDisabled, isTrue);

      final cameraButtonKeyFinder = find.byKey(const Key('home_camera_button'));
      await tester.ensureVisible(cameraButtonKeyFinder);
      await tester.tap(cameraButtonKeyFinder, warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(mockObserver.pushedRoutes.length, 1);
      expect(find.byType(CameraPage), findsNothing);
    });

    testWidgets('where Home widgets are used then they render without crashing',
        (WidgetTester tester) async {
      await setupTest(
        tester,
        const SingleChildScrollView(
          child: Column(
            children: [
              Camera(),
              Upload(),
            ],
          ),
        ),
      );

      expect(find.byType(Camera), findsOneWidget);
      expect(find.byType(Upload), findsOneWidget);
    });
  });
}
