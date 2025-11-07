import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TokenService {
  static final TokenService _instance = TokenService._internal();
  factory TokenService() => _instance;
  TokenService._internal();

  static const String _tokenKey = 'admin_auth_token';
  static String? _cachedToken;
  static SharedPreferences? _prefs;

  /// Initialize SharedPreferences (call this at app startup)
  static Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    _cachedToken = _prefs?.getString(_tokenKey);
  }

  /// Save authentication token
  Future<void> saveToken(String token) async {
    try {
      debugPrint('🔄 Saving admin token: ${token.substring(0, 20)}...');
      _prefs ??= await SharedPreferences.getInstance();
      await _prefs!.setString(_tokenKey, token);
      _cachedToken = token; // Update cache
      debugPrint('🔐 Admin token saved successfully');
    } catch (e) {
      debugPrint('❌ Error saving admin token: $e');
    }
  }

  /// Get stored authentication token (async)
  Future<String?> getToken() async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      final token = _prefs!.getString(_tokenKey);
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
    if (_cachedToken != null) {
      return _cachedToken;
    }
    // Try to get from SharedPreferences if initialized
    if (_prefs != null) {
      _cachedToken = _prefs!.getString(_tokenKey);
      return _cachedToken;
    }
    return null;
  }

  /// Check if user is authenticated (has valid token)
  Future<bool> isAuthenticated() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  /// Clear stored token
  Future<void> clearToken() async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      await _prefs!.remove(_tokenKey);
      _cachedToken = null; // Clear cache
      debugPrint('🗑️ Admin token cleared successfully');
    } catch (e) {
      debugPrint('❌ Error clearing admin token: $e');
    }
  }
}
