import 'dart:math' as math;
import 'package:flutter/material.dart';

class SegmentedCirclePainter extends CustomPainter {
  final int segments;
  final Color color;
  final double strokeWidth;
  final double gapDegrees;

  const SegmentedCirclePainter({
    required this.segments,
    required this.color,
    required this.strokeWidth,
    this.gapDegrees = 8,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (segments <= 0) return;

    final center = size.center(Offset.zero);
    final radius = size.width / 2 - strokeWidth / 2;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final totalAngle = 2 * math.pi;
    final gap = gapDegrees * math.pi / 180;
    final sweep = (totalAngle - (segments * gap)) / segments;

    var start = -math.pi / 2;
    for (var i = 0; i < segments; i++) {
      canvas.drawArc(Rect.fromCircle(center: center, radius: radius), start, sweep, false, paint);
      start += sweep + gap;
    }
  }

  @override
  bool shouldRepaint(covariant SegmentedCirclePainter oldDelegate) {
    return oldDelegate.segments != segments ||
        oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.gapDegrees != gapDegrees;
  }
}
