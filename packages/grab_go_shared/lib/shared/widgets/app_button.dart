import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../utils/app_colors_extension.dart';
import '../utils/constants.dart';

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
  final bool isLoading;

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
    this.isLoading = false,
  });

  String get buttonTextValue => buttonText;

  TextStyle getButtonTextStyle(BuildContext context) {
    return textStyle ?? TextStyle(fontSize: 12.sp, fontWeight: FontWeight.bold, color: textColor);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return SizedBox(
      width: width,
      height: height,
      child: TextButton(
        onPressed: isLoading ? null : onPressed,
        style: TextButton.styleFrom(
          backgroundColor: backgroundColor ?? colors.accentOrange,
          disabledBackgroundColor: (backgroundColor ?? colors.accentOrange).withOpacity(0.6),
          foregroundColor: Colors.white,
          padding: padding ?? EdgeInsets.all(KSpacing.md15.r),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius ?? 8.0),
            side: BorderSide(color: borderColor ?? Colors.transparent, width: borderColor != null ? 1 : 0),
          ),
        ),
        child: isLoading
            ? SizedBox(
                width: 20.r,
                height: 20.r,
                child: const CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(buttonTextValue, style: getButtonTextStyle(context)),
      ),
    );
  }
}
