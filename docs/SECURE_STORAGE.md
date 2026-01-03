# Secure Storage Guide

## Overview

GrabGo uses **Flutter Secure Storage** to protect sensitive user data with platform-specific encryption:
- **iOS**: Keychain with `first_unlock` accessibility
- **Android**: KeyStore with AES encryption + encrypted SharedPreferences

## What's Stored Securely

### Sensitive Data (Encrypted)
- ✅ Authentication tokens
- ✅ Token expiry timestamps
- ✅ User passwords (when "Remember Me" is enabled)
- ✅ User email addresses (when "Remember Me" is enabled)

### Non-Sensitive Data (SharedPreferences)
- Cart items
- UI preferences
- Restaurant data cache
- Theme settings

---

## Usage Guide

### 1. Basic Operations

#### Saving Auth Token
```dart
import 'package:grab_go_shared/shared/services/secure_storage_service.dart';

// Save token with expiry
await SecureStorageService.saveAuthToken(
  token,
  expiryMillis: DateTime.now().add(Duration(days: 7)).millisecondsSinceEpoch,
);
```

#### Retrieving Auth Token
```dart
// Get token (returns null if expired or not found)
final token = await SecureStorageService.getAuthToken();

if (token != null) {
  // Token is valid and not expired
  print('Token: $token');
}
```

#### Checking Authentication Status
```dart
// Check if user is authenticated
final isAuthenticated = await SecureStorageService.isAuthenticated();

if (isAuthenticated) {
  // User has valid, non-expired token
}
```

#### Clearing Auth Token
```dart
// Logout - clear token
await SecureStorageService.clearAuthToken();
```

---

### 2. Credential Management

#### Saving Credentials (Remember Me)
```dart
await SecureStorageService.saveCredentials(
  email: 'user@example.com',
  password: 'securePassword123',
  rememberMe: true,
);
```

#### Retrieving Credentials
```dart
final credentials = await SecureStorageService.getCredentials();

if (credentials['rememberMe'] == true) {
  final email = credentials['email'];
  final password = credentials['password'];
  // Auto-fill login form
}
```

#### Clearing Credentials
```dart
// Clear saved credentials
await SecureStorageService.clearCredentials();
```

---

### 3. Complete Logout

```dart
// Clear all secure data (tokens + credentials)
await SecureStorageService.clearAll();
```

---

## CacheService Integration

For backward compatibility, `CacheService` delegates to `SecureStorageService`:

```dart
import 'package:grab_go_shared/grub_go_shared.dart';

// These methods now use secure storage internally
await CacheService.saveAuthToken(token);
final token = await CacheService.getAuthToken();
await CacheService.clearAuthToken();

await CacheService.saveCredentials(
  email: email,
  password: password,
  rememberMe: true,
);
final credentials = await CacheService.getCredentials();
await CacheService.clearCredentials();
```

**Note**: All these methods are now **async** and must be awaited!

---

## Initialization

### Required Setup

