import 'package:flutter/foundation.dart';
import 'package:grab_go_shared/shared/services/secure_storage_service.dart';

class TokenService {
  static final TokenService _instance = TokenService._internal();
  factory TokenService() => _instance;
  TokenService._internal();

  /// Save authentication token securely
  Future<void> saveToken(String token, {Duration? expiry}) async {
    try {
      debugPrint('🔄 Saving token: ${token.substring(0, 20)}...');

      int? expiryMillis;
      if (expiry != null) {
        expiryMillis = DateTime.now().add(expiry).millisecondsSinceEpoch;
        debugPrint('🔐 Token expiry set: ${DateTime.fromMillisecondsSinceEpoch(expiryMillis)}');
      }

      await SecureStorageService.saveAuthToken(token, expiryMillis: expiryMillis);
      debugPrint('🔐 Token saved securely');

      // Verify token was saved
      final savedToken = await SecureStorageService.getAuthToken();
      debugPrint('🔍 Token verification: ${savedToken != null ? 'Saved' : 'Not saved'}');
    } catch (e) {
      debugPrint('❌ Error saving token: $e');
    }
  }

  /// Get stored authentication token
  Future<String?> getToken() async {
    try {
      final token = await SecureStorageService.getAuthToken();

      if (token != null) {
        debugPrint('🔐 Token retrieved successfully');
        return token;
      }

      debugPrint('ℹ️ No token found');
      return null;
    } catch (e) {
      debugPrint('❌ Error retrieving token: $e');
      return null;
    }
  }

  /// Check if token is expired
  Future<bool> isTokenExpired() async {
    try {
      return await SecureStorageService.isTokenExpired();
    } catch (e) {
      debugPrint('❌ Error checking token expiry: $e');
      return true; // Assume expired if error
    }
  }

  /// Check if user is authenticated (has valid token)
  Future<bool> isAuthenticated() async {
    return await SecureStorageService.isAuthenticated();
  }

  /// Clear stored token
  Future<void> clearToken() async {
    try {
      await SecureStorageService.clearAuthToken();
      debugPrint('🗑️ Token cleared successfully');
    } catch (e) {
      debugPrint('❌ Error clearing token: $e');
    }
  }

  /// Get token info for debugging
  Future<Map<String, dynamic>> getTokenInfo() async {
    try {
      return await SecureStorageService.getDebugInfo();
    } catch (e) {
      debugPrint('❌ Error getting token info: $e');
      return {'error': e.toString()};
    }
  }
}
