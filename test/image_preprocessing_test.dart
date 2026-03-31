import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:doomoo/utils/image_preprocessing.dart';

void main() {
  group('test ImagePreprocessor', () {
    test('where the path is invalid, preprocess throws exception', () {
      expect(() => ImagePreprocessor.preprocess('invalid_path.jpg', 432),
          throwsA(isA<PathNotFoundException>()));
    });

    test('where the file is not an image, preprocess throws exception',
        () async {
      final file = File('temp.txt');
      await file.writeAsString('not an image');

      expect(() => ImagePreprocessor.preprocess('temp.txt', 432),
          throwsA(isA<Exception>()));

      await file.delete();
    });
  });
}
