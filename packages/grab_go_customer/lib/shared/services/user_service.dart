import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:grab_go_customer/core/api/api_client.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:grab_go_customer/features/auth/service/phone_auth_service.dart';
import 'package:grab_go_shared/shared/services/device_id_service.dart';

class UserService {
  static final UserService _instance = UserService._internal();
  factory UserService() => _instance;
  UserService._internal();

  User? _currentUser;
  bool _isLoading = false;

  User? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _currentUser != null;

  Future<void> initialize() async {
    try {
      await _loadCachedUserData();
      if (_currentUser == null) {
        debugPrint('No stored user data found, showing login screen');
      }
    } catch (e) {
      debugPrint('Error during auto-login: $e');
    }
  }

  Future<void> _loadCachedUserData() async {
    try {
      final userData = CacheService.getUserData();

      if (userData != null) {
        _currentUser = User.fromJson(userData);
        debugPrint('Loaded cached user data: ${_currentUser?.username}');
      }
    } catch (e) {
      debugPrint('Error loading cached user data: $e');
    }
  }

  Future<void> _saveUserDataToCache(User user) async {
    try {
      final userData = user.toJson();

      await CacheService.saveUserData(userData);

      debugPrint('Saved user data to cache');
    } catch (e) {
      debugPrint('Error saving user data to cache: $e');
    }
  }

  Future<void> _clearCachedUserData() async {
    try {
      await CacheService.clearUserData();
      debugPrint('Cleared cached user data');
    } catch (e) {
      debugPrint('Error clearing cached user data: $e');
    }
  }

  Future<User?> getUserById(String userId) async {
    try {
      _isLoading = true;

      final response = await authService
          .getUser(userId)
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              throw TimeoutException('Server is taking too long to respond.');
            },
          );

