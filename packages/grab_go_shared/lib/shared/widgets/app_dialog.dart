import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';

enum AppDialogType { info, warning, error, success, question, logout }

class AppDialog extends StatelessWidget {
  final String title;
  final String message;
  final AppDialogType type;
  final String? icon;
  final String? primaryButtonText;
  final String? secondaryButtonText;
  final VoidCallback? onPrimaryPressed;
  final VoidCallback? onSecondaryPressed;
  final Color? primaryButtonColor;
  final Color? secondaryButtonColor;
  final bool barrierDismissible;
  final double? borderRadius;
  final double? buttonBorderRadius;

  const AppDialog({
    super.key,
    required this.title,
    required this.message,
    this.type = AppDialogType.info,
    this.icon,
    this.primaryButtonText,
    this.secondaryButtonText,
    this.onPrimaryPressed,
    this.onSecondaryPressed,
    this.primaryButtonColor,
    this.secondaryButtonColor,
    this.barrierDismissible = true,
    this.borderRadius,
    this.buttonBorderRadius,
  });

  static Future<bool?> show({
    required BuildContext context,
    required String title,
    required String message,
    AppDialogType type = AppDialogType.info,
    String? icon,
    String? primaryButtonText,
    String? secondaryButtonText,
    VoidCallback? onPrimaryPressed,
    VoidCallback? onSecondaryPressed,
    Color? primaryButtonColor,
    Color? secondaryButtonColor,
    bool barrierDismissible = true,
    double? borderRadius,
    double? buttonBorderRadius,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (context) => AppDialog(
        title: title,
        message: message,
        type: type,
        icon: icon,
        primaryButtonText: primaryButtonText,
        secondaryButtonText: secondaryButtonText,
        onPrimaryPressed: onPrimaryPressed,
        onSecondaryPressed: onSecondaryPressed,
        primaryButtonColor: primaryButtonColor,
        secondaryButtonColor: secondaryButtonColor,
        barrierDismissible: barrierDismissible,
        borderRadius: borderRadius,
        buttonBorderRadius: buttonBorderRadius,
      ),
    );
  }

  Color _getTypeColor(BuildContext context) {
    final colors = context.appColors;

    if (primaryButtonColor != null) {
      return primaryButtonColor!;
    }

    switch (type) {
      case AppDialogType.info:
        return colors.accentViolet;
      case AppDialogType.warning:
        return colors.accentOrange;
      case AppDialogType.error:
        return colors.error;
      case AppDialogType.success:
        return colors.accentGreen;
      case AppDialogType.question:
        return colors.accentViolet;
      case AppDialogType.logout:
        return colors.error;
    }
  }

