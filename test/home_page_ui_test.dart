import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:DooMoo/components/HomePage/camera.dart';
import 'package:DooMoo/components/HomePage/upload.dart';
import 'package:DooMoo/pages/camera.dart';
import 'package:DooMoo/pages/home.dart';


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
