import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:grab_go_shared/shared/utils/app_colors_extension.dart';
import 'package:grab_go_shared/shared/utils/constants.dart';
import 'package:shimmer/shimmer.dart';

class OngoingOrdersSkeleton extends StatelessWidget {
  const OngoingOrdersSkeleton({super.key, required this.colors, required this.isDark});

  final AppColorsExtension colors;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: colors.backgroundPrimary,
        borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
      ),
      child: Shimmer.fromColors(
        baseColor: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
        highlightColor: isDark ? Colors.grey.shade700 : Colors.grey.shade100,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 96.w,
                  height: 22.h,
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20.r)),
                ),
                Container(
                  width: 130.w,
                  height: 12.h,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
                  ),
                ),
              ],
            ),

            SizedBox(height: 14.h),

            // Route row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Container(
                    height: 14.h,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
                    ),
                  ),
                ),
                SizedBox(width: 8.w),
                Container(
                  width: 16.w,
                  height: 12.h,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
                  ),
                ),
                SizedBox(width: 8.w),
                Container(
                  width: 110.w,
                  height: 14.h,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
                  ),
                ),
              ],
            ),

            SizedBox(height: 10.h),

            // Distance/status row
            Row(
              children: [
                Container(
                  width: 14.w,
                  height: 14.w,
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(7.r)),
                ),
                SizedBox(width: 8.w),
                Container(
                  width: 72.w,
                  height: 12.h,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
                  ),
                ),
                SizedBox(width: 10.w),
                Container(
                  width: 4.w,
                  height: 4.w,
                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: Container(
                    height: 12.h,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
                    ),
                  ),
                ),
              ],
            ),

            SizedBox(height: 12.h),

            // Compact party row
            Row(
              children: [
                Container(
                  width: 44.w,
                  height: 44.w,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
                  ),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 130.w,
                        height: 13.h,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
                        ),
                      ),
                      SizedBox(height: 6.h),
                      Container(
                        width: 190.w,
                        height: 11.h,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            SizedBox(height: 14.h),

            // Summary metric tiles
            Row(
              children: [
                Expanded(child: _metricTile()),
                SizedBox(width: 10.w),
                Expanded(child: _metricTile()),
                SizedBox(width: 10.w),
                Expanded(child: _metricTile()),
              ],
            ),

            SizedBox(height: 14.h),

            // Actions
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 56.h,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
                    ),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Container(
                    height: 56.h,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _metricTile() {
    return Container(
      height: 52.h,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(KBorderSize.borderRadius4)),
    );
  }
}
