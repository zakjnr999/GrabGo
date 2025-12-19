import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:grab_go_shared/shared/utils/app_colors_extension.dart';
import 'package:grab_go_shared/shared/utils/constants.dart';
import 'package:shimmer/shimmer.dart';

class BrowseGridSkeleton extends StatelessWidget {
  final AppColorsExtension colors;
  final bool isDark;
  final bool isGridView;

  const BrowseGridSkeleton({super.key, required this.colors, required this.isDark, this.isGridView = true});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
      highlightColor: isDark ? Colors.grey.shade700 : Colors.grey.shade100,
      child: GridView.builder(
        padding: EdgeInsets.symmetric(horizontal: 20.w),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: isGridView ? 2 : 1,
          childAspectRatio: isGridView ? 0.615 : 1.8,
          crossAxisSpacing: 12.w,
          mainAxisSpacing: 16.h,
        ),
        itemCount: 6, // Show 6 skeleton items
        itemBuilder: (context, index) {
          return Container(
            decoration: BoxDecoration(
              color: isDark ? Colors.grey.shade700 : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(KBorderSize.borderMedium),
              border: Border.all(color: isDark ? Colors.grey.shade800 : Colors.grey.shade300, width: 0.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image placeholder
                Container(
                  height: isGridView ? 140.h : 120.h,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey.shade600 : Colors.grey.shade100,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(KBorderSize.borderMedium),
                      topRight: Radius.circular(KBorderSize.borderMedium),
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.all(12.r),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title placeholder
                      Container(
                        width: double.infinity,
                        height: 14.h,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.grey.shade600 : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(4.r),
                        ),
                      ),
                      SizedBox(height: 8.h),
                      // Subtitle placeholder
                      Container(
                        width: 100.w,
                        height: 12.h,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.grey.shade600 : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(4.r),
                        ),
                      ),
                      SizedBox(height: 12.h),
                      // Rating and time placeholder
                      Row(
                        children: [
                          Container(
                            width: 50.w,
                            height: 12.h,
                            decoration: BoxDecoration(
                              color: isDark ? Colors.grey.shade600 : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(4.r),
                            ),
                          ),
                          SizedBox(width: 8.w),
                          Container(
                            width: 50.w,
                            height: 12.h,
                            decoration: BoxDecoration(
                              color: isDark ? Colors.grey.shade600 : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(4.r),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12.h),
                      // Price placeholder
                      Container(
                        width: 80.w,
                        height: 16.h,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.grey.shade600 : Colors.grey.shade100,
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
    );
  }
}
