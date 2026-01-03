import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:grab_go_shared/shared/utils/app_colors_extension.dart';
import 'package:grab_go_shared/shared/utils/constants.dart';
import 'package:shimmer/shimmer.dart';

class HorizontalCardSkeleton extends StatelessWidget {
  final AppColorsExtension colors;
  final bool isDark;
  final double height;
  final int itemCount;

  const HorizontalCardSkeleton({
    super.key,
    required this.colors,
    required this.isDark,
    required this.height,
    this.itemCount = 5,
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
      highlightColor: isDark ? Colors.grey.shade700 : Colors.grey.shade100,
      child: SizedBox(
        height: height,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.only(left: 20.w),
          itemCount: itemCount,
          itemBuilder: (context, index) {
            return Container(
              width: 280.w,
              margin: EdgeInsets.only(right: 15.w),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey.shade700 : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(KBorderSize.borderMedium),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Image placeholder
                  Container(
                    height: 120.h,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey.shade600 : Colors.grey.shade300,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(KBorderSize.borderMedium),
                        topRight: Radius.circular(KBorderSize.borderMedium),
                      ),
                    ),
                  ),
                  // Content placeholder
                  Padding(
                    padding: EdgeInsets.all(10.r),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title
                        Container(
                          width: 180.w,
                          height: 14.h,
                          decoration: BoxDecoration(
                            color: isDark ? Colors.grey.shade600 : Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(4.r),
                          ),
                        ),
                        SizedBox(height: 8.h),
                        // Price
                        Container(
                          width: 100.w,
                          height: 16.h,
                          decoration: BoxDecoration(
                            color: isDark ? Colors.grey.shade600 : Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(4.r),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
