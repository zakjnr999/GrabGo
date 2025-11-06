# GrabGo Project Brief

## 📱 Project Overview

**GrabGo** is a comprehensive food delivery platform built with Flutter, featuring a multi-application ecosystem that connects customers, delivery riders, restaurants, and administrators. The project follows a monorepo architecture using Melos for workspace management, enabling code sharing and streamlined development across all platforms.

---

## 🏗️ Architecture

### Monorepo Structure
The project uses a **Melos-managed monorepo** with 5 main packages:

```
GrabGo/
├── packages/
│   ├── grab_go_customer/    # Customer mobile app (Android/iOS)
│   ├── grab_go_rider/       # Rider/driver mobile app (Android/iOS)
│   ├── grab_go_restaurant/  # Restaurant management web panel
│   ├── grab_go_admin/       # Admin web dashboard panel
│   └── grab_go_shared/      # Shared components, assets, and utilities
├── melos.yaml               # Melos configuration
└── pubspec.yaml             # Workspace configuration
```

### Key Architectural Decisions
- **Code Sharing**: Shared package (`grab_go_shared`) contains common widgets, utilities, models, and assets
- **State Management**: Provider pattern for state management across all apps
- **Routing**: GoRouter for navigation
- **API Communication**: Chopper for type-safe HTTP client generation
- **Authentication**: Firebase Authentication (Phone, Email, Google Sign-In)
- **Payment Integration**: Paystack for payment processing

---

## 📦 Packages Breakdown

### 1. **grab_go_customer** (Mobile App - Android/iOS)
Customer-facing mobile application for ordering food.

**Key Features:**
- User authentication (Phone, Email, Google Sign-In)
- Restaurant browsing and search
- Menu viewing and food details
- Shopping cart management
- Order placement and tracking
- Payment integration (Paystack)
- Real-time order tracking with maps
- Profile management
- Favorites system
- Order history

**Tech Stack:**
- Firebase (Auth, App Check)
- Google Sign-In
- Geolocator & Geocoding
- Paystack payment
- Image picker
- Cached network images

---

### 2. **grab_go_rider** (Mobile App - Android/iOS)
Delivery driver application for managing deliveries.

**Key Features:**
- Rider authentication and verification
- Order management (accept/reject orders)
- Real-time delivery tracking
- Earnings and wallet management
- Performance analytics
- Chat functionality
- Document management
- Vehicle details management
- Bank account linking
- Notifications

**Tech Stack:**
- Firebase (Auth, App Check)
- Geolocator & Geocoding
- Real-time order updates
- Image picker

---

### 3. **grab_go_restaurant** (Web App)
Web-based restaurant management panel.

**Key Features:**
- Restaurant authentication
- Dashboard with analytics
- Menu management
- Order management
- Restaurant settings
- Setup and configuration

**Tech Stack:**
- Flutter Web
- FL Chart for analytics
- Image picker for web
- File picker

---

### 4. **grab_go_admin** (Web App)
Administrative dashboard for platform management.

**Key Features:**
- Admin authentication
- Dashboard with analytics
- Restaurant management
- Order management
- Payment tracking
- Settings management

**Tech Stack:**
- Flutter Web
- FL Chart for analytics
- Google Fonts

---

### 5. **grab_go_shared** (Shared Package)
Centralized package containing shared code and assets.

**Contents:**
- Common widgets and UI components
- Shared utilities and helpers
- Common models
- Assets (images, icons, fonts, Lottie animations)
- Theme configuration
- Shared services (Firebase, Geolocator, etc.)

---

## 🛠️ Tech Stack

### Core Technologies
- **Language**: Dart 3.9+
- **Framework**: Flutter 3.0+
- **State Management**: Provider
- **Routing**: GoRouter
- **API Client**: Chopper (with code generation)
- **Backend Communication**: RESTful APIs

### Key Dependencies
- **Firebase**: Authentication, App Check
- **Authentication**: Google Sign-In, Phone Auth
- **Location**: Geolocator, Geocoding
- **Payment**: Paystack
- **UI/UX**: 
  - Animations
  - Shimmer effects
  - Image caching
  - ScreenUtil for responsive design
- **Charts**: FL Chart (for admin/restaurant dashboards)
- **Code Generation**: build_runner, json_serializable, chopper_generator

---

## 🚀 Development Setup

### Prerequisites
- Flutter SDK (3.0+)
- Dart SDK (3.9+)
- Melos (for monorepo management)
- Android Studio / VS Code/ Xcode (for mobile development)
- Chrome (for web development)

### Getting Started

1. **Install Melos**:
   ```bash
   dart pub global activate melos
   ```

