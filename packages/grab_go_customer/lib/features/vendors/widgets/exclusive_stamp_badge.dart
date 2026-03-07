import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:grab_go_shared/grub_go_shared.dart';

class ExclusiveStampBadge extends StatelessWidget {
  final double width;
  final double height;
  final bool compact;

  const ExclusiveStampBadge({
    super.key,
    this.width = 74,
    this.height = 24,
    this.compact = false,
  });

  const ExclusiveStampBadge.compact({
    super.key,
    this.width = 16,
    this.height = 16,
  }) : compact = true;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final accent = colors.accentOrange;
    final foldColor = Color.lerp(accent, Colors.black, 0.18) ?? accent;
    final highlightColor = Color.lerp(accent, Colors.white, 0.12) ?? accent;

    if (compact) {
      final size = math.min(width, height);
      return SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _ExclusiveSealMarkPainter(
            fillColor: accent,
            detailColor: accent.withValues(alpha: 0.82),
          ),
        ),
      );
    }

    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: height * 0.14,
            bottom: height * 0.14,
            child: CustomPaint(
              size: Size(width * 0.16, height * 0.72),
              painter: _ExclusiveFoldPainter(fillColor: foldColor),
            ),
          ),
          Positioned(
            left: width * 0.06,
            child: CustomPaint(
              size: Size(width * 0.94, height),
              painter: _ExclusiveRibbonPainter(
                startColor: highlightColor,
                endColor: accent,
              ),
            ),
          ),
          Positioned(
            left: width * 0.17,
            right: width * 0.10,
            top: 0,
            bottom: 0,
            child: Center(
              child: Text(
                'EXCLUSIVE',
                maxLines: 1,
                overflow: TextOverflow.fade,
                softWrap: false,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 9.sp,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.35,
                  height: 1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExclusiveSealMarkPainter extends CustomPainter {
  final Color fillColor;
  final Color detailColor;

  const _ExclusiveSealMarkPainter({
    required this.fillColor,
    required this.detailColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerRadius = size.width * 0.48;
    final innerRadius = size.width * 0.40;
    final scallopPath = Path();
    const scallops = 10;

    for (var i = 0; i < scallops * 2; i++) {
      final radius = i.isEven ? outerRadius : innerRadius;
      final angle = (-math.pi / 2) + (math.pi / scallops) * i;
      final point = Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );
      if (i == 0) {
        scallopPath.moveTo(point.dx, point.dy);
      } else {
        scallopPath.lineTo(point.dx, point.dy);
      }
    }
    scallopPath.close();

    canvas.drawShadow(
      scallopPath,
      Colors.black.withValues(alpha: 0.14),
      2.r,
      false,
    );

    canvas.drawPath(
      scallopPath,
      Paint()
        ..color = fillColor
        ..style = PaintingStyle.fill,
    );

    canvas.drawCircle(
      center,
      size.width * 0.24,
      Paint()
        ..color = detailColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    canvas.drawCircle(
      center,
      size.width * 0.07,
      Paint()
        ..color = detailColor
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant _ExclusiveSealMarkPainter oldDelegate) {
    return oldDelegate.fillColor != fillColor ||
        oldDelegate.detailColor != detailColor;
  }
}

class _ExclusiveRibbonPainter extends CustomPainter {
  final Color startColor;
  final Color endColor;

  const _ExclusiveRibbonPainter({
    required this.startColor,
    required this.endColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width * 0.11, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width * 0.90, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawShadow(path, Colors.black.withValues(alpha: 0.16), 3.r, false);

    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [startColor, endColor],
        ).createShader(Offset.zero & size),
    );

    final highlightPath = Path()
      ..moveTo(size.width * 0.15, size.height * 0.16)
      ..lineTo(size.width * 0.94, size.height * 0.16);

    canvas.drawPath(
      highlightPath,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.18)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(covariant _ExclusiveRibbonPainter oldDelegate) {
    return oldDelegate.startColor != startColor ||
        oldDelegate.endColor != endColor;
  }
}

class _ExclusiveFoldPainter extends CustomPainter {
  final Color fillColor;

  const _ExclusiveFoldPainter({required this.fillColor});

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width, 0)
      ..lineTo(size.width * 0.34, size.height * 0.14)
      ..lineTo(0, size.height * 0.50)
      ..lineTo(size.width * 0.34, size.height * 0.86)
      ..lineTo(size.width, size.height)
      ..close();

    canvas.drawPath(
      path,
      Paint()
        ..color = fillColor
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant _ExclusiveFoldPainter oldDelegate) {
    return oldDelegate.fillColor != fillColor;
  }
}
