import 'package:flutter/material.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.light;

  ThemeMode get themeMode => _themeMode;

  bool get isDarkMode {
    return _themeMode == ThemeMode.dark;
  }

  void setThemeMode(ThemeMode mode) {
    // Only allow light and dark modes
    if (mode == ThemeMode.light || mode == ThemeMode.dark) {
      _themeMode = mode;
      notifyListeners();
    }
  }

  void toggleTheme() {
    _themeMode = _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }

  String get currentThemeName {
    switch (_themeMode) {
      case ThemeMode.light:
        return 'Day';
      case ThemeMode.dark:
        return 'Night';
      case ThemeMode.system:
        return 'Day'; // Fallback, should not occur
    }
  }

  IconData get currentThemeIcon {
    switch (_themeMode) {
      case ThemeMode.light:
        return Icons.light_mode;
      case ThemeMode.dark:
        return Icons.dark_mode;
      case ThemeMode.system:
        return Icons.light_mode; // Fallback, should not occur
    }
  }
}
