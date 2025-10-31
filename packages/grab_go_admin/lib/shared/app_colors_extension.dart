import 'package:flutter/material.dart';
import 'app_colors.dart';

@immutable
class AppColorsExtension extends ThemeExtension<AppColorsExtension> {
  const AppColorsExtension({
    required this.primary,
    required this.secondary,
    required this.accent,
    required this.background,
    required this.surface,
    required this.text,
    required this.textSecondary,
    required this.border,
    required this.error,
    required this.success,
    required this.warning,
  });

  final Color primary;
  final Color secondary;
  final Color accent;
  final Color background;
  final Color surface;
  final Color text;
  final Color textSecondary;
  final Color border;
  final Color error;
  final Color success;
  final Color warning;

  static const AppColorsExtension light = AppColorsExtension(
    primary: AppColors.primary,
    secondary: AppColors.blueAccent,
    accent: AppColors.accentOrange,
    background: AppColors.secondaryBackground,
    surface: AppColors.white,
    text: AppColors.black,
    textSecondary: AppColors.mutedBrown,
    border: AppColors.lightSurface,
    error: AppColors.errorRed,
    success: AppColors.successGreen,
    warning: AppColors.warningOrange,
  );

  static const AppColorsExtension dark = AppColorsExtension(
    primary: AppColors.accentOrange,
    secondary: AppColors.blueAccent,
    accent: AppColors.violetAccent,
    background: AppColors.darkBackground,
    surface: AppColors.darkSurface,
    text: AppColors.white,
    textSecondary: Color(0xFFB0B0B0),
    border: AppColors.darkBorder,
    error: AppColors.errorRed,
    success: AppColors.successGreen,
    warning: AppColors.warningOrange,
  );

  @override
  AppColorsExtension copyWith({
    Color? primary,
    Color? secondary,
    Color? accent,
    Color? background,
    Color? surface,
    Color? text,
    Color? textSecondary,
    Color? border,
    Color? error,
    Color? success,
    Color? warning,
  }) {
    return AppColorsExtension(
      primary: primary ?? this.primary,
      secondary: secondary ?? this.secondary,
      accent: accent ?? this.accent,
      background: background ?? this.background,
      surface: surface ?? this.surface,
      text: text ?? this.text,
      textSecondary: textSecondary ?? this.textSecondary,
      border: border ?? this.border,
      error: error ?? this.error,
      success: success ?? this.success,
      warning: warning ?? this.warning,
    );
  }

  @override
  AppColorsExtension lerp(ThemeExtension<AppColorsExtension>? other, double t) {
    if (other is! AppColorsExtension) {
      return this;
    }
    return AppColorsExtension(
      primary: Color.lerp(primary, other.primary, t)!,
      secondary: Color.lerp(secondary, other.secondary, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      text: Color.lerp(text, other.text, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      border: Color.lerp(border, other.border, t)!,
      error: Color.lerp(error, other.error, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
    );
  }
}

extension AppColorsExtensionGetter on BuildContext {
  AppColorsExtension get appColors {
    return Theme.of(this).extension<AppColorsExtension>()!;
  }
}
