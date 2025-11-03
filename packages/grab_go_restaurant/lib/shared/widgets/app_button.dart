import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:grab_go_restaurant/shared/app_colors.dart';
import 'package:grab_go_shared/shared/widgets/responsive.dart';

class AppButton extends StatelessWidget {
  final String buttonText;
  final VoidCallback onPressed;
  final TextStyle? textStyle;
  final EdgeInsetsGeometry? padding;
  final Color? backgroundColor;
  final double? width;
  final double? height;
  final double? borderRadius;
  final Color? borderColor;
  final Color? textColor;
  final Widget? icon;

  const AppButton({
    super.key,
    this.buttonText = 'Button',
    required this.onPressed,
    this.textStyle,
    this.padding,
    this.backgroundColor,
    this.width,
    this.height,
    this.borderRadius = 8.0,
    this.borderColor,
    this.textColor,
    this.icon,
  });

  String get buttonTextValue => buttonText;

  TextStyle getButtonTextStyle(BuildContext context) {
    final isMobile = Responsive.isMobile(context);
    return textStyle ??
        GoogleFonts.lato(
          fontSize: Responsive.getFontSize(context, isMobile ? 10 : 12),
          fontWeight: FontWeight.w600,
          color: textColor ?? Colors.white,
        );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          backgroundColor: backgroundColor ?? AppColors.accentOrange,
          foregroundColor: textColor ?? Colors.white,
          padding: padding ?? const EdgeInsets.all(15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius ?? 8.0),
            side: BorderSide(color: borderColor ?? Colors.transparent, width: borderColor != null ? 1 : 0),
          ),
        ),
        child: icon != null
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  icon!,
                  const SizedBox(width: 8),
                  Text(buttonTextValue, style: getButtonTextStyle(context)),
                ],
              )
            : Text(buttonTextValue, style: getButtonTextStyle(context)),
      ),
    );
  }
}
