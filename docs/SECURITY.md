# Security Best Practices

## Overview
This document outlines security best practices for the GrabGo application, with a focus on data protection and secure storage.

---

## Data Storage Security

### Sensitive Data Classification

#### 🔴 Critical (Must be encrypted)
- Authentication tokens
- User passwords
- Payment information
- Personal identification numbers
- API keys

#### 🟡 Sensitive (Should be encrypted)
- Email addresses (when stored with passwords)
- Phone numbers
- User addresses
- Order history

#### 🟢 Non-Sensitive (Can use SharedPreferences)
- UI preferences
- Theme settings
- Language preferences
- Cache data
- Non-personal app state

---

## Secure Storage Implementation

### Using SecureStorageService

**For Critical Data:**
```dart
// ✅ CORRECT - Use SecureStorageService
await SecureStorageService.saveAuthToken(token);
await SecureStorageService.saveCredentials(email, password, rememberMe);
```

**For Non-Sensitive Data:**
```dart
// ✅ CORRECT - Use SharedPreferences via CacheService
await CacheService.saveThemeMode(themeMode);
await CacheService.saveLanguage(language);
```

**Never Do This:**
```dart
// ❌ WRONG - Never store sensitive data in plain text
final prefs = await SharedPreferences.getInstance();
await prefs.setString('password', password); // SECURITY VULNERABILITY!
```

---

## Authentication Security

### Token Management

#### Token Storage
```dart
// ✅ Store with expiry
await SecureStorageService.saveAuthToken(
  token,
  expiryMillis: DateTime.now().add(Duration(days: 7)).millisecondsSinceEpoch,
);
```

#### Token Validation
```dart
// ✅ Always check if authenticated before API calls
final isAuthenticated = await SecureStorageService.isAuthenticated();

if (!isAuthenticated) {
  // Redirect to login
  navigateToLogin();
  return;
}
```

#### Token Refresh
```dart
// ✅ Implement token refresh before expiry
if (await isTokenExpiringSoon()) {
  final newToken = await refreshToken();
  await SecureStorageService.saveAuthToken(newToken);
}
```

---

## Password Security

### Password Storage Rules

#### ✅ DO
- Store passwords encrypted using `SecureStorageService`
- Only store when "Remember Me" is explicitly enabled
- Clear passwords on logout
- Use secure password hashing on backend

#### ❌ DON'T
- Store passwords in SharedPreferences
- Store passwords in plain text files
- Log passwords to console
- Send passwords over HTTP (always use HTTPS)

### Example Implementation
```dart
// ✅ CORRECT
if (rememberMe) {
  await SecureStorageService.saveCredentials(
    email: email,
    password: password,
    rememberMe: true,
  );
}

// ❌ WRONG
if (rememberMe) {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('password', password); // NEVER DO THIS!
}
```

---

## Network Security

### HTTPS Only
```dart
// ✅ CORRECT - Always use HTTPS
const String apiBaseUrl = 'https://api.grabgo.com';

// ❌ WRONG - Never use HTTP for sensitive data
const String apiBaseUrl = 'http://api.grabgo.com'; // INSECURE!
```

### Certificate Pinning (Production)
```dart
// ✅ Implement for production
final client = HttpClient()
  ..badCertificateCallback = (cert, host, port) {
    // Validate certificate
    return validateCertificate(cert, host);
  };
```

### API Key Protection
```dart
// ✅ Store API keys in environment variables
const apiKey = String.fromEnvironment('API_KEY');

// ❌ NEVER hardcode API keys
const apiKey = 'sk_live_abc123...'; // SECURITY RISK!
```

---

## Input Validation

### Sanitize User Input
```dart
// ✅ Validate and sanitize
String sanitizeInput(String input) {
  return input
      .trim()
      .replaceAll(RegExp(r'[<>]'), '') // Remove HTML tags
      .substring(0, min(input.length, 255)); // Limit length
}
```

### Email Validation
```dart
// ✅ Use proper regex
bool isValidEmail(String email) {
  return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
}
```

### Password Requirements
```dart
// ✅ Enforce strong passwords
bool isStrongPassword(String password) {
  return password.length >= 8 &&
         RegExp(r'[A-Z]').hasMatch(password) &&
         RegExp(r'[a-z]').hasMatch(password) &&
         RegExp(r'[0-9]').hasMatch(password);
}
```

---

## Session Management

### Logout Security
```dart
// ✅ Complete logout - clear all sensitive data
Future<void> secureLogout() async {
  // Clear secure storage
  await SecureStorageService.clearAll();
  
  // Clear cache
  await CacheService.clearUserData();
  
  // Clear in-memory data
  UserService().clearCurrentUser();
  
  // Disconnect sockets
  SocketService().dispose();
  
  // Navigate to login
  navigateToLogin();
}
```

### Session Timeout
```dart
// ✅ Implement session timeout
class SessionManager {
  static const sessionTimeout = Duration(minutes: 30);
  DateTime? _lastActivity;
  
  void recordActivity() {
    _lastActivity = DateTime.now();
  }
  
  Future<void> checkSession() async {
    if (_lastActivity != null &&
        DateTime.now().difference(_lastActivity!) > sessionTimeout) {
      await secureLogout();
    }
  }
}
```

