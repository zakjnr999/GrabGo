# GrabGo Rider App

Delivery driver mobile application for Android and iOS that enables riders to accept orders, navigate to restaurants and customers, and track earnings.

## Features

- 🔐 **Authentication**
  - Rider login and registration
  - Profile management

- 📦 **Order Management**
  - View available delivery orders
  - Accept/reject orders
  - Track order status
  - Navigation to pickup and delivery locations

- 📍 **Location & Navigation**
  - Real-time location tracking
  - Route optimization
  - Delivery tracking

- 💰 **Earnings**
  - Track daily/weekly/monthly earnings
  - Payment history

## Project Structure

```
lib/
├── core/              # Core utilities and configurations
├── features/          # Feature modules
└── shared/           # Shared widgets and utilities
```

## Running the App

```bash
# From root directory
melos run run:rider

# Or directly
cd packages/grab_go_rider
flutter run
```

## Dependencies

- **grab_go_shared** - Shared components, assets, and utilities
- **provider** - State management
- **geolocator** - Location services
- **firebase_auth** - Authentication
