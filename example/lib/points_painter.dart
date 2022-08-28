import 'package:flutter/material.dart';
import 'package:flutter_opencv_dlib/flutter_opencv_dlib.dart';

class PointsPainter extends CustomPainter {
  final FacePoints? pointsMap;
  final Color? backgroundColor;

  PointsPainter({
    this.pointsMap,
    this.backgroundColor,
  });

  //  68 points landmark
  // 0,  16  Jaw line
  // 17, 21  Left eyebrow
  // 22, 26  Right eyebrow
  // 27, 30  Nose bridge
  // 30, 35  Lower nose
  // 36, 41  Left eye
  // 42, 47  Right Eye
  // 48, 59  Outer lip
  // 60, 67  Inner lip
  //
  //  2 points rectangle
  // 0-1  top-left (x,y)
  // 2-3  bottom-right (x,y)
  @override
  void paint(Canvas canvas, Size size) {
    if (pointsMap == null || pointsMap!.nFaces == 0) {
      return;
    }
    var path = Path();
    Paint paint = Paint();

    // background color
    if (backgroundColor != null) {
      paint.color = backgroundColor!;
      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
    }

    paint.color = const Color(0xFFFF0000);
    paint.strokeWidth = 2;
    paint.style = PaintingStyle.stroke;

    // print('******PAINTER: $pointsMap');
    if (pointsMap!.nFacePoints == 2) {
      for (int i = 0; i < pointsMap!.nFaces; ++i) {
        path.addRect(Rect.fromLTRB(
            pointsMap!.points[i * 4 + 0].toDouble(),
            pointsMap!.points[i * 4 + 1].toDouble(),
            pointsMap!.points[i * 4 + 2].toDouble(),
            pointsMap!.points[i * 4 + 3].toDouble()));
        canvas.drawPath(path, paint);
        drawText(canvas, size, i);
      }
    } else if (pointsMap!.nFacePoints == 68) {
      for (int i = 0; i < pointsMap!.nFaces; ++i) {
        int d = i * 136;
        // jaw
        path.moveTo(pointsMap!.points[d + 0].toDouble(),
            pointsMap!.points[d + 1].toDouble());
        for (int n = 2; n <= 32; n += 2) {
          path.lineTo(pointsMap!.points[d + n].toDouble(),
              pointsMap!.points[d + n + 1].toDouble());
        }
        // Left eyebrow
        path.moveTo(pointsMap!.points[d + 34].toDouble(),
            pointsMap!.points[d + 35].toDouble());
        for (int n = 36; n <= 42; n += 2) {
          path.lineTo(pointsMap!.points[d + n].toDouble(),
              pointsMap!.points[d + n + 1].toDouble());
        }
        // Right eyebrow
        path.moveTo(pointsMap!.points[d + 44].toDouble(),
            pointsMap!.points[d + 45].toDouble());
        for (int n = 46; n <= 52; n += 2) {
          path.lineTo(pointsMap!.points[d + n].toDouble(),
              pointsMap!.points[d + n + 1].toDouble());
        }
        // Nose bridge
        path.moveTo(pointsMap!.points[d + 54].toDouble(),
            pointsMap!.points[d + 55].toDouble());
        for (int n = 56; n <= 60; n += 2) {
          path.lineTo(pointsMap!.points[d + n].toDouble(),
              pointsMap!.points[d + n + 1].toDouble());
        }
        // Lower nose
        path.moveTo(pointsMap!.points[d + 60].toDouble(),
            pointsMap!.points[d + 61].toDouble());
        for (int n = 62; n <= 70; n += 2) {
          path.lineTo(pointsMap!.points[d + n].toDouble(),
              pointsMap!.points[d + n + 1].toDouble());
        }
        path.close();
        // Left eye
        path.moveTo(pointsMap!.points[d + 72].toDouble(),
            pointsMap!.points[d + 73].toDouble());
        for (int n = 74; n <= 82; n += 2) {
          path.lineTo(pointsMap!.points[d + n].toDouble(),
              pointsMap!.points[d + n + 1].toDouble());
        }
        path.close();
        // Right eye
        path.moveTo(pointsMap!.points[d + 84].toDouble(),
            pointsMap!.points[d + 85].toDouble());
        for (int n = 86; n <= 94; n += 2) {
          path.lineTo(pointsMap!.points[d + n].toDouble(),
              pointsMap!.points[d + n + 1].toDouble());
        }
        path.close();
        // Outer lip
        path.moveTo(pointsMap!.points[d + 96].toDouble(),
            pointsMap!.points[d + 97].toDouble());
        for (int n = 98; n <= 118; n += 2) {
          path.lineTo(pointsMap!.points[d + n].toDouble(),
              pointsMap!.points[d + n + 1].toDouble());
        }
        path.close();
        // Inner lip
        path.moveTo(pointsMap!.points[d + 120].toDouble(),
            pointsMap!.points[d + 121].toDouble());
        for (int n = 122; n <= 134; n += 2) {
          path.lineTo(pointsMap!.points[d + n].toDouble(),
              pointsMap!.points[d + n + 1].toDouble());
        }
        path.close();
        canvas.drawPath(path, paint);
      }
    }
  }

  drawText(Canvas canvas, Size size, int index) {
    if (pointsMap!.names.isNotEmpty) {
      final textPainter = TextPainter(
        text: TextSpan(
          text: ' ' + pointsMap!.names[index] + ' ',
          style: const TextStyle(
            color: Color(0xFFFFFFFF),
            fontSize: 20,
            fontWeight: FontWeight.bold,
            backgroundColor: Color(0xFFFF0000),
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout(
        minWidth: 0,
        maxWidth: size.width,
      );
      final offset = Offset(pointsMap!.points[index * 4 + 0].toDouble(),
          pointsMap!.points[index * 4 + 3].toDouble());
      textPainter.paint(canvas, offset);
    }
  }

  @override
  bool shouldRepaint(covariant PointsPainter oldDelegate) {
    // bool ret = (pointsMap!.points.isNotEmpty &&
    //     pointsMap!.points[0] != oldDelegate.pointsMap!.points[0]);
    // return ret;
    return true;
    // return pointsMap!.nFaces != oldDelegate.pointsMap!.nFaces;
  }
}
