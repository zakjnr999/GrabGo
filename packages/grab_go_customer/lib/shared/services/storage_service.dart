import 'cache_service.dart';

class StorageService {

  // Save login credentials
  static Future<void> saveCredentials({
    required String email,
    required String password,
    required bool rememberMe,
  }) async {
    await CacheService.saveCredentials(
      email: email,
      password: password,
      rememberMe: rememberMe,
    );
  }

  // Load saved credentials
  static Future<Map<String, dynamic>> loadCredentials() async {
    return CacheService.getCredentials();
  }

  // Clear saved credentials
  static Future<void> clearCredentials() async {
    await CacheService.clearCredentials();
  }

  // Check if credentials are saved
  static Future<bool> hasRememberedCredentials() async {
    final credentials = CacheService.getCredentials();
    return credentials['rememberMe'] as bool? ?? false;
  }

  // Save restaurant application submitted status
  static Future<void> saveRestaurantApplicationSubmitted() async {
    await CacheService.saveRestaurantApplicationSubmitted();
  }

  // Check if restaurant application has been submitted
  static Future<bool> hasRestaurantApplicationSubmitted() async {
    return CacheService.hasRestaurantApplicationSubmitted();
  }

  // Clear restaurant application status (for testing or if needed)
  static Future<void> clearRestaurantApplicationStatus() async {
    // This functionality is handled by CacheService.clearAllCache() if needed
  }

  // Save restaurant application status (step)
  static Future<void> saveRestaurantApplicationStatus(String status) async {
    await CacheService.saveRestaurantApplicationStatus(status);
  }

  // Get restaurant application status
  static Future<String?> getRestaurantApplicationStatus() async {
    return CacheService.getRestaurantApplicationStatus();
  }

  // Check if restaurant application is completed (Account Active)
  static Future<bool> isRestaurantApplicationCompleted() async {
    return CacheService.isRestaurantApplicationCompleted();
  }

  // Check if this is the first time the app is launched
  static Future<bool> isFirstLaunch() async {
    return CacheService.isFirstLaunch();
  }

  // Mark that the app has been launched
  static Future<void> setFirstLaunchComplete() async {
    await CacheService.setFirstLaunchComplete();
  }
}



