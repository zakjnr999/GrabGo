# GrabGo Monorepo

A Flutter monorepo for the GrabGo food delivery platform.

## 📁 Project Structure

```
GrabGo/
├── packages/
│   ├── grab_go_customer/    # Customer mobile app
│   ├── grab_go_rider/       # Rider/driver mobile app
│   ├── grab_go_restaurant/  # Restaurant management app
│   └── grab_go_shared/      # Shared components and utilities
├── melos.yaml               # Melos configuration
└── pubspec.yaml             # Workspace configuration
```

## 🚀 Getting Started

### Prerequisites

- Flutter SDK (>=3.0.0)
- Dart SDK (>=3.9.2)
- [Melos](https://melos.invertase.dev) for monorepo management

### Installation

1. **Clone the repository:**
   ```bash
   git clone <repository-url>
   cd GrabGo
   ```

2. **Install Melos globally:**
   ```bash
   dart pub global activate melos
   ```

3. **Add Melos to your PATH:**
   
   **Windows (PowerShell):**
   ```powershell
   # For current session:
   $env:PATH += ";$env:LOCALAPPDATA\Pub\Cache\bin"
   
   # Or permanently, add this to your PowerShell profile:
   # $env:LOCALAPPDATA\Pub\Cache\bin
   ```

4. **Install dependencies:**
   ```bash
   flutter pub get
   ```

## 🎯 Running Apps

### Method 1: Using Melos (Recommended)

From the root directory:

```bash
# Customer app
melos run run:customer

# Rider app
melos run run:rider

# Restaurant app
melos run run:restaurant
```

### Method 2: Using Helper Script (Windows)

```powershell
.\run_customer.ps1
```

### Method 3: Direct Flutter

```bash
cd packages/grab_go_customer
flutter run
```

## 📦 Available Melos Scripts

- `melos run run:customer` - Run customer app
- `melos run run:rider` - Run rider app
- `melos run run:restaurant` - Run restaurant app
- `melos run run:customer:debug` - Run customer app in debug mode
- `melos run run:customer:release` - Run customer app in release mode
- `melos run rebuild:customer` - Clean, get dependencies, and run customer app
- `melos exec -- flutter analyze` - Analyze all packages
- `melos exec -- flutter test` - Test all packages
- `melos exec -- flutter clean` - Clean all packages
- `melos run devices` - List connected devices
- `melos run emulators` - List available emulators

## 🔧 Development

### Running in Different Modes

```bash
# Debug mode (default)
melos run run:customer

# Debug mode with detailed output
melos run run:customer:debug

# Release mode
melos run run:customer:release
```

### Code Quality

```bash
# Analyze code
melos exec -- flutter analyze

# Format code
melos exec -- dart format .

# Lint code
melos exec -- dart analyze
```

### Cleaning

```bash
# Clean all packages
melos exec -- flutter clean

# Get dependencies after cleaning
melos exec -- flutter pub get
```

## 📁 Shared Assets

All assets (images, icons, fonts) are centralized in `packages/grab_go_shared`.

### Accessing Assets

```dart
import 'package:grab_go_shared/gen/assets.gen.dart';

// Images
Assets.images.splashImage.image(fit: BoxFit.cover)
Assets.images.dishOne.image(fit: BoxFit.cover)

// Icons (SVG)
SvgPicture.asset(Assets.icons.home)

// Icons (PNG with ImageProvider)
Assets.icons.appIcon.provider()

// Fonts (automatically available)
Text('Hello', style: TextStyle(fontFamily: 'Lato'))
```

## 🔗 Workspace Configuration

The project uses Flutter's built-in workspace feature. The `pubspec.yaml` at the root defines:

```yaml
workspace:
  - packages/grab_go_customer
  - packages/grab_go_rider
  - packages/grab_go_shared
  - packages/grab_go_restaurant
```

All packages must have `resolution: workspace` in their `pubspec.yaml`.

## 📝 Notes

- If `melos` command is not found, use: `flutter pub global run melos:melos`
- On Windows, you may need to add pub's cache bin to PATH permanently
- Assets are type-safe and auto-generated using `flutter_gen`

## 🐛 Troubleshooting

### "Unable to load asset" Error

This has been fixed! All assets now load correctly from `grab_go_shared` package.

### Melos Command Not Found

**Windows:**
```powershell
# Temporarily add to PATH
$env:PATH += ";$env:LOCALAPPDATA\Pub\Cache\bin"

# Or use the long form
flutter pub global run melos:melos run run:customer
```

**Permanent fix:** Add `%LOCALAPPDATA%\Pub\Cache\bin` to your system PATH environment variable.

### Workspace Resolution Error

Ensure all packages have `resolution: workspace` in their `pubspec.yaml`.

## 📄 License

[Your License Here]

