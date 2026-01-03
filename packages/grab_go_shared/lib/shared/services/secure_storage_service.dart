import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Secure storage service for sensitive data (tokens, passwords, credentials)
/// Uses platform-specific secure storage:
/// - iOS: Keychain
/// - Android: KeyStore (AES encryption)
class SecureStorageService {
  static final SecureStorageService _instance = SecureStorageService._internal();
  factory SecureStorageService() => _instance;
  SecureStorageService._internal();

  // Secure storage instance with platform-specific options
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true, resetOnError: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  // Storage keys
  static const String _authTokenKey = 'secure_auth_token';
  static const String _tokenExpiryKey = 'secure_token_expiry';
  static const String _savedEmailKey = 'secure_saved_email';
  static const String _savedPasswordKey = 'secure_saved_password';
  static const String _rememberMeKey = 'secure_remember_me';

  // Migration flags
  static const String _migrationCompleteKey = 'migration_complete_v1';

  /// Initialize secure storage and perform migration if needed
  static Future<void> initialize() async {
    try {
      debugPrint('Initializing SecureStorageService...');

      // Check if migration is needed
      final migrationComplete = await _secureStorage.read(key: _migrationCompleteKey);

      if (migrationComplete != 'true') {
        debugPrint('Starting migration from SharedPreferences to SecureStorage...');
        await _migrateFromSharedPreferences();
        await _secureStorage.write(key: _migrationCompleteKey, value: 'true');
        debugPrint('Migration completed successfully');
      } else {
        debugPrint('SecureStorageService already initialized');
      }
    } catch (e) {
      debugPrint('Error initializing SecureStorageService: $e');
    }
  }

  /// Migrate existing data from SharedPreferences to SecureStorage
  static Future<void> _migrateFromSharedPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Migrate auth token
      final authToken = prefs.getString('auth_token');
      if (authToken != null && authToken.isNotEmpty) {
        await _secureStorage.write(key: _authTokenKey, value: authToken);
        await prefs.remove('auth_token');
        debugPrint('Migrated auth_token to secure storage');
      }

      // Migrate token expiry
      final tokenExpiry = prefs.getInt('token_expiry');
      if (tokenExpiry != null) {
        await _secureStorage.write(key: _tokenExpiryKey, value: tokenExpiry.toString());
        await prefs.remove('token_expiry');
        debugPrint('Migrated token_expiry to secure storage');
      }

      // Migrate saved credentials
      final savedEmail = prefs.getString('saved_email');
      if (savedEmail != null && savedEmail.isNotEmpty) {
        await _secureStorage.write(key: _savedEmailKey, value: savedEmail);
        await prefs.remove('saved_email');
        debugPrint('Migrated saved_email to secure storage');
      }

      final savedPassword = prefs.getString('saved_password');
      if (savedPassword != null && savedPassword.isNotEmpty) {
        await _secureStorage.write(key: _savedPasswordKey, value: savedPassword);
        await prefs.remove('saved_password');
        debugPrint('Migrated saved_password to secure storage');
      }