  SvgPicture _getTypeIcon(Color iconColor) {
    switch (type) {
      case AppDialogType.info:
        return SvgPicture.asset(
          Assets.icons.infoCircle,
          package: 'grab_go_shared',
          height: 35.h,
          width: 35.h,
          colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
        );
      case AppDialogType.warning:
        return SvgPicture.asset(
          Assets.icons.warningCircle,
          package: 'grab_go_shared',
          height: 35.h,
          width: 35.h,
          colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
        );
      case AppDialogType.error:
        return SvgPicture.asset(
          Assets.icons.infoCircle,
          package: 'grab_go_shared',
          height: 35.h,
          width: 35.h,
          colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
        );
      case AppDialogType.success:
        return SvgPicture.asset(
          Assets.icons.check,
          package: 'grab_go_shared',
          height: 35.h,
          width: 35.h,
          colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
        );
      case AppDialogType.question:
        return SvgPicture.asset(
          Assets.icons.infoCircle,
          package: 'grab_go_shared',
          height: 35.h,
          width: 35.h,
          colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
        );
      case AppDialogType.logout:
        return SvgPicture.asset(
          Assets.icons.logOut,
          package: 'grab_go_shared',
          height: 35.h,
          width: 35.h,
          colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final typeColor = _getTypeColor(context);
    final dialogBorderRadius = borderRadius ?? KBorderSize.borderRadius20;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        decoration: BoxDecoration(
          color: colors.backgroundPrimary,
          borderRadius: BorderRadius.circular(dialogBorderRadius),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(KSpacing.lg25.r),
              decoration: BoxDecoration(
                color: typeColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(KBorderSize.borderMedium),
                  topRight: Radius.circular(KBorderSize.borderMedium),
                ),
              ),
              child: Center(
                child: Container(
                  height: 70.h,
                  width: 70.h,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: typeColor.withValues(alpha: 0.15),
                  ),
                  child: Center(
                    child: icon != null
                        ? SvgPicture.asset(
                            icon!,
                            height: 35.h,
                            width: 35.h,
                            colorFilter: ColorFilter.mode(
                              typeColor,
                              BlendMode.srcIn,
                            ),
                          )
                        : _getTypeIcon(typeColor),
                  ),
                ),
              ),
            ),

            Padding(
              padding: EdgeInsets.all(KSpacing.lg25.r),
              child: Column(
                children: [
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 20.sp,
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary,
                      height: 1.3,
                    ),
                  ),
                  SizedBox(height: KSpacing.md.h),

                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w400,
                      color: colors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                  SizedBox(height: KSpacing.lg25.h),

                  Row(
                    children: [
                      Expanded(
                        child: AppButton(
                          width: double.infinity,
                          onPressed: () => Navigator.of(context).pop(),
                          buttonText: "Cancel",
                          textStyle: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w800,
                            color: secondaryButtonColor ?? colors.textPrimary,
                          ),
                          backgroundColor:
                              secondaryButtonColor?.withValues(alpha: 0.1) ??
                              colors.backgroundSecondary,
                          padding: EdgeInsets.symmetric(vertical: 16.h),
                          borderRadius: KBorderSize.borderMedium,
                        ),
                      ),

                      SizedBox(width: KSpacing.md.w),

                      Expanded(
                        child: AppButton(
                          width: double.infinity,
                          onPressed: () => Navigator.of(context).pop(true),
                          buttonText: "OK",
                          textStyle: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                          backgroundColor: typeColor,
                          padding: EdgeInsets.symmetric(vertical: 16.h),
                          borderRadius: KBorderSize.borderMedium,
                        ),
                      ),
                    ],
                  ),

                  // Row(
                  //   children: [
                  //     if (secondaryButtonText != null)
                  //       Expanded(
                  //         child: GestureDetector(
                  //           onTap: () {
                  //             if (onSecondaryPressed != null) {
                  //               onSecondaryPressed!();
                  //             } else {
                  //               Navigator.of(context).pop(false);
                  //             }
                  //           },
                  //           child: Container(
                  //             height: 50.h,
                  //             decoration: BoxDecoration(
                  //               color: secondaryButtonColor?.withValues(alpha: 0.1) ?? colors.backgroundSecondary,
                  //               borderRadius: BorderRadius.circular(btnBorderRadius),
                  //               border: Border.all(color: secondaryButtonColor ?? colors.inputBorder, width: 1.5),
                  //             ),
                  //             child: Center(
                  //               child: Text(
                  //                 secondaryButtonText!,
                  //                 style: TextStyle(
                  //                   fontSize: 15.sp,
                  //                   fontWeight: FontWeight.w600,
                  //                   color: secondaryButtonColor ?? colors.textPrimary,
                  //                 ),
                  //               ),
                  //             ),
                  //           ),
                  //         ),
                  //       ),

                  //     if (secondaryButtonText != null && primaryButtonText != null) SizedBox(width: KSpacing.md.w),

                  //     if (primaryButtonText != null)
                  //       Expanded(
                  //         child: GestureDetector(
                  //           onTap: () {
                  //             if (onPrimaryPressed != null) {
                  //               onPrimaryPressed!();
                  //             } else {
                  //               Navigator.of(context).pop(true);
                  //             }
                  //           },
                  //           child: Container(
                  //             height: 50.h,
                  //             decoration: BoxDecoration(
                  //               gradient: LinearGradient(colors: [typeColor, typeColor.withValues(alpha: 0.8)]),
                  //               borderRadius: BorderRadius.circular(btnBorderRadius),
                  //               boxShadow: [
                  //                 BoxShadow(
                  //                   color: typeColor.withValues(alpha: 0.3),
                  //                   blurRadius: 15,
                  //                   offset: const Offset(0, 5),
                  //                 ),
                  //               ],
                  //             ),
                  //             child: Center(
                  //               child: Text(
                  //                 primaryButtonText!,
                  //                 style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w700, color: Colors.white),
                  //               ),
                  //             ),
                  //           ),
                  //         ),
                  //       ),
                  //   ],
                  // ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
