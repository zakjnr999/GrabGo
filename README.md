# GrabGo - Multi-Service Delivery Platform

> A comprehensive multi-service delivery platform built with Flutter and Node.js, featuring food delivery, grocery shopping, pharmacy delivery, and ride-hailing services across multiple client applications with a robust backend API.

![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS%20%7C%20Web-blue)
![Flutter](https://img.shields.io/badge/Flutter-3.10+-02569B?logo=flutter)
![Backend](https://img.shields.io/badge/Backend-Node.js%20%7C%20Express-green)
![Database](https://img.shields.io/badge/Database-PostgreSQL%20%7C%20MongoDB-brightgreen)
![License](https://img.shields.io/badge/License-Proprietary-red)

## Features

### Multi-Service Platform

- **Food Delivery** - Browse restaurants, order meals, track deliveries in real-time
- **Grocery Shopping (GrabMart)** - Shop for groceries from local stores with quick delivery
- **Pharmacy Delivery** - Order medications and health products with prescription support
- **Ride-Hailing** - Request rides with real-time driver tracking (coming soon)

### Customer App (Mobile)

- Multi-service browsing with category-based navigation
- Advanced search and filtering capabilities
- Real-time order tracking with live GPS location updates and ETA
- In-app chat with riders (text, voice messages, images)
- Voice/Video calling with riders via WebRTC
- Multiple payment methods (Cash on Delivery, MTN Mobile Money)
- Restaurant promotional stories (Instagram-style with reactions & comments)
- Favorites management for restaurants, stores, pharmacies, and items
- Order history with one-tap reorder
- Location-based service discovery with address management
- Push notifications for order updates
- Smart nudges (meal-time reminders, cart abandonment, re-engagement)
- Referral program with credits and rewards
- Promo codes and discounts

### Restaurant/Vendor Panel (Web)

- Comprehensive menu management with categories
- Real-time order processing and status updates
- Promotional stories creation with media upload
- Sales analytics and reporting
- Inventory and stock management
- Customer reviews and ratings management
- Operating hours and availability settings

### Rider App (Mobile)

- Smart order dispatch with proximity-based assignment
- Real-time order reservation with countdown timer
- Turn-by-turn navigation integration
- Delivery window tracking with ETA management
- Delivery warnings (5-min soft warning before deadline)
- Delay reason submission for late deliveries (protects riders from unfair penalties)
- Earnings tracking (base fee, distance fee, tips)
- Performance metrics dashboard (on-time rate, completion rate)
- In-app chat with customers
- Voice/Video calling with customers via WebRTC
- Online/Offline status management with auto-offline detection
- Battery and location monitoring
- Loan application feature

### Admin Dashboard (Web)

- Platform-wide analytics and insights
- User, vendor, and rider management
- Rider verification and approval workflow
- Order monitoring and dispute resolution
- Revenue tracking and financial reports
- System configuration and settings
- Promotional campaign management
- Referral program management

## Project Structure

```
GrabGo/
├── backend/                      # Node.js Express API Server
│   ├── prisma/                   # PostgreSQL schema (Prisma ORM)
│   │   └── schema.prisma        # Database models & relations
│   ├── models/                   # MongoDB/Mongoose schemas (NoSQL data)
│   │   ├── Chat.js              # Chat conversations
│   │   ├── ChatMessage.js       # Chat messages
│   │   ├── DeliveryAnalytics.js # Rider performance metrics
│   │   ├── OrderReservation.js  # Order dispatch reservations
│   │   ├── RiderStatus.js       # Real-time rider status
│   │   ├── Status.js            # Instagram-style stories
│   │   └── Notification.js      # Push notification logs
│   ├── routes/                   # RESTful API endpoints
│   │   ├── auth.js              # Authentication & registration
│   │   ├── orders.js            # Order management
│   │   ├── riders.js            # Rider operations & dispatch
│   │   ├── restaurants.js       # Restaurant management
│   │   ├── groceries.js         # Grocery store operations
│   │   ├── pharmacies.js        # Pharmacy operations
│   │   ├── chats.js             # Real-time messaging
│   │   ├── payments.js          # Payment processing
│   │   ├── statuses.js          # Stories/status updates
│   │   ├── referrals.js         # Referral program
│   │   └── tracking_routes.js   # Order tracking
│   ├── services/                 # Business logic layer
│   │   ├── dispatch_service.js  # Smart rider dispatch algorithm
│   │   ├── tracking_service.js  # Real-time order tracking & ETA
│   │   ├── analytic_service.js  # Delivery analytics & metrics
│   │   ├── fcm_service.js       # Firebase Cloud Messaging
│   │   ├── mtn_momo_service.js  # MTN Mobile Money integration
│   │   ├── socket_service.js    # Real-time Socket.IO communication
│   │   ├── chat_service.js      # Chat & messaging logic
│   │   ├── referral_service.js  # Referral program logic
│   │   ├── promo_service.js     # Promotions & discounts
│   │   ├── notification_service.js # Push notification management
│   │   └── webrtcSignalingService.js # Voice/Video call signaling
│   ├── jobs/                     # Background cron jobs
│   │   ├── delivery_monitor.js  # Delivery window monitoring
│   │   ├── reservation_expiry.js # Order reservation timeout
│   │   ├── rider_auto_offline.js # Auto-offline inactive riders
│   │   ├── cart_abandonment.js  # Cart abandonment nudges
│   │   ├── meal_nudges.js       # Meal-time notifications
│   │   └── statusCleanup.js     # Expired stories cleanup
│   ├── middleware/               # Express middleware
│   ├── tests/                    # Jest unit & integration tests
│   ├── scripts/                  # Database seeding & utilities
│   └── docs/                     # OpenAPI documentation
│
├── packages/                     # Flutter Monorepo (Melos)
│   ├── grab_go_customer/         # Customer mobile application
│   │   └── lib/features/
│   │       ├── auth/            # Authentication & onboarding
│   │       ├── home/            # Home screen & discovery
│   │       ├── restaurant/      # Restaurant browsing & ordering
│   │       ├── groceries/       # Grocery shopping
│   │       ├── pharmacy/        # Pharmacy ordering
│   │       ├── grabmart/        # GrabMart marketplace
│   │       ├── cart/            # Shopping cart
│   │       ├── order/           # Order management & tracking
│   │       ├── chat/            # In-app messaging
│   │       ├── status/          # Stories viewing
│   │       ├── profile/         # User profile & settings
│   │       └── vendors/         # Vendor listings
│   │
│   ├── grab_go_rider/            # Rider mobile application
│   │   └── lib/features/
│   │       ├── auth/            # Rider authentication & verification
│   │       ├── home/            # Dashboard & online status
│   │       ├── orders/          # Order dispatch & delivery
│   │       ├── myorders/        # Order history
│   │       ├── chat/            # Customer communication
│   │       └── settings/        # Rider settings & profile
│   │
│   ├── grab_go_restaurant/       # Restaurant web panel
│   ├── grab_go_admin/            # Admin web dashboard
│   │
│   └── grab_go_shared/           # Shared package library
│       └── lib/
│           ├── core/            # API services (Chopper)
│           └── shared/
│               ├── services/    # Socket, Cache, Auth, WebRTC
│               ├── widgets/     # Reusable UI components
│               └── utils/       # Helper functions & extensions
│
├── melos.yaml                    # Monorepo configuration
├── pubspec.yaml                  # Workspace dependencies
├── AGENTS.md                     # AI agent guidance
└── .env.local                    # Environment configuration
```

## Tech Stack

### Backend

- **Runtime**: Node.js (v20+)
- **Framework**: Express.js
- **Database**:
  - PostgreSQL with Prisma ORM (relational data: users, orders, restaurants, products)
  - MongoDB with Mongoose (NoSQL data: chats, statuses, notifications, analytics)
- **Caching**: Redis (production) / node-cache (development)
- **Real-time Communication**: Socket.IO
- **Authentication**: JWT (JSON Web Tokens)
- **Password Hashing**: bcryptjs
- **File Storage**: Cloudinary CDN
- **Image Processing**: Sharp, Blurhash
- **Push Notifications**: Firebase Cloud Messaging (FCM)
- **Email**: SendGrid / Nodemailer
- **SMS**: Twilio
- **Payment Gateway**: MTN Mobile Money API
- **Maps & Geocoding**: Google Maps API, node-geocoder, geolib
- **Background Jobs**: node-cron
- **API Documentation**: Swagger / OpenAPI / Redocly
- **Testing**: Jest, Supertest
- **Security**: Helmet, CORS, express-rate-limit, express-validator, sanitize-html

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
- **Payments**: MTN Mobile Money
- **Media**: image_picker, photo_view
- **Audio**: record, audioplayers (voice messages)
- **Voice/Video Calls**: flutter_webrtc
- **UI Components**:
  - flutter_screenutil (responsive design)
  - shimmer (loading states)
  - animations (page transitions)
  - flutter_staggered_grid_view
  - emoji_picker_flutter
  - fluttertoast
- **Code Generation**: build_runner, json_serializable
- **Testing**: flutter_test, flutter_lints

### DevOps & Tools

- **Monorepo Management**: Melos
- **Version Control**: Git
- **Deployment**: Render (backend), Docker support
- **CI/CD**: GitHub Actions (planned)
- **Code Quality**: ESLint (backend), flutter_lints (frontend)

### External Services

- **Payment Processing**: MTN Mobile Money (Ghana)
- **Push Notifications**: Firebase Cloud Messaging
- **Media CDN**: Cloudinary
- **Email Service**: SendGrid / Nodemailer
- **SMS Service**: Twilio
- **Maps & Geocoding**: Google Maps API, Google Places API
- **WebRTC TURN Server**: Metered.ca (voice/video calls)

## Quick Start

### Prerequisites

- **Flutter SDK**: 3.10 or higher
- **Dart SDK**: 3.10 or higher
- **Node.js**: 20.x or higher
- **PostgreSQL**: 14.0 or higher
- **MongoDB**: 6.0 or higher
- **Redis**: 7.0 or higher (for production caching)
- **Melos**: Install globally with `dart pub global activate melos`

### Backend Setup

```bash
cd backend

# Install dependencies
npm install

# Set up environment variables
cp .env.example .env
# Edit .env with your database URLs, API keys, etc.

# Generate Prisma client
npm run prisma:generate

# Push schema to database (development)
npm run prisma:push

# Start development server
npm run dev

# Production
npm start
```

### Flutter Setup

```bash
# Install Melos globally
dart pub global activate melos

# Bootstrap the monorepo (from root)
melos bootstrap

# Run specific apps
melos run run:customer      # Customer mobile app (Android)
melos run run:rider         # Rider mobile app (Android)
melos run run:restaurant    # Restaurant web panel (Chrome)
melos run run:admin         # Admin dashboard (Chrome)

# Clean and rebuild
melos run clean:all         # Clean all packages
melos run rebuild:customer  # Clean, rebuild and run customer app
```

### Code Generation (after modifying models)

```bash
cd packages/<package_name>
dart run build_runner build --delete-conflicting-outputs
```

## Application Features

### Customer App Highlights

- **Service Categories**: Food, Groceries, Pharmacy (expandable)
- **Smart Search**: Search across restaurants, stores, items, and categories
- **Advanced Filters**: Price range, ratings, delivery time, dietary preferences
- **Cart Management**: Per-vendor carts with automatic grouping
- **Order Tracking**: Real-time GPS tracking with live ETA updates
- **Chat System**: Rich messaging with text, voice notes, images, and emoji reactions
- **Voice/Video Calls**: WebRTC-powered calls with riders
- **Payment Options**: Cash on Delivery, MTN Mobile Money
- **Stories**: Instagram-style promotional content with reactions and comments
- **Favorites**: Save favorite restaurants, stores, pharmacies, and items
- **Order History**: View past orders with one-tap reorder
- **Ratings & Reviews**: Rate orders and provide feedback
- **Referral Program**: Invite friends and earn credits
- **Smart Nudges**: Meal-time reminders, cart abandonment, re-engagement notifications
- **Promo Codes**: Apply discounts and promotional offers

### Restaurant/Vendor Features

- **Menu Builder**: Create and organize menu items with categories and modifiers
- **Order Management**: Accept, prepare, and complete orders with status updates
- **Story Creator**: Upload promotional images and videos (24-hour expiry)
- **Analytics Dashboard**: Sales trends, popular items, customer insights
- **Inventory Tracking**: Stock management and availability settings
- **Promotional Tools**: Discounts, promo codes, and special offers
- **Operating Hours**: Set business hours and availability

### Rider Features

- **Smart Dispatch**: Proximity-based order assignment with scoring algorithm
- **Order Reservation**: Accept/decline orders with countdown timer
- **Delivery Window**: ETA tracking with soft warnings (5 mins before deadline)
- **Delay Reasons**: Submit delay reasons for late deliveries (traffic, vendor delay, etc.)
- **Navigation**: Integrated maps with turn-by-turn directions
- **Earnings Breakdown**: Base fee, distance fee, tips, platform commission
- **Performance Metrics**: On-time rate, completion rate, ratings
- **Customer Communication**: In-app chat and voice/video calls
- **Online/Offline Status**: Toggle availability with auto-offline detection
- **Loan Application**: Request advance payments

### Admin Features

- **Dashboard**: Platform overview with key metrics
- **User Management**: Manage customers, riders, and vendors
- **Rider Verification**: Approve/reject rider applications with document review
- **Order Oversight**: Monitor all platform orders in real-time
- **Financial Reports**: Revenue, commissions, and payouts
- **Dispute Resolution**: Handle customer complaints and issues
- **Referral Management**: Configure referral rewards and track usage
- **System Configuration**: Platform settings and parameters

## Architecture

### Backend Architecture

- **Hybrid Database**: PostgreSQL (Prisma) for relational data + MongoDB for NoSQL data
- **RESTful API**: Stateless API design with JWT authentication
- **Microservices-Ready**: Modular service layer for easy scaling
- **Real-time Layer**: Socket.IO for live updates, chat, and order tracking
- **WebRTC Signaling**: Voice/video call coordination via Socket.IO
- **Caching Strategy**: Redis/node-cache for session management and frequent queries
- **Background Jobs**: node-cron for scheduled tasks (delivery monitoring, cleanup, nudges)
- **File Upload**: Cloudinary integration with image optimization and blurhash
- **Security**: Multi-layer security with rate limiting, input validation, and sanitization

### Frontend Architecture

- **Feature-First Structure**: Organized by business features
- **Shared Package**: Common code reused across all apps (grab_go_shared)
- **Provider Pattern**: Reactive state management
- **Service Layer**: API (Chopper), Socket, Cache, Auth, WebRTC services
- **Responsive Design**: flutter_screenutil for adaptive UI
- **Secure Storage**: flutter_secure_storage for sensitive data

### Real-time Communication Flow

```
┌─────────────────────────────────────────────────────────────┐
│                      Socket.IO Events                        │
├─────────────────────────────────────────────────────────────┤
│ Order Events:                                                │
│   • order_reserved → Rider receives new order offer          │
│   • reservation_cancelled → Order cancelled by customer      │
│   • reservation_expired → Timeout, reassign to next rider    │
│   • order_taken → Another rider accepted the order           │
│   • delivery_warning → 5 mins before delivery deadline       │
│   • delivery_late → Delivery past deadline                   │
│                                                              │
│ Chat Events:                                                 │
│   • chat:message → New message received                      │
│   • chat:typing → User is typing indicator                   │
│   • chat:presence → Online/offline status                    │
│                                                              │
│ Tracking Events:                                             │
│   • location_update → Rider GPS position                     │
│   • eta_update → Updated delivery ETA                        │
│   • status_update → Order status change                      │
│                                                              │
│ WebRTC Signaling:                                            │
│   • call:offer → Initiate voice/video call                   │
│   • call:answer → Accept incoming call                       │
│   • call:ice-candidate → ICE candidate exchange              │
│   • call:end → End call                                      │
└─────────────────────────────────────────────────────────────┘
```

### Rider Dispatch Algorithm

```
┌─────────────────────────────────────────────────────────────┐
│                   Smart Dispatch Flow                        │
├─────────────────────────────────────────────────────────────┤
│ 1. Order placed → Find available riders within radius        │
│ 2. Score each rider based on:                                │
│    • Distance to pickup (closer = higher score)              │
│    • On-time delivery rate (reliable = bonus)                │
│    • Current order load (fewer orders = higher score)        │
│    • Battery level (sufficient battery required)             │
│ 3. Send reservation to highest-scoring rider                 │
│ 4. Rider has 30 seconds to accept/decline                    │
│ 5. If declined/expired → Move to next rider                  │
│ 6. If accepted → Assign order, calculate ETA                 │
└─────────────────────────────────────────────────────────────┘
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
- Secure file upload validation

## API Endpoints

### Authentication

- `POST /api/auth/register` - User registration
- `POST /api/auth/login` - User login
- `POST /api/auth/verify-email` - Email verification
- `POST /api/auth/forgot-password` - Password reset request
- `POST /api/auth/rider/register` - Rider registration with documents

### Orders

- `POST /api/orders` - Create new order
- `GET /api/orders/:id` - Get order details
- `PUT /api/orders/:id/status` - Update order status
- `GET /api/orders/user/history` - User order history

### Riders

- `POST /api/riders/go-online` - Go online for deliveries
- `POST /api/riders/go-offline` - Go offline
- `POST /api/riders/accept-order/:orderId` - Accept order reservation
- `POST /api/riders/decline-order/:orderId` - Decline order reservation
- `POST /api/riders/orders/:orderId/delay-reason` - Submit delay reason
- `GET /api/riders/earnings` - Get earnings breakdown
- `GET /api/riders/analytics` - Get performance metrics

### Restaurants

- `GET /api/restaurants` - List restaurants
- `GET /api/restaurants/:id` - Restaurant details with menu
- `GET /api/restaurants/:id/foods` - Restaurant menu items

### Groceries & Pharmacy

- `GET /api/groceries/stores` - List grocery stores
- `GET /api/pharmacies/stores` - List pharmacies
- `GET /api/grabmart/items` - GrabMart items

### Chat & Communication

- `GET /api/chats/:orderId` - Get chat for order
- `POST /api/chats/:chatId/messages` - Send message
- `POST /api/calls/initiate` - Initiate voice/video call

### Payments

- `POST /api/payments/mtn-momo/initiate` - Initiate MTN MoMo payment
- `POST /api/payments/mtn-momo/callback` - Payment callback webhook

### Stories/Statuses

- `GET /api/statuses` - Get active stories
- `POST /api/statuses` - Create new story
- `POST /api/statuses/:id/reactions` - React to story

### Referrals

- `GET /api/referrals/code` - Get user's referral code
- `POST /api/referrals/apply` - Apply referral code

## Known Issues & Roadmap

### Current Limitations

- Ride-hailing service is under development
- Restaurant and Admin web panels are in progress
- Some analytics features are limited

### Upcoming Features

- [ ] Ride-hailing service integration
- [ ] Multi-language support (i18n)
- [ ] Advanced analytics dashboard
- [ ] Loyalty program and rewards
- [ ] Subscription-based delivery passes
- [ ] AI-powered restaurant recommendations
- [ ] In-app wallet and top-up
- [ ] Scheduled deliveries
- [ ] Group ordering

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
