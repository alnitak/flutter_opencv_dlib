import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_opencv_dlib/src/face_points.dart';

import 'points_painter.dart';

class CameraStack extends StatelessWidget {
  final bool isRunninOnEmulator;
  final CameraDescription cameraDescription;
  final CameraController controller;
  final double? width;
  final FacePoints? points;

  const CameraStack({
    Key? key,
    required this.isRunninOnEmulator,
    required this.cameraDescription,
    required this.controller,
    this.width,
    this.points,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Rotation on device and on emulator has a different behavior!
    Size s = (cameraDescription.sensorOrientation == 90 ||
                cameraDescription.sensorOrientation == 270) &&
            isRunninOnEmulator
        ? controller.value.previewSize ?? Size.zero
        : Size(controller.value.previewSize!.height,
            controller.value.previewSize!.width);

    return SizedBox(
      width: width,
      child: Stack(
        children: [
          RotatedBox(
            quarterTurns: (cameraDescription.sensorOrientation == 90 ||
                        cameraDescription.sensorOrientation == 270) &&
                    isRunninOnEmulator
                ? 3
                : 0,
            child: CameraPreview(controller),
          ),
          if (points != null && points!.nFaces > 0)
            FittedBox(
              child: CustomPaint(
                size: s,
                painter: PointsPainter(pointsMap: points),
              ),
            ),
        ],
      ),
    );
  }
}
