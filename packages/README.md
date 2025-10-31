# GrabGo Monorepo

This is a monorepo containing the GrabGo food delivery platform applications, managed with Melos.

## Packages

- **grub_go**: Main customer-facing food delivery app
- **grub_go_rider**: Delivery driver app for GrabGo platform
- **grub_go_shared**: Shared components, services, and utilities used across all apps

## Getting Started

### Prerequisites

- Flutter SDK (^3.9.0)
- Melos (for monorepo management)

### Installation

1. Install Melos globally:
   ```bash
   dart pub global activate melos
   ```

2. Bootstrap the workspace:
   ```bash
   melos bootstrap
   ```

### Available Scripts

- `melos analyze` - Run `flutter analyze` in all packages
- `melos test` - Run `flutter test` in all packages
- `melos clean` - Run `flutter clean` in all packages
- `melos get` - Run `flutter pub get` in all packages
- `melos build:android` - Build Android APK for all packages
- `melos build:ios` - Build iOS app for all packages
- `melos format` - Format code in all packages
- `melos lint` - Run linting in all packages

### Running Individual Apps

To run a specific app:

```bash
# Run the main customer app
cd packages/grub_go
flutter run

# Run the rider app
cd packages/grub_go_rider
flutter run
```

## Project Structure

```
├── packages/
│   ├── grub_go/          # Customer app
│   ├── grub_go_rider/    # Rider app
│   └── grub_go_shared/   # Shared components and utilities
├── melos.yaml            # Melos configuration
├── pubspec.yaml          # Workspace configuration
└── README.md
```

## Shared Package

The `grub_go_shared` package contains reusable components, services, and utilities that can be used across all apps in the monorepo:

### Components Available:
- **Widgets**: AppButton, AppTextInput, AppDialog, AppDrawer, and many more
- **Services**: UserService, LocationService, CacheService, etc.
- **Utils**: Theme utilities, color extensions, constants, routes
- **ViewModels**: ThemeProvider, LocationProvider, NavigationProvider, etc.

### Usage:
```dart
import 'package:grub_go_shared/grub_go_shared.dart';

// Use shared components
AppButton(
  text: 'Click me',
  onPressed: () => print('Button clicked'),
);

// Use shared services
final userService = UserService();
await userService.initialize();

// Use shared themes
MaterialApp(
  theme: AppTheme.lightTheme,
  darkTheme: AppTheme.darkTheme,
);
```
