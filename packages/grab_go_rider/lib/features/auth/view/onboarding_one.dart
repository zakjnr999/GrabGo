import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';

class OnboardingOne extends StatelessWidget {
  const OnboardingOne({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final padding = MediaQuery.of(context).padding;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colors.accentViolet, colors.accentViolet.withValues(alpha: 0.85)],
        ),
      ),
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 28.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          SizedBox(height: 8.h),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(20.r),
              border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SvgPicture.asset(
                  Assets.icons.boxIso,
                  package: "grab_go_shared",
                  width: 16.w,
                  height: 16.h,
                  colorFilter: ColorFilter.mode(Colors.white, BlendMode.srcIn),
                ),
                SizedBox(width: 8.w),
                Text(
                  AppStrings.riderOnboardingOneBadge,
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 24.h),
          Text(
            AppStrings.riderOnboardingOneMain,
            style: TextStyle(
              fontSize: 32.sp,
              fontWeight: FontWeight.w900,
              height: 1.2,
              color: Colors.white,
              letterSpacing: -0.2,
            ),
          ),
          SizedBox(height: 10.h),
          Text(
            AppStrings.riderOnboardingOneSub,
            style: TextStyle(
              fontSize: 15.sp,
              fontWeight: FontWeight.w400,
              height: 1.6,
              color: Colors.white.withValues(alpha: 0.9),
              letterSpacing: 0.2,
            ),
          ),
          SizedBox(height: padding.bottom + 70.h),
        ],
      ),
    );
  }
}
