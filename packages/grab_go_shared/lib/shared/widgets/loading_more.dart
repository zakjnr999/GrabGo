import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:grab_go_shared/shared/utils/app_colors_extension.dart';

class LoadingMore extends StatelessWidget {
  const LoadingMore({super.key, required this.spinnerColor, required this.borderColor, required this.colors});

  final Color spinnerColor;
  final Color borderColor;
  final AppColorsExtension colors;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 16.h),
      child: Center(
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
          decoration: BoxDecoration(
            color: colors.backgroundPrimary,
            borderRadius: BorderRadius.circular(20.r),
            border: Border.all(color: borderColor.withValues(alpha: 0.3), width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 18.w,
                height: 18.h,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(spinnerColor),
                ),
              ),
              SizedBox(width: 12.w),
              Text(
                "Loading more...",
                style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600, color: colors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
