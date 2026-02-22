import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:grab_go_shared/shared/utils/app_colors_extension.dart';

class AppFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final Color? selectedColor;
  final Color? unselectedColor;
  final Color? selectedTextColor;
  final Color? unselectedTextColor;
  final EdgeInsetsGeometry? contentPadding;

  const AppFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.selectedColor,
    this.unselectedColor,
    this.selectedTextColor,
    this.unselectedTextColor,
    this.contentPadding,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final resolvedSelectedColor = selectedColor ?? colors.vendorPrimaryBlue;
    final resolvedUnselectedColor =
        unselectedColor ?? colors.vendorPrimaryBlue.withValues(alpha: 0.12);
    final resolvedSelectedTextColor = selectedTextColor ?? Colors.white;
    final resolvedUnselectedTextColor =
        unselectedTextColor ?? colors.vendorPrimaryBlue;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999.r),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding:
            contentPadding ??
            EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
        decoration: BoxDecoration(
          color: selected ? resolvedSelectedColor : resolvedUnselectedColor,
          borderRadius: BorderRadius.circular(999.r),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.sp,
            fontWeight: FontWeight.w700,
            color: selected
                ? resolvedSelectedTextColor
                : resolvedUnselectedTextColor,
          ),
        ),
      ),
    );
  }
}
