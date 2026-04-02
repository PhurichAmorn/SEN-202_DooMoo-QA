import 'dart:io';
import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:doomoo/utils/image_preprocessing.dart';
import 'package:image/image.dart' as img;

void main() {
  group('test image preprocessing', () {
    late String testImagePath;

    setUpAll(() async {
      final image = img.Image(width: 100, height: 100);
      img.fill(image, color: img.ColorRgb8(255, 0, 0));
      final bytes = img.encodeJpg(image);
      testImagePath = 'test_pig_image.jpg';
      await File(testImagePath).writeAsBytes(bytes);
    });

    tearDownAll(() async {
      final file = File(testImagePath);
      if (await file.exists()) await file.delete();
    });

    test('where image is preprocessed then it is resized and normalized', () {
      final result = ImagePreprocessor.preprocess(testImagePath, 32);
      expect(result.targetWidth, 32);
      expect(result.data.length, 1 * 3 * 32 * 32);
    });

    test('where image is cropped then preprocessed then dimensions match crop',
        () {
      const cropRect = Rect.fromLTWH(10, 10, 50, 50);
      final result =
          ImagePreprocessor.cropAndPreprocess(testImagePath, cropRect, 32);
      expect(result.cropRect, cropRect);
      expect(result.targetWidth, 32);
    });

    test('where invalid path is provided then it throws', () {
      expect(() => ImagePreprocessor.preprocess('invalid.jpg', 32),
          throwsA(isA<PathNotFoundException>()));
    });

    test('where non-image file is provided then it throws', () async {
      const tempPath = 'not_image.txt';
      await File(tempPath).writeAsString('hello world');
      expect(
          () => ImagePreprocessor.preprocess(tempPath, 32), throwsA(anything));
      await File(tempPath).delete();
    });
  });
}
