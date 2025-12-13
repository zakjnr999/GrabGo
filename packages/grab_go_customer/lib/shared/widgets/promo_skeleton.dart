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
          height: 140.h,
          decoration: BoxDecoration(
            color: isDark ? Colors.grey.shade700 : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(KBorderSize.borderMedium),
          ),
        ),
      ),
    );
  }
}
