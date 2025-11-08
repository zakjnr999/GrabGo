import 'package:flutter/foundation.dart';
import 'package:chopper/chopper.dart';
import 'package:grab_go_customer/core/api/api_client.dart';
import 'package:grab_go_customer/features/restaurant/model/restaurants_model.dart';
import 'package:grab_go_customer/core/api/restaurant_service.dart';

class RestaurantRepository {
  final RestaurantService service;

  RestaurantRepository({RestaurantService? service}) : service = service ?? restaurantService;

  Future<List<RestaurantModel>> fetchRestaurants() async {
    final Response response = await service.getRestaurants();
    if (response.isSuccessful) {
      final body = response.body;

      // Handle different response formats
      List<dynamic>? data;

      if (body is Map<String, dynamic>) {
        data = body['data'] as List<dynamic>?;
      } else if (body is List) {
        data = body;
      }

      if (data == null) {
        return [];
      }

      // Filter approved restaurants and parse
      final List<RestaurantModel> approvedRestaurants = [];

      for (final item in data) {
        if (item is! Map<String, dynamic>) continue;

        try {
          final status = item['status']?.toString().toLowerCase() ?? '';
          if (status != 'approved') continue;

          final restaurant = RestaurantModel.fromJson(item);
          approvedRestaurants.add(restaurant);
        } catch (e) {
          // Skip invalid restaurants
          if (kDebugMode) {
            print('❌ Error parsing restaurant: $e');
            print('❌ Restaurant data: $item');
          }
          continue;
        }
      }

      return approvedRestaurants;
    } else {
      throw Exception('Failed to load restaurants: ${response.statusCode}');
    }
  }
}