      final rememberMe = prefs.getBool('remember_me');
      if (rememberMe != null) {
        await _secureStorage.write(key: _rememberMeKey, value: rememberMe.toString());
        await prefs.remove('remember_me');
        debugPrint('Migrated remember_me to secure storage');
      }
    } catch (e) {
      debugPrint('Error during migration: $e');
    }
  }

  /// Save authentication token securely
  static Future<bool> saveAuthToken(String token, {int? expiryMillis}) async {
    try {
      await _secureStorage.write(key: _authTokenKey, value: token);

      if (expiryMillis != null) {
        await _secureStorage.write(key: _tokenExpiryKey, value: expiryMillis.toString());
      }

      debugPrint('Auth token saved securely');
      return true;
    } catch (e) {
      debugPrint('Error saving auth token: $e');
      return false;
    }
  }

  /// Get authentication token from secure storage
  static Future<String?> getAuthToken() async {
    try {
      final token = await _secureStorage.read(key: _authTokenKey);

      if (token != null && token.isNotEmpty) {
        // Check if token is expired
        final isExpired = await isTokenExpired();
        if (isExpired) {
          debugPrint('Token has expired');
          await clearAuthToken();
          return null;
        }

        debugPrint('Auth token retrieved from secure storage');
        return token;
      }

      return null;
    } catch (e) {
      debugPrint('Error retrieving auth token: $e');
      return null;
    }
  }

  /// Check if token is expired
  static Future<bool> isTokenExpired() async {
    try {
      final expiryStr = await _secureStorage.read(key: _tokenExpiryKey);

      if (expiryStr == null || expiryStr.isEmpty) {
        return false; // No expiry set, assume valid
      }

      final expiryMillis = int.tryParse(expiryStr);
      if (expiryMillis == null) return false;

      final now = DateTime.now().millisecondsSinceEpoch;
      return now >= expiryMillis;
    } catch (e) {
      debugPrint('Error checking token expiry: $e');
      return true; // Assume expired on error
    }
  }

  /// Clear authentication token
  static Future<bool> clearAuthToken() async {
    try {
      await _secureStorage.delete(key: _authTokenKey);
      await _secureStorage.delete(key: _tokenExpiryKey);
      debugPrint('Auth token cleared from secure storage');
      return true;
    } catch (e) {
      debugPrint('Error clearing auth token: $e');
      return false;
    }
  }

  /// Save user credentials securely (for "Remember Me" feature)
  static Future<bool> saveCredentials({
    required String email,
    required String password,
    required bool rememberMe,
  }) async {
    try {
      await _secureStorage.write(key: _rememberMeKey, value: rememberMe.toString());

      if (rememberMe) {
        await _secureStorage.write(key: _savedEmailKey, value: email);
        await _secureStorage.write(key: _savedPasswordKey, value: password);
        debugPrint('Credentials saved securely');
      } else {
        await clearCredentials();
      }

      return true;
    } catch (e) {
      debugPrint('Error saving credentials: $e');
      return false;
    }
  }

  /// Get saved credentials from secure storage
  static Future<Map<String, dynamic>> getCredentials() async {
    try {
      final rememberMeStr = await _secureStorage.read(key: _rememberMeKey);
      final rememberMe = rememberMeStr == 'true';

      if (!rememberMe) {
        return {'rememberMe': false, 'email': '', 'password': ''};
      }

      final email = await _secureStorage.read(key: _savedEmailKey) ?? '';
      final password = await _secureStorage.read(key: _savedPasswordKey) ?? '';

      return {'rememberMe': rememberMe, 'email': email, 'password': password};
    } catch (e) {
      debugPrint('Error getting credentials: $e');
      return {'rememberMe': false, 'email': '', 'password': ''};
    }
  }

  /// Clear saved credentials
  static Future<bool> clearCredentials() async {
    try {
      await _secureStorage.delete(key: _savedEmailKey);
      await _secureStorage.delete(key: _savedPasswordKey);
      await _secureStorage.delete(key: _rememberMeKey);
      debugPrint('Credentials cleared from secure storage');
      return true;
    } catch (e) {
      debugPrint('Error clearing credentials: $e');
      return false;
    }
  }

  /// Clear all secure storage (use with caution)
  static Future<bool> clearAll() async {
    try {
      await _secureStorage.deleteAll();
      debugPrint('All secure storage cleared');
      return true;
    } catch (e) {
      debugPrint('Error clearing all secure storage: $e');
      return false;
    }
  }

  /// Check if user has valid authentication
  static Future<bool> isAuthenticated() async {
    final token = await getAuthToken();
    return token != null && token.isNotEmpty;
  }

  /// Get debug info (for development only)
  static Future<Map<String, dynamic>> getDebugInfo() async {
    try {
      final hasToken = await _secureStorage.read(key: _authTokenKey) != null;
      final hasExpiry = await _secureStorage.read(key: _tokenExpiryKey) != null;
      final hasEmail = await _secureStorage.read(key: _savedEmailKey) != null;
      final rememberMe = await _secureStorage.read(key: _rememberMeKey);

      return {
        'hasToken': hasToken,
        'hasExpiry': hasExpiry,
        'hasEmail': hasEmail,
        'rememberMe': rememberMe,
        'isAuthenticated': await isAuthenticated(),
        'isTokenExpired': await isTokenExpired(),
      };
    } catch (e) {
      debugPrint('Error getting debug info: $e');
      return {'error': e.toString()};
    }
  }
}
