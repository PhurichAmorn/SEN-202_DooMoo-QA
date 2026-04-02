import 'package:flutter/material.dart';
import 'package:doomoo/utils/responsive.dart';
import 'package:doomoo/models/detection_result.dart';
import 'package:doomoo/utils/camera_metadata.dart';
import 'package:doomoo/utils/pig_measurements.dart';
import 'package:doomoo/utils/config.dart';
import 'package:doomoo/utils/pig_math.dart';

class PigInfo extends StatefulWidget {
  final DetectionResult? detectionResult;
  final int? selectedPigIndex;
  final VoidCallback? onReset;
  final CameraMetadata? cameraMetadata;

  const PigInfo({
    super.key,
    this.detectionResult,
    this.selectedPigIndex,
    this.onReset,
    this.cameraMetadata,
  });

  @override
  State<PigInfo> createState() => _PigInfoState();
}

class _PigInfoState extends State<PigInfo> {
  final TextEditingController _distanceController = TextEditingController();
  double? _distanceMm; // stored internally in mm
  String? _errorText;

  @override
  void dispose() {
    _distanceController.dispose();
    super.dispose();
  }

  /// Convert pixel length to real-world mm using camera metadata and distance.
  double? _pixelToMm(double pixelLength) {
    final meta = widget.cameraMetadata;
    return PigMath.pixelToMm(
      pixelLength: pixelLength,
      distanceMm: _distanceMm,
      focalLength: meta?.focalLength,
      sensorWidth: meta?.sensorWidth,
      sensorHeight: meta?.sensorHeight,
      imageWidth: meta?.imageWidth,
      imageHeight: meta?.imageHeight,
    );
  }

  String _formatSize(double? mm) {
    if (mm == null) return '-';
    return '${(mm / 10).toStringAsFixed(1)} cm';
  }

  @override
  Widget build(BuildContext context) {
    final hasDetections =
        widget.detectionResult != null && !widget.detectionResult!.isEmpty;

    return Padding(
      padding: ResponsiveUtils.responsivePadding(context, bottom: 25),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color.fromRGBO(252, 252, 252, 30),
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 13,
              spreadRadius: 6,
              offset: Offset(0, 0),
            ),
          ],
        ),
        child: Padding(
          padding: ResponsiveUtils.responsivePadding(context, all: 20, top: 30),
          child: hasDetections && widget.selectedPigIndex == null
              ? _buildSelectionPrompt(context)
              : hasDetections && widget.selectedPigIndex != null
                  ? _buildSelectedPigInfo(context)
                  : _buildNoDetections(context),
        ),
      ),
    );
  }

  /// Step 1: Prompt user to tap a bounding box
  Widget _buildSelectionPrompt(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ตรวจพบหมู: ${widget.detectionResult!.count} ตัว',
          style: TextStyle(
            fontSize: ResponsiveUtils.fontSize(context, 30),
            fontWeight: FontWeight.bold,
            color: Color(0xFF2671F4),
          ),
        ),
        SizedBox(height: ResponsiveUtils.height(context, 1)),
        Text(
          'แตะที่กรอบหมูเพื่อวิเคราะห์',
          style: TextStyle(
            fontSize: ResponsiveUtils.fontSize(context, 24),
            color: Color(0xFF999999),
          ),
        ),
      ],
    );
  }

  /// Step 2: Show selected pig's details
  Widget _buildSelectedPigInfo(BuildContext context) {
    final det = widget.detectionResult!.detections[widget.selectedPigIndex!];
    final box = det.boundingBox;

    final PigMeasurements? pca = det.mask != null
        ? PigMeasurements.fromMask(
            det.mask!,
            box,
            imageWidth: widget.detectionResult!.imageWidth,
            imageHeight: widget.detectionResult!.imageHeight,
            maskRect: det.maskRect,
          )
        : null;

    final lengthPx = pca?.length ?? box.width;
    final chestPx = pca?.widthTop ?? box.height;
    final abdominalPx = pca?.widthMiddle ?? box.height;
    final hipPx = pca?.widthBottom ?? box.height;

    final lengthMm = _pixelToMm(lengthPx);
    final chestMm = _pixelToMm(chestPx);
    final abdominalMm = _pixelToMm(abdominalPx);
    final hipMm = _pixelToMm(hipPx);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                'หมูตัวที่ ${widget.selectedPigIndex! + 1}',
                style: TextStyle(
                  fontSize: ResponsiveUtils.fontSize(context, 30),
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2671F4),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            GestureDetector(
              onTap: widget.onReset,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Color(0xFFEEEEEE),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'เลือกตัวอื่น',
                  style: TextStyle(
                    fontSize: ResponsiveUtils.fontSize(context, 20),
                    color: Color(0xFF5A5A5A),
                  ),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: ResponsiveUtils.height(context, 2)),
        _buildDistanceInput(context),
        SizedBox(height: ResponsiveUtils.height(context, 2)),
        _buildField(
          context,
          'น้ำหนัก: ',
          _distanceMm != null
              ? PigMath.estimateWeight(
                  bodyLengthMm: lengthMm,
                  chestWidthMm: chestMm,
                  abdominalWidthMm: abdominalMm,
                  hipWidthMm: hipMm,
                )
              : '-',
          fontWeight: FontWeight.bold,
        ),
      ],
    );
  }

  Widget _buildDistanceInput(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ระยะห่างกล้องถึงหมู (เมตร):',
          style: TextStyle(
            fontSize: ResponsiveUtils.fontSize(context, 24),
            fontWeight: FontWeight.bold,
            color: Color(0xFF5A5A5A),
          ),
        ),
        SizedBox(height: ResponsiveUtils.height(context, 1)),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                controller: _distanceController,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  hintText: 'เช่น 0.67',
                  errorText: _errorText,
                  suffixText: 'ม.',
                ),
                onChanged: (_) {
                  if (_errorText != null) setState(() => _errorText = null);
                },
              ),
            ),
            SizedBox(width: 8),
            ElevatedButton(
              onPressed: _applyDistance,
              child: const Text('คำนวณ'),
            ),
          ],
        ),
      ],
    );
  }

  void _applyDistance() {
    final value = double.tryParse(_distanceController.text);
    if (value != null && value > 0) {
      setState(() {
        _distanceMm = value * 1000;
        _errorText = null;
      });
    } else {
      setState(() {
        _errorText = 'ความสูงไม่ถูกต้อง';
        _distanceMm = null;
      });
    }
  }

  Widget _buildNoDetections(BuildContext context) {
    return Text(
      'ไม่พบหมูในรูป',
      style: TextStyle(
        fontSize: ResponsiveUtils.fontSize(context, 30),
        fontWeight: FontWeight.bold,
        color: Color(0xFF999999),
      ),
    );
  }

  Widget _buildField(BuildContext context, String label, String value,
      {FontWeight fontWeight = FontWeight.normal}) {
    return Text(
      '$label$value',
      style: TextStyle(
        fontSize: ResponsiveUtils.fontSize(context, 30),
        color: Color(0xFF5A5A5A),
        fontWeight: fontWeight,
      ),
    );
  }
}
