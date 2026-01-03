# GrabGo Shared Package

Shared package containing common components, utilities, assets, and services used across all GrabGo applications.

## Contents

### Assets
- **Images** - App images, icons, and graphics
- **Icons** - SVG icons for UI elements
- **Fonts** - Custom fonts (Lato, Lobster)

All assets are type-safe and auto-generated using `flutter_gen`.

### Widgets
Reusable UI components including:
- AppButton
- AppDialog
- AppDrawer
- AppPopupMenu
- AppTextInput
- And more...

### Utilities
- **Theme** - AppColors, AppColorsExtension for theme-aware colors
- **Responsive** - Responsive design helpers
- **Constants** - App-wide constants
- **Config** - App configuration (API keys, base URLs)
- **Helpers** - Utility functions

### Services
Shared business logic services and providers.

### Models
Common data models used across applications.

## Usage

### Adding as Dependency

Add to your `pubspec.yaml`:

```yaml
dependencies:
  grab_go_shared:
    path: ../grab_go_shared
```

### Accessing Assets

```dart
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:flutter_svg/flutter_svg.dart';

// SVG Icons
SvgPicture.asset(
  Assets.icons.home,
  package: 'grab_go_shared',
)

// Images
Assets.images.splashImage.image(
  package: 'grab_go_shared',
)
```

### Using Shared Widgets

```dart
import 'package:grab_go_shared/shared/widgets/app_button.dart';

AppButton(
  buttonText: 'Click me',
  onPressed: () {},
)
```

### Using Utilities

```dart
import 'package:grab_go_shared/shared/utils/colors.dart';
import 'package:grab_go_shared/shared/utils/app_colors_extension.dart';

// Access colors
AppColors.primary

// Theme-aware colors
final colors = context.appColors;
colors.textPrimary
```

## Generating Assets

After adding new assets, regenerate the asset files:

```bash
cd packages/grab_go_shared
dart run build_runner build
```

## Project Structure

```
lib/
├── assets/            # Image, icon, and font files
├── gen/               # Generated asset files
├── shared/            # Shared utilities and widgets
└── grub_go_shared.dart # Main export file
```
