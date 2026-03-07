import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:grab_go_customer/core/api/api_client.dart';
import 'package:grab_go_customer/features/restaurant/service/restaurant_service.dart';

class RestaurantDetailService {
  static final RestaurantService _restaurantService = chopperClient
      .getService<RestaurantService>();
  static final Map<String, Map<String, dynamic>> _cache = {};
  static Future<void>? _restaurantIndexLoadFuture;
  static bool _hasLoadedRestaurantIndex = false;

  /// Fetch restaurant details by ID with caching
  static Future<Map<String, dynamic>?> getRestaurantDetails(
    String restaurantId,
  ) async {
    if (restaurantId.isEmpty) return null;

    // Return cached data if available
    if (_cache.containsKey(restaurantId)) {
      return _cache[restaurantId];
    }

    await _ensureRestaurantIndexLoaded();
    return _cache[restaurantId];
  }

  static Future<void> _ensureRestaurantIndexLoaded() async {
    if (_hasLoadedRestaurantIndex) return;

    final activeLoad = _restaurantIndexLoadFuture;
    if (activeLoad != null) {
      await activeLoad;
      return;
    }

    _restaurantIndexLoadFuture = _loadRestaurantIndex();
    try {
      await _restaurantIndexLoadFuture;
    } finally {
      _restaurantIndexLoadFuture = null;
    }
  }

  static Future<void> _loadRestaurantIndex() async {
    try {
      if (kDebugMode) {
        print('🏪 Fetching restaurant detail index');
      }

      final response = await _restaurantService.getRestaurants();

      if (response.isSuccessful && response.body != null) {
        final responseData = response.body!;
        if (responseData['success'] == true) {
          final List<dynamic> restaurants = responseData['data'] ?? [];

          for (final rawRestaurant in restaurants) {
            if (rawRestaurant is! Map) continue;
            final restaurant = Map<String, dynamic>.from(rawRestaurant);
            final restaurantId =
                restaurant['_id']?.toString() ??
                restaurant['id']?.toString() ??
                '';
            if (restaurantId.isEmpty) continue;

            final dynamic rawRating =
                restaurant['weightedRating'] ??
                restaurant['displayRating'] ??
                restaurant['rating'];
            final dynamic rawReviewCount =
                restaurant['totalReviews'] ??
                restaurant['total_reviews'] ??
                restaurant['reviewCount'] ??
                restaurant['ratingCount'];

            final parsedRating = rawRating is num
                ? rawRating.toDouble()
                : double.tryParse(rawRating.toString()) ?? 0.0;
            final parsedReviewCount = rawReviewCount is num
                ? rawReviewCount.toInt()
                : int.tryParse(rawReviewCount.toString()) ?? 0;
            final displayRating = parsedReviewCount <= 0 && parsedRating <= 0
                ? 4.0
                : parsedRating;

            _cache[restaurantId] = {
              '_id': restaurantId,
              'restaurant_name':
                  restaurant['restaurant_name'] ?? restaurant['name'] ?? '',
              'logo': restaurant['logo'] ?? restaurant['image'] ?? '',
              'rating': displayRating,
              'totalReviews': parsedReviewCount,
              'address': restaurant['address'] ?? 'Address not available',
              'phone': restaurant['phone'] ?? '',
              'description': restaurant['description'] ?? '',
            };
          }

          _hasLoadedRestaurantIndex = true;
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error fetching restaurant details: $e');
      }
    }
  }

  /// Update food item with restaurant details
  static Future<void> updateFoodItemWithRestaurantDetails(
    Map<String, dynamic> foodItemJson,
  ) async {
    final restaurantId = foodItemJson['restaurantId'] ?? '';
    if (restaurantId.isEmpty) return;

    // Skip if restaurant details are already populated
    final currentSellerName = foodItemJson['sellerName'] ?? '';
    if (currentSellerName.isNotEmpty &&
        currentSellerName != 'Loading Restaurant...' &&
        currentSellerName != 'Unknown Restaurant') {
      return;
    }

    final restaurantDetails = await getRestaurantDetails(restaurantId);
    if (restaurantDetails != null) {
      foodItemJson['sellerName'] = restaurantDetails['restaurant_name'];
      foodItemJson['restaurantImage'] = restaurantDetails['logo'];

      if (kDebugMode) {
        print(
          '🔄 Updated food item with restaurant: ${restaurantDetails['restaurant_name']}',
        );
      }
    }
  }

  /// Clear cache (useful for refreshing data)
  static void clearCache() {
    _cache.clear();
    _hasLoadedRestaurantIndex = false;
    _restaurantIndexLoadFuture = null;
  }
}
