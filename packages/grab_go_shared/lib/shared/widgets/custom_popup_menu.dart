// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import '../utils/constants.dart';
import '../utils/app_colors_extension.dart';

class CustomPopupMenuItem {
  final String value;
  final String label;
  final String? icon;
  final IconData? materialIcon;
  final Color? iconColor;
  final Color? backgroundColor;
  final bool isDanger;
  final bool isDestructive;
  final String? badge;
  final Color? badgeColor;

  const CustomPopupMenuItem({
    required this.value,
    required this.label,
    this.icon,
    this.materialIcon,
    this.iconColor,
    this.backgroundColor,
    this.isDanger = false,
    this.isDestructive = false,
    this.badge,
    this.badgeColor,
  });
}

class CustomPopupMenuDivider {
  final String? label;
  const CustomPopupMenuDivider({this.label});
}

class CustomPopupMenu extends StatefulWidget {
  final List<dynamic> items;
  final Function(String) onSelected;
  final Widget child;
  final double? iconSize;
  final double? menuWidth;
  final Offset? offset;
  final bool showArrow;
  final Color? backgroundColor;
  final double? elevation;
  final BorderRadius? borderRadius;

  const CustomPopupMenu({
    super.key,
    required this.items,
    required this.onSelected,
    required this.child,
    this.iconSize,
    this.menuWidth,
    this.offset,
    this.showArrow = true,
    this.backgroundColor,
    this.elevation,
    this.borderRadius,
  });

  @override
  State<CustomPopupMenu> createState() => _CustomPopupMenuState();
}

class _CustomPopupMenuState extends State<CustomPopupMenu> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(duration: const Duration(milliseconds: 200), vsync: this);

    _scaleAnimation = CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic);

    _fadeAnimation = CurvedAnimation(parent: _animationController, curve: Curves.easeIn);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopupMenuButton<String>(
      onSelected: widget.onSelected,
      elevation: widget.elevation ?? 12,
      color: Colors.transparent,
      shadowColor: isDark ? Colors.black.withAlpha(30) : Colors.black.withAlpha(8),
      shape: RoundedRectangleBorder(
        borderRadius: widget.borderRadius ?? BorderRadius.circular(KBorderSize.borderRadius15),
      ),
      offset: widget.offset ?? Offset(0, 8.h),
      onOpened: () => _animationController.forward(),
      onCanceled: () => _animationController.reverse(),
      itemBuilder: (context) {
        _animationController.forward();

        return [
          PopupMenuItem<String>(
            enabled: false,
            padding: EdgeInsets.zero,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                alignment: Alignment.topCenter,
                child: Container(
                  width: widget.menuWidth ?? 240.w,
                  decoration: BoxDecoration(
                    color: widget.backgroundColor ?? colors.backgroundPrimary,
                    borderRadius: widget.borderRadius ?? BorderRadius.circular(KBorderSize.borderRadius15),
                    border: Border.all(color: colors.border.withOpacity(0.3), width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: isDark ? Colors.black.withAlpha(30) : Colors.black.withAlpha(8),
                        spreadRadius: 0,
                        blurRadius: 12,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: widget.borderRadius ?? BorderRadius.circular(KBorderSize.borderRadius15),
                    child: Column(mainAxisSize: MainAxisSize.min, children: _buildMenuItems(context, colors)),
                  ),
                ),
              ),
            ),
          ),
        ];
      },
      child: widget.child,
    );
  }

  List<Widget> _buildMenuItems(BuildContext context, AppColorsExtension colors) {
    List<Widget> menuWidgets = [];

    for (int i = 0; i < widget.items.length; i++) {
      final item = widget.items[i];

      if (item is CustomPopupMenuDivider) {
        menuWidgets.add(_buildDivider(colors, item.label));
      } else if (item is CustomPopupMenuItem) {
        menuWidgets.add(_buildMenuItem(context, colors, item, i));
      }
    }

    return menuWidgets;
  }

  Widget _buildDivider(AppColorsExtension colors, String? label) {
    if (label != null) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
        child: Row(
          children: [
            Expanded(child: Divider(color: colors.divider.withOpacity(0.5), thickness: 1, height: 1)),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 8.w),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w600,
                  color: colors.textTertiary,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            Expanded(child: Divider(color: colors.divider.withOpacity(0.5), thickness: 1, height: 1)),
          ],
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
      child: Divider(color: colors.divider.withOpacity(0.5), thickness: 1, height: 1),
    );
  }

  Widget _buildMenuItem(BuildContext context, AppColorsExtension colors, CustomPopupMenuItem item, int index) {
    final effectiveIconColor = item.isDanger || item.isDestructive
        ? colors.error
        : (item.iconColor ?? colors.textPrimary);

    final effectiveBackgroundColor = item.isDanger || item.isDestructive
        ? colors.error.withOpacity(0.1)
        : (item.backgroundColor ?? colors.backgroundSecondary);

    final textColor = item.isDanger || item.isDestructive ? colors.error : colors.textPrimary;

    return _AnimatedMenuItem(
      index: index,
      onTap: () {
        Navigator.of(context).pop();
        widget.onSelected(item.value);
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
        child: Row(
          children: [
            Container(
              height: 40.h,
              width: 40.h,
              decoration: BoxDecoration(color: colors.backgroundSecondary, borderRadius: BorderRadius.circular(10.r)),
              child: Center(
                child: item.icon != null
                    ? SvgPicture.asset(
                        item.icon!,
                        package: "grab_go_shared",
                        height: widget.iconSize ?? 20.h,
                        width: widget.iconSize ?? 20.h,
                        colorFilter: ColorFilter.mode(effectiveIconColor, BlendMode.srcIn),
                      )
                    : Icon(
                        item.materialIcon ?? Icons.settings,
                        size: widget.iconSize ?? 20.h,
                        color: effectiveIconColor,
                      ),
              ),
            ),
            SizedBox(width: 12.w),

            Expanded(
              child: Text(
                item.label,
                style: TextStyle(color: textColor, fontSize: 14.sp, fontWeight: FontWeight.w600, letterSpacing: -0.2),
              ),
            ),

            if (item.badge != null) ...[
              SizedBox(width: 8.w),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: item.badgeColor ?? colors.accentOrange,
                  borderRadius: BorderRadius.circular(KBorderSize.borderRadius8),
                ),
                child: Text(
                  item.badge!,
                  style: TextStyle(color: Colors.white, fontSize: 11.sp, fontWeight: FontWeight.w700),
                ),
              ),
            ],

            if (widget.showArrow) ...[
              SizedBox(width: 8.w),
              SvgPicture.asset(
                Assets.icons.navArrowRight,
                package: "grab_go_shared",
                height: 18.h,
                width: 18.w,
                colorFilter: ColorFilter.mode(colors.textPrimary, BlendMode.srcIn),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AnimatedMenuItem extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;
  final int index;

  const _AnimatedMenuItem({required this.child, required this.onTap, required this.index});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: colors.backgroundPrimary,
        borderRadius: BorderRadius.circular(KBorderSize.borderRadius12),
        child: child,
      ),
    );
  }
}
