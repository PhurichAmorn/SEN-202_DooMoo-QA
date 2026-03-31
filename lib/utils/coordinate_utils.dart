import 'dart:ui';
import 'dart:math';

class CoordinateUtils {
  /// Maps YOLO normalized output coordinates to original image pixels.
  ///
  /// [cx], [cy], [w], [h] are from YOLO output (relative to input size).
  /// [inputSize] is the size the image was resized to for the model (e.g. 640).
  /// [imgW], [imgH] are original image dimensions.
  static Rect mapYoloToImagePixels({
    required double cx,
    required double cy,
    required double w,
    required double h,
    required int inputSize,
    required int imgW,
    required int imgH,
  }) {
    if (inputSize <= 0 || imgW <= 0 || imgH <= 0) {
      return Rect.zero;
    }

    final scaledCx = cx * imgW / inputSize;
    final scaledCy = cy * imgH / inputSize;
    final scaledW = w * imgW / inputSize;
    final scaledH = h * imgH / inputSize;

    final left = (scaledCx - scaledW / 2).clamp(0.0, imgW.toDouble());
    final top = (scaledCy - scaledH / 2).clamp(0.0, imgH.toDouble());
    final right = (scaledCx + scaledW / 2).clamp(0.0, imgW.toDouble());
    final bottom = (scaledCy + scaledH / 2).clamp(0.0, imgH.toDouble());

    return Rect.fromLTRB(left, top, right, bottom);
  }
}