      if (response.isSuccessful && response.body != null) {
        final user = response.body!.userData ?? response.body!.user ?? response.body!.data;
        return user;
      } else {
        debugPrint('Failed to fetch user data: ${response.error}');
        return null;
      }
    } catch (e) {
      debugPrint('Error fetching user data: $e');
      return null;
    } finally {
      _isLoading = false;
    }
  }

  Future<User?> getCurrentUser({bool forceRefresh = false}) async {
    try {
      if (_currentUser != null && !forceRefresh) {
        return _currentUser;
      }

      final userId = _currentUser?.id ?? PhoneAuthService().userId;
      if (userId == null) {
        debugPrint('User ID not found');
        return null;
      }

      final user = await getUserById(userId);
      if (user != null) {
        _currentUser = user;
        await _saveUserDataToCache(user);
      }

      return _currentUser;
    } catch (e) {
      debugPrint('Error getting current user: $e');
      return null;
    }
  }

  Future<void> setCurrentUser(User user) async {
    try {
      _currentUser = user;
      await _saveUserDataToCache(user);

      if (user.id != null) {
        PhoneAuthService().setUserId(user.id!);
      }

      // Register FCM token after login (don't block the UI)
      _registerFcmTokenAfterLogin().catchError((e) {
        debugPrint('❌ Fatal error in FCM registration background task: $e');
      });
    } catch (e) {
      debugPrint('❌ Error saving user data: $e');
    }
  }

  /// Register FCM token after user logs in with retry logic
  Future<void> _registerFcmTokenAfterLogin() async {
    try {
      final token = await PushNotificationService().getToken();
      if (token == null) {
        debugPrint('⚠️ No FCM token available for registration');
        return;
      }

      // Get unique device ID (guaranteed non-null now)
      final deviceId = await DeviceIdService().getDeviceId();

      // Attempt registration with retry logic
      await _registerFcmTokenWithRetry(token, deviceId);
    } catch (e) {
      debugPrint('❌ Error during FCM registration flow: $e');
    }
  }

  /// Internal helper to register FCM token with exponential backoff
  Future<void> _registerFcmTokenWithRetry(String token, String deviceId, {int maxRetries = 3}) async {
    int retryCount = 0;
    int delaySeconds = 2;

    while (retryCount < maxRetries) {
      try {
        final success = await registerFcmToken(token, platform: Platform.isIOS ? 'ios' : 'android', deviceId: deviceId);

        if (success) {
          debugPrint('✅ FCM token registered successfully on attempt ${retryCount + 1}');
          return;
        }

        debugPrint('⚠️ FCM registration failed, retrying in $delaySeconds seconds... (${retryCount + 1}/$maxRetries)');
      } catch (e) {
        debugPrint(
          '❌ FCM registration error: $e, retrying in $delaySeconds seconds... (${retryCount + 1}/$maxRetries)',
        );
      }

      retryCount++;
      if (retryCount < maxRetries) {
        await Future.delayed(Duration(seconds: delaySeconds));
        delaySeconds *= 2; // Exponential backoff
      }
    }

    debugPrint('❌ Failed to register FCM token after $maxRetries attempts');
  }

  Future<User?> updateCurrentUser(User updatedUser) async {
    try {
      _currentUser = updatedUser;
      await _saveUserDataToCache(updatedUser);
      debugPrint('Current user updated: ${updatedUser.username}');
      return _currentUser;
    } catch (e) {
      debugPrint('Error updating current user: $e');
      return null;
    }
  }

  Future<void> logout() async {
    try {
      // Remove FCM token before logout
      final token = await PushNotificationService().getToken();
      if (token != null) {
        await removeFcmToken(token);
      }

      _currentUser = null;
      await _clearCachedUserData();
      await CacheService.clearUserSpecificData();

      PhoneAuthService().clear();
    } catch (e) {
      debugPrint('Error during logout: $e');
    }
  }

  String? getUserId() {
    return _currentUser?.id ?? PhoneAuthService().userId;
  }

  bool hasPermission(String permission) {
    if (_currentUser?.permissions == null) return false;

    switch (permission) {
      case 'canManageUsers':
        return _currentUser!.permissions!.canManageUsers ?? false;
      case 'canManageProducts':
        return _currentUser!.permissions!.canManageProducts ?? false;
      case 'canManageOrders':
        return _currentUser!.permissions!.canManageOrders ?? false;
      case 'canManageContent':
        return _currentUser!.permissions!.canManageContent ?? false;
      default:
        return false;
    }
  }

  String getFullName() {
    return _currentUser?.username ?? 'Unknown User';
  }

  String getEmail() {
    return _currentUser?.email ?? '';
  }

  String? getProfilePicture() {
    return _currentUser?.profilePicture;
  }

  bool hasProfilePicture() {
    return _currentUser?.profilePicture != null && _currentUser!.profilePicture!.isNotEmpty;
  }

  bool isPhoneVerified() {
    return _currentUser?.isPhoneVerified ?? false;
  }

  Future<User?> refreshUserData() async {
    return await getCurrentUser(forceRefresh: true);
  }

  /// Register FCM token with backend for push notifications
  Future<bool> registerFcmToken(String token, {String platform = 'android', String? deviceId}) async {
    try {
      final response = await authService.registerFcmToken({
        'token': token,
        'platform': platform,
        if (deviceId != null) 'deviceId': deviceId,
      });

      if (response.isSuccessful) {
        debugPrint('FCM token registered successfully');
        return true;
      } else {
        debugPrint('Failed to register FCM token: ${response.error}');
        return false;
      }
    } catch (e) {
      debugPrint('Error registering FCM token: $e');
      return false;
    }
  }

  /// Remove FCM token from backend (on logout)
  Future<bool> removeFcmToken(String token) async {
    try {
      final response = await authService.removeFcmToken({'token': token});

      if (response.isSuccessful) {
        debugPrint('FCM token removed successfully');
        return true;
      } else {
        debugPrint('Failed to remove FCM token: ${response.error}');
        return false;
      }
    } catch (e) {
      debugPrint('Error removing FCM token: $e');
      return false;
    }
  }
}
