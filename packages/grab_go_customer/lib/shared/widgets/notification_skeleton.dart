import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shimmer/shimmer.dart';
import 'package:grab_go_shared/grub_go_shared.dart';

class NotificationSkeleton extends StatelessWidget {
  final AppColorsExtension colors;
  final bool isDark;

  const NotificationSkeleton({super.key, required this.colors, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: colors.backgroundPrimary,
        borderRadius: BorderRadius.circular(KBorderSize.borderRadius15),
        border: Border.all(color: colors.inputBorder.withValues(alpha: 0.3), width: 0.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon/Avatar Skeleton
          Shimmer.fromColors(
            baseColor: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
            highlightColor: isDark ? Colors.grey.shade700 : Colors.grey.shade100,
            child: Container(
              height: 36.h,
              width: 36.w,
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            ),
          ),
          SizedBox(width: 16.w),
          // Content Skeleton
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Shimmer.fromColors(
                  baseColor: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                  highlightColor: isDark ? Colors.grey.shade700 : Colors.grey.shade100,
                  child: Container(
                    width: 150.w,
                    height: 14.h,
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4.r)),
                  ),
                ),
                SizedBox(height: 8.h),
                // Message Line 1
                Shimmer.fromColors(
                  baseColor: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                  highlightColor: isDark ? Colors.grey.shade700 : Colors.grey.shade100,
                  child: Container(
                    width: double.infinity,
                    height: 12.h,
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4.r)),
                  ),
                ),
                SizedBox(height: 6.h),
                // Message Line 2 (shorter)
                Shimmer.fromColors(
                  baseColor: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                  highlightColor: isDark ? Colors.grey.shade700 : Colors.grey.shade100,
                  child: Container(
                    width: 200.w,
                    height: 12.h,
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4.r)),
                  ),
                ),
                SizedBox(height: 12.h),
                // Timestamp
                Shimmer.fromColors(
                  baseColor: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                  highlightColor: isDark ? Colors.grey.shade700 : Colors.grey.shade100,
                  child: Container(
                    width: 60.w,
                    height: 10.h,
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4.r)),
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