2. **Bootstrap the project**:
   ```bash
   melos bootstrap
   ```

3. **Get dependencies**:
   ```bash
   melos get
   ```

### Running Applications

**Customer App:**
```bash
melos run:customer
# or
cd packages/grab_go_customer && flutter run
```

**Rider App:**
```bash
melos run:rider
# or
cd packages/grab_go_rider && flutter run
```

**Restaurant Web App:**
```bash
melos run:restaurant
# or
cd packages/grab_go_restaurant && flutter run -d chrome
```

**Admin Web App:**
```bash
melos run:admin
# or
cd packages/grab_go_admin && flutter run -d chrome
```

### Common Commands

```bash
# Run tests
melos test

# Analyze code
melos analyze

# Format code
melos format

# Clean all packages
melos clean

# Build all packages
melos build:android  # or build:ios
```

---

## 📁 Project Structure (Feature-based)

Each app follows a **feature-based architecture using the MVVM pattern**:

```
lib/
├── core/           # Core functionality (API, services)
├── features/       # Feature modules
│   ├── auth/      # Authentication
│   ├── home/      # Home/dashboard
│   ├── orders/    # Order management
│   └── ...
├── shared/         # App-specific shared code
│   ├── widgets/   # Reusable widgets
│   ├── utils/     # Utilities
│   ├── models/    # Models
│   └── services/  # Services
└── main.dart      # Entry point
```

Each feature typically contains:
- `view/` - UI screens
- `viewmodel/` - State management (Providers)
- `model/` - Data models
- `service/` - API services
- `repository/` - Data repositories

---

## 🔑 Key Features Overview

### Customer App
- ✅ Multi-authentication methods (Phone, Email, Google)
- ✅ Restaurant discovery and search
- ✅ Menu browsing with categories
- ✅ Shopping cart with persistence
- ✅ Secure payment processing (Paystack)
- ✅ Real-time order tracking with maps
- ✅ Order history and favorites
- ✅ Profile management

### Rider App
- ✅ Rider registration and verification
- ✅ Order acceptance and management
- ✅ GPS-based delivery tracking
- ✅ Earnings tracking and wallet
- ✅ Performance metrics
- ✅ Chat functionality
- ✅ Document management

### Restaurant Panel
- ✅ Dashboard with analytics
- ✅ Menu management
- ✅ Order processing
- ✅ Restaurant settings

### Admin Dashboard
- ✅ Platform-wide analytics
- ✅ Restaurant management
- ✅ Order oversight
- ✅ Payment tracking

---

## 🔐 Authentication & Security

- **Firebase Authentication**: Phone, Email, Google Sign-In
- **Firebase App Check**: App integrity verification
- **Token Management**: Secure token storage and refresh
- **Payment Security**: Paystack integration for secure payments

---

## 🎨 Design System

- **Theme Support**: Light and dark themes
- **Custom Fonts**: Lato (primary), Lobster (accent)
- **Responsive Design**: ScreenUtil for multi-screen support
- **Shared Assets**: Centralized in `grab_go_shared`
- **Icons**: Custom app icons for each platform

---

## 📱 Platform Support

- **Customer App**: Android & iOS
- **Rider App**: Android & iOS
- **Restaurant Panel**: Web (Chrome, Firefox, Safari, Edge)
- **Admin Dashboard**: Web (Chrome, Firefox, Safari, Edge)

---

## 🔄 Development Workflow

1. **Code Changes**: Make changes in respective package
2. **Shared Code**: Update `grab_go_shared` for common changes
3. **Testing**: Run `melos test` to test all packages
4. **Code Quality**: Run `melos analyze` and `melos format`
5. **Build**: Use Melos scripts for platform-specific builds

---

## 📝 Notes for New Developers

1. **Start with `grab_go_shared`**: Understand shared components first
2. **Feature-based Structure**: Each feature is self-contained
3. **State Management**: Provider pattern is used throughout
4. **Code Generation**: Run `flutter pub run build_runner build` after model changes
5. **API Services**: Chopper generates type-safe API clients
6. **Assets**: All assets are in `grab_go_shared/lib/assets/`

---

## 🚧 Current Status

The project appears to be in active development with:
- Core features implemented across all platforms
- Authentication flows complete
- Order management system in place
- Payment integration ready
- Admin and restaurant dashboards functional

---

## 📞 Getting Help

- Check the main `README.md` for workspace setup
- Review individual package `README.md` files
- Use Melos scripts for common tasks
- Check `analysis_options.yaml` for linting rules

---

**Welcome to the GrabGo team! 🚀**

