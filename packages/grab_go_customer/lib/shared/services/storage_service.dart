import 'cache_service.dart';

class StorageService {
  static Future<void> saveCredentials({
    required String email,
    required String password,
    required bool rememberMe,
  }) async {
    await CacheService.saveCredentials(email: email, password: password, rememberMe: rememberMe);
  }

  static Future<Map<String, dynamic>> loadCredentials() async {
    return CacheService.getCredentials();
  }

  static Future<void> clearCredentials() async {
    await CacheService.clearCredentials();
  }

  static Future<bool> hasRememberedCredentials() async {
    final credentials = CacheService.getCredentials();
    return credentials['rememberMe'] as bool? ?? false;
  }

  static Future<void> saveRestaurantApplicationSubmitted() async {
    await CacheService.saveRestaurantApplicationSubmitted();
  }

  static Future<bool> hasRestaurantApplicationSubmitted() async {
    return CacheService.hasRestaurantApplicationSubmitted();
  }

  static Future<void> clearRestaurantApplicationStatus() async {
    await CacheService.clearAllCache();
  }

  static Future<void> saveRestaurantApplicationStatus(String status) async {
    await CacheService.saveRestaurantApplicationStatus(status);
  }

  static Future<String?> getRestaurantApplicationStatus() async {
    return CacheService.getRestaurantApplicationStatus();
  }

  static Future<bool> isRestaurantApplicationCompleted() async {
    return CacheService.isRestaurantApplicationCompleted();
  }

  static Future<bool> isFirstLaunch() async {
    return CacheService.isFirstLaunch();
  }

  static Future<void> setFirstLaunchComplete() async {
    await CacheService.setFirstLaunchComplete();
  }

  static Future<void> setLocationPermissionScreenShown() async {
    await CacheService.setLocationPermissionScreenShown();
  }

  static bool hasLocationPermissionScreenShown() {
    return CacheService.hasLocationPermissionScreenShown();
  }
}
