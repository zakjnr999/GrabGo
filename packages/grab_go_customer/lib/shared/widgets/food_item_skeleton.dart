import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:grab_go_shared/shared/utils/app_colors_extension.dart';
import 'package:grab_go_shared/shared/utils/constants.dart';
import 'package:shimmer/shimmer.dart';

class FoodItemSkeleton extends StatelessWidget {
  final AppColorsExtension colors;
  final bool isDark;
  final Size size;
  final EdgeInsetsGeometry? margin;

  const FoodItemSkeleton({
    super.key,
    required this.colors,
    required this.isDark,
    required this.size,
    this.margin,
  });

  Color get _baseColor => isDark ? Colors.grey.shade800 : Colors.grey.shade300;
  Color get _highlightColor =>
      isDark ? Colors.grey.shade700 : Colors.grey.shade100;
  Color get _surfaceColor =>
      isDark ? Colors.grey.shade700 : Colors.grey.shade200;

  Widget _block({
    double? width,
    double? height,
    BorderRadiusGeometry? borderRadius,
    BoxShape shape = BoxShape.rectangle,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: _surfaceColor,
        shape: shape,
        borderRadius: shape == BoxShape.rectangle
            ? (borderRadius ?? BorderRadius.circular(6.r))
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: _baseColor,
      highlightColor: _highlightColor,
      child: Column(
        children: List.generate(4, (index) {
          return Container(
            margin:
                margin ??
                EdgeInsets.only(left: 20.w, right: 20.w, bottom: 16.h),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(KBorderSize.borderRadius15),
              border: Border.all(color: _surfaceColor.withValues(alpha: 0.5)),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    _block(
                      width: double.infinity,
                      height: 120.h,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(KBorderSize.borderRadius15),
                        topRight: Radius.circular(KBorderSize.borderRadius15),
                        bottomLeft: Radius.circular(KBorderSize.borderRadius4),
                        bottomRight: Radius.circular(KBorderSize.borderRadius4),
                      ),
                    ),
                    Positioned(
                      top: 6.h,
                      right: 6.w,
                      child: _block(
                        width: 24.w,
                        height: 24.w,
                        shape: BoxShape.circle,
                      ),
                    ),
                    Positioned(
                      top: 0,
                      left: 8.w,
                      child: Column(
                        children: [
                          _block(
                            width: 28.w,
                            height: 38.h,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(
                                KBorderSize.borderRadius8,
                              ),
                              topRight: Radius.circular(
                                KBorderSize.borderRadius8,
                              ),
                              bottomLeft: Radius.circular(
                                KBorderSize.borderRadius4,
                              ),
                              bottomRight: Radius.circular(
                                KBorderSize.borderRadius4,
                              ),
                            ),
                          ),
                          SizedBox(height: 2.h),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _block(width: 6.w, height: 4.h),
                              SizedBox(width: 2.w),
                              _block(width: 6.w, height: 4.h),
                              SizedBox(width: 2.w),
                              _block(width: 6.w, height: 4.h),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(12.w, 12.h, 12.w, 12.h),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _block(width: double.infinity, height: 16.h),
                          ),
                          SizedBox(width: 12.w),
                          _block(
                            width: 12.w,
                            height: 12.w,
                            shape: BoxShape.circle,
                          ),
                          SizedBox(width: 4.w),
                          _block(width: 42.w, height: 12.h),
                        ],
                      ),
                      SizedBox(height: 8.h),
                      Row(
                        children: [
                          _block(width: 84.w, height: 12.h),
                          SizedBox(width: 8.w),
                          _block(
                            width: 3.w,
                            height: 3.w,
                            shape: BoxShape.circle,
                          ),
                          SizedBox(width: 8.w),
                          _block(
                            width: 12.w,
                            height: 12.w,
                            shape: BoxShape.circle,
                          ),
                          SizedBox(width: 4.w),
                          _block(width: 54.w, height: 12.h),
                        ],
                      ),
                      SizedBox(height: 12.h),
                      Row(
                        children: [
                          _block(
                            width: 82.w,
                            height: 28.h,
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                          SizedBox(width: 8.w),
                          _block(width: 62.w, height: 12.h),
                          const Spacer(),
                          _block(
                            width: 32.w,
                            height: 32.w,
                            shape: BoxShape.circle,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}
