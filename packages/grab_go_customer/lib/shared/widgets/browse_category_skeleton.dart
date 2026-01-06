import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:grab_go_shared/shared/utils/app_colors_extension.dart';
import 'package:grab_go_shared/shared/utils/constants.dart';
import 'package:shimmer/shimmer.dart';

class BrowseCategorySkeleton extends StatelessWidget {
  final AppColorsExtension colors;
  final bool isDark;

  const BrowseCategorySkeleton({super.key, required this.colors, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      padding: EdgeInsets.only(left: 20.w, right: 20.w, bottom: 16.h),
      itemCount: 8, // Show 8 placeholder items
      separatorBuilder: (context, index) => SizedBox(height: 12.h),
      itemBuilder: (context, index) {
        return Container(
          padding: EdgeInsets.all(16.r),
          decoration: BoxDecoration(
            color: colors.backgroundPrimary,
            borderRadius: BorderRadius.circular(KBorderSize.borderMedium),
            border: Border.all(color: colors.inputBorder.withValues(alpha: 0.3), width: 0.5),
          ),
          child: Row(
            children: [
              // Category Icon/Emoji Placeholder
              Shimmer.fromColors(
                baseColor: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                highlightColor: isDark ? Colors.grey.shade700 : Colors.grey.shade100,
                child: Container(
                  width: 56.w,
                  height: 56.h,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(KBorderSize.borderSmall),
                  ),
                ),
              ),
              SizedBox(width: 16.w),
              // Category Info Placeholders
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Shimmer.fromColors(
                      baseColor: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                      highlightColor: isDark ? Colors.grey.shade700 : Colors.grey.shade100,
                      child: Container(
                        width: 120.w,
                        height: 16.h,
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4.r)),
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Shimmer.fromColors(
                      baseColor: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                      highlightColor: isDark ? Colors.grey.shade700 : Colors.grey.shade100,
                      child: Container(
                        width: 80.w,
                        height: 13.h,
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4.r)),
                      ),
                    ),
                  ],
                ),
              ),
              // Arrow Icon Placeholder
              Shimmer.fromColors(
                baseColor: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                highlightColor: isDark ? Colors.grey.shade700 : Colors.grey.shade100,
                child: Container(
                  width: 24.w,
                  height: 24.h,
                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
