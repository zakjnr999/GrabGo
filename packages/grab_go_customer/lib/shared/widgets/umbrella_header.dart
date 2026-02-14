import 'package:flutter/material.dart';
import 'dart:ui' show lerpDouble;
import 'package:grab_go_shared/grub_go_shared.dart';

class UmbrellaClipper extends CustomClipper<Path> {
  final double curveDepth;
  final int numberOfCurves;

  UmbrellaClipper({this.curveDepth = 20, this.numberOfCurves = 8});

  @override
  Path getClip(Size size) {
    final path = Path();

    path.lineTo(0, 0);

    path.lineTo(size.width, 0);

    path.lineTo(size.width, size.height - curveDepth);

    final curveWidth = size.width / numberOfCurves;

    for (int i = numberOfCurves - 1; i >= 0; i--) {
      final startX = (i + 1) * curveWidth;
      final endX = i * curveWidth;
      final midX = (startX + endX) / 2;

      final controlPoint1 = Offset(startX - curveWidth * 0.2, size.height - curveDepth * 0.5);
      final controlPoint2 = Offset(midX + curveWidth * 0.1, size.height - curveDepth * 0.1);
      final controlPoint3 = Offset(midX - curveWidth * 0.1, size.height - curveDepth * 0.1);
      final controlPoint4 = Offset(endX + curveWidth * 0.2, size.height - curveDepth * 0.5);

      path.cubicTo(
        controlPoint1.dx,
        controlPoint1.dy,
        controlPoint2.dx,
        controlPoint2.dy,
        midX,
        size.height - curveDepth * 0.2,
      );

      path.cubicTo(
        controlPoint3.dx,
        controlPoint3.dy,
        controlPoint4.dx,
        controlPoint4.dy,
        endX,
        size.height - curveDepth,
      );
    }

    path.lineTo(0, 0);
    path.close();

    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => true;
}

class UmbrellaHeaderMetrics {
  static double _baseExpandedHeight(Size size) {
    final height = size.height;
    final width = size.width;
    final safeWidth = width <= 0 ? 1.0 : width;
    final aspectRatio = height / safeWidth;

    final heightBased = height >= 900
        ? height * 0.205
        : height >= 780
        ? height * 0.215
        : height >= 700
        ? height * 0.205
        : height * 0.195;

    // Width-based fallback prevents very tall devices from producing oversized headers.
    final widthBased = width * 0.46;
    final tallScreenBlend = ((aspectRatio - 2.0) / 0.45).clamp(0.0, 1.0);
    final blended = lerpDouble(heightBased, widthBased, tallScreenBlend) ?? heightBased;

    return blended.clamp(138.0, 188.0);
  }

  static double expandedHeightFor(Size size, {double extra = 0}) {
    return _baseExpandedHeight(size) + extra;
  }

  static double contentTopPaddingFor(Size size, {double extra = 0}) {
    final expandedHeight = expandedHeightFor(size, extra: extra);
    final overlap = (expandedHeight * 0.18).clamp(22.0, 32.0);
    return expandedHeight - overlap;
  }

  static double contentPaddingFor(Size size, {double extra = 0, double gap = 12}) {
    final resolvedGap = gap == 12 ? (size.height * 0.012).clamp(10.0, 16.0) : gap;
    return expandedHeightFor(size, extra: extra) + resolvedGap;
  }
}

class UmbrellaHeader extends StatelessWidget {
  final Widget child;
  final double curveDepth;
  final int numberOfCurves;
  final double? height;
  final Color? backgroundColor;

  const UmbrellaHeader({
    super.key,
    required this.child,
    this.curveDepth = 20,
    this.numberOfCurves = 8,
    this.height,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final resolvedCurveDepth = curveDepth.clamp(16.0, 24.0).toDouble();

    return ClipPath(
      clipper: UmbrellaClipper(curveDepth: resolvedCurveDepth, numberOfCurves: numberOfCurves),
      child: Container(
        height: height,
        decoration: BoxDecoration(color: backgroundColor ?? colors.accentOrange),
        child: child,
      ),
    );
  }
}

class UmbrellaHeaderWithShadow extends StatelessWidget {
  final Widget child;
  final double curveDepth;
  final int numberOfCurves;
  final List<Color>? gradientColors;
  final double? height;
  final bool showShadow;
  final Color? backgroundColor;

  const UmbrellaHeaderWithShadow({
    super.key,
    required this.child,
    this.curveDepth = 20,
    this.numberOfCurves = 8,
    this.gradientColors,
    this.height,
    this.showShadow = true,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final resolvedCurveDepth = curveDepth.clamp(16.0, 24.0).toDouble();
    final effectiveBackgroundColor = backgroundColor ?? colors.accentOrange;

    return Stack(
      children: [
        if (showShadow)
          Positioned.fill(
            child: ClipPath(
              clipper: UmbrellaClipper(curveDepth: resolvedCurveDepth, numberOfCurves: numberOfCurves),
              child: Container(
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: effectiveBackgroundColor.withAlpha(40),
                      blurRadius: 20,
                      spreadRadius: 0,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
              ),
            ),
          ),
        UmbrellaHeader(
          curveDepth: resolvedCurveDepth,
          numberOfCurves: numberOfCurves,
          height: height,
          backgroundColor: effectiveBackgroundColor,
          child: child,
        ),
      ],
    );
  }
}
