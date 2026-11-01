import 'package:flutter/material.dart';

import '../core/models.dart';

/// Draws walking-corridor guides and high-contrast, glowing detection boxes
/// exactly matching the web interface (index.html).
class OverlayPainter extends CustomPainter {
  OverlayPainter(this.result, this.frameSize);

  final FrameResult? result;
  final Size frameSize;

  @override
  void paint(Canvas canvas, Size size) {
    final r = result;
    if (r == null || frameSize.width <= 0 || frameSize.height <= 0) return;

    // Compute exact coordinate mapping matching BoxFit.cover
    final fitted = applyBoxFit(BoxFit.cover, frameSize, size);
    final dst = fitted.destination;
    final dx = (size.width - dst.width) / 2;
    final dy = (size.height - dst.height) / 2;
    final sx = dst.width / frameSize.width;
    final sy = dst.height / frameSize.height;

    double mapX(double x) => dx + x * sx;
    double mapY(double y) => dy + y * sy;

    // 1. Draw Subtle Walking Corridor Guides (matching web index.html)
    final corridorXMin = r.corridorXMin ?? (frameSize.width * 0.32);
    final corridorXMax = r.corridorXMax ?? (frameSize.width * 0.68);
    final screenXMin = mapX(corridorXMin);
    final screenXMax = mapX(corridorXMax);

    final corridorPaint = Paint()
      ..color = const Color(0x6638BDF8) // cyan rgba(56, 189, 248, 0.4)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    // Draw dashed lines
    _drawDashedVerticalLine(canvas, screenXMin, 0, size.height, corridorPaint);
    _drawDashedVerticalLine(canvas, screenXMax, 0, size.height, corridorPaint);

    // Corridor label at bottom
    final corridorText = TextPainter(
      text: const TextSpan(
        text: 'WALKING CORRIDOR',
        style: TextStyle(
          color: Color(0x9938BDF8),
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.5,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    corridorText.paint(
      canvas,
      Offset((screenXMin + screenXMax - corridorText.width) / 2, size.height - 110),
    );

    // 2. Map hazards by trackId
    final urgentSet = <int>{};
    final hazardMap = <int, Hazard>{};
    for (final h in r.hazards) {
      if (h.trackId != null) {
        hazardMap[h.trackId!] = h;
        if (h.isUrgent) urgentSet.add(h.trackId!);
      }
    }

    // 3. Draw Bounding Boxes and Labels with glowing borders
    for (final d in r.detections) {
      if (d.box.length < 4) continue;

      final isUrgent = (d.trackId != null && urgentSet.contains(d.trackId)) || r.isUrgent && d.isApproaching;
      final isHazard = (d.trackId != null && hazardMap.containsKey(d.trackId)) ||
          r.hazards.any((h) => h.className == d.className);

      final Color strokeColor;
      final Color shadowColor;
      final double strokeWidth;

      if (isUrgent) {
        strokeColor = const Color(0xFFEF4444); // Red
        shadowColor = const Color(0xAAEF4444);
        strokeWidth = 3.5;
      } else if (isHazard) {
        strokeColor = const Color(0xFFF59E0B); // Amber
        shadowColor = const Color(0xAAF59E0B);
        strokeWidth = 3.0;
      } else if (d.isFace) {
        strokeColor = const Color(0xFF38BDF8); // Cyan
        shadowColor = const Color(0xAA38BDF8);
        strokeWidth = 2.5;
      } else if (d.isText) {
        strokeColor = const Color(0xFFA855F7); // Purple
        shadowColor = const Color(0xAAA855F7);
        strokeWidth = 2.5;
      } else {
        strokeColor = const Color(0xFF38BDF8); // Sky Blue (like web)
        shadowColor = const Color(0x8838BDF8);
        strokeWidth = 2.5;
      }

      final rx1 = mapX(d.box[0]);
      final ry1 = mapY(d.box[1]);
      final rx2 = mapX(d.box[2]);
      final ry2 = mapY(d.box[3]);
      final rect = Rect.fromLTRB(rx1, ry1, rx2, ry2);

      // Draw glowing outline (shadow blur effect)
      final glowPaint = Paint()
        ..color = shadowColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth + 2.0
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);
      canvas.drawRect(rect, glowPaint);

      // Draw primary bounding box
      final boxPaint = Paint()
        ..color = strokeColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth;
      canvas.drawRect(rect, boxPaint);

      // Construct label matching index.html: "[#1] person 89% ↑ APPROACHING"
      final parts = <String>[];
      if (d.trackId != null) parts.add('[#${d.trackId}]');
      parts.add(d.className);
      parts.add('${(d.confidence * 100).round()}%');
      if (d.isApproaching) parts.add('↑ APPROACHING');

      final label = parts.join(' ');

      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            color: strokeColor,
            fontSize: 13,
            fontWeight: FontWeight.bold,
            shadows: [
              Shadow(color: Colors.black.withOpacity(0.9), blurRadius: 4, offset: const Offset(1, 1)),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: size.width - 20);

      final labelY = (rect.top - tp.height - 4).clamp(10.0, size.height - 30.0).toDouble();
      final labelX = rect.left.clamp(10.0, size.width - tp.width - 10.0).toDouble();

      // Translucent dark background badge behind label
      final badgeRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(labelX - 4, labelY - 2, tp.width + 8, tp.height + 4),
        const Radius.circular(4),
      );
      canvas.drawRRect(
        badgeRect,
        Paint()..color = Colors.black.withOpacity(0.75),
      );
      canvas.drawRRect(
        badgeRect,
        Paint()
          ..color = strokeColor.withOpacity(0.5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );

      tp.paint(canvas, Offset(labelX, labelY));
    }
  }

  void _drawDashedVerticalLine(Canvas canvas, double x, double startY, double endY, Paint paint) {
    const dashHeight = 8.0;
    const dashSpace = 8.0;
    double currentY = startY;
    while (currentY < endY) {
      canvas.drawLine(Offset(x, currentY), Offset(x, currentY + dashHeight), paint);
      currentY += dashHeight + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant OverlayPainter old) =>
      old.result != result || old.frameSize != frameSize;
}
