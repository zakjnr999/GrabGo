import 'package:flutter/material.dart';

/// Custom color extension for theme-aware colors
/// This allows colors to automatically switch between light and dark themes
@immutable
class AppColorsExtension extends ThemeExtension<AppColorsExtension> {
  // Text colors
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;

  // Background colors
  final Color backgroundPrimary;
  final Color backgroundSecondary;
  final Color backgroundTertiary;

  // Surface colors
  final Color surfacePrimary;
  final Color surfaceSecondary;

  // Accent colors (these typically stay the same in both themes)
  final Color accentOrange;
  final Color accentOrangeLight;
  final Color accentBlue;
  final Color accentViolet;
  final Color accentGreen;

  // Semantic colors
  final Color error;
  final Color success;
  final Color warning;
  final Color info;

  // Border and divider colors
  final Color border;
  final Color divider;

  // Icon colors
  final Color iconPrimary;
  final Color iconSecondary;

  // Card and container colors
  final Color cardBackground;
  final Color containerBackground;

  // Input field colors
  final Color inputBackground;
  final Color inputBorder;
  final Color inputFocusedBorder;

  // Overlay colors
  final Color overlay;
  final Color shadow;

  const AppColorsExtension({
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.backgroundPrimary,
    required this.backgroundSecondary,
    required this.backgroundTertiary,
    required this.surfacePrimary,
    required this.surfaceSecondary,
    required this.accentOrange,
    required this.accentOrangeLight,
    required this.accentBlue,
    required this.accentViolet,
    required this.accentGreen,
    required this.error,
    required this.success,
    required this.warning,
    required this.info,
    required this.border,
    required this.divider,
    required this.iconPrimary,
    required this.iconSecondary,
    required this.cardBackground,
    required this.containerBackground,
    required this.inputBackground,
    required this.inputBorder,
    required this.inputFocusedBorder,
    required this.overlay,
    required this.shadow,
  });

  static const light = AppColorsExtension(
    textPrimary: Color(0xFF000000),
    textSecondary: Color(0xFF534C4B),
    textTertiary: Color(0xFF9E9E9E),
    backgroundPrimary: Color(0xFFFFFFFF),
    backgroundSecondary: Color(0xFFF5F5F5),
    backgroundTertiary: Color(0xFFFFFFFF),
    surfacePrimary: Color(0xFFFFFFFF),
    surfaceSecondary: Color(0xFFF5F5F5),
    accentOrange: Color(0xFFFE6132),
    accentOrangeLight: Color(0xFFFFDFD6),
    accentBlue: Color(0xFF018FFF),
    accentViolet: Color(0xFF9E37FF),
    accentGreen: Color(0xFF4CAF50),
    error: Color(0xFFE53935),
    success: Color(0xFF4CAF50),
    warning: Color(0xFFFFA726),
    info: Color(0xFF29B6F6),
    border: Color(0xFFEEEEEE),
    divider: Color(0xFFE0E0E0),
    iconPrimary: Color(0xFF000000),
    iconSecondary: Color(0xFF534C4B),
    cardBackground: Color(0xFFFFFFFF),
    containerBackground: Color(0xFFF5F5F5),
    inputBackground: Color(0xFFFFFFFF),
    inputBorder: Color(0xFFEEEEEE),
    inputFocusedBorder: Color(0xFFFE6132),
    overlay: Color(0x80000000),
    shadow: Color(0x1A000000),
  );

