import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shimmer/shimmer.dart';
import 'package:grab_go_shared/grub_go_shared.dart';

class ChatSkeleton extends StatelessWidget {
  final AppColorsExtension colors;
  final bool isDark;

  const ChatSkeleton({super.key, required this.colors, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.r),
      margin: EdgeInsets.only(bottom: 8.h),
      decoration: BoxDecoration(
        color: colors.backgroundPrimary,
        borderRadius: BorderRadius.circular(KBorderSize.borderRadius15),
        border: Border.all(color: colors.inputBorder.withValues(alpha: 0.3), width: 0.5),
      ),
      child: Row(
        children: [
          Shimmer.fromColors(
            baseColor: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
            highlightColor: isDark ? Colors.grey.shade700 : Colors.grey.shade100,
            child: Container(
              height: 48.h,
              width: 48.w,
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Shimmer.fromColors(
                      baseColor: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                      highlightColor: isDark ? Colors.grey.shade700 : Colors.grey.shade100,
                      child: Container(
                        width: 120.w,
                        height: 14.h,
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4.r)),
                      ),
                    ),
                    Shimmer.fromColors(
                      baseColor: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                      highlightColor: isDark ? Colors.grey.shade700 : Colors.grey.shade100,
                      child: Container(
                        width: 40.w,
                        height: 10.h,
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4.r)),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8.h),
                Shimmer.fromColors(
                  baseColor: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                  highlightColor: isDark ? Colors.grey.shade700 : Colors.grey.shade100,
                  child: Container(
                    width: double.infinity,
                    height: 12.h,
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4.r)),
                  ),
                ),
                SizedBox(height: 6.h),
                Shimmer.fromColors(
                  baseColor: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                  highlightColor: isDark ? Colors.grey.shade700 : Colors.grey.shade100,
                  child: Container(
                    width: 180.w,
                    height: 12.h,
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4.r)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
