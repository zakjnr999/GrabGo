import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class CacheService {
  static SharedPreferences? _prefs;
  static const Duration _defaultCacheExpiry = Duration(hours: 24);

  static Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
  }

  static SharedPreferences get _instance {
    if (_prefs == null) {
      throw Exception('CacheService not initialized. Call initialize() first.');
    }
    return _prefs!;
  }

  static Future<bool> saveAuthToken(String token) async {
    try {
      return await _instance.setString('auth_token', token);
    } catch (e) {
      debugPrint('Error saving auth token: $e');
      return false;
    }
  }

  static String? getAuthToken() {
    try {
      return _instance.getString('auth_token');
    } catch (e) {
      debugPrint('Error getting auth token: $e');
      return null;
    }
  }

  static Future<bool> clearAuthToken() async {
    try {
      return await _instance.remove('auth_token');
    } catch (e) {
      debugPrint('Error clearing auth token: $e');
      return false;
    }
  }

  static Future<bool> saveUserData(Map<String, dynamic> userData) async {
    try {
      final userJson = jsonEncode(userData);
      return await _instance.setString('user_data', userJson);
    } catch (e) {
      debugPrint('Error saving user data: $e');
      return false;
    }
  }

  /// Get user data
  static Map<String, dynamic>? getUserData() {
    try {
      final userJson = _instance.getString('user_data');
      if (userJson != null) {
        return jsonDecode(userJson) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      debugPrint('Error getting user data: $e');
      return null;
    }
  }

  /// Clear user data
  static Future<bool> clearUserData() async {
    try {
      return await _instance.remove('user_data');
    } catch (e) {
      debugPrint('Error clearing user data: $e');
      return false;
    }
  }

  /// Save login credentials
  static Future<bool> saveCredentials({
    required String email,
    required String password,
    required bool rememberMe,
  }) async {
    try {
      await _instance.setBool('remember_me', rememberMe);

      if (rememberMe) {
        await _instance.setString('saved_email', email);
        await _instance.setString('saved_password', password);
      } else {
        await clearCredentials();
      }
      return true;
    } catch (e) {
      debugPrint('Error saving credentials: $e');
      return false;
    }
  }

  /// Get saved credentials
  static Map<String, dynamic> getCredentials() {
    try {
      final rememberMe = _instance.getBool('remember_me') ?? false;
      final email = _instance.getString('saved_email') ?? '';
      final password = _instance.getString('saved_password') ?? '';

      return {'rememberMe': rememberMe, 'email': email, 'password': password};
    } catch (e) {
      debugPrint('Error getting credentials: $e');
      return {'rememberMe': false, 'email': '', 'password': ''};
    }
  }

  /// Clear saved credentials
  static Future<bool> clearCredentials() async {
    try {
      await _instance.remove('saved_email');
      await _instance.remove('saved_password');
      await _instance.setBool('remember_me', false);
      return true;
    } catch (e) {
      debugPrint('Error clearing credentials: $e');
      return false;
    }
  }

  // ==================== CART CACHING ====================

  /// Save cart items
  static Future<bool> saveCartItems(List<Map<String, dynamic>> cartItems) async {
    try {
      final cartJson = jsonEncode(cartItems);
      return await _instance.setString('cart_items', cartJson);
    } catch (e) {
      debugPrint('Error saving cart items: $e');
      return false;
    }
  }

  /// Get cart items
  static List<Map<String, dynamic>> getCartItems() {
    try {
      final cartJson = _instance.getString('cart_items');
      if (cartJson != null) {
        final List<dynamic> cartList = jsonDecode(cartJson);
        return cartList.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      debugPrint('Error getting cart items: $e');
      return [];
    }
  }

  /// Clear cart items
  static Future<bool> clearCartItems() async {
    try {
      return await _instance.remove('cart_items');
    } catch (e) {
      debugPrint('Error clearing cart items: $e');
      return false;
    }
  }

  // ==================== RESTAURANT CACHING ====================

  /// Save restaurants data
  static Future<bool> saveRestaurants(List<Map<String, dynamic>> restaurants) async {
    try {
      final restaurantsJson = jsonEncode(restaurants);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      await _instance.setString('restaurants_data', restaurantsJson);
      await _instance.setInt('restaurants_cache_timestamp', timestamp);
      return true;
    } catch (e) {
      debugPrint('Error saving restaurants: $e');
      return false;
    }
  }

  /// Get restaurants data
  static List<Map<String, dynamic>> getRestaurants() {
    try {
      final restaurantsJson = _instance.getString('restaurants_data');
      if (restaurantsJson != null) {
        final List<dynamic> restaurantsList = jsonDecode(restaurantsJson);
        return restaurantsList.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      debugPrint('Error getting restaurants: $e');
      return [];
    }
  }

  /// Check if restaurants cache is valid (not expired)
  static bool isRestaurantsCacheValid() {
    try {
      final timestamp = _instance.getInt('restaurants_cache_timestamp') ?? 0;
      final cacheTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      final now = DateTime.now();
      return now.difference(cacheTime) < _defaultCacheExpiry;
    } catch (e) {
      debugPrint('Error checking restaurants cache validity: $e');
      return false;
    }
  }

  /// Clear restaurants cache
  static Future<bool> clearRestaurantsCache() async {
    try {
      await _instance.remove('restaurants_data');
      await _instance.remove('restaurants_cache_timestamp');
      return true;
    } catch (e) {
      debugPrint('Error clearing restaurants cache: $e');
      return false;
    }
  }

  // ==================== FOOD/MENU CACHING ====================

  /// Save food categories
  static Future<bool> saveFoodCategories(List<Map<String, dynamic>> categories) async {
    try {
      final categoriesJson = jsonEncode(categories);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      await _instance.setString('food_categories', categoriesJson);
      await _instance.setInt('food_categories_cache_timestamp', timestamp);
      return true;
    } catch (e) {
      debugPrint('Error saving food categories: $e');
      return false;
    }
  }

  /// Get food categories
  static List<Map<String, dynamic>> getFoodCategories() {
    try {
      final categoriesJson = _instance.getString('food_categories');
      if (categoriesJson != null) {
        final List<dynamic> categoriesList = jsonDecode(categoriesJson);
        return categoriesList.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      debugPrint('Error getting food categories: $e');
      return [];
    }
  }

  /// Check if food categories cache is valid
  static bool isFoodCategoriesCacheValid() {
    try {
      final timestamp = _instance.getInt('food_categories_cache_timestamp') ?? 0;
      final cacheTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      final now = DateTime.now();
      return now.difference(cacheTime) < _defaultCacheExpiry;
    } catch (e) {
      debugPrint('Error checking food categories cache validity: $e');
      return false;
    }
  }

  // ==================== ORDER CACHING ====================

  /// Save order history
  static Future<bool> saveOrderHistory(List<Map<String, dynamic>> orders) async {
    try {
      final ordersJson = jsonEncode(orders);
      return await _instance.setString('order_history', ordersJson);
    } catch (e) {
      debugPrint('Error saving order history: $e');
      return false;
    }
  }

  /// Get order history
  static List<Map<String, dynamic>> getOrderHistory() {
    try {
      final ordersJson = _instance.getString('order_history');
      if (ordersJson != null) {
        final List<dynamic> ordersList = jsonDecode(ordersJson);
        return ordersList.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      debugPrint('Error getting order history: $e');
      return [];
    }
  }

  /// Add single order to history
  static Future<bool> addOrderToHistory(Map<String, dynamic> order) async {
    try {
      final currentOrders = getOrderHistory();
      currentOrders.insert(0, order); // Add to beginning

      // Keep only last 50 orders
      if (currentOrders.length > 50) {
        currentOrders.removeRange(50, currentOrders.length);
      }

      return await saveOrderHistory(currentOrders);
    } catch (e) {
      debugPrint('Error adding order to history: $e');
      return false;
    }
  }

  /// Clear order history
  static Future<bool> clearOrderHistory() async {
    try {
      return await _instance.remove('order_history');
    } catch (e) {
      debugPrint('Error clearing order history: $e');
      return false;
    }
  }

  // ==================== APP SETTINGS CACHING ====================

  /// Save theme mode
  static Future<bool> saveThemeMode(int themeModeIndex) async {
    try {
      return await _instance.setInt('theme_mode', themeModeIndex);
    } catch (e) {
      debugPrint('Error saving theme mode: $e');
      return false;
    }
  }

  /// Get theme mode
  static int getThemeMode() {
    try {
      return _instance.getInt('theme_mode') ?? 0;
    } catch (e) {
      debugPrint('Error getting theme mode: $e');
      return 0;
    }
  }

  /// Save language preference
  static Future<bool> saveLanguage(String languageCode) async {
    try {
      return await _instance.setString('language', languageCode);
    } catch (e) {
      debugPrint('Error saving language: $e');
      return false;
    }
  }

  /// Get language preference
  static String getLanguage() {
    try {
      return _instance.getString('language') ?? 'en';
    } catch (e) {
      debugPrint('Error getting language: $e');
      return 'en';
    }
  }

  /// Save notification preferences
  static Future<bool> saveNotificationSettings(Map<String, bool> settings) async {
    try {
      final settingsJson = jsonEncode(settings);
      return await _instance.setString('notification_settings', settingsJson);
    } catch (e) {
      debugPrint('Error saving notification settings: $e');
      return false;
    }
  }

  /// Get notification preferences
  static Map<String, bool> getNotificationSettings() {
    try {
      final settingsJson = _instance.getString('notification_settings');
      if (settingsJson != null) {
        final Map<String, dynamic> settings = jsonDecode(settingsJson);
        return settings.cast<String, bool>();
      }
      return {'push_notifications': true, 'email_notifications': true, 'order_updates': true, 'promotions': true};
    } catch (e) {
      debugPrint('Error getting notification settings: $e');
      return {'push_notifications': true, 'email_notifications': true, 'order_updates': true, 'promotions': true};
    }
  }

  // ==================== LOCATION CACHING ====================

  /// Save user location
  static Future<bool> saveUserLocation({
    required double latitude,
    required double longitude,
    required String address,
  }) async {
    try {
      final locationData = {
        'latitude': latitude,
        'longitude': longitude,
        'address': address,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
      final locationJson = jsonEncode(locationData);
      return await _instance.setString('user_location', locationJson);
    } catch (e) {
      debugPrint('Error saving user location: $e');
      return false;
    }
  }

  /// Get user location
  static Map<String, dynamic>? getUserLocation() {
    try {
      final locationJson = _instance.getString('user_location');
      if (locationJson != null) {
        return jsonDecode(locationJson) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      debugPrint('Error getting user location: $e');
      return null;
    }
  }

  /// Check if location cache is valid (not older than 1 hour)
  static bool isLocationCacheValid() {
    try {
      final location = getUserLocation();
      if (location == null) return false;

      final timestamp = location['timestamp'] as int? ?? 0;
      final locationTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      final now = DateTime.now();
      return now.difference(locationTime) < const Duration(hours: 1);
    } catch (e) {
      debugPrint('Error checking location cache validity: $e');
      return false;
    }
  }

  // ==================== RESTAURANT APPLICATION CACHING ====================

  /// Save restaurant application status
  static Future<bool> saveRestaurantApplicationStatus(String status) async {
    try {
      return await _instance.setString('restaurant_application_status', status);
    } catch (e) {
      debugPrint('Error saving restaurant application status: $e');
      return false;
    }
  }

  /// Get restaurant application status
  static String? getRestaurantApplicationStatus() {
    try {
      return _instance.getString('restaurant_application_status');
    } catch (e) {
      debugPrint('Error getting restaurant application status: $e');
      return null;
    }
  }

  /// Save restaurant application submitted status
  static Future<bool> saveRestaurantApplicationSubmitted() async {
    try {
      return await _instance.setBool('restaurant_application_submitted', true);
    } catch (e) {
      debugPrint('Error saving restaurant application submitted: $e');
      return false;
    }
  }

  /// Check if restaurant application has been submitted
  static bool hasRestaurantApplicationSubmitted() {
    try {
      return _instance.getBool('restaurant_application_submitted') ?? false;
    } catch (e) {
      debugPrint('Error checking restaurant application submitted: $e');
      return false;
    }
  }

  /// Check if restaurant application is completed
  static bool isRestaurantApplicationCompleted() {
    try {
      final status = getRestaurantApplicationStatus();
      return status == 'Account Active';
    } catch (e) {
      debugPrint('Error checking restaurant application completed: $e');
      return false;
    }
  }

  // ==================== RIDER DATA CACHING ====================

  /// Save vehicle type
  static Future<bool> saveVehicleType(String vehicleType) async {
    try {
      return await _instance.setString('vehicle_type', vehicleType);
    } catch (e) {
      debugPrint('Error saving vehicle type: $e');
      return false;
    }
  }

  /// Get vehicle type
  static String? getVehicleType() {
    try {
      return _instance.getString('vehicle_type');
    } catch (e) {
      debugPrint('Error getting vehicle type: $e');
      return null;
    }
  }

  /// Clear vehicle type
  static Future<bool> clearVehicleType() async {
    try {
      return await _instance.remove('vehicle_type');
    } catch (e) {
      debugPrint('Error clearing vehicle type: $e');
      return false;
    }
  }

  // ==================== APP STATE CACHING ====================

  /// Save first launch status
  static Future<bool> setFirstLaunchComplete() async {
    try {
      return await _instance.setBool('is_first_launch', false);
    } catch (e) {
      debugPrint('Error setting first launch complete: $e');
      return false;
    }
  }

  /// Check if this is the first launch
  static bool isFirstLaunch() {
    try {
      return _instance.getBool('is_first_launch') ?? true;
    } catch (e) {
      debugPrint('Error checking first launch: $e');
      return true;
    }
  }

  /// Save last app version
  static Future<bool> saveLastAppVersion(String version) async {
    try {
      return await _instance.setString('last_app_version', version);
    } catch (e) {
      debugPrint('Error saving last app version: $e');
      return false;
    }
  }

  /// Get last app version
  static String? getLastAppVersion() {
    try {
      return _instance.getString('last_app_version');
    } catch (e) {
      debugPrint('Error getting last app version: $e');
      return null;
    }
  }

  // ==================== SEARCH HISTORY CACHING ====================

  /// Save search history
  static Future<bool> saveSearchHistory(List<String> searchTerms) async {
    try {
      final searchJson = jsonEncode(searchTerms);
      return await _instance.setString('search_history', searchJson);
    } catch (e) {
      debugPrint('Error saving search history: $e');
      return false;
    }
  }

  /// Get search history
  static List<String> getSearchHistory() {
    try {
      final searchJson = _instance.getString('search_history');
      if (searchJson != null) {
        final List<dynamic> searchList = jsonDecode(searchJson);
        return searchList.cast<String>();
      }
      return [];
    } catch (e) {
      debugPrint('Error getting search history: $e');
      return [];
    }
  }

  /// Add search term to history
  static Future<bool> addSearchTerm(String term) async {
    try {
      final currentHistory = getSearchHistory();
      currentHistory.remove(term); // Remove if exists
      currentHistory.insert(0, term); // Add to beginning

      // Keep only last 20 search terms
      if (currentHistory.length > 20) {
        currentHistory.removeRange(20, currentHistory.length);
      }

      return await saveSearchHistory(currentHistory);
    } catch (e) {
      debugPrint('Error adding search term: $e');
      return false;
    }
  }

  /// Clear search history
  static Future<bool> clearSearchHistory() async {
    try {
      return await _instance.remove('search_history');
    } catch (e) {
      debugPrint('Error clearing search history: $e');
      return false;
    }
  }

  // ==================== FAVORITES CACHING ====================

  /// Save favorite restaurants
  static Future<bool> saveFavoriteRestaurants(List<String> restaurantIds) async {
    try {
      final favoritesJson = jsonEncode(restaurantIds);
      return await _instance.setString('favorite_restaurants', favoritesJson);
    } catch (e) {
      debugPrint('Error saving favorite restaurants: $e');
      return false;
    }
  }

  /// Get favorite restaurants
  static List<String> getFavoriteRestaurants() {
    try {
      final favoritesJson = _instance.getString('favorite_restaurants');
      if (favoritesJson != null) {
        final List<dynamic> favoritesList = jsonDecode(favoritesJson);
        return favoritesList.cast<String>();
      }
      return [];
    } catch (e) {
      debugPrint('Error getting favorite restaurants: $e');
      return [];
    }
  }

  /// Add restaurant to favorites
  static Future<bool> addFavoriteRestaurant(String restaurantId) async {
    try {
      final currentFavorites = getFavoriteRestaurants();
      if (!currentFavorites.contains(restaurantId)) {
        currentFavorites.add(restaurantId);
        return await saveFavoriteRestaurants(currentFavorites);
      }
      return true;
    } catch (e) {
      debugPrint('Error adding favorite restaurant: $e');
      return false;
    }
  }

  /// Remove restaurant from favorites
  static Future<bool> removeFavoriteRestaurant(String restaurantId) async {
    try {
      final currentFavorites = getFavoriteRestaurants();
      currentFavorites.remove(restaurantId);
      return await saveFavoriteRestaurants(currentFavorites);
    } catch (e) {
      debugPrint('Error removing favorite restaurant: $e');
      return false;
    }
  }

  /// Check if restaurant is favorite
  static bool isFavoriteRestaurant(String restaurantId) {
    try {
      final favorites = getFavoriteRestaurants();
      return favorites.contains(restaurantId);
    } catch (e) {
      debugPrint('Error checking favorite restaurant: $e');
      return false;
    }
  }

  // ==================== FAVORITE FOODS CACHING ====================

  /// Save favorite foods
  static Future<bool> saveFavoriteFoods(List<Map<String, dynamic>> favoriteFoods) async {
    try {
      final favoritesJson = jsonEncode(favoriteFoods);
      return await _instance.setString('favorite_foods', favoritesJson);
    } catch (e) {
      debugPrint('Error saving favorite foods: $e');
      return false;
    }
  }

  /// Get favorite foods
  static List<Map<String, dynamic>> getFavoriteFoods() {
    try {
      final favoritesJson = _instance.getString('favorite_foods');
      if (favoritesJson != null) {
        final List<dynamic> favoritesList = jsonDecode(favoritesJson);
        return favoritesList.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      debugPrint('Error getting favorite foods: $e');
      return [];
    }
  }

  /// Add favorite food
  static Future<bool> addFavoriteFood(Map<String, dynamic> foodItem) async {
    try {
      final currentFavorites = getFavoriteFoods();
      // Check if food item already exists (by name and sellerId)
      final exists = currentFavorites.any(
        (item) => item['name'] == foodItem['name'] && item['sellerId'] == foodItem['sellerId'],
      );

      if (!exists) {
        currentFavorites.add(foodItem);
        return await saveFavoriteFoods(currentFavorites);
      }
      return true; // Already exists
    } catch (e) {
      debugPrint('Error adding favorite food: $e');
      return false;
    }
  }

  /// Remove favorite food
  static Future<bool> removeFavoriteFood(Map<String, dynamic> foodItem) async {
    try {
      final currentFavorites = getFavoriteFoods();
      currentFavorites.removeWhere(
        (item) => item['name'] == foodItem['name'] && item['sellerId'] == foodItem['sellerId'],
      );
      return await saveFavoriteFoods(currentFavorites);
    } catch (e) {
      debugPrint('Error removing favorite food: $e');
      return false;
    }
  }

  /// Check if food is favorite
  static bool isFavoriteFood(Map<String, dynamic> foodItem) {
    try {
      final favorites = getFavoriteFoods();
      return favorites.any((item) => item['name'] == foodItem['name'] && item['sellerId'] == foodItem['sellerId']);
    } catch (e) {
      debugPrint('Error checking favorite food: $e');
      return false;
    }
  }

  /// Clear favorite foods
  static Future<bool> clearFavoriteFoods() async {
    try {
      return await _instance.remove('favorite_foods');
    } catch (e) {
      debugPrint('Error clearing favorite foods: $e');
      return false;
    }
  }

  // ==================== UTILITY METHODS ====================

  /// Clear all cache data
  static Future<bool> clearAllCache() async {
    try {
      return await _instance.clear();
    } catch (e) {
      debugPrint('Error clearing all cache: $e');
      return false;
    }
  }

  /// Clear user-specific data (keep app settings)
  static Future<bool> clearUserSpecificData() async {
    try {
      await clearAuthToken();
      await clearUserData();
      await clearCredentials();
      await clearCartItems();
      await clearOrderHistory();
      await clearSearchHistory();
      await _clearFavoriteRestaurants();
      await clearFavoriteFoods();
      return true;
    } catch (e) {
      debugPrint('Error clearing user data: $e');
      return false;
    }
  }

  /// Clear favorite restaurants (private method)
  static Future<bool> _clearFavoriteRestaurants() async {
    try {
      return await _instance.remove('favorite_restaurants');
    } catch (e) {
      debugPrint('Error clearing favorite restaurants: $e');
      return false;
    }
  }

  /// Get cache size (approximate)
  static Future<int> getCacheSize() async {
    try {
      final keys = _instance.getKeys();
      int totalSize = 0;
      for (String key in keys) {
        final value = _instance.getString(key);
        if (value != null) {
          totalSize += value.length;
        }
      }
      return totalSize;
    } catch (e) {
      debugPrint('Error getting cache size: $e');
      return 0;
    }
  }

  /// Check if cache is available
  static bool isCacheAvailable() {
    return _prefs != null;
  }
}
