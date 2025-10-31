# GrabGo Monorepo

A Flutter monorepo for the GrabGo food delivery platform, featuring customer mobile app, rider app, restaurant web panel, and admin web dashboard.

## 📁 Project Structure

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

## 📁 Shared Assets & Components

All assets (images, icons, fonts) are centralized in `packages/grab_go_shared`.

## 📝 Packages

- **grab_go_customer** - Customer-facing mobile application for Android and iOS
- **grab_go_rider** - Delivery driver mobile application for Android and iOS
- **grab_go_restaurant** - Web-based restaurant management panel
- **grab_go_admin** - Web-based admin dashboard for platform management
- **grab_go_shared** - Shared package with common widgets, utilities, assets, and services
