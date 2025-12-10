import 'package:flutter/foundation.dart';
import 'package:grab_go_shared/shared/services/secure_storage_service.dart';

class TokenService {
  static final TokenService _instance = TokenService._internal();
  factory TokenService() => _instance;
  TokenService._internal();

  static String? _cachedToken;

  /// Initialize secure storage (call this at app startup)
  static Future<void> initialize() async {
    await SecureStorageService.initialize();
    _cachedToken = await SecureStorageService.getAuthToken();
  }

  /// Save authentication token securely
  Future<void> saveToken(String token) async {
    try {
      debugPrint('🔄 Saving admin token: ${token.substring(0, 20)}...');
      await SecureStorageService.saveAuthToken(token);
      _cachedToken = token; // Update cache
      debugPrint('🔐 Admin token saved securely');
    } catch (e) {
      debugPrint('❌ Error saving admin token: $e');
    }
  }

  /// Get stored authentication token (async)
  Future<String?> getToken() async {
    try {
      final token = await SecureStorageService.getAuthToken();
      _cachedToken = token; // Update cache

      if (token != null && token.isNotEmpty) {
        debugPrint('🔐 Admin token retrieved successfully');
        return token;
      }

      debugPrint('ℹ️ No admin token found');
      return null;
    } catch (e) {
      debugPrint('❌ Error retrieving admin token: $e');
      return null;
    }
  }

  /// Get stored authentication token synchronously (from cache)
  /// Returns null if not cached yet - use getToken() for first access
  static String? getTokenSync() {
    return _cachedToken;
  }

  /// Check if user is authenticated (has valid token)
  Future<bool> isAuthenticated() async {
    return await SecureStorageService.isAuthenticated();
  }

  /// Clear stored token
  Future<void> clearToken() async {
    try {
      await SecureStorageService.clearAuthToken();
      _cachedToken = null; // Clear cache
      debugPrint('🗑️ Admin token cleared successfully');
    } catch (e) {
      debugPrint('❌ Error clearing admin token: $e');
    }
  }
}
