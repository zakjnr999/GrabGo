import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:grab_go_shared/grub_go_shared.dart';

class GoogleSignInService {
  static final GoogleSignInService _instance = GoogleSignInService._internal();
  factory GoogleSignInService() => _instance;
  GoogleSignInService._internal();

  bool _initialized = false;

  /// Initialize Google Sign-In (call this once at app startup)
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      // Initialize GoogleSignIn singleton with Web Client ID
      await GoogleSignIn.instance.initialize(serverClientId: GoogleSignInConfig.serverClientId);

      _initialized = true;
      debugPrint('✅ Google Sign-In initialized');
      debugPrint('📋 Server Client ID configured: ${GoogleSignInConfig.serverClientId != null}');

      // Try to sign in silently on initialization
      await signInSilently();
    } catch (e) {
      debugPrint('⚠️ Google Sign-In initialization error: $e');
      _initialized = true;
    }
  }

  /// Sign in with Google (full interactive flow)
  Future<Map<String, dynamic>?> signInWithGoogle() async {
    try {
      // Ensure initialized
      if (!_initialized) {
        await initialize();
      }

      debugPrint('🔵 Starting Google Sign-In...');
      debugPrint('📱 Opening Google account picker...');

      // Trigger the authentication flow
      final GoogleSignInAccount googleUser = await GoogleSignIn.instance.authenticate();

      debugPrint('✅ User selected: ${googleUser.displayName}');

      // Get auth details
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      debugPrint('✅ Google Sign-In successful!');
      debugPrint('User: ${googleUser.displayName}');
      debugPrint('Email: ${googleUser.email}');
      debugPrint('ID Token: ${googleAuth.idToken != null ? "Received" : "Not received"}');

      return {
        'googleId': googleUser.id,
        'email': googleUser.email,
        'displayName': googleUser.displayName ?? '',
        'photoUrl': googleUser.photoUrl ?? '',
        'idToken': googleAuth.idToken ?? '',
        'accessToken': googleAuth.idToken ?? '', // Use idToken as accessToken
      };
    } catch (error) {
      debugPrint('❌ Google Sign-In Error: $error');

      // Provide helpful error messages for configuration issues
      final errorStr = error.toString().toLowerCase();
      if (errorStr.contains('developer_error') ||
          errorStr.contains('configuration') ||
          errorStr.contains('provider dependencies') ||
          errorStr.contains('play services')) {
        debugPrint('');
        debugPrint('══════════════════════════════════════════');
        debugPrint('⚠️  CONFIGURATION ERROR DETECTED');
        debugPrint('══════════════════════════════════════════');
        debugPrint('');
        debugPrint('Possible causes:');
        debugPrint('');
        debugPrint('1️⃣  Google Play Services outdated:');
        debugPrint('   - Update Play Services in your emulator/device');
        debugPrint('   - Or use a newer emulator (API 33+)');
        debugPrint('   - See: FIX_PLAY_SERVICES.md');
        debugPrint('');
        debugPrint('2️⃣  Missing SHA-1 fingerprints:');
        debugPrint('   - Get SHA-1: ./get_sha1.bat (Windows) or ./get_sha1.sh (Mac/Linux)');
        debugPrint('   - Add to Google Cloud Console');
        debugPrint('   - See: QUICK_START_GOOGLE_SIGNIN.md');
        debugPrint('');
        debugPrint('3️⃣  Missing Web Client ID:');
        debugPrint('   - Create Web OAuth Client in Google Cloud Console');
        debugPrint('   - Add to lib/config/google_signin_config.dart');
        debugPrint('   - See: GET_WEB_CLIENT_ID.md');
        debugPrint('');
        debugPrint('4️⃣  Missing google-services.json:');
        debugPrint('   - Download from Firebase Console');
        debugPrint('   - Place in: android/app/google-services.json');
        debugPrint('');
        debugPrint('══════════════════════════════════════════');
        debugPrint('');
      }

      return null;
    }
  }

  /// Sign out from Google
  Future<void> signOut() async {
    try {
      if (!_initialized) {
        await initialize();
      }

      await GoogleSignIn.instance.signOut();
      debugPrint('✅ Successfully signed out from Google');
    } catch (error) {
      debugPrint('❌ Sign out error: $error');
    }
  }

  /// Sign in silently (without showing account picker)
  Future<Map<String, dynamic>?> signInSilently() async {
    try {
      if (!_initialized) {
        await initialize();
      }

      debugPrint('🔵 Attempting silent sign-in...');

      final GoogleSignInAccount? googleUser = await GoogleSignIn.instance.attemptLightweightAuthentication();

      if (googleUser == null) {
        debugPrint('❌ No previously signed-in user found');
        return null;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      debugPrint('✅ Silent sign-in successful!');
      debugPrint('User: ${googleUser.displayName} (${googleUser.email})');

      return {
        'googleId': googleUser.id,
        'email': googleUser.email,
        'displayName': googleUser.displayName ?? '',
        'photoUrl': googleUser.photoUrl ?? '',
        'idToken': googleAuth.idToken ?? '',
        'accessToken': googleAuth.idToken ?? '',
      };
    } catch (error) {
      debugPrint('ℹ️  Silent sign-in not available: $error');
      return null;
    }
  }

  /// Check if user is currently signed in
  Future<bool> isSignedIn() async {
    try {
      if (!_initialized) {
        await initialize();
      }
      final user = await GoogleSignIn.instance.attemptLightweightAuthentication();
      return user != null;
    } catch (e) {
      debugPrint('Error checking sign-in status: $e');
      return false;
    }
  }

  /// Get current user if signed in
  GoogleSignInAccount? get currentUser {
    try {
      if (!_initialized) {
        return null;
      }
      return null; // v7.2.0 doesn't have currentUser - use attemptLightweightAuthentication instead
    } catch (e) {
      debugPrint('Error getting current user: $e');
      return null;
    }
  }

  /// Disconnect from Google (revoke access)
  Future<void> disconnect() async {
    try {
      if (!_initialized) {
        await initialize();
      }

      await GoogleSignIn.instance.disconnect();
      debugPrint('✅ Successfully disconnected from Google');
    } catch (error) {
      debugPrint('❌ Disconnect error: $error');
    }
  }
}
