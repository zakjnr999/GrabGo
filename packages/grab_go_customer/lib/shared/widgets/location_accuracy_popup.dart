import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:flutter_svg/svg.dart';

class LocationAccuracyPopup extends StatelessWidget {
  final double distanceInMeters;
  final VoidCallback onUpdateLocation;
  final VoidCallback onDismiss;

  const LocationAccuracyPopup({
    super.key,
    required this.distanceInMeters,
    required this.onUpdateLocation,
    required this.onDismiss,
  });

  String _getDistanceText() {
    if (distanceInMeters < 1000) {
      return '${distanceInMeters.toStringAsFixed(0)}m';
    } else {
      return '${(distanceInMeters / 1000).toStringAsFixed(1)}km';
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final Color bgColor = isDark ? colors.backgroundSecondary : Colors.white;
    final Color primaryColor = colors.accentOrange;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tooltip Arrow
          Padding(
            padding: EdgeInsets.only(left: 12.w),
            child: CustomPaint(
              painter: _TrianglePainter(color: bgColor),
              size: Size(16.w, 8.h),
            ),
          ),
          // Tooltip Body
          Container(
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(KBorderSize.borderRadius15),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 15, offset: const Offset(0, 8)),
              ],
            ),
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
            child: Row(
              children: [
                SvgPicture.asset(
                  Assets.icons.mapPin,
                  package: 'grab_go_shared',
                  height: 18.h,
                  width: 18.w,
                  colorFilter: ColorFilter.mode(primaryColor, BlendMode.srcIn),
                ),
                SizedBox(width: 12.w),
                // Text content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Location Mismatch',
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w800,
                          fontFamily: "Lato",
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        'You seem to be quite far away from your current location.',
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w500,
                          fontFamily: "Lato",
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 8.w),
                // Update Location Action
                Material(
                  color: primaryColor,
                  borderRadius: BorderRadius.circular(KBorderSize.borderRadius15),
                  child: InkWell(
                    onTap: onUpdateLocation,
                    borderRadius: BorderRadius.circular(KBorderSize.borderRadius15),
                    child: Padding(
                      padding: EdgeInsets.all(8.r),
                      child: SvgPicture.asset(
                        Assets.icons.crosshair,
                        package: 'grab_go_shared',
                        height: 18.h,
                        width: 18.w,
                        colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 8.w),
                // Close button
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onDismiss,
                    borderRadius: BorderRadius.circular(20.r),
                    child: Padding(
                      padding: EdgeInsets.all(4.r),
                      child: SvgPicture.asset(
                        Assets.icons.xmark,
                        package: 'grab_go_shared',
                        height: 22.h,
                        width: 22.w,
                        colorFilter: ColorFilter.mode(colors.textSecondary.withValues(alpha: 0.6), BlendMode.srcIn),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TrianglePainter extends CustomPainter {
  final Color color;

  _TrianglePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(size.width / 2, 0);
    path.lineTo(0, size.height);
    path.lineTo(size.width, size.height);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
