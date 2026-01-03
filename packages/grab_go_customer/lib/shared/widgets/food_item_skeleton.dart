import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:grab_go_shared/shared/utils/app_colors_extension.dart';
import 'package:grab_go_shared/shared/utils/constants.dart';
import 'package:shimmer/shimmer.dart';

class FoodItemSkeleton extends StatelessWidget {
  final AppColorsExtension colors;
  final bool isDark;
  final Size size;
  const FoodItemSkeleton({super.key, required this.colors, required this.isDark, required this.size});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
      highlightColor: isDark ? Colors.grey.shade700 : Colors.grey.shade100,
      child: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: Column(
          children: List.generate(4, (index) {
            return Container(
              margin: EdgeInsets.only(left: 20.w, right: 20.w, bottom: 12.h),
              decoration: BoxDecoration(
                border: Border.all(color: isDark ? Colors.grey.shade800 : Colors.grey.shade300, width: 0.5),
                borderRadius: BorderRadius.circular(KBorderSize.borderRadius15),
              ),
              child: Row(
                children: [
                  // Image placeholder
                  Container(
                    height: size.height * 0.14,
                    width: size.width * 0.32,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey.shade700 : Colors.grey.shade200,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(KBorderSize.borderRadius15),
                        bottomLeft: Radius.circular(KBorderSize.borderRadius15),
                      ),
                    ),
                  ),

                  // Itemname placeholder
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12.r, vertical: 8.h),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 140.w,
                            height: 16.h,
                            decoration: BoxDecoration(
                              color: isDark ? Colors.grey.shade700 : Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(4.r),
                            ),
                          ),
                          SizedBox(height: 6.h),
                          // Rating and delivery time placeholder
                          Container(
                            width: 120.w,
                            height: 16.h,
                            decoration: BoxDecoration(
                              color: isDark ? Colors.grey.shade700 : Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(4.r),
                            ),
                          ),
                          SizedBox(height: 10.h),
                          // Price and cart placeholder
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              //Price placeholder
                              Container(
                                width: 100.w,
                                height: 25.h,
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.grey.shade700 : Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(4.r),
                                ),
                              ),

                              // Cart icon placeholder
                              Container(
                                height: 32.h,
                                width: 32.w,
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.grey.shade700 : Colors.grey.shade200,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }
}
