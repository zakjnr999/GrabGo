import 'package:flutter/material.dart';
import 'package:grab_go_shared/grub_go_shared.dart';

/// Custom clipper that creates an umbrella/scalloped bottom shape with multiple small curves
class UmbrellaClipper extends CustomClipper<Path> {
  final double curveDepth;
  final int numberOfCurves;

  UmbrellaClipper({this.curveDepth = 20, this.numberOfCurves = 8});

  @override
  Path getClip(Size size) {
    final path = Path();

    // Start from top left
    path.lineTo(0, 0);

    // Top edge
    path.lineTo(size.width, 0);

    // Right edge down to where curves start
    path.lineTo(size.width, size.height - curveDepth);

    // Create multiple small scalloped curves at the bottom (umbrella style)
    final curveWidth = size.width / numberOfCurves;

    for (int i = numberOfCurves - 1; i >= 0; i--) {
      final startX = (i + 1) * curveWidth;
      final endX = i * curveWidth;
      final midX = (startX + endX) / 2;

      // Control points for smooth, rounded scalloped curves
      // Adjusted to create softer, rounder curves instead of sharp points
      final controlPoint1 = Offset(startX - curveWidth * 0.2, size.height - curveDepth * 0.5);
      final controlPoint2 = Offset(midX + curveWidth * 0.1, size.height - curveDepth * 0.1);
      final controlPoint3 = Offset(midX - curveWidth * 0.1, size.height - curveDepth * 0.1);
      final controlPoint4 = Offset(endX + curveWidth * 0.2, size.height - curveDepth * 0.5);

      // Create smooth rounded scalloped curve (down curve)
      path.cubicTo(
        controlPoint1.dx,
        controlPoint1.dy,
        controlPoint2.dx,
        controlPoint2.dy,
        midX,
        size.height - curveDepth * 0.05,
      );

      // Create smooth rounded scalloped curve (up curve)
      path.cubicTo(
        controlPoint3.dx,
        controlPoint3.dy,
        controlPoint4.dx,
        controlPoint4.dy,
        endX,
        size.height - curveDepth,
      );
    }

    // Left edge back to start
    path.lineTo(0, 0);
    path.close();

    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => true;
}

/// Umbrella-shaped header widget with gradient background
class UmbrellaHeader extends StatelessWidget {
  final Widget child;
  final double curveDepth;
  final int numberOfCurves;
  final List<Color>? gradientColors;
  final double? height;

  const UmbrellaHeader({
    super.key,
    required this.child,
    this.curveDepth = 20,
    this.numberOfCurves = 8,
    this.gradientColors,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    final defaultGradient = [colors.accentOrange, colors.accentOrange];

    return ClipPath(
      clipper: UmbrellaClipper(curveDepth: curveDepth, numberOfCurves: numberOfCurves),
      child: Container(
        height: height,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradientColors ?? defaultGradient,
          ),
        ),
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

  const UmbrellaHeaderWithShadow({
    super.key,
    required this.child,
    this.curveDepth = 20,
    this.numberOfCurves = 8,
    this.gradientColors,
    this.height,
    this.showShadow = true,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Stack(
      children: [
        // Shadow layer
        if (showShadow)
          Positioned.fill(
            child: ClipPath(
              clipper: UmbrellaClipper(curveDepth: curveDepth, numberOfCurves: numberOfCurves),
              child: Container(
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: colors.accentOrange.withAlpha(40),
                      blurRadius: 20,
                      spreadRadius: 0,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
              ),
            ),
          ),
        // Main content
        UmbrellaHeader(
          curveDepth: curveDepth,
          numberOfCurves: numberOfCurves,
          gradientColors: gradientColors,
          height: height,
          child: child,
        ),
      ],
    );
  }
}
