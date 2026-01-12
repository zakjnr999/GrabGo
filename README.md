# GrabGo - Multi-Service Delivery Platform

> A comprehensive multi-service delivery platform built with Flutter and Node.js, featuring food delivery, grocery shopping, and ride-hailing services across multiple client applications with a robust backend API.

![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS%20%7C%20Web-blue)
![Flutter](https://img.shields.io/badge/Flutter-3.10+-02569B?logo=flutter)
![Backend](https://img.shields.io/badge/Backend-Node.js%20%7C%20Express-green)
![Database](https://img.shields.io/badge/Database-MongoDB-brightgreen)
![License](https://img.shields.io/badge/License-Proprietary-red)

## Features

### Multi-Service Platform

- **Food Delivery** - Browse restaurants, order meals, track deliveries in real-time
- **Grocery Shopping** - Shop for groceries from local stores with quick delivery
- **Ride-Hailing** - Request rides with real-time driver tracking (coming soon)

### Customer App (Mobile)

- Multi-service browsing with category-based navigation
- Advanced search and filtering capabilities
- Real-time order tracking with live location updates
- In-app chat with riders (text, voice messages, images)
- Multiple payment methods (Cash on Delivery, MTN Mobile Money)
- Restaurant promotional stories (Instagram-style)
- Favorites and order history
- Location-based service discovery
- Push notifications for order updates

### Restaurant/Vendor Panel (Web)

- Comprehensive menu management
- Real-time order processing
- Promotional stories creation
- Sales analytics and reporting
- Inventory management
- Customer reviews and ratings

### Rider App (Mobile)

- Real-time delivery assignment notifications
- Turn-by-turn navigation integration
- Multi-order batch delivery support
- Earnings tracking and history
- In-app chat with customers
- Delivery status updates
- Performance metrics dashboard

### Admin Dashboard (Web)

- Platform-wide analytics and insights
- User and vendor management
- Order monitoring and dispute resolution
- Revenue tracking and financial reports
- System configuration and settings
- Promotional campaign management

## Project Structure

```
GrabGo/
├── backend/                      # Node.js Express API Server
│   ├── models/                   # Mongoose database schemas
│   ├── routes/                   # RESTful API endpoints
│   ├── services/                 # Business logic layer
│   │   ├── fcm.service.js       # Firebase Cloud Messaging
│   │   ├── momo.service.js      # MTN Mobile Money integration
│   │   └── socket.service.js    # Real-time communication
│   ├── middleware/               # Express middleware
│   │   ├── auth.js              # JWT authentication
│   │   ├── upload.js            # File upload handling
│   │   └── validator.js         # Input validation
│   ├── tests/                    # Jest unit & integration tests
│   ├── scripts/                  # Database seeding & utilities
│   └── docs/                     # API documentation
│
├── packages/                     # Flutter Monorepo (Melos)
│   ├── grab_go_customer/         # Customer mobile application
│   │   ├── lib/
│   │   │   ├── features/        # Feature-based modules
│   │   │   ├── shared/          # Shared widgets & utilities
│   │   │   └── core/            # Core app configuration
│   │   └── assets/              # App-specific assets
│   │
│   ├── grab_go_rider/            # Rider mobile application
│   │   ├── lib/
│   │   │   ├── features/        # Delivery management features
│   │   │   └── shared/          # Shared components
│   │   └── assets/
│   │
│   ├── grab_go_restaurant/       # Restaurant web panel
│   │   └── lib/
│   │       ├── features/        # Restaurant management
│   │       └── shared/
│   │
│   ├── grab_go_admin/            # Admin web dashboard
│   │   └── lib/
│   │       ├── features/        # Platform administration
│   │       └── shared/
│   │
│   └── grab_go_shared/           # Shared package library
│       ├── lib/
│       │   ├── models/          # Common data models
│       │   ├── services/        # Shared services (API, Socket, Cache)
│       │   ├── widgets/         # Reusable UI components
│       │   ├── utils/           # Helper functions
│       │   └── assets/          # Shared assets (fonts, icons)
│       └── test/                # Shared package tests
│
├── docs/                         # Project documentation
│   ├── README.md                # Developer documentation
│   ├── SECURITY.md              # Security guidelines
│   └── SECURE_STORAGE.md        # Secure storage best practices
│
├── melos.yaml                    # Monorepo configuration
├── pubspec.yaml                  # Workspace dependencies
└── .env.local                    # Environment configuration
```

## Tech Stack

### Backend

- **Runtime**: Node.js (v18+)
- **Framework**: Express.js
- **Database**: MongoDB with Mongoose ODM
- **Caching**: Redis (production) / node-cache (development)
- **Real-time Communication**: Socket.IO
- **Authentication**: JWT (JSON Web Tokens)
- **Password Hashing**: bcrypt
- **File Storage**: Cloudinary CDN
- **Image Processing**: Sharp, Blurhash
- **Push Notifications**: Firebase Cloud Messaging (FCM)
- **Email**: SendGrid / Nodemailer
- **SMS**: Twilio
- **Payment Gateway**: MTN Mobile Money API
- **API Documentation**: Swagger / OpenAPI
- **Testing**: Jest, Supertest
- **Security**: Helmet, CORS, express-rate-limit, express-validator

### Frontend (Flutter)

- **Framework**: Flutter 3.10+ / Dart 3.10+
- **State Management**: Provider
- **HTTP Client**: Chopper (with code generation)
- **Navigation**: GoRouter
- **Local Storage**: SharedPreferences (non-sensitive), flutter_secure_storage (sensitive)
- **Dependency Injection**: GetIt
- **Image Handling**: cached_network_image, flutter_blurhash
- **Real-time**: Socket.IO Client
- **Maps & Location**: Geolocator, Geocoding, Google Places
- **Payments**: MTN Mobile Money, Paystack
- **Media**: image_picker, photo_view
- **Audio**: record, audioplayers
- **UI Components**:
  - flutter_screenutil (responsive design)
  - shimmer (loading states)
  - animations (page transitions)
  - flutter_staggered_grid_view
  - emoji_picker_flutter
- **Code Generation**: build_runner, json_serializable
- **Testing**: flutter_test, flutter_lints

### DevOps & Tools

- **Monorepo Management**: Melos
- **Version Control**: Git
- **CI/CD**: GitHub Actions (planned)
- **Code Quality**: ESLint (backend), flutter_lints (frontend)

### External Services

- **Payment Processing**: MTN Mobile Money (Ghana)
- **Push Notifications**: Firebase Cloud Messaging
- **Media CDN**: Cloudinary
- **Email Service**: SendGrid
- **SMS Service**: Twilio
- **Maps**: Google Maps API

## Quick Start

### Prerequisites

- **Flutter SDK**: 3.10 or higher
- **Dart SDK**: 3.10 or higher
- **Node.js**: 18.x or higher
- **MongoDB**: 6.0 or higher
- **Redis**: 7.0 or higher (for production)
- **Melos**: Install globally with `dart pub global activate melos`

## Application Features

### Customer App Highlights

- **Service Categories**: Food, Groceries, Rides (expandable)
- **Smart Search**: Search across restaurants, items, and categories
- **Advanced Filters**: Price range, ratings, delivery time, dietary preferences
- **Cart Management**: Multi-restaurant orders with smart grouping
- **Order Tracking**: Real-time GPS tracking with ETA updates
- **Chat System**: Rich messaging with text, voice notes, and images
- **Payment Options**: Cash on Delivery, MTN Mobile Money, Paystack
- **Stories**: View promotional content from restaurants
- **Favorites**: Save favorite restaurants and items
- **Order History**: Reorder with one tap
- **Ratings & Reviews**: Rate orders and provide feedback

### Restaurant/Vendor Features

- **Menu Builder**: Create and organize menu items with categories
- **Order Management**: Accept, prepare, and complete orders
- **Story Creator**: Upload promotional images and videos
- **Analytics Dashboard**: Sales trends, popular items, customer insights
- **Inventory Tracking**: Stock management and low-stock alerts
- **Promotional Tools**: Discounts, coupons, and special offers

### Rider Features

- **Delivery Queue**: View and accept available deliveries
- **Navigation**: Integrated maps with optimal routing
- **Batch Deliveries**: Handle multiple orders efficiently
- **Earnings Tracker**: Daily, weekly, and monthly earnings
- **Performance Metrics**: Delivery time, ratings, completion rate
- **Customer Communication**: In-app chat for delivery coordination

### Admin Features

- **Dashboard**: Platform overview with key metrics
- **User Management**: Manage customers, riders, and vendors
- **Order Oversight**: Monitor all platform orders
- **Financial Reports**: Revenue, commissions, and payouts
- **Dispute Resolution**: Handle customer complaints and issues
- **System Configuration**: Platform settings and parameters

## Architecture

### Backend Architecture

- **RESTful API**: Stateless API design with JWT authentication
- **Microservices-Ready**: Modular service layer for easy scaling
- **Real-time Layer**: Socket.IO for live updates and chat
- **Caching Strategy**: Redis for session management and frequent queries
- **File Upload**: Cloudinary integration with image optimization
- **Security**: Multi-layer security with rate limiting and validation

### Frontend Architecture

- **Feature-First Structure**: Organized by business features
- **Shared Package**: Common code reused across all apps
- **Provider Pattern**: Reactive state management
- **Repository Pattern**: Clean separation of data layer
- **Service Layer**: API, Socket, Cache, and Storage services
- **Responsive Design**: Adaptive UI for different screen sizes

### Data Flow

```
User Action → Provider → Service → API/Socket → Backend
                ↓                                    ↓
            UI Update ← Provider ← Response ← Database
```

## Security

### Authentication & Authorization

- JWT-based authentication with refresh tokens
- Role-based access control (Customer, Rider, Restaurant, Admin)
- Secure password hashing with bcrypt
- Token expiration and rotation

### Data Protection

- **Sensitive Data**: Encrypted storage using flutter_secure_storage
- **Non-Sensitive Data**: SharedPreferences for app preferences
- **API Communication**: HTTPS only in production
- **Input Validation**: Server-side validation with express-validator
- **SQL Injection Prevention**: MongoDB parameterized queries

### Security Best Practices

- Rate limiting on authentication endpoints
- CORS configuration for allowed origins
- Helmet.js for HTTP header security
- Sanitization of user-generated content
- Secure file upload validation```

## Known Issues & Roadmap

### Current Limitations

- Ride-hailing service is under development
- Live Order tracking system still under progress
- Admin dashboard has limited analytics features

### Upcoming Features

- [ ] Ride-hailing service integration
- [ ] Multi-language support
- [ ] Advanced analytics dashboard
- [ ] Loyalty program and rewards
- [ ] Subscription-based delivery passes
- [ ] AI-powered restaurant recommendations

## License

**Proprietary License** - All rights reserved.

This software is proprietary and confidential. Unauthorized copying, distribution, or use of this software, via any medium, is strictly prohibited.

## Team & Support

### Development Team

- **Project Lead**: Muktar Zakari Junior
- **Backend Developer**: Muktar Zakari Junior & Emmanuel Doe
- **Mobile Developer**: Muktar Zakari Junior
- **UI/UX Designer**: Muktar Zakari Junior

### Contact & Support

- **Email**: support@grabgo.com
- **Developer Email**: zakjnr165@gmail.com
- **Website**: https://grabgo.com (comming soon)
- **Issue Tracker**: GitHub Issues
