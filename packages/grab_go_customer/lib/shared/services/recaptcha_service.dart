import 'package:flutter/foundation.dart';
import 'package:firebase_app_check/firebase_app_check.dart';

class RecaptchaService {
  static final RecaptchaService _instance = RecaptchaService._internal();
  factory RecaptchaService() => _instance;
  RecaptchaService._internal();

  bool _isInitialized = false;

  /// Initialize reCAPTCHA with your site key
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      debugPrint('🔐 Initializing reCAPTCHA...');
      
      // Use debug provider for immediate testing - this works without additional configuration
      await FirebaseAppCheck.instance.activate(
        androidProvider: AndroidProvider.debug, // Debug provider works immediately
        appleProvider: AppleProvider.debug, // Use debug provider for iOS testing
      );

      _isInitialized = true;
      debugPrint('✅ reCAPTCHA initialized successfully with debug provider');
      debugPrint('📱 Ready for immediate OTP testing!');
    } catch (e) {
      debugPrint('❌ Error initializing reCAPTCHA: $e');
      rethrow;
    }
  }

  /// Get reCAPTCHA token for phone authentication
  Future<String?> getRecaptchaToken() async {
    try {
      if (!_isInitialized) {
        await initialize();
      }

      debugPrint('🔐 Getting reCAPTCHA token...');
      
      // Get App Check token which includes reCAPTCHA verification
      final token = await FirebaseAppCheck.instance.getToken();
      
      if (token != null) {
        debugPrint('✅ reCAPTCHA token obtained successfully');
        return token;
      } else {
        debugPrint('❌ Failed to get reCAPTCHA token');
        return null;
      }
    } catch (e) {
      debugPrint('❌ Error getting reCAPTCHA token: $e');
      return null;
    }
  }

  /// Initialize with debug token for immediate testing
  Future<void> initializeWithDebugToken() async {
    if (_isInitialized) return;

    try {
      debugPrint('🔐 Initializing reCAPTCHA with debug token...');
      
      // Use debug provider for immediate testing
      await FirebaseAppCheck.instance.activate(
        androidProvider: AndroidProvider.debug,
        appleProvider: AppleProvider.debug,
      );

      _isInitialized = true;
      debugPrint('✅ reCAPTCHA initialized successfully with debug token');
      debugPrint('📱 Ready for immediate OTP testing!');
    } catch (e) {
      debugPrint('❌ Error initializing reCAPTCHA with debug token: $e');
      rethrow;
    }
  }

  /// Check if reCAPTCHA is properly configured
  bool get isInitialized => _isInitialized;
}


