# GrabGo Developer Documentation

Welcome to the GrabGo developer documentation. This guide will help you understand the architecture, setup, and best practices for developing the GrabGo food delivery application.

## Table of Contents

1. [Getting Started](#getting-started)
2. [Architecture](#architecture)
3. [Security](#security)
4. [Development Guidelines](#development-guidelines)
5. [API Documentation](#api-documentation)

---

## Getting Started

### Prerequisites
- Flutter SDK (latest stable)
- Dart SDK (latest stable)
- Android Studio / Xcode
- Node.js (for backend)
- MongoDB

### Project Structure
```
GrabGo/
├── packages/
│   ├── grab_go_customer/    # Customer mobile app
│   ├── grab_go_rider/       # Rider mobile app
│   ├── grab_go_admin/       # Admin web panel
│   └── grab_go_shared/      # Shared code and utilities
├── backend/                 # Node.js backend
└── docs/                    # Documentation
```

### Setup Instructions

1. **Clone the repository**
   ```bash
   git clone https://github.com/yourorg/grabgo.git
   cd grabgo
   ```

2. **Install dependencies**
   ```bash
   # Flutter packages
   cd packages/grab_go_customer && flutter pub get
   cd ../grab_go_rider && flutter pub get
   cd ../grab_go_admin && flutter pub get
   cd ../grab_go_shared && flutter pub get
   
   # Backend
   cd ../../backend && npm install
   ```

3. **Configure environment**
   - Copy `.env.example` to `.env` in backend
   - Update API keys and configuration

4. **Run the app**
   ```bash
   # Customer app
   cd packages/grab_go_customer
   flutter run
   
   # Rider app
   cd packages/grab_go_rider
   flutter run
   
   # Backend
   cd backend
   npm start
   ```

---

## Architecture

### Multi-Package Structure

GrabGo uses a mono-repo structure with multiple packages:

- **grab_go_customer**: Customer-facing mobile app
- **grab_go_rider**: Rider-facing mobile app
- **grab_go_admin**: Admin web panel
- **grab_go_shared**: Shared utilities, models, and services

### Key Services

#### CacheService
Manages local data storage using SharedPreferences for non-sensitive data.

```dart
import 'package:grab_go_shared/grub_go_shared.dart';

// Save non-sensitive data
await CacheService.saveThemeMode(ThemeMode.dark);
final theme = CacheService.getThemeMode();
```

#### SecureStorageService
Manages encrypted storage for sensitive data (tokens, passwords).

```dart
import 'package:grab_go_shared/shared/services/secure_storage_service.dart';

// Save sensitive data
await SecureStorageService.saveAuthToken(token);
final token = await SecureStorageService.getAuthToken();
```

**📖 See [SECURE_STORAGE.md](./SECURE_STORAGE.md) for detailed usage**

#### SocketService
Manages real-time communication via WebSockets.

```dart
import 'package:grab_go_shared/grub_go_shared.dart';

// Initialize socket connection
await SocketService().initialize();

// Listen for messages
SocketService().addNewMessageListener((data) {
  print('New message: $data');
});
```

---

## Security

### Data Classification

**Critical Data (Encrypted Storage)**
- Authentication tokens
- User passwords
- Payment information

**Sensitive Data (Encrypted Storage)**
- Email addresses (with passwords)
- Phone numbers
- User addresses

**Non-Sensitive Data (SharedPreferences)**
- UI preferences
- Theme settings
- Cache data

### Best Practices

✅ **DO**
- Use `SecureStorageService` for sensitive data
- Always use HTTPS for API calls
- Validate and sanitize user input
- Implement proper error handling
- Clear sensitive data on logout

❌ **DON'T**
- Store passwords in SharedPreferences
- Log sensitive data to console
- Hardcode API keys or secrets
- Use HTTP for sensitive data
- Expose detailed error messages to users

**📖 See [SECURITY.md](./SECURITY.md) for comprehensive security guidelines**

---

## Development Guidelines

### Code Style

Follow the [Dart Style Guide](https://dart.dev/guides/language/effective-dart/style):

```dart
// ✅ Good
class UserService {
  Future<User?> getCurrentUser() async {
    final token = await SecureStorageService.getAuthToken();
    if (token == null) return null;
    return await _fetchUser(token);
  }
}

// ❌ Bad
class userservice {
  Future<User?> get_current_user() async {
    var token = await SecureStorageService.getAuthToken();
    if(token==null)return null;
    return await _fetchUser(token);
  }
}
```

### Naming Conventions

- **Classes**: PascalCase (`UserService`, `OrderProvider`)
- **Variables**: camelCase (`userName`, `isAuthenticated`)
- **Constants**: camelCase with const (`const apiBaseUrl`)
- **Files**: snake_case (`user_service.dart`, `order_provider.dart`)

### State Management

GrabGo uses **Provider** for state management:

```dart
// Define provider
class OrderProvider extends ChangeNotifier {
  List<Order> _orders = [];
  
  Future<void> fetchOrders() async {
    _orders = await orderService.getOrders();
    notifyListeners();
  }
}

// Use in widget
Consumer<OrderProvider>(
  builder: (context, orderProvider, child) {
    return ListView.builder(
      itemCount: orderProvider.orders.length,
      itemBuilder: (context, index) {
        return OrderCard(order: orderProvider.orders[index]);
      },
    );
  },
)
```

### Error Handling

```dart
// ✅ Proper error handling
try {
  await SecureStorageService.saveAuthToken(token);
} catch (e) {
  debugPrint('Error saving token: $e');
  showError('Failed to save login information');
}

// ❌ Poor error handling
await SecureStorageService.saveAuthToken(token); // No error handling
```

---

## API Documentation

### Authentication

#### Login
```dart
POST /api/users/login
Content-Type: application/json

{
  "email": "user@example.com",
  "password": "password123"
}

Response:
{
  "token": "eyJhbGciOiJIUzI1NiIs...",
  "userData": {
    "id": "123",
    "email": "user@example.com",
    "username": "John Doe"
  }
}
```

#### Register
```dart
POST /api/users
Content-Type: application/json

{
  "email": "user@example.com",
  "password": "password123",
  "username": "John Doe"
}
```

### Orders

#### Get Orders
```dart
GET /api/orders
Authorization: Bearer {token}

Response:
{
  "data": [
    {
      "id": "order123",
      "status": "pending",
      "totalAmount": 25.99,
      "items": [...]
    }
  ]
}
```

---

## Testing

### Unit Tests
```bash
# Run unit tests
flutter test

# Run with coverage
flutter test --coverage
```

### Integration Tests
```bash
# Run integration tests
flutter test integration_test/
```

### Manual Testing Checklist
- [ ] Login/Logout flow
- [ ] Order placement
- [ ] Payment processing
- [ ] Real-time chat
- [ ] Push notifications
- [ ] Offline functionality

---

## Deployment

### Android
```bash
# Build release APK
flutter build apk --release --obfuscate --split-debug-info=build/debug-info

# Build App Bundle
flutter build appbundle --release --obfuscate --split-debug-info=build/debug-info
```

### iOS
```bash
# Build release IPA
flutter build ios --release --obfuscate --split-debug-info=build/debug-info
```

---

## Additional Resources

- [Secure Storage Guide](./SECURE_STORAGE.md)
- [Security Best Practices](./SECURITY.md)
- [Flutter Documentation](https://flutter.dev/docs)
- [Dart Documentation](https://dart.dev/guides)

---

## Contributing

1. Create a feature branch
2. Make your changes
3. Write tests
4. Submit a pull request

---

## Support

For questions or issues:
- Email: dev@grabgo.com
- Slack: #grabgo-dev

---

**Last Updated**: December 2024
