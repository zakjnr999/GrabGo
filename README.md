# GrabGo - Food Delivery Platform

A comprehensive food delivery platform built with Flutter and Node.js, featuring multiple client applications and a robust backend API.

![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS%20%7C%20Web-blue)
![Backend](https://img.shields.io/badge/Backend-Node.js%20%7C%20Express-green)
![Database](https://img.shields.io/badge/Database-MongoDB-brightgreen)

## 🚀 Features

- **Customer App** - Browse restaurants, order food, track deliveries, chat with riders
- **Restaurant App** - Manage menu, process orders, create promotional stories
- **Rider App** - Accept deliveries, update status, communicate with customers
- **Admin Dashboard** - Platform management, analytics, user administration
- **Real-time Chat** - Text, voice, and image messaging between customers and riders
- **Mobile Payments** - MTN Mobile Money integration (Ghana)
- **Status/Stories** - Instagram-like stories for restaurant promotions

## 📁 Project Structure

```
GrabGo/
├── backend/                 # Node.js Express API
│   ├── models/              # Mongoose schemas
│   ├── routes/              # API endpoints
│   ├── services/            # Business logic (FCM, MOMO)
│   ├── middleware/          # Auth, upload handlers
│   ├── tests/               # Jest unit tests
│   └── docs/                # API documentation
│
├── packages/                # Flutter apps (Melos monorepo)
│   ├── grab_go_customer/    # Customer mobile app
│   ├── grab_go_rider/       # Rider mobile app
│   ├── grab_go_restaurant/  # Restaurant management
│   ├── grab_go_admin/       # Admin dashboard
│   └── grab_go_shared/      # Shared code library
│
├── melos.yaml               # Monorepo configuration
└── pubspec.yaml             # Workspace configuration
```

## 🛠️ Tech Stack

### Backend
- **Runtime**: Node.js
- **Framework**: Express.js
- **Database**: MongoDB with Mongoose
- **Caching**: Redis (production) / In-memory (development)
- **Real-time**: Socket.IO
- **Authentication**: JWT
- **File Storage**: Cloudinary
- **Push Notifications**: Firebase Cloud Messaging

### Frontend
- **Framework**: Flutter
- **State Management**: Provider
- **HTTP Client**: Chopper (code generation)
- **Navigation**: GoRouter
- **Local Storage**: SharedPreferences

### External Services
- MTN Mobile Money (Payments)
- Firebase (Push Notifications)
- Cloudinary (Media CDN)
- SendGrid/Nodemailer (Email)
- Twilio (SMS)

## 🚀 Quick Start

### Backend
```bash
cd backend
npm install
cp .env.example .env  # Configure environment variables
npm run dev
```

### Customer App
```bash
cd packages/grab_go_customer
flutter pub get
flutter run
```

### Run All Apps (Melos)
```bash
melos bootstrap
melos run build_runner  # Generate code
```

## 🧪 Testing

### Backend
```bash
cd backend
npm test                 # Run all tests
npm run test:coverage    # With coverage report
```

### Flutter
```bash
flutter analyze          # Static analysis
flutter test             # Unit tests
```

## 📱 Apps Overview

### Customer App
- Browse restaurants and menus
- Add items to cart and place orders
- Multiple payment options (Cash, MTN MOMO)
- Real-time order tracking
- Chat with delivery riders
- View restaurant stories/promotions
- Save favorites

### Restaurant Panel
- Manage restaurant profile
- Add/edit menu items
- Process incoming orders
- Create promotional stories
- View analytics

### Rider App
- Register and verify identity
- Accept delivery assignments
- Update delivery status
- Chat with customers
- Track earnings

### Admin Panel
- User management
- Restaurant approvals
- Order monitoring
- Platform analytics

## 🔐 Security

- JWT authentication with role-based access
- bcrypt password hashing
- Rate limiting on sensitive endpoints
- Input validation with express-validator
- CORS and Helmet security headers

## 📝 API Endpoints

See [Quick Reference](docs/QUICK_REFERENCE.pdf) for endpoint summary or check individual route files in `backend/routes/`.

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run tests
5. Submit a pull request

## 📄 License

Proprietary - All rights reserved

---

**GrabGo** - Delivering happiness, one meal at a time 🍔
