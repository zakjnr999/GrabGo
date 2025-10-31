# GrabGo Restaurant Panel

Web-based restaurant management panel that enables restaurant owners to manage their menu, orders, analytics, and settings.

## Features

- 📊 **Dashboard**
  - Restaurant overview with key metrics
  - Revenue and order statistics
  - Real-time order updates

- 🍽️ **Menu Management**
  - Add, edit, and delete menu items
  - Category management
  - Item availability toggle
  - Image upload for dishes

- 📦 **Order Management**
  - View incoming orders
  - Accept/reject orders
  - Update order status
  - Order history

- 📈 **Analytics**
  - Sales analytics and reports
  - Order trends
  - Revenue charts

- ⚙️ **Settings**
  - Restaurant profile management
  - Operating hours configuration
  - Payment methods setup
  - Social media links

- 🔧 **Setup Wizard**
  - Initial restaurant setup
  - Business details configuration
  - Location and delivery settings

## Project Structure

```
lib/
├── features/          # Feature modules
│   ├── dashboard/    # Main dashboard screen
│   ├── menu/         # Menu management
│   ├── orders/       # Order management
│   ├── analytics/    # Analytics and reports
│   ├── settings/     # Restaurant settings
│   └── setup/        # Initial setup wizard
└── shared/           # Shared widgets, models, and utilities
```

## Running the App

```bash
# From root directory
melos run run:restaurant

# Or directly
cd packages/grab_go_restaurant
flutter run -d chrome
```

## Dependencies

- **grab_go_shared** - Shared components, assets, and utilities
- **provider** - State management
- **google_fonts** - Custom fonts
- **flutter_svg** - SVG icon support
- **fl_chart** - Charts and graphs
- **image_picker** - Image upload functionality
- **file_picker** - File selection

## Platform

This app runs on **web** (Chrome, Firefox, Safari, Edge).
