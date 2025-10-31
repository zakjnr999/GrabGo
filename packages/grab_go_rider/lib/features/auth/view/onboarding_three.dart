import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:grab_go_shared/grub_go_shared.dart';

class OnboardingThree extends StatelessWidget {
  const OnboardingThree({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      color: colors.accentOrange,
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 28.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 8.h),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
            decoration: BoxDecoration(color: colors.backgroundPrimary, borderRadius: BorderRadius.circular(20.r)),
            child: Text(
              AppStrings.riderOnboardingThreeBadge,
              style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w700, color: colors.textPrimary),
            ),
          ),
          SizedBox(height: 16.h),
          Text(
            AppStrings.riderOnboardingThreeMain,
            style: TextStyle(fontSize: 28.sp, fontWeight: FontWeight.w800, height: 1.25, color: colors.textPrimary),
          ),
          SizedBox(height: 14.h),
          Text(
            AppStrings.riderOnboardingThreeSub,
            style: TextStyle(fontSize: 14.sp, height: 1.5, color: colors.textSecondary),
          ),
          const Spacer(),
        ],
      ),
    );
  }
}
