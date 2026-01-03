import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:grab_go_shared/shared/utils/app_colors_extension.dart';
import 'package:grab_go_shared/shared/utils/constants.dart';
import 'package:shimmer/shimmer.dart';

class PromoSkeleton extends StatelessWidget {
  final AppColorsExtension colors;
  final bool isDark;

  const PromoSkeleton({super.key, required this.colors, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
      highlightColor: isDark ? Colors.grey.shade700 : Colors.grey.shade100,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 20.w),
        child: Container(
          width: double.infinity,
          height: 160.h,
          decoration: BoxDecoration(
            color: colors.backgroundPrimary,
            borderRadius: BorderRadius.circular(KBorderSize.borderMedium),
          ),
          child: Row(
            children: [
              // Left side - Text content (60%)
              Expanded(
                flex: 6,
                child: Padding(
                  padding: EdgeInsets.all(16.r),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Title placeholder
                      Container(
                        height: 18.h,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.grey.shade700 : Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(4.r),
                        ),
                      ),
                      SizedBox(height: 8.h),
                      // Subtitle placeholder
                      Container(
                        height: 12.h,
                        width: 120.w,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.grey.shade700 : Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(4.r),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Right side - Image (40%)
              Expanded(
                flex: 4,
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey.shade700 : Colors.grey.shade200,
                    borderRadius: BorderRadius.only(
                      topRight: Radius.circular(KBorderSize.borderMedium),
                      bottomRight: Radius.circular(KBorderSize.borderMedium),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
