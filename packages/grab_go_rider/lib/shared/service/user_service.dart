import 'package:flutter/foundation.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'cache_service.dart';

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

      if (_currentUser != null) {
        debugPrint('✅ Auto-login successful!');
        debugPrint('   Current user: ${_currentUser?.username}');
        debugPrint('   Email: ${_currentUser?.email}');
        debugPrint('   Role: ${_currentUser?.role}');
      }
    } catch (e) {
      debugPrint('❌ Error during auto-login: $e');
    }
  }

  Future<void> _loadCachedUserData() async {
    try {
      final userData = CacheService.getUserData();

      if (userData != null) {
        _currentUser = User.fromJson(userData);
        debugPrint('📱 Loaded cached user data: ${_currentUser?.username}');
      }
    } catch (e) {
      debugPrint('❌ Error loading cached user data: $e');
    }
  }

  Future<void> _saveUserDataToCache(User user) async {
    try {
      await CacheService.saveUserData(user.toJson());
    } catch (e) {
      debugPrint('❌ Error saving user data to cache: $e');
    }
  }

  Future<void> setCurrentUser(User user) async {
    try {
      _currentUser = user;
      await _saveUserDataToCache(user);
      debugPrint('✅ User data saved successfully!');
    } catch (e) {
      debugPrint('❌ Error saving user data: $e');
    }
  }

  Future<void> logout() async {
    try {
      _currentUser = null;
      await CacheService.clearUserData();
      await CacheService.clearAuthToken();
      debugPrint('✅ User logged out successfully');
    } catch (e) {
      debugPrint('❌ Error logging out: $e');
    }
  }
}
