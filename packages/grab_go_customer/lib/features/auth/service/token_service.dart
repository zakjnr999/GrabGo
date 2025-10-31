import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TokenService {
  static final TokenService _instance = TokenService._internal();
  factory TokenService() => _instance;
  TokenService._internal();

  static const String _tokenKey = 'auth_token';
  static const String _tokenExpiryKey = 'token_expiry';

  /// Save authentication token
  Future<void> saveToken(String token, {Duration? expiry}) async {
    try {
      debugPrint('🔄 Saving token: ${token.substring(0, 20)}...');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, token);
      
      if (expiry != null) {
        final expiryTime = DateTime.now().add(expiry).millisecondsSinceEpoch;
        await prefs.setInt(_tokenExpiryKey, expiryTime);
        debugPrint('🔐 Token expiry set: ${DateTime.fromMillisecondsSinceEpoch(expiryTime)}');
      }
      
      debugPrint('🔐 Token saved successfully');
      
      // Verify token was saved
      final savedToken = await prefs.getString(_tokenKey);
      debugPrint('🔍 Token verification: ${savedToken != null ? 'Saved' : 'Not saved'}');
    } catch (e) {
      debugPrint('❌ Error saving token: $e');
    }
  }

  /// Get stored authentication token
  Future<String?> getToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(_tokenKey);
      
      if (token != null) {
        // Check if token is expired
        if (await isTokenExpired()) {
          debugPrint('⚠️ Token has expired');
          await clearToken();
          return null;
        }
        
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
      final prefs = await SharedPreferences.getInstance();
      final expiryTime = prefs.getInt(_tokenExpiryKey);
      
      if (expiryTime == null) {
        // No expiry set, assume token is valid
        return false;
      }
      
      final now = DateTime.now().millisecondsSinceEpoch;
      final isExpired = now >= expiryTime;
      
      if (isExpired) {
        debugPrint('⚠️ Token expired at: ${DateTime.fromMillisecondsSinceEpoch(expiryTime)}');
      }
      
      return isExpired;
    } catch (e) {
      debugPrint('❌ Error checking token expiry: $e');
      return true; // Assume expired if error
    }
  }

  /// Check if user is authenticated (has valid token)
  Future<bool> isAuthenticated() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  /// Clear stored token
  Future<void> clearToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenKey);
      await prefs.remove(_tokenExpiryKey);
      debugPrint('🗑️ Token cleared successfully');
    } catch (e) {
      debugPrint('❌ Error clearing token: $e');
    }
  }

  /// Get token info for debugging
  Future<Map<String, dynamic>> getTokenInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(_tokenKey);
      final expiryTime = prefs.getInt(_tokenExpiryKey);
      
      return {
        'hasToken': token != null,
        'tokenLength': token?.length ?? 0,
        'expiryTime': expiryTime,
        'isExpired': await isTokenExpired(),
        'expiryDate': expiryTime != null 
            ? DateTime.fromMillisecondsSinceEpoch(expiryTime).toString()
            : null,
      };
    } catch (e) {
      debugPrint('❌ Error getting token info: $e');
      return {'error': e.toString()};
    }
  }
}


