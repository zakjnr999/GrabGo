// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:grab_go_shared/shared/utils/responsive.dart';

enum AppDialogType { info, warning, error, success, question, logout }

class AppDialogPanels extends StatelessWidget {
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

  const AppDialogPanels({
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
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (context) => AppDialogPanels(
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
        return colors.warning;
      case AppDialogType.error:
        return colors.error;
      case AppDialogType.success:
        return colors.success;
      case AppDialogType.question:
        return colors.accentViolet;
      case AppDialogType.logout:
        return colors.error;
    }
  }

  SvgPicture _getTypeIcon(Color iconColor) {
    const iconSize = 35.0;
    switch (type) {
      case AppDialogType.info:
        return SvgPicture.asset(
          Assets.icons.infoCircle,
          package: 'grab_go_shared',
          height: iconSize,
          width: iconSize,
          colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
        );
      case AppDialogType.warning:
        return SvgPicture.asset(
          Assets.icons.warningCircle,
          package: 'grab_go_shared',
          height: iconSize,
          width: iconSize,
          colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
        );
      case AppDialogType.error:
        return SvgPicture.asset(
          Assets.icons.infoCircle,
          package: 'grab_go_shared',
          height: iconSize,
          width: iconSize,
          colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
        );
      case AppDialogType.success:
        return SvgPicture.asset(
          Assets.icons.check,
          package: 'grab_go_shared',
          height: iconSize,
          width: iconSize,
          colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
        );
      case AppDialogType.question:
        return SvgPicture.asset(
          Assets.icons.infoCircle,
          package: 'grab_go_shared',
          height: iconSize,
          width: iconSize,
          colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
        );
      case AppDialogType.logout:
        return SvgPicture.asset(
          Assets.icons.logOut,
          package: 'grab_go_shared',
          height: iconSize,
          width: iconSize,
          colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isMobile = Responsive.isMobile(context);
    final isTablet = Responsive.isTablet(context);
    final typeColor = _getTypeColor(context);

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: EdgeInsets.symmetric(horizontal: isMobile ? 20.0 : (isTablet ? 40.0 : 100.0), vertical: 24.0),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: isMobile ? 300.0 : (isTablet ? 400.0 : 400.0)),
        child: Container(
          decoration: BoxDecoration(
            color: colors.backgroundPrimary,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [BoxShadow(color: colors.shadow, blurRadius: 20, offset: const Offset(0, 10))],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(KSpacing.lg25),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [typeColor.withOpacity(0.15), typeColor.withOpacity(0.05)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(8), topRight: Radius.circular(8)),
                ),
                child: Center(
                  child: Container(
                    height: 70.0,
                    width: 70.0,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(colors: [typeColor.withOpacity(0.2), typeColor.withOpacity(0.1)]),
                    ),
                    child: Center(
                      child: icon != null
                          ? SvgPicture.asset(
                              icon!,
                              height: 35.0,
                              width: 35.0,
                              colorFilter: ColorFilter.mode(typeColor, BlendMode.srcIn),
                            )
                          : _getTypeIcon(typeColor),
                    ),
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(KSpacing.lg25),
                child: Column(
                  children: [
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.lato(
                        fontSize: Responsive.getFontSize(context, 20),
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: KSpacing.md),

                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.lato(
                        fontSize: Responsive.getFontSize(context, 14),
                        fontWeight: FontWeight.w400,
                        color: colors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: KSpacing.lg25),

                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (secondaryButtonText != null)
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                if (onSecondaryPressed != null) {
                                  onSecondaryPressed!();
                                } else {
                                  Navigator.of(context).pop(false);
                                }
                              },
                              child: Container(
                                height: 50.0,
                                decoration: BoxDecoration(
                                  color: secondaryButtonColor?.withOpacity(0.1) ?? colors.backgroundSecondary,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: secondaryButtonColor ?? colors.inputBorder, width: 1.5),
                                ),
                                child: Center(
                                  child: Text(
                                    secondaryButtonText!,
                                    style: GoogleFonts.lato(
                                      fontSize: Responsive.getFontSize(context, 15),
                                      fontWeight: FontWeight.w600,
                                      color: secondaryButtonColor ?? colors.textPrimary,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),

                        if (secondaryButtonText != null && primaryButtonText != null)
                          const SizedBox(width: KSpacing.md),

                        if (primaryButtonText != null)
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                if (onPrimaryPressed != null) {
                                  onPrimaryPressed!();
                                } else {
                                  Navigator.of(context).pop(true);
                                }
                              },
                              child: Container(
                                height: 50.0,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(colors: [typeColor, typeColor.withOpacity(0.8)]),
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: [
                                    BoxShadow(
                                      color: typeColor.withOpacity(0.3),
                                      blurRadius: 15,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: Text(
                                    primaryButtonText!,
                                    style: GoogleFonts.lato(
                                      fontSize: Responsive.getFontSize(context, 15),
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
