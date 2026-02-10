import 'package:flutter/material.dart';
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
    final double factor = height >= 780
        ? 0.22
        : height >= 700
        ? 0.215
        : 0.20;
    return (height * factor).clamp(130.0, 200.0);
  }

  static double expandedHeightFor(Size size, {double extra = 0}) {
    return _baseExpandedHeight(size) + extra;
  }

  static double contentTopPaddingFor(Size size, {double extra = 0}) {
    return (_baseExpandedHeight(size) * 0.58) + extra;
  }
}

class UmbrellaHeader extends StatelessWidget {
  final Widget child;
  final double curveDepth;
  final int numberOfCurves;
  final double? height;

  const UmbrellaHeader({super.key, required this.child, this.curveDepth = 20, this.numberOfCurves = 8, this.height});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return ClipPath(
      clipper: UmbrellaClipper(curveDepth: curveDepth, numberOfCurves: numberOfCurves),
      child: Container(
        height: height,
        decoration: BoxDecoration(color: colors.accentOrange),
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
        UmbrellaHeader(curveDepth: curveDepth, numberOfCurves: numberOfCurves, height: height, child: child),
      ],
    );
  }
}
