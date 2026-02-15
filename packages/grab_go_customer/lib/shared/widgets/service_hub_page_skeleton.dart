import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:grab_go_customer/shared/widgets/wavy_banner_clipper.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:shimmer/shimmer.dart';

class ServiceHubPageSkeleton extends StatelessWidget {
  const ServiceHubPageSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.sizeOf(context);
    final dealCardWidth = (size.width * 0.78).clamp(230.0, 320.0);
    final dealCardHeight = (dealCardWidth * 0.74).clamp(180.0, 230.0);
    final popularCardWidth = size.width * 0.5;
    final popularImageHeight = (popularCardWidth * 0.60).clamp(96.0, 120.0);
    final popularCardHeight = (popularImageHeight + 114.0).clamp(210.0, 250.0);
    final nearbyCardWidth = (size.width * 0.72).clamp(220.0, 300.0);
    final nearbyCardHeight = (nearbyCardWidth * 0.75).clamp(180.0, 210.0);
    final recommendedCardHeight = (size.height * 0.17).clamp(132.0, 172.0);

    return IgnorePointer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBannerSkeleton(isDark, size),
          SizedBox(height: 8.h),
          _buildCategoriesSectionSkeleton(isDark),
          SizedBox(height: KSpacing.lg.h),
          _buildHorizontalSectionSkeleton(isDark, cardWidth: dealCardWidth, cardHeight: dealCardHeight),
          SizedBox(height: KSpacing.lg.h),
          _buildHorizontalSectionSkeleton(isDark, cardWidth: popularCardWidth, cardHeight: popularCardHeight),
          SizedBox(height: KSpacing.lg.h),
          _buildHorizontalSectionSkeleton(isDark, cardWidth: nearbyCardWidth, cardHeight: nearbyCardHeight),
          SizedBox(height: KSpacing.lg.h),
          _buildRecommendedSectionSkeleton(isDark, recommendedCardHeight),
        ],
      ),
    );
  }

  Widget _buildBannerSkeleton(bool isDark, Size size) {
    final cardWidth = size.width - (40.w);
    final baseHeight = (cardWidth * 0.48).clamp(145.0, 195.0);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: ClipPath(
        clipper: WavyBannerClipper(waveHeight: 8, waveCount: 12, cornerRadius: 16),
        child: _buildShimmerBox(isDark: isDark, width: double.infinity, height: baseHeight, borderRadius: 0),
      ),
    );
  }

  Widget _buildCategoriesSectionSkeleton(bool isDark) {
    return Column(
      children: [
        SizedBox(height: 14.h),
        _buildSectionHeaderSkeleton(isDark),
        SizedBox(height: 10.h),
        SizedBox(
          height: 108,
          child: ListView.builder(
            physics: const NeverScrollableScrollPhysics(),
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.only(left: 20.w, right: 20.w),
            itemCount: 5,
            itemBuilder: (context, index) {
              return Padding(
                padding: EdgeInsets.only(right: 14.w),
                child: Column(
                  children: [
                    _buildShimmerBox(isDark: isDark, width: 68, height: 68, borderRadius: KBorderSize.border),
                    SizedBox(height: 8.h),
                    _buildShimmerBox(isDark: isDark, width: 60, height: 12, borderRadius: 6.r),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHorizontalSectionSkeleton(bool isDark, {required double cardWidth, required double cardHeight}) {
    final imageHeight = (cardHeight * 0.57).clamp(96.0, 132.0);

    return Column(
      children: [
        _buildSectionHeaderSkeleton(isDark),
        SizedBox(height: 10.h),
        SizedBox(
          height: cardHeight,
          child: ListView.builder(
            physics: const NeverScrollableScrollPhysics(),
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.only(left: 20.w, right: 20.w),
            itemCount: 2,
            itemBuilder: (context, index) {
              return Container(
                width: cardWidth,
                margin: EdgeInsets.only(right: 15.w),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey.shade900 : Colors.white,
                  borderRadius: BorderRadius.circular(KBorderSize.borderMedium),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildShimmerBox(
                      isDark: isDark,
                      width: cardWidth,
                      height: imageHeight,
                      borderRadius: KBorderSize.borderMedium,
                    ),
                    SizedBox(height: 10.h),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10.w),
                      child: _buildShimmerBox(isDark: isDark, width: cardWidth * 0.55, height: 18.h, borderRadius: 6.r),
                    ),
                    SizedBox(height: 8.h),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10.w),
                      child: _buildShimmerBox(isDark: isDark, width: cardWidth * 0.4, height: 12.h, borderRadius: 6.r),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRecommendedSectionSkeleton(bool isDark, double cardHeight) {
    return Column(
      children: [
        _buildSectionHeaderSkeleton(isDark),
        SizedBox(height: KSpacing.lg.h),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 20.w),
          child: _buildShimmerBox(
            isDark: isDark,
            width: double.infinity,
            height: cardHeight,
            borderRadius: KBorderSize.borderMedium,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeaderSkeleton(bool isDark) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildShimmerBox(isDark: isDark, width: 168, height: 20, borderRadius: 6.r),
          _buildShimmerBox(isDark: isDark, width: 62, height: 16, borderRadius: 6.r),
        ],
      ),
    );
  }

  Widget _buildShimmerBox({required bool isDark, required double width, required double height, double? borderRadius}) {
    return Shimmer.fromColors(
      baseColor: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
      highlightColor: isDark ? Colors.grey.shade700 : Colors.grey.shade100,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(borderRadius ?? KBorderSize.borderMedium),
        ),
      ),
    );
  }
}
