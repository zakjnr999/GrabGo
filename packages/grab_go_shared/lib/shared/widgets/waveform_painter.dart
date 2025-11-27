import 'package:flutter/material.dart';

class WaveformPainter extends CustomPainter {
  WaveformPainter({required this.bars, required this.progress, required this.activeColor, required this.inactiveColor});

  final List<double> bars;
  final double progress;
  final Color activeColor;
  final Color inactiveColor;

  @override
  void paint(Canvas canvas, Size size) {
    // Guard against empty bars list
    if (bars.isEmpty) return;

    final barWidth = 3.0;
    // Avoid division by zero when there's only 1 bar
    final spacing = bars.length > 1 ? (size.width - (bars.length * barWidth)) / (bars.length - 1) : 0.0;
    final maxHeight = size.height;
    // Clamp progressIndex to valid range to avoid edge case when progress is exactly 1.0
    final progressIndex = (progress * bars.length).floor().clamp(0, bars.length - 1);

    for (int i = 0; i < bars.length; i++) {
      final x = i * (barWidth + spacing);
      final barHeight = bars[i] * maxHeight;
      final y = (maxHeight - barHeight) / 2;

      final paint = Paint()
        ..color = i <= progressIndex ? activeColor : inactiveColor
        ..strokeCap = StrokeCap.round;

      final rect = RRect.fromRectAndRadius(Rect.fromLTWH(x, y, barWidth, barHeight), const Radius.circular(2));
      canvas.drawRRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant WaveformPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.inactiveColor != inactiveColor ||
        oldDelegate.bars != bars;
  }
}
