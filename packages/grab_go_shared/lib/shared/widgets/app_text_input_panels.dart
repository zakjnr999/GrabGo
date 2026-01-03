// ignore_for_file: deprecated_member_use

import 'dart:io' show Platform;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../utils/constants.dart';
import 'package:intl/intl.dart';
import '../utils/app_colors_extension.dart';

class AppTextInputPanels extends StatelessWidget {
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
  const AppTextInputPanels({
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
  });

  Future<void> _handleTap(BuildContext context) async {
    if (onTap != null) {
      onTap!();
      return;
    }

    if (keyboardType == TextInputType.datetime && readOnly && controller != null) {
      FocusScope.of(context).unfocus();

      final colors = context.appColors;
      DateTime selectedDate = DateTime(2005, 1, 1);
      final dateFormatter = DateFormat('MMM d, yyyy');

      if (Platform.isIOS) {
        showModalBottomSheet(
          context: context,
          backgroundColor: colors.backgroundPrimary,
          builder: (_) {
            return Container(
              height: 260,
              decoration: BoxDecoration(color: colors.backgroundPrimary),
              child: Column(
                children: [
                  SizedBox(
                    height: 200,
                    child: CupertinoTheme(
                      data: CupertinoThemeData(
                        textTheme: CupertinoTextThemeData(
                          dateTimePickerTextStyle: TextStyle(color: colors.textPrimary, fontSize: 21),
                        ),
                        brightness: Theme.of(context).brightness,
                      ),
                      child: CupertinoDatePicker(
                        mode: CupertinoDatePickerMode.date,
                        initialDateTime: DateTime(2005, 1, 1),
                        minimumDate: DateTime(1900),
                        maximumDate: DateTime.now(),
                        onDateTimeChanged: (DateTime newDate) {
                          selectedDate = newDate;
                        },
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      controller!.text = dateFormatter.format(selectedDate);
                      Navigator.of(context).pop();
                    },
                    child: Text("Done", style: TextStyle(color: colors.accentOrange)),
                  ),
                ],
              ),
            );
          },
        );
      } else {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final pickedDate = await showDatePicker(
          context: context,
          initialDate: DateTime(2005, 1, 1),
          firstDate: DateTime(1900),
          lastDate: DateTime.now(),
          helpText: 'Select your birth date',
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: isDark
                    ? ColorScheme.dark(
                        primary: colors.accentOrange,
                        onPrimary: colors.backgroundPrimary,
                        onSurface: colors.textPrimary,
                        surface: colors.backgroundSecondary,
                      )
                    : ColorScheme.light(
                        primary: colors.accentOrange,
                        onPrimary: Colors.white,
                        onSurface: colors.textPrimary,
                        surface: colors.backgroundPrimary,
                      ),
              ),
              child: child!,
            );
          },
        );

        if (pickedDate != null) {
          controller!.text = dateFormatter.format(pickedDate);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null && label!.isNotEmpty) ...[
          Text(
            label!,
            style:
                labelStyle ??
                TextStyle(fontSize: KTextSize.small, fontWeight: FontWeight.w600, color: colors.textPrimary),
          ),
          SizedBox(height: KSpacing.sm),
        ],
        TextField(
          controller: controller,
          cursorOpacityAnimates: true,
          keyboardType: keyboardType,
          obscureText: obscureText,
          enabled: enabled,
          readOnly: readOnly,
          cursorColor: colors.accentOrange,
          onTap: () => _handleTap(context),
          maxLines: obscureText ? 1 : maxLines,
          style:
              textStyle ??
              TextStyle(
                fontFamily: "Lato",
                package: 'grab_go_shared',
                fontSize: KTextSize.small,
                color: colors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
          decoration: InputDecoration(
            filled: true,
            fillColor: fillColor ?? colors.inputBorder,
            hintText: hintText,
            hintStyle: hintStyle ?? TextStyle(fontSize: 13.0, color: colors.textSecondary.withOpacity(0.7)),
            prefixIcon: prefixIcon,
            suffixIcon: suffixIcon,
            errorText: errorText,
            errorStyle: TextStyle(fontSize: KTextSize.extraSmall, color: colors.error, fontWeight: FontWeight.w500),
            errorMaxLines: 2,
            contentPadding: contentPadding ?? const EdgeInsets.symmetric(vertical: 15, horizontal: 15),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(borderRadius),
              borderSide: BorderSide(color: errorText != null ? colors.error : (borderColor ?? Colors.transparent)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(borderRadius),
              borderSide: BorderSide(
                color: errorText != null ? colors.error : colors.accentOrange,
                width: KBorderWidth.thick,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(borderRadius),
              borderSide: BorderSide(color: colors.error),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(borderRadius),
              borderSide: BorderSide(color: colors.error, width: KBorderWidth.thick),
            ),
          ),
        ),
      ],
    );
  }
}
