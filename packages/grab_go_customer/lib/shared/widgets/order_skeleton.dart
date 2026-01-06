import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:shimmer/shimmer.dart';

class OrderSkeleton extends StatelessWidget {
  final AppColorsExtension colors;
  final bool isDark;

  const OrderSkeleton({super.key, required this.colors, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
      itemCount: 4,
      separatorBuilder: (context, index) => SizedBox(height: 16.h),
      itemBuilder: (context, index) {
        return Container(
          padding: EdgeInsets.all(16.r),
          decoration: BoxDecoration(
            color: colors.backgroundPrimary,
            borderRadius: BorderRadius.circular(KBorderSize.borderRadius15),
            border: Border.all(color: colors.inputBorder.withValues(alpha: 0.3), width: 0.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Shimmer.fromColors(
                              baseColor: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                              highlightColor: isDark ? Colors.grey.shade700 : Colors.grey.shade100,
                              child: Container(
                                width: 60.w,
                                height: 12.h,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(4.r),
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 6.h),
                        Shimmer.fromColors(
                          baseColor: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                          highlightColor: isDark ? Colors.grey.shade700 : Colors.grey.shade100,
                          child: Container(
                            width: 80.w,
                            height: 10.h,
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4.r)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Shimmer.fromColors(
                    baseColor: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                    highlightColor: isDark ? Colors.grey.shade700 : Colors.grey.shade100,
                    child: Container(
                      width: 90.w,
                      height: 24.h,
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20.r)),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16.h),
              // Restaurant Info
              Row(
                children: [
                  Shimmer.fromColors(
                    baseColor: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                    highlightColor: isDark ? Colors.grey.shade700 : Colors.grey.shade100,
                    child: Container(
                      width: 60.w,
                      height: 60.h,
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12.r)),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Shimmer.fromColors(
                          baseColor: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                          highlightColor: isDark ? Colors.grey.shade700 : Colors.grey.shade100,
                          child: Container(
                            width: 150.w,
                            height: 15.h,
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4.r)),
                          ),
                        ),
                        SizedBox(height: 6.h),
                        Shimmer.fromColors(
                          baseColor: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                          highlightColor: isDark ? Colors.grey.shade700 : Colors.grey.shade100,
                          child: Container(
                            width: 100.w,
                            height: 12.h,
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4.r)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16.h),
              // Items (2 placeholder items)
              for (int i = 0; i < 2; i++)
                Padding(
                  padding: EdgeInsets.only(bottom: 8.h),
                  child: Row(
                    children: [
                      Shimmer.fromColors(
                        baseColor: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                        highlightColor: isDark ? Colors.grey.shade700 : Colors.grey.shade100,
                        child: Container(
                          width: 6.w,
                          height: 6.h,
                          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                        ),
                      ),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: Shimmer.fromColors(
                          baseColor: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                          highlightColor: isDark ? Colors.grey.shade700 : Colors.grey.shade100,
                          child: Container(
                            width: double.infinity,
                            height: 13.h,
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4.r)),
                          ),
                        ),
                      ),
                      SizedBox(width: 16.w),
                      Shimmer.fromColors(
                        baseColor: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                        highlightColor: isDark ? Colors.grey.shade700 : Colors.grey.shade100,
                        child: Container(
                          width: 50.w,
                          height: 13.h,
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4.r)),
                        ),
                      ),
                    ],
                  ),
                ),
              SizedBox(height: 16.h),
              // Footer
              Container(
                padding: EdgeInsets.all(12.r),
                decoration: BoxDecoration(color: colors.backgroundSecondary, borderRadius: BorderRadius.circular(12.r)),
                child: Row(
                  children: [
                    Shimmer.fromColors(
                      baseColor: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                      highlightColor: isDark ? Colors.grey.shade700 : Colors.grey.shade100,
                      child: Container(
                        width: 32.w,
                        height: 32.h,
                        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Shimmer.fromColors(
                            baseColor: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                            highlightColor: isDark ? Colors.grey.shade700 : Colors.grey.shade100,
                            child: Container(
                              width: 80.w,
                              height: 11.h,
                              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4.r)),
                            ),
                          ),
                          SizedBox(height: 4.h),
                          Shimmer.fromColors(
                            baseColor: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                            highlightColor: isDark ? Colors.grey.shade700 : Colors.grey.shade100,
                            child: Container(
                              width: 120.w,
                              height: 13.h,
                              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4.r)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Shimmer.fromColors(
                      baseColor: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                      highlightColor: isDark ? Colors.grey.shade700 : Colors.grey.shade100,
                      child: Container(
                        width: 70.w,
                        height: 16.h,
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4.r)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
