import 'package:flutter_test/flutter_test.dart';
import 'package:doomoo/services/pig_detector.dart';
import 'package:flutter/services.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('test PigDetector Singleton', () {
    test(
        'where getInstance attempts to load and handles missing native library',
        () async {
      try {
        await PigDetector.getInstance();
      } catch (e) {
        // We expect an ArgumentError or Exception due to missing native library
        expect(e.toString(), contains('Failed to load dynamic library'));
      }
    });

    test(
        'where PigDetector handles asset loading failure before native library',
        () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('flutter/assets'),
        (message) async => throw Exception('Asset not found'),
      );

      try {
        await PigDetector.getInstance();
        fail('Should have thrown an exception');
      } catch (e) {
        expect(e.toString(),
            anyOf(contains('Asset not found'), contains('Failed to load')));
      }

      // Clean up
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
              const MethodChannel('flutter/assets'), null);
    });
  });
}
