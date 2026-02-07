import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:shimmer/shimmer.dart';

class PickupMapSkeleton extends StatelessWidget {
  const PickupMapSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      children: [
        // Map Placeholder removed to keep real map visible during loading

        // Add a subtle loading indicator in the center to show it's active
        Center(
          child: SpinKitPulse(color: colors.accentOrange.withValues(alpha: 0.3), size: 100.r),
        ),

        // Header Skeleton
        Positioned(
          top: MediaQuery.of(context).padding.top + 10.h,
          left: 16.w,
          right: 16.w,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Search bar placeholder
              _buildShimmerBox(
                width: double.infinity,
                height: 48.h,
                colors: colors,
                isDark: isDark,
                borderRadius: 30.r,
              ),
              SizedBox(height: 12.h),

              // Filter chips placeholder
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const NeverScrollableScrollPhysics(),
                child: Row(
                  children: List.generate(
                    4,
                    (index) => Padding(
                      padding: EdgeInsets.only(right: 8.w),
                      child: _buildShimmerBox(
                        width: index == 0 ? 60.w : 100.w,
                        height: 36.h,
                        colors: colors,
                        isDark: isDark,
                        borderRadius: 20.r,
                      ),
                    ),
                  ),
                ),
              ),

              SizedBox(height: 16.h),

              // Position button placeholder
              _buildShimmerBox(
                width: 44.w,
                height: 44.w,
                colors: colors,
                isDark: isDark,
                borderRadius: 22.r, // Circle
              ),
              SizedBox(height: 12.h),
              // Expand button placeholder
              _buildShimmerBox(
                width: 44.w,
                height: 44.w,
                colors: colors,
                isDark: isDark,
                borderRadius: 22.r, // Circle
              ),
            ],
          ),
        ),
      ],
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