Each app must initialize `SecureStorageService` on startup:

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize secure storage FIRST
  await SecureStorageService.initialize();
  
  // Then other services
  await CacheService.initialize();
  
  runApp(MyApp());
}
```

### Initialization Order (Critical!)
1. ✅ `SecureStorageService.initialize()` - **FIRST**
2. ✅ `CacheService.initialize()` - After secure storage
3. ✅ Other services - After cache

---

## Migration

### Automatic Migration

On first launch after update, `SecureStorageService` automatically:
1. Checks if migration is needed
2. Reads sensitive data from SharedPreferences
3. Writes to secure storage with encryption
4. Removes data from SharedPreferences
5. Sets migration complete flag

**User Impact**: None - users stay logged in, credentials preserved.

### Migration Keys
The following keys are migrated:
- `auth_token`
- `token_expiry`
- `saved_email`
- `saved_password`
- `remember_me`

---

## Error Handling

### Handling Errors

```dart
try {
  await SecureStorageService.saveAuthToken(token);
} catch (e) {
  // Handle error - secure storage might be unavailable
  print('Failed to save token: $e');
  // Fallback: use in-memory storage or prompt re-login
}
```

### Common Errors
- **iOS**: Keychain access denied (rare, usually permissions)
- **Android**: KeyStore unavailable (device-specific)
- **Both**: Storage corrupted (auto-resets on next init)

---

## Best Practices

### ✅ DO
- Always `await` secure storage calls
- Initialize on app startup
- Handle errors gracefully
- Clear tokens on logout
- Use `isAuthenticated()` to check token validity

### ❌ DON'T
- Store non-sensitive data in secure storage (performance overhead)
- Forget to await async calls
- Skip initialization
- Store tokens in SharedPreferences directly
- Hardcode sensitive data

---

## Debugging

### Check Storage Contents

```dart
// Debug mode only - shows what's stored
final debugInfo = await SecureStorageService.getDebugInfo();
print(debugInfo);
```

**Output**:
```
Secure Storage Debug Info:
- Has auth token: true
- Token expiry: 2024-12-17 16:00:00.000
- Is authenticated: true
- Has saved credentials: true
- Remember me: true
```

### Verify Migration

Check logs on first launch after update:
```
🔄 Starting migration from SharedPreferences...
✅ Migration completed successfully
```

---

## Platform-Specific Details

### iOS (Keychain)
- **Accessibility**: `first_unlock` - accessible after first device unlock
- **Synchronization**: Disabled (data stays on device)
- **Backup**: Excluded from iCloud backup

### Android (KeyStore)
- **Encryption**: AES with hardware-backed keys
- **Fallback**: Encrypted SharedPreferences if KeyStore unavailable
- **Backup**: Excluded from Android backup

---

## API Reference

### SecureStorageService Methods

| Method | Returns | Description |
|--------|---------|-------------|
| `initialize()` | `Future<void>` | Initialize and run migration |
| `saveAuthToken(token, expiryMillis)` | `Future<void>` | Save encrypted token |
| `getAuthToken()` | `Future<String?>` | Get token (null if expired) |
| `clearAuthToken()` | `Future<void>` | Remove token |
| `saveCredentials(email, password, rememberMe)` | `Future<void>` | Save encrypted credentials |
| `getCredentials()` | `Future<Map<String, dynamic>>` | Get credentials |
| `clearCredentials()` | `Future<void>` | Remove credentials |
| `clearAll()` | `Future<void>` | Clear all secure data |
| `isAuthenticated()` | `Future<bool>` | Check if token is valid |
| `getDebugInfo()` | `Future<String>` | Get debug information |

---

## Examples

### Complete Login Flow

```dart
Future<void> login(String email, String password, bool rememberMe) async {
  try {
    // Call login API
    final response = await authService.login(email, password);
    
    if (response.isSuccessful && response.body?.token != null) {
      final token = response.body!.token!;
      final expiryMillis = DateTime.now()
          .add(Duration(days: 7))
          .millisecondsSinceEpoch;
      
      // Save token securely
      await SecureStorageService.saveAuthToken(token, expiryMillis: expiryMillis);
      
      // Save credentials if remember me
      if (rememberMe) {
        await SecureStorageService.saveCredentials(
          email: email,
          password: password,
          rememberMe: true,
        );
      }
      
      // Navigate to home
      navigateToHome();
    }
  } catch (e) {
    showError('Login failed: $e');
  }
}
```

### Complete Logout Flow

```dart
Future<void> logout() async {
  try {
    // Clear all secure data
    await SecureStorageService.clearAll();
    
    // Clear other app data
    await CacheService.clearUserData();
    
    // Navigate to login
    navigateToLogin();
  } catch (e) {
    showError('Logout failed: $e');
  }
}
```

### Auto-Login with Saved Credentials

```dart
Future<void> checkAutoLogin() async {
  // Check if authenticated
  final isAuthenticated = await SecureStorageService.isAuthenticated();
  
  if (isAuthenticated) {
    // User has valid token, go to home
    navigateToHome();
    return;
  }
  
  // Check for saved credentials
  final credentials = await SecureStorageService.getCredentials();
  
  if (credentials['rememberMe'] == true) {
    final email = credentials['email'];
    final password = credentials['password'];
    
    if (email != null && password != null) {
      // Auto-login with saved credentials
      await login(email, password, true);
    }
  }
}
```

---

## Troubleshooting

### Issue: "Undefined name 'SecureStorageService'"
**Solution**: Add import:
```dart
import 'package:grab_go_shared/shared/services/secure_storage_service.dart';
```

### Issue: "The argument type 'Future<String?>' can't be assigned"
**Solution**: Add `await`:
```dart
// Wrong
final token = SecureStorageService.getAuthToken();

// Correct
final token = await SecureStorageService.getAuthToken();
```

### Issue: Migration not running
**Solution**: Ensure initialization is called:
```dart
await SecureStorageService.initialize();
```

### Issue: Token always null
**Solution**: Check if token is expired:
```dart
final debugInfo = await SecureStorageService.getDebugInfo();
print(debugInfo); // Check expiry time
```

---

## Security Considerations

### What's Protected
- ✅ Data encrypted at rest
- ✅ Hardware-backed encryption (when available)
- ✅ Protected from other apps
- ✅ Protected from device backup

### What's NOT Protected
- ❌ Data in memory (while app is running)
- ❌ Data during transmission (use HTTPS)
- ❌ Rooted/jailbroken devices (OS-level compromise)
- ❌ Physical device access with debugging enabled

### Recommendations
- Always use HTTPS for API calls
- Implement certificate pinning for production
- Use biometric authentication for sensitive operations
- Implement token refresh mechanism
- Monitor for suspicious activity

---

## Additional Resources

- [Flutter Secure Storage Package](https://pub.dev/packages/flutter_secure_storage)
- [iOS Keychain Documentation](https://developer.apple.com/documentation/security/keychain_services)
- [Android KeyStore Documentation](https://developer.android.com/training/articles/keystore)
- [OWASP Mobile Security](https://owasp.org/www-project-mobile-security/)

---

**Last Updated**: December 2024  
**Version**: 1.0.0
