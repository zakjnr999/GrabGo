# GrabGo - Multi-Service Delivery Platform

> A comprehensive multi-service delivery platform built with Flutter and Node.js, featuring food delivery, grocery shopping, and ride-hailing services across multiple client applications with a robust backend API.

![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS%20%7C%20Web-blue)
![Flutter](https://img.shields.io/badge/Flutter-3.10+-02569B?logo=flutter)
![Backend](https://img.shields.io/badge/Backend-Node.js%20%7C%20Express-green)
![Database](https://img.shields.io/badge/Database-MongoDB-brightgreen)
![License](https://img.shields.io/badge/License-Proprietary-red)

## ✨ Features

### 🛍️ Multi-Service Platform
- **Food Delivery** - Browse restaurants, order meals, track deliveries in real-time
- **Grocery Shopping** - Shop for groceries from local stores with quick delivery
- **Ride-Hailing** - Request rides with real-time driver tracking (coming soon)

### 📱 Customer App (Mobile)
- Multi-service browsing with category-based navigation
- Advanced search and filtering capabilities
- Real-time order tracking with live location updates
- In-app chat with riders (text, voice messages, images)
- Multiple payment methods (Cash on Delivery, MTN Mobile Money)
- Restaurant promotional stories (Instagram-style)
- Favorites and order history
- Location-based service discovery
- Push notifications for order updates

### 🏪 Restaurant/Vendor Panel (Web)
- Comprehensive menu management
- Real-time order processing
- Promotional stories creation
- Sales analytics and reporting
- Inventory management
- Customer reviews and ratings

### 🚴 Rider App (Mobile)
- Real-time delivery assignment notifications
- Turn-by-turn navigation integration
- Multi-order batch delivery support
- Earnings tracking and history
- In-app chat with customers
- Delivery status updates
- Performance metrics dashboard

### 👨‍💼 Admin Dashboard (Web)
- Platform-wide analytics and insights
- User and vendor management
- Order monitoring and dispute resolution
- Revenue tracking and financial reports
- System configuration and settings
- Promotional campaign management

## 📁 Project Structure

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

## 🛠️ Tech Stack

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

## 🚀 Quick Start

### Prerequisites
- **Flutter SDK**: 3.10 or higher
- **Dart SDK**: 3.10 or higher
- **Node.js**: 18.x or higher
- **MongoDB**: 6.0 or higher
- **Redis**: 7.0 or higher (for production)
- **Melos**: Install globally with `dart pub global activate melos`

### 1. Clone the Repository
```bash
git clone https://github.com/yourusername/GrabGo.git
cd GrabGo
```

### 2. Backend Setup
```bash
cd backend
npm install

# Configure environment variables
cp .env.example .env
# Edit .env with your configuration (MongoDB URI, API keys, etc.)

# Initialize database with sample data (optional)
npm run init-db
npm run setup-restaurants

# Start development server
npm run dev
```

The backend will run on `http://localhost:5000` (or your configured port).

### 3. Flutter Apps Setup

#### Using Melos (Recommended)
```bash
# Install all dependencies for all packages
melos bootstrap

# Generate code (Chopper, JSON serialization)
melos run build_runner

# Run specific app
melos run run:customer      # Customer app
melos run run:rider         # Rider app
melos run run:restaurant    # Restaurant panel (web)
melos run run:admin         # Admin dashboard (web)
```

#### Manual Setup (Individual Apps)
```bash
# Customer App
cd packages/grab_go_customer
flutter pub get
flutter run --dart-define-from-file=../../.env.local

# Rider App
cd packages/grab_go_rider
flutter pub get
flutter run --dart-define-from-file=../../.env.local
```

### 4. Environment Configuration
Create `.env.local` in the project root:
```env
API_BASE_URL=http://localhost:5000/api
SOCKET_URL=http://localhost:5000
CLOUDINARY_CLOUD_NAME=your_cloud_name
GOOGLE_MAPS_API_KEY=your_api_key
```

## 🧪 Testing

### Backend Tests
```bash
cd backend

# Run all tests
npm test

# Run tests in watch mode
npm run test:watch

# Generate coverage report
npm run test:coverage

# Run specific test suites
npm run test:status
npm run test:cache
npm run test:routes
```

### Flutter Tests
```bash
# Run tests for all packages
melos run test

# Run tests for specific package
cd packages/grab_go_customer
flutter test

# Run with coverage
flutter test --coverage

# Static analysis
melos run analyze
```

### Code Quality
```bash
# Format code
melos run format

# Lint code
melos run lint

# Clean all packages
melos run clean
```

## 📱 Application Features

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

## 🏗️ Architecture

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

## 🔐 Security

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
- Secure file upload validation

📖 **See [docs/SECURITY.md](docs/SECURITY.md) for comprehensive security guidelines**

## 📝 API Documentation

### Available Endpoints
- **Authentication**: `/api/auth/*` - Login, register, refresh token
- **Users**: `/api/users/*` - User profile management
- **Restaurants**: `/api/restaurants/*` - Restaurant listings and details
- **Foods**: `/api/foods/*` - Menu items and categories
- **Orders**: `/api/orders/*` - Order creation and management
- **Payments**: `/api/payments/*` - Payment processing
- **Chat**: `/api/chats/*` - Messaging system
- **Stories**: `/api/stories/*` - Promotional content
- **Riders**: `/api/riders/*` - Rider management

### API Documentation Tools
```bash
cd backend

# Build API documentation
npm run docs:build

# Validate OpenAPI spec
npm run docs:lint

# Serve documentation locally
npm run docs:serve
```

Access documentation at `http://localhost:8080`

## 🚢 Deployment

### Backend Deployment
```bash
cd backend

# Production build
npm install --production

# Start with PM2
pm2 start server.js --name grabgo-api

# Environment variables
# Set NODE_ENV=production
# Configure MongoDB URI, Redis URL, API keys
```

### Flutter Apps Deployment

#### Android (Customer & Rider Apps)
```bash
# Development build
melos run build:dev

# Production build
melos run build:prod

# Or manually
cd packages/grab_go_customer
flutter build apk --release --dart-define-from-file=../../.env.production
flutter build appbundle --release --dart-define-from-file=../../.env.production
```

#### iOS
```bash
cd packages/grab_go_customer
flutter build ios --release --dart-define-from-file=../../.env.production
```

#### Web (Restaurant & Admin)
```bash
cd packages/grab_go_restaurant
flutter build web --release --dart-define-from-file=../../.env.production

cd packages/grab_go_admin
flutter build web --release --dart-define-from-file=../../.env.production
```

## 📚 Additional Resources

### Documentation
- [Developer Guide](docs/README.md) - Comprehensive development documentation
- [Security Guidelines](docs/SECURITY.md) - Security best practices
- [Secure Storage Guide](docs/SECURE_STORAGE.md) - Data storage guidelines

### External Resources
- [Flutter Documentation](https://flutter.dev/docs)
- [Dart Language Guide](https://dart.dev/guides)
- [Express.js Guide](https://expressjs.com/)
- [MongoDB Documentation](https://docs.mongodb.com/)
- [Melos Documentation](https://melos.invertase.dev/)

## 🤝 Contributing

We welcome contributions! Please follow these steps:

1. **Fork the repository**
2. **Create a feature branch**: `git checkout -b feature/amazing-feature`
3. **Make your changes**
4. **Run tests**: `melos run test` and `npm test`
5. **Commit your changes**: `git commit -m 'Add amazing feature'`
6. **Push to branch**: `git push origin feature/amazing-feature`
7. **Open a Pull Request**

### Development Guidelines
- Follow the existing code style and conventions
- Write meaningful commit messages
- Add tests for new features
- Update documentation as needed
- Ensure all tests pass before submitting PR

## 🐛 Known Issues & Roadmap

### Current Limitations
- Ride-hailing service is under development
- iOS app pending App Store review
- Admin dashboard has limited analytics features

### Upcoming Features
- [ ] Ride-hailing service integration
- [ ] Multi-language support
- [ ] Dark mode for all apps
- [ ] Advanced analytics dashboard
- [ ] Loyalty program and rewards
- [ ] Subscription-based delivery passes
- [ ] AI-powered restaurant recommendations

## 📄 License

**Proprietary License** - All rights reserved.

This software is proprietary and confidential. Unauthorized copying, distribution, or use of this software, via any medium, is strictly prohibited.

## 👥 Team & Support

### Development Team
- **Project Lead**: [Your Name]
- **Backend Developer**: [Name]
- **Mobile Developer**: [Name]
- **UI/UX Designer**: [Name]

### Contact & Support
- **Email**: support@grabgo.com
- **Developer Email**: dev@grabgo.com
- **Website**: https://grabgo.com
- **Issue Tracker**: GitHub Issues

---

<div align="center">

**GrabGo** - Delivering happiness, one service at a time 🍔🛒🚗

Made with ❤️ using Flutter & Node.js

*Last Updated: January 2026*

</div>