  static const dark = AppColorsExtension(
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xFFB0B0B0),
    textTertiary: Color(0xFF757575),
    backgroundPrimary: Color(0xFF121212),
    backgroundSecondary: Color(0xFF1E1E1E),
    backgroundTertiary: Color(0xFF1B1B1B),
    surfacePrimary: Color(0xFF121212),
    surfaceSecondary: Color(0xFF2A2A2A),
    accentOrange: Color(0xFFFE6132),
    accentOrangeLight: Color(0xFFFFDFD6),
    accentBlue: Color(0xFF018FFF),
    accentViolet: Color(0xFF9E37FF),
    accentGreen: Color(0xFF4CAF50),
    error: Color(0xFFE53935),
    success: Color(0xFF4CAF50),
    warning: Color(0xFFFFA726),
    info: Color(0xFF29B6F6),
    border: Color(0xFF2A2A2A),
    divider: Color(0xFF424242),
    iconPrimary: Color(0xFFFFFFFF),
    iconSecondary: Color(0xFFB0B0B0),
    cardBackground: Color(0xFF121212),
    containerBackground: Color(0xFF121212),
    inputBackground: Color(0xFF1E1E1E),
    inputBorder: Color(0xFF2A2A2A),
    inputFocusedBorder: Color(0xFFFE6132),
    overlay: Color(0x80000000),
    shadow: Color(0x33000000),
  );

  @override
  ThemeExtension<AppColorsExtension> copyWith({
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? backgroundPrimary,
    Color? backgroundSecondary,
    Color? backgroundTertiary,
    Color? surfacePrimary,
    Color? surfaceSecondary,
    Color? accentOrange,
    Color? accentOrangeLight,
    Color? accentBlue,
    Color? accentViolet,
    Color? accentGreen,
    Color? error,
    Color? success,
    Color? warning,
    Color? info,
    Color? border,
    Color? divider,
    Color? iconPrimary,
    Color? iconSecondary,
    Color? cardBackground,
    Color? containerBackground,
    Color? inputBackground,
    Color? inputBorder,
    Color? inputFocusedBorder,
    Color? overlay,
    Color? shadow,
  }) {
    return AppColorsExtension(
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      backgroundPrimary: backgroundPrimary ?? this.backgroundPrimary,
      backgroundSecondary: backgroundSecondary ?? this.backgroundSecondary,
      backgroundTertiary: backgroundTertiary ?? this.backgroundTertiary,
      surfacePrimary: surfacePrimary ?? this.surfacePrimary,
      surfaceSecondary: surfaceSecondary ?? this.surfaceSecondary,
      accentOrange: accentOrange ?? this.accentOrange,
      accentOrangeLight: accentOrangeLight ?? this.accentOrangeLight,
      accentBlue: accentBlue ?? this.accentBlue,
      accentViolet: accentViolet ?? this.accentViolet,
      accentGreen: accentGreen ?? this.accentGreen,
      error: error ?? this.error,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      info: info ?? this.info,
      border: border ?? this.border,
      divider: divider ?? this.divider,
      iconPrimary: iconPrimary ?? this.iconPrimary,
      iconSecondary: iconSecondary ?? this.iconSecondary,
      cardBackground: cardBackground ?? this.cardBackground,
      containerBackground: containerBackground ?? this.containerBackground,
      inputBackground: inputBackground ?? this.inputBackground,
      inputBorder: inputBorder ?? this.inputBorder,
      inputFocusedBorder: inputFocusedBorder ?? this.inputFocusedBorder,
      overlay: overlay ?? this.overlay,
      shadow: shadow ?? this.shadow,
    );
  }

  @override
  ThemeExtension<AppColorsExtension> lerp(covariant ThemeExtension<AppColorsExtension>? other, double t) {
    if (other is! AppColorsExtension) return this;

    return AppColorsExtension(
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
      backgroundPrimary: Color.lerp(backgroundPrimary, other.backgroundPrimary, t)!,
      backgroundSecondary: Color.lerp(backgroundSecondary, other.backgroundSecondary, t)!,
      backgroundTertiary: Color.lerp(backgroundTertiary, other.backgroundTertiary, t)!,
      surfacePrimary: Color.lerp(surfacePrimary, other.surfacePrimary, t)!,
      surfaceSecondary: Color.lerp(surfaceSecondary, other.surfaceSecondary, t)!,
      accentOrange: Color.lerp(accentOrange, other.accentOrange, t)!,
      accentOrangeLight: Color.lerp(accentOrangeLight, other.accentOrangeLight, t)!,
      accentBlue: Color.lerp(accentBlue, other.accentBlue, t)!,
      accentViolet: Color.lerp(accentViolet, other.accentViolet, t)!,
      accentGreen: Color.lerp(accentGreen, other.accentGreen, t)!,
      error: Color.lerp(error, other.error, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      info: Color.lerp(info, other.info, t)!,
      border: Color.lerp(border, other.border, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      iconPrimary: Color.lerp(iconPrimary, other.iconPrimary, t)!,
      iconSecondary: Color.lerp(iconSecondary, other.iconSecondary, t)!,
      cardBackground: Color.lerp(cardBackground, other.cardBackground, t)!,
      containerBackground: Color.lerp(containerBackground, other.containerBackground, t)!,
      inputBackground: Color.lerp(inputBackground, other.inputBackground, t)!,
      inputBorder: Color.lerp(inputBorder, other.inputBorder, t)!,
      inputFocusedBorder: Color.lerp(inputFocusedBorder, other.inputFocusedBorder, t)!,
      overlay: Color.lerp(overlay, other.overlay, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
    );
  }
}

/// Extension to easily access AppColorsExtension from BuildContext
extension AppColorsContext on BuildContext {
  AppColorsExtension get appColors {
    return Theme.of(this).extension<AppColorsExtension>() ?? AppColorsExtension.light;
  }
}
