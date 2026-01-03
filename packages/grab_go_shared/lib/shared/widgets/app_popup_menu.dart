// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import '../utils/constants.dart';
import '../utils/app_colors_extension.dart';

class AppPopupMenuItem {
  final String value;
  final String label;
  final String? icon;
  final IconData? materialIcon;
  final Color? iconColor;
  final Color? backgroundColor;
  final bool isDanger;

  const AppPopupMenuItem({
    required this.value,
    required this.label,
    this.icon,
    this.materialIcon,
    this.iconColor,
    this.backgroundColor,
    this.isDanger = false,
  });
}

class AppPopupMenu extends StatelessWidget {
  final List<AppPopupMenuItem> items;
  final Function(String) onSelected;
  final Widget child;
  final double? iconSize;

  const AppPopupMenu({super.key, required this.items, required this.onSelected, required this.child, this.iconSize});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return PopupMenuButton<String>(
      onSelected: onSelected,
      elevation: 8,
      color: colors.backgroundPrimary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(KBorderSize.borderRadius15),
        side: BorderSide(color: colors.inputBorder.withOpacity(0.5), width: 1),
      ),
      offset: Offset(0, 8.h),
      itemBuilder: (context) => items.map((item) {
        final effectiveIconColor = item.isDanger ? Colors.red : (item.iconColor ?? colors.textSecondary);
        final effectiveBackgroundColor = item.isDanger
            ? Colors.red.withOpacity(0.1)
            : (item.backgroundColor ?? colors.backgroundSecondary);
        final textColor = item.isDanger ? Colors.red : colors.textPrimary;

        return PopupMenuItem<String>(
          value: item.value,
          padding: EdgeInsets.zero,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
            child: Row(
              children: [
                Container(
                  height: 36.h,
                  width: 36.h,
                  decoration: BoxDecoration(color: effectiveBackgroundColor, borderRadius: BorderRadius.circular(10.r)),
                  child: Center(
                    child: item.icon != null
                        ? SvgPicture.asset(
                            item.icon!,
                            package: "grab_go_shared",
                            height: iconSize ?? 18.h,
                            width: iconSize ?? 18.h,
                            colorFilter: ColorFilter.mode(effectiveIconColor, BlendMode.srcIn),
                          )
                        : Icon(item.materialIcon ?? Icons.settings, size: iconSize ?? 18.h, color: effectiveIconColor),
                  ),
                ),
                SizedBox(width: 12.w),

                Expanded(
                  child: Text(
                    item.label,
                    style: TextStyle(color: textColor, fontSize: 14.sp, fontWeight: FontWeight.w600),
                  ),
                ),

                SvgPicture.asset(
                  Assets.icons.navArrowRight,
                  height: 14.h,
                  width: 14.w,
                  colorFilter: ColorFilter.mode(colors.textSecondary.withOpacity(0.5), BlendMode.srcIn),
                ),
              ],
            ),
          ),
        );
      }).toList(),
      child: child,
    );
  }
}
