import 'package:flutter/material.dart';
import 'colors.dart';
import 'app_colors_extension.dart';
import '../utils/constants.dart';

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: "Lato",
      package: 'grab_go_shared',
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
        backgroundColor: Color(0xFFF5F5F5),
        foregroundColor: Color(0xFF000000),
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF000000)),
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFFFFFFFF),
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
      package: 'grab_go_shared',
      scaffoldBackgroundColor: const Color(0xFF1E1E1E),
      primaryColor: AppColors.accentOrange,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.accentOrange,
        secondary: AppColors.blueAccent,
        surface: Color(0xFF1E1E1E),
        error: AppColors.errorRed,
        onPrimary: AppColors.white,
        onSecondary: AppColors.white,
        onSurface: AppColors.white,
        onError: AppColors.white,
      ),
      extensions: const <ThemeExtension<dynamic>>[AppColorsExtension.dark],
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF1E1E1E),
        foregroundColor: Color(0xFFFFFFFF),
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFFFFFFFF)),
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF121212),
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
      textTheme: TextTheme(
        displayLarge: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.white),
        displayMedium: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.white),
        displaySmall: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.white),
        headlineLarge: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: AppColors.white),
        headlineMedium: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.white),
        headlineSmall: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.white),
        titleLarge: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.white),
        titleMedium: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.white),
        titleSmall: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.white),
        bodyLarge: const TextStyle(fontSize: 16, fontWeight: FontWeight.w400, color: AppColors.white),
        bodyMedium: const TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: AppColors.white),
        bodySmall: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: Color(0xFFB0B0B0)),
      ),
    );
  }
}
