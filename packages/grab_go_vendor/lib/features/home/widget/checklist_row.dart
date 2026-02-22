import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/shared/utils/app_colors_extension.dart';

class ChecklistRow extends StatelessWidget {
  final String label;
  final bool done;
  final String? statusLabel;

  const ChecklistRow({
    super.key,
    required this.label,
    required this.done,
    this.statusLabel,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: Row(
        children: [
          Container(
            width: 14.w,
            height: 14.w,
            margin: EdgeInsets.only(top: 4.h),
            decoration: BoxDecoration(
              color: done ? colors.success : Colors.transparent,
              shape: BoxShape.circle,
              border: done
                  ? null
                  : Border.all(color: colors.inputBorder, width: 1.5),
            ),
            child: done
                ? SvgPicture.asset(
                    Assets.icons.check,
                    package: 'grab_go_shared',
                    colorFilter: ColorFilter.mode(
                      colors.backgroundPrimary,
                      BlendMode.srcIn,
                    ),
                    width: 6.w,
                    height: 6.w,
                  )
                : null,
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
                decoration: done ? TextDecoration.lineThrough : null,
              ),
            ),
          ),
          if (statusLabel != null)
            Text(
              statusLabel!,
              style: TextStyle(
                fontSize: 10.sp,
                fontWeight: FontWeight.w700,
                color: done ? colors.success : colors.textSecondary,
              ),
            ),
        ],
      ),
    );
  }
}