---

## Error Handling

### Secure Error Messages
```dart
// ✅ CORRECT - Generic error messages to users
try {
  await login(email, password);
} catch (e) {
  showError('Login failed. Please try again.');
  debugPrint('Login error: $e'); // Detailed logs only in debug
}

// ❌ WRONG - Exposing sensitive information
try {
  await login(email, password);
} catch (e) {
  showError('Error: $e'); // May expose sensitive data!
}
```

### Logging Security
```dart
// ✅ CORRECT - Sanitize logs
debugPrint('User logged in: ${email.replaceAll(RegExp(r'@.*'), '@***')}');

// ❌ WRONG - Logging sensitive data
debugPrint('Login: $email, $password'); // NEVER LOG PASSWORDS!
```

---

## Platform-Specific Security

### iOS Security
```dart
// ✅ Use Keychain for sensitive data
// Automatically handled by SecureStorageService

// ✅ Disable screenshots for sensitive screens
import 'package:flutter/services.dart';

void disableScreenshots() {
  // iOS: Set secure flag
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: []);
}
```

### Android Security
```dart
// ✅ Use KeyStore for encryption
// Automatically handled by SecureStorageService

// ✅ Detect rooted devices
Future<bool> isDeviceRooted() async {
  // Check for root indicators
  final rootPaths = ['/system/app/Superuser.apk', '/sbin/su'];
  for (final path in rootPaths) {
    if (await File(path).exists()) return true;
  }
  return false;
}
```

---

## Code Security

### Obfuscation (Production)
```bash
# ✅ Build with obfuscation
flutter build apk --obfuscate --split-debug-info=build/debug-info
flutter build ios --obfuscate --split-debug-info=build/debug-info
```

### ProGuard Rules (Android)
```proguard
# ✅ Protect sensitive classes
-keep class com.grabgo.** { *; }
-keepclassmembers class * {
    @com.grabgo.annotations.Sensitive *;
}
```

---

## Dependency Security

### Regular Updates
```bash
# ✅ Check for vulnerabilities
flutter pub outdated
flutter pub upgrade

# ✅ Audit dependencies
flutter pub deps
```

### Trusted Packages Only
```yaml
# ✅ Use well-maintained packages
dependencies:
  flutter_secure_storage: ^9.2.2  # ✅ Official, well-maintained
  
  # ❌ Avoid unknown/unmaintained packages
  # some_random_package: ^0.0.1  # ❌ Low version, unknown author
```

---

## Testing Security

### Security Testing Checklist
- [ ] Test with rooted/jailbroken devices
- [ ] Test with network interceptors (Charles Proxy)
- [ ] Test token expiry handling
- [ ] Test logout clears all data
- [ ] Test migration from old versions
- [ ] Test on different Android/iOS versions
- [ ] Penetration testing (production)

### Automated Security Scans
```bash
# ✅ Run security analysis
flutter analyze
dart analyze --fatal-infos

# ✅ Check for known vulnerabilities
flutter pub audit
```

---

## Compliance

### GDPR Compliance
- ✅ Implement data deletion on user request
- ✅ Provide data export functionality
- ✅ Clear consent for data collection
- ✅ Secure data storage and transmission

### Data Retention
```dart
// ✅ Implement data retention policies
Future<void> deleteUserData(String userId) async {
  // Delete from secure storage
  await SecureStorageService.clearAll();
  
  // Delete from cache
  await CacheService.clearAll();
  
  // Delete from backend
  await apiService.deleteUserAccount(userId);
}
```

---

## Security Incident Response

### If Security Breach Detected
1. **Immediate Actions**
   - Revoke all active tokens
   - Force password reset for affected users
   - Disable compromised features

2. **Investigation**
   - Identify breach scope
   - Review logs
   - Document timeline

3. **Remediation**
   - Patch vulnerabilities
   - Update security measures
   - Deploy hotfix

4. **Communication**
   - Notify affected users
   - Report to authorities (if required)
   - Update security documentation

---

## Security Checklist

### Before Production Release
- [ ] All sensitive data uses `SecureStorageService`
- [ ] No hardcoded secrets or API keys
- [ ] HTTPS enforced for all API calls
- [ ] Certificate pinning implemented
- [ ] Code obfuscation enabled
- [ ] Security testing completed
- [ ] Dependency audit passed
- [ ] Error messages sanitized
- [ ] Logging sanitized (no sensitive data)
- [ ] Session timeout implemented
- [ ] Proper logout implementation
- [ ] Input validation on all forms
- [ ] SQL injection prevention (if applicable)
- [ ] XSS prevention (if applicable)
- [ ] CSRF protection (if applicable)

---

## Resources

- [OWASP Mobile Security Project](https://owasp.org/www-project-mobile-security/)
- [Flutter Security Best Practices](https://flutter.dev/docs/deployment/security)
- [iOS Security Guide](https://support.apple.com/guide/security/welcome/web)
- [Android Security Best Practices](https://developer.android.com/topic/security/best-practices)

---

**Last Updated**: December 2024  
**Review Frequency**: Quarterly  
**Next Review**: March 2025
