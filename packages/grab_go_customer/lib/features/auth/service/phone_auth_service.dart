import 'package:grab_go_customer/core/api/api_client.dart';
import 'package:grab_go_shared/shared/services/cache_service.dart';

class PhoneAuthService {
  static final PhoneAuthService _instance = PhoneAuthService._internal();
  factory PhoneAuthService() => _instance;
  PhoneAuthService._internal();

  String? _phoneNumber;
  String? _userId; // Store user ID from registration
  String? _channel;

  /// Send OTP to phone number
  Future<bool> sendOTP({
    required String phoneNumber,
    required String userId,
    String channel = 'sms',
    required Function() onCodeSent,
    required Function(String error) onError,
  }) async {
    try {
      _phoneNumber = phoneNumber;
      _userId = userId;
      _channel = channel;

      final response =
          await authService.sendPhoneOTP({'phoneNumber': phoneNumber, 'userId': userId, 'channel': channel});

      if (response.isSuccessful && response.body != null) {
        final success = response.body!['success'] as bool? ?? false;
        if (success) {
          onCodeSent();
          return true;
        } else {
          final message = response.body!['message'] as String? ?? 'Failed to send OTP';
          onError(message);
          return false;
        }
      } else {
        final errorMessage = response.body?['message'] as String? ?? 'Failed to send OTP';
        onError(errorMessage);
        return false;
      }
    } catch (e) {
      onError(e.toString());
      return false;
    }
  }

  /// Resend OTP
  Future<bool> resendOTP({
    required String phoneNumber,
    required String userId,
    String? channel,
    required Function() onCodeSent,
    required Function(String error) onError,
  }) async {
    try {
      _phoneNumber = phoneNumber;
      _userId = userId;
      final resolvedChannel = channel ?? _channel ?? 'sms';
      _channel = resolvedChannel;

      final response = await authService.resendPhoneOTP(
        {'phoneNumber': phoneNumber, 'userId': userId, 'channel': resolvedChannel},
      );

      if (response.isSuccessful && response.body != null) {
        final success = response.body!['success'] as bool? ?? false;
        if (success) {
          onCodeSent();
          return true;
        } else {
          final message = response.body!['message'] as String? ?? 'Failed to resend OTP';
          onError(message);
          return false;
        }
      } else {
        final errorMessage = response.body?['message'] as String? ?? 'Failed to resend OTP';
        onError(errorMessage);
        return false;
      }
    } catch (e) {
      onError(e.toString());
      return false;
    }
  }

  /// Verify OTP code
  Future<Map<String, dynamic>?> verifyOTP({required String otpCode, required Function(String error) onError}) async {
    try {
      if (_phoneNumber == null || _userId == null) {
        onError('Phone number or user ID not found. Please request OTP again.');
        return null;
      }

      final response = await authService.verifyPhoneOTP({
        'phoneNumber': _phoneNumber,
        'otp': otpCode,
        'userId': _userId,
      });

      if (response.isSuccessful && response.body != null) {
        final success = response.body!['success'] as bool? ?? false;
        if (success) {
          // Update token if provided
          final token = response.body!['token'] as String?;
          if (token != null && token.isNotEmpty) {
            await CacheService.saveAuthToken(token);
          }

          // Return user data
          return {'user': response.body!['user'], 'token': token};
        } else {
          final message = response.body!['message'] as String? ?? 'Invalid OTP';
          onError(message);
          return null;
        }
      } else {
        final errorMessage = response.body?['message'] as String? ?? 'Invalid OTP';
        onError(errorMessage);
        return null;
      }
    } catch (e) {
      onError(e.toString());
      return null;
    }
  }

  /// Get phone number
  String? get phoneNumber => _phoneNumber;

  /// Get last used channel
  String? get channel => _channel;

  /// Store user ID from registration
  void setUserId(String userId) {
    _userId = userId;
  }

  /// Get user ID
  String? get userId => _userId;

  /// Clear stored data
  void clear() {
    _phoneNumber = null;
    _userId = null;
    _channel = null;
  }
}
