import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// A custom progress bar with step markers (seek points) evenly distributed.
///
/// Each step shows a dot on the track. Completed steps are filled with
/// [activeColor], remaining steps show as hollow circles, and the track
/// smoothly fills between them.
///
/// Use [steps] for the total number of segments (i.e. milestones),
/// [completedSteps] for how many are done, and optionally [progress] (0..1)
/// for partial fill within the current step.
class SteppedProgressBar extends StatelessWidget {
  /// Total number of steps (seek points = steps + 1 if you count start).
  final int steps;

  /// How many steps are fully completed (0..steps).
  final int completedSteps;

  /// Optional fractional progress within the current step (0.0 – 1.0).
  /// For example, 0.5 means half-way through the current incomplete step.
  final double progress;

  /// Height of the track bar.
  final double trackHeight;

  /// Radius of each seek-point dot.
  final double dotRadius;

  /// Color of the filled track and completed dots.
  final Color activeColor;

  /// Color of the unfilled track and remaining dots.
  final Color inactiveColor;

  /// Optional glow behind the leading edge dot.
  final bool showGlow;

  const SteppedProgressBar({
    super.key,
    required this.steps,
    required this.completedSteps,
    this.progress = 0.0,
    this.trackHeight = 5,
    this.dotRadius = 6,
    this.activeColor = const Color(0xFF7C5CFC),
    this.inactiveColor = const Color(0x30888888),
    this.showGlow = true,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: (dotRadius * 2 + 8).h,
      child: CustomPaint(
        size: Size(double.infinity, (dotRadius * 2 + 8).h),
        painter: _SteppedProgressPainter(
          steps: steps,
          completedSteps: completedSteps,
          progress: progress.clamp(0.0, 1.0),
          trackHeight: trackHeight.h,
          dotRadius: dotRadius.r,
          activeColor: activeColor,
          inactiveColor: inactiveColor,
          showGlow: showGlow,
        ),
      ),
    );
  }
}

class _SteppedProgressPainter extends CustomPainter {
  final int steps;
  final int completedSteps;
  final double progress;
  final double trackHeight;
  final double dotRadius;
  final Color activeColor;
  final Color inactiveColor;
  final bool showGlow;

  _SteppedProgressPainter({
    required this.steps,
    required this.completedSteps,
    required this.progress,
    required this.trackHeight,
    required this.dotRadius,
    required this.activeColor,
    required this.inactiveColor,
    required this.showGlow,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (steps <= 0) return;

    final centerY = size.height / 2;
    final leftPad = dotRadius;
    final rightPad = dotRadius;
    final trackWidth = size.width - leftPad - rightPad;

    // ─── Inactive Track (full width) ───
    final inactiveTrackPaint = Paint()
      ..color = inactiveColor
      ..style = PaintingStyle.fill;

    final inactiveRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(leftPad, centerY - trackHeight / 2, trackWidth, trackHeight),
      Radius.circular(trackHeight / 2),
    );
    canvas.drawRRect(inactiveRect, inactiveTrackPaint);

    // ─── Calculate fill amount ───
    // Each step is 1/steps of the track.
    // completedSteps gives full segments, progress fills part of the next one.
    final segmentWidth = trackWidth / steps;
    final filledWidth = (completedSteps * segmentWidth) + (progress * segmentWidth);
    final clampedFill = filledWidth.clamp(0.0, trackWidth);

    // ─── Active Track ───
    if (clampedFill > 0) {
      final activeTrackPaint = Paint()
        ..shader = LinearGradient(
          colors: [activeColor, activeColor.withValues(alpha: 0.85)],
        ).createShader(Rect.fromLTWH(leftPad, centerY - trackHeight / 2, clampedFill, trackHeight))
        ..style = PaintingStyle.fill;

      final activeRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(leftPad, centerY - trackHeight / 2, clampedFill, trackHeight),
        Radius.circular(trackHeight / 2),
      );
      canvas.drawRRect(activeRect, activeTrackPaint);
    }

    // ─── Seek Points (dots at each step boundary) ───
    // We draw steps + 1 dots (start + each segment end)
    final totalDots = steps + 1;
    for (int i = 0; i < totalDots; i++) {
      final cx = leftPad + (i / steps) * trackWidth;
      final isCompleted = i <= completedSteps;
      final isLeading = i == completedSteps && !_allDone;

      if (isCompleted) {
        // ── Filled dot ──
        final filledPaint = Paint()
          ..color = activeColor
          ..style = PaintingStyle.fill;

        // Glow on the leading edge
        if (showGlow && isLeading && !_allDone) {
          final glowPaint = Paint()
            ..color = activeColor.withValues(alpha: 0.25)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, dotRadius * 0.8);
          canvas.drawCircle(Offset(cx, centerY), dotRadius * 1.5, glowPaint);
        }

        canvas.drawCircle(Offset(cx, centerY), dotRadius, filledPaint);

        // Inner check-like accent for completed (non-leading) dots
        if (!isLeading || _allDone) {
          final innerPaint = Paint()
            ..color = Colors.white
            ..style = PaintingStyle.fill;
          canvas.drawCircle(Offset(cx, centerY), dotRadius * 0.38, innerPaint);
        }
      } else {
        // ── Solid dot (remaining) ──
        final solidPaint = Paint()
          ..color = inactiveColor
          ..style = PaintingStyle.fill;

        canvas.drawCircle(Offset(cx, centerY), dotRadius, solidPaint);
      }
    }
  }

  bool get _allDone => completedSteps >= steps;

  @override
  bool shouldRepaint(covariant _SteppedProgressPainter oldDelegate) =>
      oldDelegate.steps != steps ||
      oldDelegate.completedSteps != completedSteps ||
      oldDelegate.progress != progress ||
      oldDelegate.activeColor != activeColor ||
      oldDelegate.inactiveColor != inactiveColor;
}
