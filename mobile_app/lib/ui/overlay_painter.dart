import 'package:flutter/material.dart';

import '../core/models.dart';

/// Draws walking-corridor guides and detection boxes over the camera preview.
class OverlayPainter extends CustomPainter {
  OverlayPainter(this.result, this.frameSize);

  final FrameResult? result;
  final Size frameSize;

  @override
  void paint(Canvas canvas, Size size) {
    final r = result;
    if (r == null || frameSize.width == 0) return;

    final guide = Paint()
      ..color = Colors.white54
      ..strokeWidth = 2;
    final sx = size.width / frameSize.width;
    final sy = size.height / frameSize.height;
    final xs = (r.corridorXMin != null && r.corridorXMax != null)
        ? [r.corridorXMin! * sx, r.corridorXMax! * sx]
        : [0.32 * size.width, 0.68 * size.width];
    for (final x in xs) {
      for (double y = 0; y < size.height; y += 16) {
        canvas.drawLine(Offset(x, y), Offset(x, y + 8), guide);
      }
    }

    final hazardNames = r.hazards.map((h) => h.className).toSet();

    for (final d in r.detections) {
      if (d.box.length < 4) continue;
      final isHazard = hazardNames.contains(d.className);
      final color = d.isApproaching
          ? Colors.redAccent
          : isHazard
              ? Colors.orangeAccent
              : d.isFace
                  ? Colors.lightBlueAccent
                  : d.isText
                      ? Colors.purpleAccent
                      : Colors.greenAccent;
      final rect = Rect.fromLTRB(d.box[0] * sx, d.box[1] * sy, d.box[2] * sx, d.box[3] * sy);
      canvas.drawRect(
        rect,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = d.isApproaching ? 4 : 2.5,
      );
      final tp = TextPainter(
        text: TextSpan(
          text: '${d.className} ${(d.confidence * 100).round()}%',
          style: TextStyle(color: Colors.black, backgroundColor: color, fontSize: 12, fontWeight: FontWeight.bold),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: 180);
      tp.paint(canvas, Offset(rect.left, (rect.top - tp.height).clamp(0.0, size.height).toDouble()));
    }
  }

  @override
  bool shouldRepaint(covariant OverlayPainter old) => old.result != result;
}
