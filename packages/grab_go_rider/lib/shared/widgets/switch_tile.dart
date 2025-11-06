import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:grab_go_shared/grub_go_shared.dart';

Widget switchTile({
  required BuildContext context,
  required String title,
  required String subtitle,
  required String icon,
  required Color iconColor,
  required bool value,
  required ValueChanged<bool> onChanged,
  required AppColorsExtension colors,
}) {
  final colors = context.appColors;
  return Padding(
    padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
    child: Row(
      children: [
        Container(
          padding: EdgeInsets.all(8.r),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
          ),
          child: SvgPicture.asset(
            icon,
            package: 'grab_go_shared',
            width: 20.w,
            height: 20.w,
            colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
          ),
        ),
        SizedBox(width: 16.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(color: colors.textPrimary, fontSize: 15.sp, fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 2.h),
              Text(
                subtitle,
                style: TextStyle(color: colors.textSecondary, fontSize: 12.sp, fontWeight: FontWeight.w400),
              ),
            ],
          ),
        ),
        Switch.adaptive(
          value: value,
          onChanged: onChanged,
          activeThumbColor: AppColors.white,
          activeTrackColor: colors.accentGreen,
        ),
      ],
    ),
  );
}
