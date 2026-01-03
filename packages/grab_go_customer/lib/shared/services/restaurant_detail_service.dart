import 'package:flutter/foundation.dart';
import 'package:grab_go_customer/core/api/api_client.dart';
import 'package:grab_go_customer/features/restaurant/service/restaurant_service.dart';

class RestaurantDetailService {
  static final RestaurantService _restaurantService = chopperClient.getService<RestaurantService>();
  static final Map<String, Map<String, dynamic>> _cache = {};

  /// Fetch restaurant details by ID with caching
  static Future<Map<String, dynamic>?> getRestaurantDetails(String restaurantId) async {
    if (restaurantId.isEmpty) return null;

    // Return cached data if available
    if (_cache.containsKey(restaurantId)) {
      return _cache[restaurantId];
    }

    try {
      if (kDebugMode) {
        print('🏪 Fetching restaurant details for ID: $restaurantId');
      }

      final response = await _restaurantService.getRestaurants();
      
      if (kDebugMode) {
        print('🏪 Restaurant API response status: ${response.statusCode}');
        print('🏪 Restaurant API response successful: ${response.isSuccessful}');
      }
      
      if (response.isSuccessful && response.body != null) {
        final responseData = response.body!;
        if (responseData['success'] == true) {
          final List<dynamic> restaurants = responseData['data'] ?? [];
          
          // Find the restaurant with matching ID
          final restaurant = restaurants.firstWhere(
            (r) => r['_id'] == restaurantId,
            orElse: () => null,
          );

          if (restaurant != null) {
            final restaurantDetails = {
              '_id': restaurant['_id'],
              'restaurant_name': restaurant['restaurant_name'] ?? restaurant['name'] ?? '',
              'logo': restaurant['logo'] ?? restaurant['image'] ?? '',
              'rating': restaurant['rating'] ?? 4.5,
              'totalReviews': restaurant['totalReviews'] ?? 100,
              'address': restaurant['address'] ?? 'Address not available',
              'phone': restaurant['phone'] ?? '',
              'description': restaurant['description'] ?? '',
            };

            // Cache the result
            _cache[restaurantId] = restaurantDetails;
            
            if (kDebugMode) {
              print('✅ Found restaurant: ${restaurantDetails['restaurant_name']}');
            }
            
            return restaurantDetails;
          }
        }
      }

      if (kDebugMode) {
        print('⚠️ Restaurant not found for ID: $restaurantId');
      }
      return null;
      
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error fetching restaurant details: $e');
      }
      return null;
    }
  }

  /// Update food item with restaurant details
  static Future<void> updateFoodItemWithRestaurantDetails(Map<String, dynamic> foodItemJson) async {
    final restaurantId = foodItemJson['restaurantId'] ?? '';
    if (restaurantId.isEmpty) return;

    // Skip if restaurant details are already populated
    final currentSellerName = foodItemJson['sellerName'] ?? '';
    if (currentSellerName.isNotEmpty && currentSellerName != 'Loading Restaurant...' && currentSellerName != 'Unknown Restaurant') {
      return;
    }

    final restaurantDetails = await getRestaurantDetails(restaurantId);
    if (restaurantDetails != null) {
      foodItemJson['sellerName'] = restaurantDetails['restaurant_name'];
      foodItemJson['restaurantImage'] = restaurantDetails['logo'];
      
      if (kDebugMode) {
        print('🔄 Updated food item with restaurant: ${restaurantDetails['restaurant_name']}');
      }
    }
  }

  /// Clear cache (useful for refreshing data)
  static void clearCache() {
    _cache.clear();
  }
}