import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_colors_extension.dart';

class ThemeHelper {
  static SystemUiOverlayStyle getSystemUiOverlayStyle(
    BuildContext context, {
    Color? statusBarColor,
    Color? navigationBarColor,
  }) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SystemUiOverlayStyle(
      statusBarColor: statusBarColor ?? Colors.transparent,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      systemNavigationBarColor: navigationBarColor ?? colors.backgroundPrimary,
      systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
    );
  }

  static bool isDarkMode(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark;
  }
}
