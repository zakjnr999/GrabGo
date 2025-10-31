import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class FirebasePhoneAuthService {
  static final FirebasePhoneAuthService _instance = FirebasePhoneAuthService._internal();
  factory FirebasePhoneAuthService() => _instance;
  FirebasePhoneAuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  String? _verificationId;
  int? _resendToken;
  String? _phoneNumber;
  String? _userId; // Store user ID from registration

  /// Send OTP to phone number
  Future<bool> sendOTP({
    required String phoneNumber,
    required Function(String verificationId) onCodeSent,
    required Function(String error) onError,
    required Function() onTimeout,
  }) async {
    try {
      debugPrint('📱 Sending OTP to: $phoneNumber');
      _phoneNumber = phoneNumber; // Store phone number for later use
      
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          debugPrint('✅ Phone verification completed automatically');
          // Auto-verification completed
        },
        verificationFailed: (FirebaseAuthException e) {
          debugPrint('❌ Phone verification failed: ${e.message}');
          onError(e.message ?? 'Verification failed');
        },
        codeSent: (String verificationId, int? resendToken) {
          debugPrint('✅ OTP sent successfully');
          _verificationId = verificationId;
          _resendToken = resendToken;
          onCodeSent(verificationId);
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          debugPrint('⏰ Auto-retrieval timeout');
          _verificationId = verificationId;
          onTimeout();
        },
        timeout: const Duration(seconds: 60),
      );
      
      return true;
    } catch (e) {
      debugPrint('❌ Error sending OTP: $e');
      onError(e.toString());
      return false;
    }
  }

  /// Resend OTP
  Future<bool> resendOTP({
    required String phoneNumber,
    required Function(String verificationId) onCodeSent,
    required Function(String error) onError,
  }) async {
    try {
      debugPrint('📱 Resending OTP to: $phoneNumber');
      
      // Skip reCAPTCHA for resend as well
      debugPrint('⚠️ Skipping reCAPTCHA token for resend - OTP should still work');
      
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        forceResendingToken: _resendToken,
        verificationCompleted: (PhoneAuthCredential credential) async {
          debugPrint('✅ Phone verification completed automatically');
        },
        verificationFailed: (FirebaseAuthException e) {
          debugPrint('❌ Phone verification failed: ${e.message}');
          onError(e.message ?? 'Verification failed');
        },
        codeSent: (String verificationId, int? resendToken) {
          debugPrint('✅ OTP resent successfully');
          _verificationId = verificationId;
          _resendToken = resendToken;
          onCodeSent(verificationId);
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          debugPrint('⏰ Auto-retrieval timeout');
          _verificationId = verificationId;
        },
        timeout: const Duration(seconds: 60),
      );
      
      return true;
    } catch (e) {
      debugPrint('❌ Error resending OTP: $e');
      onError(e.toString());
      return false;
    }
  }

  /// Verify OTP code
  Future<UserCredential?> verifyOTP({
    required String otpCode,
    required Function(String error) onError,
  }) async {
    try {
      if (_verificationId == null) {
        onError('No verification ID found. Please request OTP again.');
        return null;
      }

      debugPrint('🔐 Verifying OTP: $otpCode');
      
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: otpCode,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      
      debugPrint('✅ OTP verified successfully');
      debugPrint('User ID: ${userCredential.user?.uid}');
      debugPrint('Phone: ${userCredential.user?.phoneNumber}');
      
      return userCredential;
    } catch (e) {
      debugPrint('❌ Error verifying OTP: $e');
      onError(e.toString());
      return null;
    }
  }

  /// Get current user
  User? get currentUser => _auth.currentUser;

  /// Sign out
  Future<void> signOut() async {
    await _auth.signOut();
    _verificationId = null;
    _resendToken = null;
  }

  /// Check if phone is verified
  bool get isPhoneVerified => currentUser?.phoneNumber != null;

  /// Get verification ID
  String? get verificationId => _verificationId;

  /// Get phone number
  String? get phoneNumber => _phoneNumber;

  /// Store user ID from registration
  void setUserId(String userId) {
    _userId = userId;
    debugPrint('📝 Stored user ID: $userId');
  }

  /// Get user ID
  String? get userId => _userId;
}


