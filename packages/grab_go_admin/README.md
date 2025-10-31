# GrabGo Admin Dashboard

Web-based admin dashboard for platform management, enabling administrators to manage restaurants, oversee orders, handle payments, and view platform analytics.

## Features

- 📊 **Dashboard**
  - Platform overview with key metrics
  - Revenue and order statistics
  - Real-time updates
  - Summary cards and charts

- 🏪 **Restaurant Management**
  - View all registered restaurants
  - Approve/reject restaurant applications
  - Suspend/activate restaurants
  - Restaurant details and analytics

- 📦 **Order Oversight**
  - View all platform orders
  - Monitor order status
  - Order analytics and trends

- 💳 **Payment Management**
  - Track payments across the platform
  - Payment analytics
  - Transaction history

- 📈 **Analytics & Reports**
  - Platform-wide analytics
  - Revenue reports
  - Order trends
  - Restaurant performance metrics

- ⚙️ **Settings**
  - System configuration
  - Admin preferences
  - Platform settings

## Project Structure

```
lib/
├── features/          # Feature modules
│   ├── dashboard/    # Main admin dashboard
│   ├── restaurants/  # Restaurant management
│   ├── orders/       # Order oversight
│   ├── payments/     # Payment management
│   ├── analytics/    # Analytics and reports
│   ├── settings/     # System settings
│   └── auth/         # Admin authentication
└── shared/           # Shared widgets, models, and utilities
```

## Running the App

```bash
# From root directory
melos run run:admin

# Or directly
cd packages/grab_go_admin
flutter run -d chrome
```

## Dependencies

- **grab_go_shared** - Shared components, assets, and utilities
- **provider** - State management
- **google_fonts** - Custom fonts
- **flutter_svg** - SVG icon support
- **fl_chart** - Charts and graphs

## Platform

This app runs on **web** (Chrome, Firefox, Safari, Edge).
