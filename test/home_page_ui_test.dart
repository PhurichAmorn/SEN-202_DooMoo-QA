import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:doomoo/components/HomePage/camera.dart';
import 'package:doomoo/components/HomePage/upload.dart';
import 'package:doomoo/pages/camera.dart';
import 'package:doomoo/pages/home.dart';

// Mock NavigatorObserver to track navigation
class MockNavigatorObserver extends NavigatorObserver {
  final List<Route<dynamic>> pushedRoutes = [];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushedRoutes.add(route);
    super.didPush(route, previousRoute);
  }
}

void main() {
  group('Home Page UI Buttons Tests', () {
    Future<void> setupTest(
      WidgetTester tester,
      Widget child, {
      List<NavigatorObserver> observers = const [],
    }) async {
      // Simulate realistic screen size to satisfy ResponsiveUtils and prevent overflows
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

    testWidgets('Camera button displays and navigates correctly',
        (WidgetTester tester) async {
      final mockObserver = MockNavigatorObserver();

      await setupTest(
        tester,
        const Camera(),
        observers: [mockObserver],
      );

      // Verify UI elements exist
      expect(find.text('ถ่ายรูปหมู'), findsOneWidget);
      final cameraButton = find.byKey(const Key('home_camera_button'));
      expect(cameraButton, findsOneWidget);

      // Tap button using Key
      await tester.tap(cameraButton);
      await tester.pumpAndSettle();

      expect(find.byType(CameraPage), findsOneWidget);
    });

    testWidgets('Upload button displays and triggers action',
        (WidgetTester tester) async {
      await setupTest(tester, const Upload());

      // Verify UI elements exist
      expect(find.text('อัพโหลดรูปหมู'), findsOneWidget);
      final uploadButton = find.byKey(const Key('home_upload_button'));
      expect(uploadButton, findsOneWidget);

      // Tap button using Key
      await tester.tap(uploadButton);
      await tester.pumpAndSettle();

      // Verify it didn't crash
      expect(tester.takeException(), isNull);
    });

    testWidgets('Camera button should be disabled when Upload is processing',
        (WidgetTester tester) async {
      // We use the real HomePage which coordinates the state between Camera and Upload
      // Set a large enough surface size for the whole page
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

      // Find both widgets
      final cameraFinder = find.byType(Camera);
      final uploadFinder = find.byType(Upload);

      // 1. Initially enabled
      Camera cameraWidget = tester.widget(cameraFinder);
      expect(cameraWidget.isDisabled, isFalse);

      // 2. Trigger processing state manually via the widget's callback
      final Upload uploadWidget = tester.widget(uploadFinder);
      uploadWidget.onProcessingChanged!(true);
      await tester.pump(); // Rebuild with new state

      // 3. Verify Camera widget is now disabled in the UI
      cameraWidget = tester.widget(cameraFinder);
      expect(cameraWidget.isDisabled, isTrue);

      // 4. Try to tap the camera button while disabled
      final cameraButtonKeyFinder = find.byKey(const Key('home_camera_button'));
      await tester.tap(cameraButtonKeyFinder);
      await tester.pumpAndSettle();

      // 5. Assert: No navigation should have occurred (only the initial route exists)
      expect(mockObserver.pushedRoutes.length, 1);
      expect(find.byType(CameraPage), findsNothing);
    });

    testWidgets('Home widgets render without crashing',
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
