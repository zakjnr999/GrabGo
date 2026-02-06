import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';

class NoInternetScreen extends StatelessWidget {
  final VoidCallback onRetry;

  const NoInternetScreen({super.key, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 40.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(24.r),
              decoration: BoxDecoration(color: colors.accentOrange.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: SvgPicture.asset(
                Assets.icons.wifiOff,
                package: 'grab_go_shared',
                height: 56.h,
                width: 56.w,
                colorFilter: ColorFilter.mode(colors.accentOrange, BlendMode.srcIn),
              ),
            ),

            SizedBox(height: 24.h),

            Text(
              'No Internet Connection',
              style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.w700, color: colors.textPrimary),
              textAlign: TextAlign.center,
            ),

            SizedBox(height: 8.h),

            // Subtitle
            Text(
              'Please check your network settings and try again.',
              style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w400, color: colors.textSecondary),
              textAlign: TextAlign.center,
            ),

            SizedBox(height: 32.h),

            // Retry button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onRetry,
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.accentOrange,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 14.h),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(KBorderSize.borderMedium)),
                  elevation: 0,
                ),
                child: Text(
                  'Try Again',
                  style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
