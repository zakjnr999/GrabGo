import 'package:flutter/material.dart';
import 'package:grab_go_restaurant/shared/app_colors.dart';
import 'package:grab_go_restaurant/shared/app_colors_extension.dart';
import 'package:grab_go_restaurant/shared/utils/constants.dart';

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: "Lato",
      scaffoldBackgroundColor: AppColors.secondaryBackground,
      primaryColor: AppColors.accentOrange,
      colorScheme: const ColorScheme.light(
        primary: AppColors.accentOrange,
        secondary: AppColors.blueAccent,
        surface: AppColors.white,
        error: AppColors.errorRed,
        onPrimary: AppColors.white,
        onSecondary: AppColors.white,
        onSurface: AppColors.black,
        onError: AppColors.white,
      ),
      extensions: const <ThemeExtension<dynamic>>[AppColorsExtension.light],
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.secondaryBackground,
        foregroundColor: AppColors.black,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.black),
      ),
      cardTheme: CardThemeData(
        color: AppColors.white,
        elevation: KElevation.sm,
        shadowColor: Colors.black.withAlpha(10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(KBorderSize.borderRadius12)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accentOrange,
          foregroundColor: AppColors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(KBorderSize.borderRadius8)),
        ),
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.black),
        displayMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.black),
        displaySmall: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.black),
        headlineLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: AppColors.black),
        headlineMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.black),
        headlineSmall: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.black),
        titleLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.black),
        titleMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.black),
        titleSmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.black),
        bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w400, color: AppColors.black),
        bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: AppColors.black),
        bodySmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: AppColors.mutedBrown),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: "Lato",
      scaffoldBackgroundColor: AppColors.darkBackground,
      primaryColor: AppColors.accentOrange,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.accentOrange,
        secondary: AppColors.blueAccent,
        surface: AppColors.darkSurface,
        error: AppColors.errorRed,
        onPrimary: AppColors.white,
        onSecondary: AppColors.white,
        onSurface: AppColors.white,
        onError: AppColors.white,
      ),
      extensions: const <ThemeExtension<dynamic>>[AppColorsExtension.dark],
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.darkSurface,
        foregroundColor: AppColors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.white),
      ),
      cardTheme: CardThemeData(
        color: AppColors.darkSurface,
        elevation: KElevation.sm,
        shadowColor: Colors.black.withAlpha(20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(KBorderSize.borderRadius12)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accentOrange,
          foregroundColor: AppColors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(KBorderSize.borderRadius8)),
        ),
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.white),
        displayMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.white),
        displaySmall: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.white),
        headlineLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: AppColors.white),
        headlineMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.white),
        headlineSmall: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.white),
        titleLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.white),
        titleMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.white),
        titleSmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.white),
        bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w400, color: AppColors.white),
        bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: AppColors.white),
        bodySmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: const Color(0xFFB0B0B0)),
      ),
    );
  }
}
