# GrabGo Customer App

Customer-facing mobile application for Android and iOS that enables users to browse restaurants, order food, and track deliveries.

## Features

- 🔐 **Authentication**
  - Email/Password registration and login
  - Google Sign-In
  - Phone number verification (OTP)
  - Email verification
  - Password reset

- 🍔 **Restaurant Features**
  - Browse restaurants with search functionality
  - View restaurant details and reviews
  - Restaurant registration for business owners

- 🛒 **Food Ordering**
  - Browse menu items and categories
  - Add items to cart
  - Checkout with Paystack payment integration
  - Real-time order tracking

- 👤 **Profile Management**
  - User profile with photo upload
  - Order history
  - Favorite restaurants
  - Payment methods management

- 🌓 **UI/UX**
  - Dark/Light theme support
  - Responsive design
  - Smooth animations and transitions

## Project Structure

```
lib/
├── core/              # Core utilities, API client, and configurations
├── features/          # Feature modules
│   ├── auth/         # Authentication screens and logic
│   ├── home/         # Home screen, food browsing, search
│   ├── restaurant/   # Restaurant browsing and details
│   ├── cart/         # Shopping cart and checkout
│   ├── order/        # Order tracking and history
│   └── profile/      # User profile management
└── shared/           # Shared widgets and utilities
```

## Running the App

```bash
# From root directory
melos run run:customer

# Or directly
cd packages/grab_go_customer
flutter run
```

## Dependencies

- **grab_go_shared** - Shared components, assets, and utilities
- **chopper** - HTTP client for API calls
- **provider** - State management
- **firebase_auth** - Authentication
- **paystack** - Payment processing
- **geolocator** - Location services

## Environment Variables

The app uses environment variables for configuration:
- `API_KEY` - API key for backend authentication
- `API_BASE_URL` - Base URL for API endpoints
- `PAYSTACK_PUBLIC_KEY` - Paystack public key for payments
