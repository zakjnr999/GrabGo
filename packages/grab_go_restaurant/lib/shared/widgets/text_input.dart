// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:grab_go_restaurant/shared/app_colors_extension.dart';
import 'package:grab_go_restaurant/shared/app_colors.dart';
import 'package:grab_go_shared/shared/widgets/responsive.dart';

class TextInput extends StatelessWidget {
  final TextEditingController? controller;
  final String? label;
  final String hintText;
  final TextInputType keyboardType;
  final bool obscureText;
  final Color? borderColor;
  final Color? fillColor;
  final double borderRadius;
  final EdgeInsetsGeometry? contentPadding;
  final TextStyle? textStyle;
  final TextStyle? hintStyle;
  final TextStyle? labelStyle;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final bool enabled;
  final bool readOnly;
  final VoidCallback? onTap;
  final String? errorText;
  final int? maxLines;
  final ValueChanged<String>? onChanged;

  const TextInput({
    super.key,
    this.controller,
    this.label,
    this.hintText = '',
    this.keyboardType = TextInputType.text,
    this.obscureText = false,
    this.borderColor,
    this.fillColor,
    this.borderRadius = 8.0,
    this.contentPadding,
    this.textStyle,
    this.hintStyle,
    this.labelStyle,
    this.prefixIcon,
    this.suffixIcon,
    this.enabled = true,
    this.readOnly = false,
    this.onTap,
    this.errorText,
    this.maxLines,
    this.onChanged,
  });

  void _handleTap(BuildContext context) {
    if (onTap != null) {
      onTap!();
    }
  }

  bool _shouldObscureText() {
    // If maxLines is specified and greater than 1, never obscure text
    if (maxLines != null && maxLines! > 1) {
      return false;
    }
    // Otherwise, use the provided obscureText value
    return obscureText;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isMobile = Responsive.isMobile(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null && label!.isNotEmpty) ...[
          Text(
            label!,
            style:
                labelStyle ??
                GoogleFonts.lato(
                  fontSize: Responsive.getFontSize(context, isMobile ? 10 : 12),
                  fontWeight: FontWeight.w600,
                  color: colors.text,
                ),
          ),
          SizedBox(height: isMobile ? 6 : 8),
        ],
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: _shouldObscureText(),
          enabled: enabled,
          readOnly: readOnly,
          maxLines: maxLines,
          cursorColor: AppColors.accentOrange,
          onTap: () => _handleTap(context),
          onChanged: onChanged,
          style:
              textStyle ??
              GoogleFonts.lato(
                fontSize: Responsive.getFontSize(context, isMobile ? 10 : 12),
                color: colors.text,
                fontWeight: FontWeight.w500,
              ),
          decoration: InputDecoration(
            filled: true,
            fillColor: fillColor ?? colors.border,
            hintText: hintText,
            hintStyle:
                hintStyle ??
                GoogleFonts.lato(
                  fontSize: Responsive.getFontSize(context, isMobile ? 10 : 12),
                  color: colors.textSecondary.withValues(alpha: 0.7),
                ),
            prefixIcon: prefixIcon,
            suffixIcon: suffixIcon,
            errorText: errorText,
            errorStyle: GoogleFonts.lato(
              fontSize: Responsive.getFontSize(context, 10),
              color: colors.error,
              fontWeight: FontWeight.w500,
            ),
            errorMaxLines: 2,
            contentPadding: contentPadding ?? EdgeInsets.all(isMobile ? 12 : 14),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(borderRadius),
              borderSide: BorderSide(
                color: errorText != null ? colors.border.withValues(alpha: 1) : (borderColor ?? Colors.transparent),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(borderRadius),
              borderSide: BorderSide(color: errorText != null ? colors.error : AppColors.accentOrange, width: 1),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(borderRadius),
              borderSide: BorderSide(color: colors.border.withValues(alpha: 1), width: 1),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(borderRadius),
              borderSide: BorderSide(color: colors.border.withValues(alpha: 1), width: 1),
            ),
          ),
        ),
      ],
    );
  }
}
