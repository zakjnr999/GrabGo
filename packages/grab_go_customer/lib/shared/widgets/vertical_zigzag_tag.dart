import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class VerticalZigzagTag extends StatelessWidget {
  final String primaryText;
  final String secondaryText;
  final Color color;

  const VerticalZigzagTag({super.key, required this.primaryText, required this.secondaryText, required this.color});

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: const _ZigzagBottomTagClipper(depth: 7, teeth: 5),
      child: Container(
        width: 40,
        height: 56,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color, color.withValues(alpha: 0.84)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        padding: EdgeInsets.fromLTRB(5.w, 6.h, 5.w, 12.h),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              primaryText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.white, fontSize: 10.sp, fontWeight: FontWeight.w800, height: 1),
            ),
            SizedBox(height: 2.h),
            Text(
              secondaryText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.95),
                fontSize: 8.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ZigzagBottomTagClipper extends CustomClipper<Path> {
  final double depth;
  final int teeth;

  const _ZigzagBottomTagClipper({required this.depth, required this.teeth});

  @override
  Path getClip(Size size) {
    final resolvedTeeth = teeth.clamp(2, 8).toInt();
    final resolvedDepth = depth.clamp(3.0, size.height * 0.4).toDouble();
    final baseY = size.height - resolvedDepth;
    final toothWidth = size.width / resolvedTeeth;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, baseY);

    for (int i = resolvedTeeth; i > 0; i--) {
      final left = toothWidth * (i - 1);
      final mid = left + (toothWidth / 2);
      path
        ..lineTo(mid, size.height)
        ..lineTo(left, baseY);
    }

    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant _ZigzagBottomTagClipper oldClipper) {
    return oldClipper.depth != depth || oldClipper.teeth != teeth;
  }
}
