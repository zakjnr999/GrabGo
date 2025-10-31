/// Font sizes used throughout the app
class KTextSize {
  static const double extraSmall = 10;
  static const double small = 12;
  static const double medium = 14;
  static const double large = 16;
  static const double extraLarge = 26;
  static const double heading = 24;
  static const double display = 32;
}

/// Border radius values
class KBorderSize {
  static const double border = 30;
  static const double borderMedium = 10;
  static const double borderSmall = 6;
  static const double borderRadius4 = 4;
  static const double borderRadius8 = 8;
  static const double borderRadius12 = 12;
  static const double borderRadius15 = 15;
  static const double borderRadius20 = 20;
  static const double borderRadius50 = 50; // For pill-shaped buttons/inputs
}

/// Border width values
class KBorderWidth {
  static const double thin = 0.5;
  static const double normal = 1.0;
  static const double thick = 1.5;
  static const double extraThick = 2.0;
}

/// Spacing values for padding, margin, and gaps
class KSpacing {
  // Extra small spacing
  static const double xs = 4;

  // Small spacing
  static const double sm = 8;

  // Medium spacing
  static const double md = 10;
  static const double md12 = 12;
  static const double md15 = 15;

  // Large spacing
  static const double lg = 20;
  static const double lg25 = 25;

  // Extra large spacing
  static const double xl = 30;
  static const double xl40 = 40;
  static const double xl50 = 50;
}

/// Icon sizes
class KIconSize {
  static const double xs = 16;
  static const double sm = 20;
  static const double md = 22;
  static const double lg = 24;
  static const double xl = 28;
  static const double xxl = 32;
}

/// Common widget sizes
class KWidgetSize {
  // Button heights
  static const double buttonHeight = 50;
  static const double buttonHeightSmall = 40;
  static const double buttonHeightLarge = 60;

  // Input field heights
  static const double inputHeight = 50;
  static const double inputHeightSmall = 40;

  // Avatar/Profile sizes
  static const double avatarSmall = 35;
  static const double avatarMedium = 45;
  static const double avatarLarge = 60;

  // Icon button sizes
  static const double iconButton = 38;
  static const double iconButtonSmall = 30;
  static const double iconButtonLarge = 45;

  // Card/Container heights
  static const double cardSmall = 80;
  static const double cardMedium = 100;
  static const double cardLarge = 120;
}

/// Elevation values
class KElevation {
  static const double none = 0;
  static const double xs = 1;
  static const double sm = 2;
  static const double md = 4;
  static const double lg = 6;
  static const double xl = 8;
}

bool isValidEmail(String email) {
  final regex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
  return regex.hasMatch(email);
}
