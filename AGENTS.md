# AGENTS.md

This file provides guidance to WARP (warp.dev) when working with code in this repository.

## Project Overview

GrabGo is a multi-service delivery platform (food, groceries, pharmacy, ride-hailing) with:
- **Backend**: Node.js/Express API with hybrid database (PostgreSQL via Prisma + MongoDB for NoSQL data)
- **Frontend**: Flutter monorepo managed with Melos containing multiple apps

## Build & Run Commands

### Prerequisites
```bash
# Install Melos globally
dart pub global activate melos

# Bootstrap the monorepo (run from root)
melos bootstrap
```

### Backend (Node.js)
```bash
cd backend

# Install dependencies
npm install

# Generate Prisma client (required before running)
npm run prisma:generate

# Development server with hot reload
npm run dev

# Production server
npm start
```

### Flutter Apps (via Melos from root)
```bash
# Run specific apps with environment config
melos run run:customer      # Customer mobile app (Android)
melos run run:rider         # Rider mobile app (Android)
melos run run:restaurant    # Restaurant web panel (Chrome)
melos run run:admin         # Admin dashboard (Chrome)

# Clean and rebuild
melos run clean:all         # Clean all packages and reinstall deps
melos run rebuild:customer  # Clean, rebuild and run customer app
```

### Linting & Analysis
```bash
# Flutter (all packages)
melos run analyze
melos run format
melos run lint

# Backend
npm run docs:lint  # Lint OpenAPI docs
```

### Testing
```bash
# Backend tests
cd backend
npm test                    # Run all tests
npm run test:watch          # Watch mode
npm run test:coverage       # With coverage
npm run test:status         # Single test file

# Flutter tests
melos run test              # All packages
```

### Code Generation (Flutter)
After modifying models or API services with annotations:
```bash
cd packages/<package_name>
dart run build_runner build --delete-conflicting-outputs
```

### Database Commands (Backend)
```bash
cd backend
npm run prisma:generate     # Generate Prisma client
npm run prisma:migrate      # Run migrations (dev)
npm run prisma:push         # Push schema to DB
npm run prisma:studio       # Open Prisma Studio GUI
```

## Architecture

### Backend Structure
- **Hybrid Database**: PostgreSQL (via Prisma) for relational data, MongoDB for NoSQL (statuses, chats, notifications, tracking)
- **Real-time**: Socket.IO for chat, presence, typing indicators, order tracking, WebRTC signaling for calls
- **`routes/`**: RESTful endpoints (auth, orders, restaurants, riders, payments, etc.)
- **`services/`**: Business logic layer (FCM, MTN MoMo payments, notifications, tracking)
- **`models/`**: MongoDB/Mongoose schemas for NoSQL collections
- **`prisma/schema.prisma`**: PostgreSQL schema definitions

### Flutter Monorepo Structure
```
packages/
├── grab_go_shared/    # Shared code used by ALL apps
│   ├── lib/core/      # API services (Chopper), auth, config
│   └── lib/shared/    # Services, utils, widgets
├── grab_go_customer/  # Customer mobile app
├── grab_go_rider/     # Rider mobile app
├── grab_go_restaurant/ # Restaurant web panel (not in workspace yet)
└── grab_go_admin/     # Admin web dashboard (not in workspace yet)
```

### Key Patterns
- **State Management**: Provider pattern across all Flutter apps
- **API Client**: Chopper with `JsonSerializableConverter` for type-safe HTTP requests
- **Navigation**: GoRouter
- **DI**: GetIt service locator
- **Feature-First**: Each app organizes code by business feature (`lib/features/`)

### Shared Package (`grab_go_shared`)
Common code reused across Flutter apps. Key exports in `lib/grub_go_shared.dart`:
- `AuthService`, `RiderService` - Authentication
- `SocketService` - Real-time communication
- `CacheService` - Local caching
- `PushNotificationService` - FCM integration
- `WebrtcService` - Video/voice calls
- Reusable widgets (buttons, dialogs, inputs)

### Environment Configuration
- Backend: `.env` file in `backend/`
- Flutter: `--dart-define-from-file=../../.env.local` (automatically applied by melos run commands)

### Real-time Communication Flow
1. Socket.IO connection authenticated via JWT
2. Users join rooms: `user:{userId}` for notifications, `chat:{chatId}` for messaging
3. Events: `chat:join`, `chat:typing`, `chat:mark_read`, `chat:presence`
4. WebRTC signaling for voice/video calls via `WebRTCSignalingService`

## Important Notes

- The root `pubspec.yaml` workspace only includes `grab_go_customer`, `grab_go_rider`, and `grab_go_shared`
- Restaurant and Admin apps exist but are not in the Dart workspace (managed separately via Melos)
- Backend uses JWT authentication stored in `JWT_SECRET` env variable
- Mobile apps target Android; web apps run in Chrome
