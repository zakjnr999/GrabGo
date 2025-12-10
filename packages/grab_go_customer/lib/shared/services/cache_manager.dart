import 'package:flutter/foundation.dart';
import 'package:grab_go_shared/shared/services/cache_service.dart';

/// Cache management utility for handling cache operations
class CacheManager {
  /// Clear all cache data
  static Future<bool> clearAllCache() async {
    try {
      return await CacheService.clearAllCache();
    } catch (e) {
      if (kDebugMode) {
        print('Error clearing all cache: $e');
      }
      return false;
    }
  }

  /// Clear user-specific data (keep app settings)
  static Future<bool> clearUserData() async {
    try {
      return await CacheService.clearUserSpecificData();
    } catch (e) {
      if (kDebugMode) {
        print('Error clearing user data: $e');
      }
      return false;
    }
  }

  /// Clear expired cache data
  static Future<void> clearExpiredCache() async {
    try {
      // Clear expired restaurant cache
      if (!CacheService.isRestaurantsCacheValid()) {
        await CacheService.clearRestaurantsCache();
        if (kDebugMode) {
          print('Cleared expired restaurant cache');
        }
      }

      // Clear expired food categories cache
      if (!CacheService.isFoodCategoriesCacheValid()) {
        // Note: Food categories cache doesn't have a clear method,
        // but it will be refreshed on next fetch
        if (kDebugMode) {
          print('Food categories cache expired, will refresh on next fetch');
        }
      }

      // Clear expired location cache
      if (!CacheService.isLocationCacheValid()) {
        // Location cache doesn't have a clear method,
        // but it will be refreshed on next fetch
        if (kDebugMode) {
          print('Location cache expired, will refresh on next fetch');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error clearing expired cache: $e');
      }
    }
  }

  /// Get cache statistics
  static Future<Map<String, dynamic>> getCacheStatistics() async {
    try {
      final cacheSize = await CacheService.getCacheSize();
      final isCacheAvailable = CacheService.isCacheAvailable();

      return {
        'cacheSize': cacheSize,
        'isCacheAvailable': isCacheAvailable,
        'restaurantsCacheValid': CacheService.isRestaurantsCacheValid(),
        'foodCategoriesCacheValid': CacheService.isFoodCategoriesCacheValid(),
        'locationCacheValid': CacheService.isLocationCacheValid(),
        'hasUserData': CacheService.getUserData() != null,
        'hasAuthToken': await CacheService.getAuthToken() != null,
        'cartItemsCount': CacheService.getCartItems().length,
        'orderHistoryCount': CacheService.getOrderHistory().length,
        'searchHistoryCount': CacheService.getSearchHistory().length,
        'favoriteRestaurantsCount': CacheService.getFavoriteRestaurants().length,
      };
    } catch (e) {
      if (kDebugMode) {
        print('Error getting cache statistics: $e');
      }
      return {};
    }
  }

  /// Optimize cache (remove old data, keep recent)
  static Future<void> optimizeCache() async {
    try {
      // Limit search history to last 20 items
      final searchHistory = CacheService.getSearchHistory();
      if (searchHistory.length > 20) {
        final recentHistory = searchHistory.take(20).toList();
        await CacheService.saveSearchHistory(recentHistory);
        if (kDebugMode) {
          print('Optimized search history: ${searchHistory.length} -> ${recentHistory.length}');
        }
      }

      // Limit order history to last 50 items
      final orderHistory = CacheService.getOrderHistory();
      if (orderHistory.length > 50) {
        final recentOrders = orderHistory.take(50).toList();
        await CacheService.saveOrderHistory(recentOrders);
        if (kDebugMode) {
          print('Optimized order history: ${orderHistory.length} -> ${recentOrders.length}');
        }
      }

      // Clear expired cache
      await clearExpiredCache();

      if (kDebugMode) {
        print('Cache optimization completed');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error optimizing cache: $e');
      }
    }
  }

  /// Preload essential data
  static Future<void> preloadEssentialData() async {
    try {
      // Preload user data if available
      final userData = CacheService.getUserData();
      if (userData != null) {
        if (kDebugMode) {
          print('Preloaded user data');
        }
      }

      // Preload cart data
      final cartItems = CacheService.getCartItems();
      if (cartItems.isNotEmpty) {
        if (kDebugMode) {
          print('Preloaded ${cartItems.length} cart items');
        }
      }

      // Preload location data if valid
      if (CacheService.isLocationCacheValid()) {
        final location = CacheService.getUserLocation();
        if (location != null) {
          if (kDebugMode) {
            print('Preloaded location data');
          }
        }
      }

      if (kDebugMode) {
        print('Essential data preloading completed');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error preloading essential data: $e');
      }
    }
  }

  /// Backup cache data (for debugging or migration)
  static Future<Map<String, dynamic>> backupCacheData() async {
    try {
      return {
        'userData': CacheService.getUserData(),
        'cartItems': CacheService.getCartItems(),
        'restaurants': CacheService.getRestaurants(),
        'foodCategories': CacheService.getFoodCategories(),
        'orderHistory': CacheService.getOrderHistory(),
        'searchHistory': CacheService.getSearchHistory(),
        'favoriteRestaurants': CacheService.getFavoriteRestaurants(),
        'userLocation': CacheService.getUserLocation(),
        'themeMode': CacheService.getThemeMode(),
        'language': CacheService.getLanguage(),
        'notificationSettings': CacheService.getNotificationSettings(),
        'credentials': await CacheService.getCredentials(),
        'restaurantApplicationStatus': CacheService.getRestaurantApplicationStatus(),
        'isFirstLaunch': CacheService.isFirstLaunch(),
        'lastAppVersion': CacheService.getLastAppVersion(),
      };
    } catch (e) {
      if (kDebugMode) {
        print('Error backing up cache data: $e');
      }
      return {};
    }
  }

  /// Restore cache data (for debugging or migration)
  static Future<bool> restoreCacheData(Map<String, dynamic> backupData) async {
    try {
      if (backupData['userData'] != null) {
        await CacheService.saveUserData(backupData['userData']);
      }

      if (backupData['cartItems'] != null) {
        await CacheService.saveCartItems(backupData['cartItems']);
      }

      if (backupData['restaurants'] != null) {
        await CacheService.saveRestaurants(backupData['restaurants']);
      }

      if (backupData['foodCategories'] != null) {
        await CacheService.saveFoodCategories(backupData['foodCategories']);
      }

      if (backupData['orderHistory'] != null) {
        await CacheService.saveOrderHistory(backupData['orderHistory']);
      }

      if (backupData['searchHistory'] != null) {
        await CacheService.saveSearchHistory(backupData['searchHistory']);
      }

      if (backupData['favoriteRestaurants'] != null) {
        await CacheService.saveFavoriteRestaurants(backupData['favoriteRestaurants']);
      }

      if (backupData['userLocation'] != null) {
        final location = backupData['userLocation'];
        await CacheService.saveUserLocation(
          latitude: location['latitude'],
          longitude: location['longitude'],
          address: location['address'],
        );
      }

      if (backupData['themeMode'] != null) {
        await CacheService.saveThemeMode(backupData['themeMode']);
      }

      if (backupData['language'] != null) {
        await CacheService.saveLanguage(backupData['language']);
      }

      if (backupData['notificationSettings'] != null) {
        await CacheService.saveNotificationSettings(backupData['notificationSettings']);
      }

      if (backupData['credentials'] != null) {
        final credentials = backupData['credentials'];
        await CacheService.saveCredentials(
          email: credentials['email'],
          password: credentials['password'],
          rememberMe: credentials['rememberMe'],
        );
      }

      if (backupData['restaurantApplicationStatus'] != null) {
        await CacheService.saveRestaurantApplicationStatus(backupData['restaurantApplicationStatus']);
      }

      if (backupData['isFirstLaunch'] != null) {
        if (!backupData['isFirstLaunch']) {
          await CacheService.setFirstLaunchComplete();
        }
      }

      if (backupData['lastAppVersion'] != null) {
        await CacheService.saveLastAppVersion(backupData['lastAppVersion']);
      }

      if (kDebugMode) {
        print('Cache data restored successfully');
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error restoring cache data: $e');
      }
      return false;
    }
  }
}
