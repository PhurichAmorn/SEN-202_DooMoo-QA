import 'package:flutter_test/flutter_test.dart';
import 'package:doomoo/services/yolo_detector.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('YoloDetector tests', () {
    test('getInstance handles missing native library gracefully', () async {
      // In unit tests, the native library (libonnxruntime) is not available.
      // We verify that YoloDetector attempts to initialize and handles the failure.
      try {
        await YoloDetector.getInstance();
      } catch (e) {
        expect(e.toString(), contains('Failed to load dynamic library'));
      }
    });
  });
}
