import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:shimmer/shimmer.dart';
import 'package:grab_go_customer/shared/widgets/wavy_banner_clipper.dart';

class HomePageSkeleton extends StatelessWidget {
  const HomePageSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: KSpacing.lg.h),

        // Service selector skeleton
        _buildServiceSelectorSkeleton(colors, isDark),

        SizedBox(height: KSpacing.lg.h),

        // Promotional banner skeleton
        _buildBannerSkeleton(colors, isDark),

        SizedBox(height: KSpacing.lg.h),

        // Category chips skeleton
        _buildCategoryChipsSkeleton(colors, isDark),

        SizedBox(height: KSpacing.lg.h),

        // Deals section skeleton
        _buildHorizontalCardsSkeleton(colors, isDark, 'Exclusive Deals'),

        SizedBox(height: KSpacing.lg.h),

        // Popular section skeleton
        _buildHorizontalCardsSkeleton(colors, isDark, 'Popular Items'),

        SizedBox(height: KSpacing.lg.h),

        // Grid section skeleton
        _buildGridSkeleton(colors, isDark),
      ],
    );
  }

  Widget _buildServiceSelectorSkeleton(AppColorsExtension colors, bool isDark) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 4,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12.w,
          mainAxisSpacing: 12.h,
          childAspectRatio: 2.1,
        ),
        itemBuilder: (context, index) {
          return _buildShimmerBox(
            width: double.infinity,
            height: double.infinity,
            colors: colors,
            isDark: isDark,
            borderRadius: KBorderSize.borderMedium,
          );
        },
      ),
    );
  }

  Widget _buildCategoryChipsSkeleton(AppColorsExtension colors, bool isDark) {
    return SizedBox(
      height: 80.h,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 20.w),
        itemCount: 6,
        itemBuilder: (context, index) {
          return Padding(
            padding: EdgeInsets.only(right: 12.w),
            child: Column(
              children: [
                // Circular category icon
                _buildShimmerBox(
                  width: 56.w,
                  height: 56.h,
                  colors: colors,
                  isDark: isDark,
                  borderRadius: KBorderSize.border,
                ),
                SizedBox(height: 6.h),
                // Category name
                _buildShimmerBox(width: 50.w, height: 10.h, colors: colors, isDark: isDark, borderRadius: 5.r),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildBannerSkeleton(AppColorsExtension colors, bool isDark) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: ClipPath(
        clipper: WavyBannerClipper(waveHeight: 8, waveCount: 12, cornerRadius: 16),
        child: _buildShimmerBox(width: double.infinity, height: 150.h, colors: colors, isDark: isDark, borderRadius: 0),
      ),
    );
  }

  Widget _buildHorizontalCardsSkeleton(AppColorsExtension colors, bool isDark, String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header skeleton
        Padding(
          padding: EdgeInsets.symmetric(horizontal: KSpacing.lg.w),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildShimmerBox(width: 150.w, height: 20.h, colors: colors, isDark: isDark),
              _buildShimmerBox(width: 60.w, height: 16.h, colors: colors, isDark: isDark),
            ],
          ),
        ),

        SizedBox(height: KSpacing.md.h),

        // Horizontal cards
        SizedBox(
          height: 200.h,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: KSpacing.lg.w),
            itemCount: 3,
            itemBuilder: (context, index) {
              return Padding(
                padding: EdgeInsets.only(right: KSpacing.md.w),
                child: _buildShimmerBox(
                  width: 160.w,
                  height: 200.h,
                  colors: colors,
                  isDark: isDark,
                  borderRadius: 12.r,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildGridSkeleton(AppColorsExtension colors, bool isDark) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: KSpacing.lg.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          _buildShimmerBox(width: 150.w, height: 20.h, colors: colors, isDark: isDark),

          SizedBox(height: KSpacing.md.h),

          // Grid items
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: KSpacing.md.w,
              mainAxisSpacing: KSpacing.md.h,
              childAspectRatio: 0.75,
            ),
            itemCount: 4,
            itemBuilder: (context, index) {
              return _buildShimmerBox(
                width: double.infinity,
                height: double.infinity,
                colors: colors,
                isDark: isDark,
                borderRadius: 12.r,
              );
            },
          ),
        ],
      ),
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
