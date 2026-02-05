import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:shimmer/shimmer.dart';

class BrowsePageSkeleton extends StatelessWidget {
  const BrowsePageSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(colors, isDark, 'Trending Now'),
        SizedBox(height: 12.h),
        _buildTrendingItemSkeleton(colors, isDark),

        SizedBox(height: KSpacing.lg.h),

        _buildSectionHeader(colors, isDark, 'Popular Categories'),
        SizedBox(height: 12.h),
        _buildCategoryChipsSkeleton(colors, isDark),

        SizedBox(height: KSpacing.lg.h),

        _buildSectionHeader(colors, isDark, 'Quick Searches'),
        SizedBox(height: 12.h),
        _buildQuickSearchSkeleton(colors, isDark),
      ],
    );
  }

  Widget _buildSectionHeader(AppColorsExtension colors, bool isDark, String title) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildShimmerBox(width: 150.w, height: 20.h, colors: colors, isDark: isDark, borderRadius: 4.r),
          SizedBox(height: 4.h),
          _buildShimmerBox(width: 120.w, height: 14.h, colors: colors, isDark: isDark, borderRadius: 4.r),
        ],
      ),
    );
  }

  Widget _buildTrendingItemSkeleton(AppColorsExtension colors, bool isDark) {
    return Column(
      children: List.generate(3, (index) {
        return Container(
          margin: EdgeInsets.symmetric(horizontal: 20.w, vertical: 6.h),
          decoration: BoxDecoration(
            color: colors.backgroundPrimary,
            borderRadius: BorderRadius.circular(KBorderSize.borderMedium),
          ),
          child: Shimmer.fromColors(
            baseColor: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
            highlightColor: isDark ? Colors.grey.shade700 : Colors.grey.shade100,
            child: Row(
              children: [
                Container(
                  width: 32.w,
                  height: 32.h,
                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                ),
                SizedBox(width: 16.w),
                // Item Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        height: 14.h,
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4.r)),
                      ),
                      SizedBox(height: 6.h),
                      Container(
                        width: 100.w,
                        height: 12.h,
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4.r)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildCategoryChipsSkeleton(AppColorsExtension colors, bool isDark) {
    return SizedBox(
      height: 110.h,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 20.w),
        itemCount: 5,
        itemBuilder: (context, index) {
          return Padding(
            padding: EdgeInsets.only(right: 16.w),
            child: Shimmer.fromColors(
              baseColor: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
              highlightColor: isDark ? Colors.grey.shade700 : Colors.grey.shade100,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 68.w,
                    height: 68.h,
                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                  ),
                  SizedBox(height: 8.h),
                  Container(
                    width: 60.w,
                    height: 12.h,
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4.r)),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildQuickSearchSkeleton(AppColorsExtension colors, bool isDark) {
    return Column(
      children: List.generate(2, (index) {
        return Container(
          margin: EdgeInsets.symmetric(horizontal: 20.w, vertical: 6.h),
          decoration: BoxDecoration(
            color: colors.backgroundPrimary,
            borderRadius: BorderRadius.circular(KBorderSize.borderMedium),
          ),
          child: Shimmer.fromColors(
            baseColor: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
            highlightColor: isDark ? Colors.grey.shade700 : Colors.grey.shade100,
            child: Row(
              children: [
                // Search Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        height: 14.h,
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4.r)),
                      ),
                      SizedBox(height: 4.h),
                      Container(
                        width: 120.w,
                        height: 12.h,
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4.r)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildShimmerBox({
    required double width,
    required double height,
    required AppColorsExtension colors,
    required bool isDark,
    double? borderRadius,
  }) {
    return Shimmer.fromColors(
      baseColor: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
      highlightColor: isDark ? Colors.grey.shade700 : Colors.grey.shade100,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(borderRadius ?? 8.r)),
      ),
    );
  }
}
