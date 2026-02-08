import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'secure_storage_service.dart';

class CacheService {
  static SharedPreferences? _prefs;
  static const Duration _defaultCacheExpiry = Duration(hours: 24);

  /// Cache version - increment this when data structure changes
  static const int CACHE_VERSION = 1;
  static const String _cacheVersionKey = 'cache_version';

  /// Initialize the cache service
  static Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    await _checkCacheVersion();
  }

  /// Check cache version and clear if mismatch
  static Future<void> _checkCacheVersion() async {
    try {
      final storedVersion = _instance.getInt(_cacheVersionKey) ?? 0;

      if (storedVersion != CACHE_VERSION) {
        if (kDebugMode) {
          print('⚠️ Cache version mismatch (stored: $storedVersion, current: $CACHE_VERSION)');
          print('🗑️ Clearing all cache data...');
        }

        // Clear all cache data
        await clearFoodCategoriesCache();
        await clearRestaurantsCache();
        await clearChatList();
        await clearAllVendorsCache();
        await clearGroceryCache();

        // Update version
        await _instance.setInt(_cacheVersionKey, CACHE_VERSION);

        if (kDebugMode) {
          print('✅ Cache cleared and version updated to $CACHE_VERSION');
        }
      } else {
        if (kDebugMode) {
          print('✅ Cache version $CACHE_VERSION is current');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error checking cache version: $e');
      }
    }
  }


  /// Get SharedPreferences instance
  static SharedPreferences get _instance {
    if (_prefs == null) {
      throw Exception('CacheService not initialized. Call initialize() first.');
    }
    return _prefs!;
  }

  /// Save generic string data
  static Future<bool> saveData(String key, String value) async {
    try {
      return await _instance.setString(key, value);
    } catch (e) {
      debugPrint('Error saving data to cache: $e');
      return false;
    }
  }

  /// Get generic string data
  static String? getData(String key) {
    try {
      return _instance.getString(key);
    } catch (e) {
      debugPrint('Error getting data from cache: $e');
      return null;
    }
  }

  // ==================== CACHE AGE UTILITIES ====================
  
  /// Check if cache is stale based on timestamp key and max age
  static bool isCacheStale(String timestampKey, Duration maxAge) {
    try {
      final timestamp = _instance.getInt(timestampKey) ?? 0;
      if (timestamp == 0) return true; // No cache exists
      
      final cacheDate = DateTime.fromMillisecondsSinceEpoch(timestamp);
      final age = DateTime.now().difference(cacheDate);
      
      return age > maxAge;
    } catch (e) {
      if (kDebugMode) {
        print('Error checking cache age for $timestampKey: $e');
      }
      return true; // Treat errors as stale
    }
  }

  /// Get cache age in minutes
  static int getCacheAgeInMinutes(String timestampKey) {
    try {
      final timestamp = _instance.getInt(timestampKey) ?? 0;
      if (timestamp == 0) return -1; // No cache
      
      final cacheDate = DateTime.fromMillisecondsSinceEpoch(timestamp);
      final age = DateTime.now().difference(cacheDate);
      
      return age.inMinutes;
    } catch (e) {
      return -1;
    }
  }

  /// Get human-readable cache age string
  static String getCacheAgeString(String timestampKey) {
    final minutes = getCacheAgeInMinutes(timestampKey);
    if (minutes < 0) return 'No cache';
    if (minutes == 0) return 'Just now';
    if (minutes < 60) return '$minutes min${minutes > 1 ? 's' : ''} ago';
    
    final hours = minutes ~/ 60;
    if (hours < 24) return '$hours hour${hours > 1 ? 's' : ''} ago';
    
    final days = hours ~/ 24;
    return '$days day${days > 1 ? 's' : ''} ago';
  }

  // ==================== CACHE TIMESTAMP KEYS ====================
  
  /// Timestamp keys for different cache types
  static const String foodCategoriesTimestampKey = 'food_categories_cache_timestamp';
  static const String foodDealsTimestampKey = 'food_deals_cache_timestamp';
  static const String popularItemsTimestampKey = 'popular_items_cache_timestamp';
  static const String topRatedItemsTimestampKey = 'top_rated_items_cache_timestamp';
  static const String recommendedItemsTimestampKey = 'recommended_items_cache_timestamp';
  static const String promotionalBannersTimestampKey = 'promotional_banners_cache_timestamp';
  static const String restaurantsTimestampKey = 'restaurants_cache_timestamp';
  
  static const String groceryCategoriesTimestampKey = 'grocery_categories_cache_timestamp';
  static const String groceryStoresTimestampKey = 'grocery_stores_cache_timestamp';
  static const String groceryItemsTimestampKey = 'grocery_items_cache_timestamp';
  static const String groceryDealsTimestampKey = 'grocery_deals_cache_timestamp';
  
  static const String pharmacyCategoriesTimestampKey = 'pharmacy_categories_cache_timestamp';
  static const String pharmacyItemsTimestampKey = 'pharmacy_items_cache_timestamp';
  
  static const String grabmartCategoriesTimestampKey = 'grabmart_categories_cache_timestamp';
  static const String grabmartItemsTimestampKey = 'grabmart_items_cache_timestamp';

  /// Save user authentication token (delegates to SecureStorageService)
  static Future<bool> saveAuthToken(String token) async {
    try {
      return await SecureStorageService.saveAuthToken(token);
    } catch (e) {
      debugPrint('Error saving auth token: $e');
      return false;
    }
  }

  /// Get user authentication token (delegates to SecureStorageService)
  static Future<String?> getAuthToken() async {
    try {
      return await SecureStorageService.getAuthToken();
    } catch (e) {
      debugPrint('Error getting auth token: $e');
      return null;
    }
  }

  /// Clear authentication token (delegates to SecureStorageService)
  static Future<bool> clearAuthToken() async {
    try {
      return await SecureStorageService.clearAuthToken();
    } catch (e) {
      debugPrint('Error clearing auth token: $e');
      return false;
    }
  }

  /// Save user data
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

  /// Save login credentials (delegates to SecureStorageService)
  static Future<bool> saveCredentials({
    required String email,
    required String password,
    required bool rememberMe,
  }) async {
    try {
      return await SecureStorageService.saveCredentials(email: email, password: password, rememberMe: rememberMe);
    } catch (e) {
      debugPrint('Error saving credentials: $e');
      return false;
    }
  }

  /// Get saved credentials (delegates to SecureStorageService)
  static Future<Map<String, dynamic>> getCredentials() async {
    try {
      return await SecureStorageService.getCredentials();
    } catch (e) {
      debugPrint('Error getting credentials: $e');
      return {'rememberMe': false, 'email': '', 'password': ''};
    }
  }

  /// Clear saved credentials (delegates to SecureStorageService)
  static Future<bool> clearCredentials() async {
    try {
      return await SecureStorageService.clearCredentials();
    } catch (e) {
      debugPrint('Error clearing credentials: $e');
      return false;
    }
  }

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

  /// Save vendors by type
  static Future<bool> saveVendorsByType(String type, List<Map<String, dynamic>> vendors) async {
    try {
      final vendorsJson = jsonEncode(vendors);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      await _instance.setString('vendors_data_$type', vendorsJson);
      await _instance.setInt('vendors_cache_timestamp_$type', timestamp);
      return true;
    } catch (e) {
      debugPrint('Error saving vendors for $type: $e');
      return false;
    }
  }

  /// Get vendors by type
  static List<Map<String, dynamic>> getVendorsByType(String type) {
    try {
      final vendorsJson = _instance.getString('vendors_data_$type');
      if (vendorsJson != null) {
        final List<dynamic> vendorsList = jsonDecode(vendorsJson);
        return vendorsList.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('Error getting vendors for $type: $e');
      return [];
    }
  }

  /// Clear all vendors cache
  static Future<void> clearAllVendorsCache() async {
    try {
      final keys = _instance.getKeys();
      final vendorKeys = keys.where((k) => k.startsWith('vendors_data_') || k.startsWith('vendors_cache_timestamp_'));
      for (final key in vendorKeys) {
        await _instance.remove(key);
      }
    } catch (e) {
      debugPrint('Error clearing all vendors cache: $e');
    }
  }

  /// Check if vendors cache is valid for a specific type
  static bool isVendorsCacheValid(String type) {
    try {
      final timestamp = _instance.getInt('vendors_cache_timestamp_$type') ?? 0;
      final cacheTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      final now = DateTime.now();
      return now.difference(cacheTime) < _defaultCacheExpiry;
    } catch (e) {
      debugPrint('Error checking vendors cache validity for $type: $e');
      return false;
    }
  }

  /// Clear vendors cache for a specific type
  static Future<bool> clearVendorsCache(String type) async {
    try {
      await _instance.remove('vendors_data_$type');
      await _instance.remove('vendors_cache_timestamp_$type');
      return true;
    } catch (e) {
      debugPrint('Error clearing vendors cache for $type: $e');
      return false;
    }
  }

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

  /// Save food deals
  static Future<bool> saveFoodDeals(List<Map<String, dynamic>> deals) async {
    try {
      final dealsJson = jsonEncode(deals);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      await _instance.setString('food_deals', dealsJson);
      await _instance.setInt('food_deals_cache_timestamp', timestamp);
      return true;
    } catch (e) {
      debugPrint('Error saving food deals: $e');
      return false;
    }
  }

  /// Get food deals
  static List<Map<String, dynamic>> getFoodDeals() {
    try {
      final dealsJson = _instance.getString('food_deals');
      if (dealsJson != null) {
        final List<dynamic> dealsList = jsonDecode(dealsJson);
        return dealsList.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      debugPrint('Error getting food deals: $e');
      return [];
    }
  }

  /// Check if food deals cache is valid
  static bool isFoodDealsCacheValid() {
    try {
      final timestamp = _instance.getInt('food_deals_cache_timestamp') ?? 0;
      final cacheTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      final now = DateTime.now();
      return now.difference(cacheTime) < _defaultCacheExpiry;
    } catch (e) {
      return false;
    }
  }

  /// Save popular items
  static Future<bool> savePopularItems(List<Map<String, dynamic>> items) async {
    try {
      final itemsJson = jsonEncode(items);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      await _instance.setString('popular_items', itemsJson);
      await _instance.setInt('popular_items_cache_timestamp', timestamp);
      return true;
    } catch (e) {
      debugPrint('Error saving popular items: $e');
      return false;
    }
  }

  /// Get popular items
  static List<Map<String, dynamic>> getPopularItems() {
    try {
      final itemsJson = _instance.getString('popular_items');
      if (itemsJson != null) {
        final List<dynamic> itemsList = jsonDecode(itemsJson);
        return itemsList.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      debugPrint('Error getting popular items: $e');
      return [];
    }
  }

  /// Check if popular items cache is valid
  static bool isPopularItemsCacheValid() {
    try {
      final timestamp = _instance.getInt('popular_items_cache_timestamp') ?? 0;
      final cacheTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      final now = DateTime.now();
      return now.difference(cacheTime) < _defaultCacheExpiry;
    } catch (e) {
      return false;
    }
  }

  /// Save top rated items
  static Future<bool> saveTopRatedItems(List<Map<String, dynamic>> items) async {
    try {
      final itemsJson = jsonEncode(items);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      await _instance.setString('top_rated_items', itemsJson);
      await _instance.setInt('top_rated_items_cache_timestamp', timestamp);
      return true;
    } catch (e) {
      debugPrint('Error saving top rated items: $e');
      return false;
    }
  }

  /// Get top rated items
  static List<Map<String, dynamic>> getTopRatedItems() {
    try {
      final itemsJson = _instance.getString('top_rated_items');
      if (itemsJson != null) {
        final List<dynamic> itemsList = jsonDecode(itemsJson);
        return itemsList.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      debugPrint('Error getting top rated items: $e');
      return [];
    }
  }

  /// Check if top rated items cache is valid
  static bool isTopRatedItemsCacheValid() {
    try {
      final timestamp = _instance.getInt('top_rated_items_cache_timestamp') ?? 0;
      final cacheTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      final now = DateTime.now();
      return now.difference(cacheTime) < _defaultCacheExpiry;
    } catch (e) {
      return false;
    }
  }

  /// Save recommended items
  static void saveRecommendedItems(List<Map<String, dynamic>> items) {
    try {
      _instance.setString('recommended_items', jsonEncode(items));
      _instance.setInt('recommended_items_cache_timestamp', DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      debugPrint('Error saving recommended items: $e');
    }
  }

  /// Get recommended items
  static List<Map<String, dynamic>> getRecommendedItems() {
    try {
      final itemsJson = _instance.getString('recommended_items');
      if (itemsJson != null) {
        final List<dynamic> itemsList = jsonDecode(itemsJson);
        return itemsList.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      debugPrint('Error getting recommended items: $e');
      return [];
    }
  }

  /// Check if recommended items cache is valid
  static bool isRecommendedItemsCacheValid() {
    try {
      final timestamp = _instance.getInt('recommended_items_cache_timestamp') ?? 0;
      final cacheTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      final now = DateTime.now();
      return now.difference(cacheTime) < _defaultCacheExpiry;
    } catch (e) {
      return false;
    }
  }

  /// Save promotional banners
  static Future<bool> savePromotionalBanners(List<Map<String, dynamic>> banners) async {
    try {
      final bannersJson = jsonEncode(banners);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      await _instance.setString('promotional_banners', bannersJson);
      await _instance.setInt('promotional_banners_cache_timestamp', timestamp);
      return true;
    } catch (e) {
      debugPrint('Error saving promotional banners: $e');
      return false;
    }
  }

  /// Get promotional banners
  static List<Map<String, dynamic>> getPromotionalBanners() {
    try {
      final bannersJson = _instance.getString('promotional_banners');
      if (bannersJson != null) {
        final List<dynamic> bannersList = jsonDecode(bannersJson);
        return bannersList.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      debugPrint('Error getting promotional banners: $e');
      return [];
    }
  }

  /// Check if promotional banners cache is valid
  static bool isPromotionalBannersCacheValid() {
    try {
      final timestamp = _instance.getInt('promotional_banners_cache_timestamp') ?? 0;
      final cacheTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      final now = DateTime.now();
      return now.difference(cacheTime) < _defaultCacheExpiry;
    } catch (e) {
      return false;
    }
  }

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
      currentOrders.insert(0, order);

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

  /// Clear food categories cache
  static Future<void> clearFoodCategoriesCache() async {
    try {
      await _instance.remove('food_categories');
      await _instance.remove('food_categories_cache_timestamp');
      if (kDebugMode) {
        print('Food categories cache cleared');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error clearing food categories cache: $e');
      }
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

  /// Save recent order items (different from full history)
  static Future<bool> saveRecentOrderItems(List<Map<String, dynamic>> items) async {
    try {
      final itemsJson = jsonEncode(items);
      return await _instance.setString('recent_order_items', itemsJson);
    } catch (e) {
      debugPrint('Error saving recent order items: $e');
      return false;
    }
  }

  /// Get recent order items
  static List<Map<String, dynamic>> getRecentOrderItems() {
    try {
      final itemsJson = _instance.getString('recent_order_items');
      if (itemsJson != null) {
        final List<dynamic> itemsList = jsonDecode(itemsJson);
        return itemsList.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      debugPrint('Error getting recent order items: $e');
      return [];
    }
  }

  /// Save per-chat text draft
  static Future<bool> saveChatDraft(String chatId, String text) async {
    try {
      final key = 'chat_draft_$chatId';
      if (text.isEmpty) {
        return await _instance.remove(key);
      }
      return await _instance.setString(key, text);
    } catch (e) {
      debugPrint('Error saving chat draft: $e');
      return false;
    }
  }

  /// Get per-chat text draft
  static String getChatDraft(String chatId) {
    try {
      final key = 'chat_draft_$chatId';
      return _instance.getString(key) ?? '';
    } catch (e) {
      debugPrint('Error getting chat draft: $e');
      return '';
    }
  }

  /// Clear per-chat text draft
  static Future<bool> clearChatDraft(String chatId) async {
    try {
      final key = 'chat_draft_$chatId';
      return await _instance.remove(key);
    } catch (e) {
      debugPrint('Error clearing chat draft: $e');
      return false;
    }
  }

  /// Save per-chat last seen timestamp (for unread separators)
  static Future<bool> saveChatLastSeen(String chatId, DateTime timestamp) async {
    try {
      final key = 'chat_last_seen_$chatId';
      return await _instance.setInt(key, timestamp.millisecondsSinceEpoch);
    } catch (e) {
      debugPrint('Error saving chat last seen: $e');
      return false;
    }
  }

  /// Get per-chat last seen timestamp
  static DateTime? getChatLastSeen(String chatId) {
    try {
      final key = 'chat_last_seen_$chatId';
      final millis = _instance.getInt(key);
      if (millis == null) return null;
      return DateTime.fromMillisecondsSinceEpoch(millis);
    } catch (e) {
      debugPrint('Error getting chat last seen: $e');
      return null;
    }
  }

  /// Clear per-chat last seen timestamp
  static Future<bool> clearChatLastSeen(String chatId) async {
    try {
      final key = 'chat_last_seen_$chatId';
      return await _instance.remove(key);
    } catch (e) {
      debugPrint('Error clearing chat last seen: $e');
      return false;
    }
  }

  /// Save last known order status for a specific order
  static Future<bool> saveOrderLastStatus(String orderId, String status) async {
    try {
      final key = 'order_last_status_$orderId';
      return await _instance.setString(key, status);
    } catch (e) {
      debugPrint('Error saving order last status: $e');
      return false;
    }
  }

  /// Get last known order status for a specific order
  static String? getOrderLastStatus(String orderId) {
    try {
      final key = 'order_last_status_$orderId';
      return _instance.getString(key);
    } catch (e) {
      debugPrint('Error getting order last status: $e');
      return null;
    }
  }

  /// Clear last known order status for a specific order
  static Future<bool> clearOrderLastStatus(String orderId) async {
    try {
      final key = 'order_last_status_$orderId';
      return await _instance.remove(key);
    } catch (e) {
      debugPrint('Error clearing order last status: $e');
      return false;
    }
  }

  static Future<bool> saveChatList(List<Map<String, dynamic>> chats) async {
    try {
      final chatsJson = jsonEncode(chats);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      await _instance.setString('chat_list', chatsJson);
      await _instance.setInt('chat_list_cache_timestamp', timestamp);
      return true;
    } catch (e) {
      debugPrint('Error saving chat list: $e');
      return false;
    }
  }

  static List<Map<String, dynamic>> getChatList() {
    try {
      final chatsJson = _instance.getString('chat_list');
      if (chatsJson != null) {
        final decoded = jsonDecode(chatsJson);
        if (decoded is List) {
          return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        }
      }
      return [];
    } catch (e) {
      debugPrint('Error getting chat list: $e');
      return [];
    }
  }

  static Future<bool> clearChatList() async {
    try {
      await _instance.remove('chat_list');
      await _instance.remove('chat_list_cache_timestamp');
      return true;
    } catch (e) {
      debugPrint('Error clearing chat list: $e');
      return false;
    }
  }

  static Future<bool> saveChatUnreadCount(int count) async {
    try {
      return await _instance.setInt('chat_unread_count', count);
    } catch (e) {
      debugPrint('Error saving chat unread count: $e');
      return false;
    }
  }

  static int getChatUnreadCount() {
    try {
      return _instance.getInt('chat_unread_count') ?? 0;
    } catch (e) {
      debugPrint('Error getting chat unread count: $e');
      return 0;
    }
  }

  /// Save messages for a specific chat so the detail view can load instantly
  static Future<bool> saveChatMessages(String chatId, List<Map<String, dynamic>> messages) async {
    try {
      final key = 'chat_messages_$chatId';
      final json = jsonEncode(messages);
      return await _instance.setString(key, json);
    } catch (e) {
      debugPrint('Error saving chat messages: $e');
      return false;
    }
  }

  /// Get cached messages for a specific chat
  static List<Map<String, dynamic>> getChatMessages(String chatId) {
    try {
      final key = 'chat_messages_$chatId';
      final json = _instance.getString(key);
      if (json == null) return [];

      final decoded = jsonDecode(json);
      if (decoded is List) {
        return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('Error getting chat messages: $e');
      return [];
    }
  }

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

  /// Save location permission screen shown status
  static Future<bool> setLocationPermissionScreenShown() async {
    try {
      return await _instance.setBool('location_permission_screen_shown', true);
    } catch (e) {
      debugPrint('Error setting location permission screen shown: $e');
      return false;
    }
  }

  /// Check if location permission screen has been shown
  static bool hasLocationPermissionScreenShown() {
    try {
      return _instance.getBool('location_permission_screen_shown') ?? false;
    } catch (e) {
      debugPrint('Error checking location permission screen shown: $e');
      return false;
    }
  }

  /// Save notification permission screen shown status
  static Future<bool> setNotificationPermissionScreenShown() async {
    try {
      return await _instance.setBool('notification_permission_screen_shown', true);
    } catch (e) {
      debugPrint('Error setting notification permission screen shown: $e');
      return false;
    }
  }

  /// Check if notification permission screen has been shown
  static bool hasNotificationPermissionScreenShown() {
    try {
      return _instance.getBool('notification_permission_screen_shown') ?? false;
    } catch (e) {
      debugPrint('Error checking notification permission screen shown: $e');
      return false;
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
      currentHistory.remove(term);
      currentHistory.insert(0, term);

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
      return true;
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
      await clearAllVendorsCache();
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

  /// Save grocery categories
  static Future<bool> saveGroceryCategories(List<Map<String, dynamic>> categories) async {
    try {
      final categoriesJson = jsonEncode(categories);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      await _instance.setString('grocery_categories', categoriesJson);
      await _instance.setInt('grocery_categories_cache_timestamp', timestamp);
      return true;
    } catch (e) {
      debugPrint('Error saving grocery categories: $e');
      return false;
    }
  }

  /// Get grocery categories
  static List<Map<String, dynamic>> getGroceryCategories() {
    try {
      final categoriesJson = _instance.getString('grocery_categories');
      if (categoriesJson != null) {
        final List<dynamic> categoriesList = jsonDecode(categoriesJson);
        return categoriesList.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('Error getting grocery categories: $e');
      return [];
    }
  }

  /// Save grocery stores
  static Future<bool> saveGroceryStores(List<Map<String, dynamic>> stores) async {
    try {
      final storesJson = jsonEncode(stores);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      await _instance.setString('grocery_stores', storesJson);
      await _instance.setInt('grocery_stores_cache_timestamp', timestamp);
      return true;
    } catch (e) {
      debugPrint('Error saving grocery stores: $e');
      return false;
    }
  }

  /// Get grocery stores
  static List<Map<String, dynamic>> getGroceryStores() {
    try {
      final storesJson = _instance.getString('grocery_stores');
      if (storesJson != null) {
        final List<dynamic> storesList = jsonDecode(storesJson);
        return storesList.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('Error getting grocery stores: $e');
      return [];
    }
  }

  /// Save grocery items
  static Future<bool> saveGroceryItems(List<Map<String, dynamic>> items) async {
    try {
      final itemsJson = jsonEncode(items);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      await _instance.setString('grocery_items', itemsJson);
      await _instance.setInt('grocery_items_cache_timestamp', timestamp);
      return true;
    } catch (e) {
      debugPrint('Error saving grocery items: $e');
      return false;
    }
  }

  /// Get grocery items
  static List<Map<String, dynamic>> getGroceryItems() {
    try {
      final itemsJson = _instance.getString('grocery_items');
      if (itemsJson != null) {
        final List<dynamic> itemsList = jsonDecode(itemsJson);
        return itemsList.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('Error getting grocery items: $e');
      return [];
    }
  }

  /// Save grocery deals
  static Future<bool> saveGroceryDeals(List<Map<String, dynamic>> deals) async {
    try {
      final dealsJson = jsonEncode(deals);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      await _instance.setString('grocery_deals', dealsJson);
      await _instance.setInt('grocery_deals_cache_timestamp', timestamp);
      return true;
    } catch (e) {
      debugPrint('Error saving grocery deals: $e');
      return false;
    }
  }

  /// Get grocery deals
  static List<Map<String, dynamic>> getGroceryDeals() {
    try {
      final dealsJson = _instance.getString('grocery_deals');
      if (dealsJson != null) {
        final List<dynamic> dealsList = jsonDecode(dealsJson);
        return dealsList.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('Error getting grocery deals: $e');
      return [];
    }
  }

  /// Save grocery popular items
  static Future<bool> saveGroceryPopularItems(List<Map<String, dynamic>> items) async {
    try {
      final itemsJson = jsonEncode(items);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      await _instance.setString('grocery_popular_items', itemsJson);
      await _instance.setInt('grocery_popular_items_cache_timestamp', timestamp);
      return true;
    } catch (e) {
      debugPrint('Error saving grocery popular items: $e');
      return false;
    }
  }

  /// Get grocery popular items
  static List<Map<String, dynamic>> getGroceryPopularItems() {
    try {
      final itemsJson = _instance.getString('grocery_popular_items');
      if (itemsJson != null) {
        final List<dynamic> itemsList = jsonDecode(itemsJson);
        return itemsList.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('Error getting grocery popular items: $e');
      return [];
    }
  }

  /// Save grocery top rated items
  static Future<bool> saveGroceryTopRatedItems(List<Map<String, dynamic>> items) async {
    try {
      final itemsJson = jsonEncode(items);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      await _instance.setString('grocery_top_rated_items', itemsJson);
      await _instance.setInt('grocery_top_rated_items_cache_timestamp', timestamp);
      return true;
    } catch (e) {
      debugPrint('Error saving grocery top rated items: $e');
      return false;
    }
  }

  /// Get grocery top rated items
  static List<Map<String, dynamic>> getGroceryTopRatedItems() {
    try {
      final itemsJson = _instance.getString('grocery_top_rated_items');
      if (itemsJson != null) {
        final List<dynamic> itemsList = jsonDecode(itemsJson);
        return itemsList.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('Error getting grocery top rated items: $e');
      return [];
    }
  }

  /// Save grocery buy again items
  static Future<bool> saveGroceryBuyAgainItems(List<Map<String, dynamic>> items) async {
    try {
      final itemsJson = jsonEncode(items);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      await _instance.setString('grocery_buy_again_items', itemsJson);
      await _instance.setInt('grocery_buy_again_items_cache_timestamp', timestamp);
      return true;
    } catch (e) {
      debugPrint('Error saving grocery buy again items: $e');
      return false;
    }
  }

  /// Get grocery buy again items
  static List<Map<String, dynamic>> getGroceryBuyAgainItems() {
    try {
      final itemsJson = _instance.getString('grocery_buy_again_items');
      if (itemsJson != null) {
        final List<dynamic> itemsList = jsonDecode(itemsJson);
        return itemsList.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('Error getting grocery buy again items: $e');
      return [];
    }
  }

  /// Save grocery store specials
  static Future<bool> saveGroceryStoreSpecials(List<Map<String, dynamic>> specials) async {
    try {
      final specialsJson = jsonEncode(specials);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      await _instance.setString('grocery_store_specials', specialsJson);
      await _instance.setInt('grocery_store_specials_cache_timestamp', timestamp);
      return true;
    } catch (e) {
      debugPrint('Error saving grocery store specials: $e');
      return false;
    }
  }

  /// Get grocery store specials
  static List<Map<String, dynamic>> getGroceryStoreSpecials() {
    try {
      final specialsJson = _instance.getString('grocery_store_specials');
      if (specialsJson != null) {
        final List<dynamic> specialsList = jsonDecode(specialsJson);
        return specialsList.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('Error getting grocery store specials: $e');
      return [];
    }
  }

  /// Clear all grocery cache
  static Future<void> clearGroceryCache() async {
    try {
      final keys = [
        'grocery_categories',
        'grocery_categories_cache_timestamp',
        'grocery_stores',
        'grocery_stores_cache_timestamp',
        'grocery_items',
        'grocery_items_cache_timestamp',
        'grocery_deals',
        'grocery_deals_cache_timestamp',
        'grocery_popular_items',
        'grocery_popular_items_cache_timestamp',
        'grocery_top_rated_items',
        'grocery_top_rated_items_cache_timestamp',
        'grocery_buy_again_items',
        'grocery_buy_again_items_cache_timestamp',
        'grocery_store_specials',
        'grocery_store_specials_cache_timestamp'
      ];
      for (final key in keys) {
        await _instance.remove(key);
      }
    } catch (e) {
      debugPrint('Error clearing grocery cache: $e');
    }
  }

  // ==================== PHARMACY CACHE ====================

  /// Save pharmacy categories
  static Future<bool> savePharmacyCategories(List<Map<String, dynamic>> categories) async {
    try {
      final categoriesJson = jsonEncode(categories);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      await _instance.setString('pharmacy_categories', categoriesJson);
      await _instance.setInt('pharmacy_categories_cache_timestamp', timestamp);
      return true;
    } catch (e) {
      debugPrint('Error saving pharmacy categories: $e');
      return false;
    }
  }

  /// Get pharmacy categories
  static List<Map<String, dynamic>> getPharmacyCategories() {
    try {
      final categoriesJson = _instance.getString('pharmacy_categories');
      if (categoriesJson != null) {
        final List<dynamic> categoriesList = jsonDecode(categoriesJson);
        return categoriesList.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('Error getting pharmacy categories: $e');
      return [];
    }
  }


  /// Clear pharmacy cache
  static Future<void> clearPharmacyCache() async {
    try {
      final keys = [
        'pharmacy_categories',
        'pharmacy_categories_cache_timestamp',
        'pharmacy_items',
        'pharmacy_items_cache_timestamp'
      ];
      for (final key in keys) {
        await _instance.remove(key);
      }
    } catch (e) {
      debugPrint('Error clearing pharmacy cache: $e');
    }
  }

  /// Save pharmacy items
  static Future<bool> savePharmacyItems(List<Map<String, dynamic>> items) async {
    try {
      final itemsJson = jsonEncode(items);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      await _instance.setString('pharmacy_items', itemsJson);
      await _instance.setInt('pharmacy_items_cache_timestamp', timestamp);
      return true;
    } catch (e) {
      debugPrint('Error saving pharmacy items: $e');
      return false;
    }
  }

  /// Get pharmacy items
  static List<Map<String, dynamic>> getPharmacyItems() {
    try {
      final itemsJson = _instance.getString('pharmacy_items');
      if (itemsJson != null) {
        final List<dynamic> itemsList = jsonDecode(itemsJson);
        return itemsList.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('Error getting pharmacy items: $e');
      return [];
    }
  }

  // ==================== GRABMART CACHE ====================

  /// Save GrabMart categories
  static Future<bool> saveGrabMartCategories(List<Map<String, dynamic>> categories) async {
    try {
      final categoriesJson = jsonEncode(categories);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      await _instance.setString('grabmart_categories', categoriesJson);
      await _instance.setInt('grabmart_categories_cache_timestamp', timestamp);
      return true;
    } catch (e) {
      debugPrint('Error saving GrabMart categories: $e');
      return false;
    }
  }

  /// Get GrabMart categories
  static List<Map<String, dynamic>> getGrabMartCategories() {
    try {
      final categoriesJson = _instance.getString('grabmart_categories');
      if (categoriesJson != null) {
        final List<dynamic> categoriesList = jsonDecode(categoriesJson);
        return categoriesList.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('Error getting GrabMart categories: $e');
      return [];
    }
  }

  /// Clear GrabMart cache
  static Future<void> clearGrabMartCache() async {
    try {
      final keys = [
        'grabmart_categories',
        'grabmart_categories_cache_timestamp',
        'grabmart_items',
        'grabmart_items_cache_timestamp'
      ];
      for (final key in keys) {
        await _instance.remove(key);
      }
    } catch (e) {
      debugPrint('Error clearing GrabMart cache: $e');
    }
  }

  /// Save GrabMart items
  static Future<bool> saveGrabMartItems(List<Map<String, dynamic>> items) async {
    try {
      final itemsJson = jsonEncode(items);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      await _instance.setString('grabmart_items', itemsJson);
      await _instance.setInt('grabmart_items_cache_timestamp', timestamp);
      return true;
    } catch (e) {
      debugPrint('Error saving GrabMart items: $e');
      return false;
    }
  }

  /// Get GrabMart items
  static List<Map<String, dynamic>> getGrabMartItems() {
    try {
      final itemsJson = _instance.getString('grabmart_items');
      if (itemsJson != null) {
        final List<dynamic> itemsList = jsonDecode(itemsJson);
        return itemsList.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('Error getting GrabMart items: $e');
      return [];
    }
  }
}
