import 'package:chopper/chopper.dart';
import 'package:flutter/foundation.dart';
import 'package:grab_go_customer/core/api/api_client.dart';
import 'package:grab_go_customer/features/home/model/food_category.dart';
import 'package:grab_go_customer/features/home/model/promotional_banner.dart';
import 'package:grab_go_customer/features/home/service/food_service.dart';

class FoodRepository {
  final FoodService service;

  FoodRepository({FoodService? service}) : service = service ?? foodService;

  Future<List<FoodCategoryModel>> fetchCategories() async {
    final Response response = await service.getCategories();
    if (response.isSuccessful) {
      final body = response.body;
      final data = (body['data'] as List<dynamic>?) ?? [];
      return data.map((e) => FoodCategoryModel.fromJson(e as Map<String, dynamic>)).toList();
    } else {
      throw Exception('Failed to load categories: ${response.statusCode}');
    }
  }

  Future<List<FoodItem>> fetchFoods({String? restaurantId, String? categoryId}) async {
    final Response response = await service.getFoods(
      restaurant: restaurantId,
      category: categoryId,
      isAvailable: 'true',
    );
    if (response.isSuccessful) {
      final body = response.body;
      final data = (body['data'] as List<dynamic>?) ?? [];
      return data.map((e) => FoodItem.fromJson(e as Map<String, dynamic>)).toList();
    } else {
      throw Exception('Failed to load foods: ${response.statusCode}');
    }
  }

  Future<List<FoodCategoryModel>> fetchCategoriesWithFoods() async {
    final categories = await fetchCategories();

    if (categories.isEmpty) {
      return [];
    }

    final List<FoodCategoryModel> categoriesWithFoods = [];
    for (final category in categories) {
      try {
        final categoryFoods = await fetchFoods(categoryId: category.id);
        categoriesWithFoods.add(
          FoodCategoryModel(
            id: category.id,
            name: category.name,
            description: category.description,
            emoji: category.emoji,
            isActive: category.isActive,
            items: categoryFoods,
          ),
        );
      } catch (e) {
        categoriesWithFoods.add(
          FoodCategoryModel(
            id: category.id,
            name: category.name,
            description: category.description,
            emoji: category.emoji,
            isActive: category.isActive,
            items: [],
          ),
        );
      }
    }

    return categoriesWithFoods;
  }

  /// Fetch user's recent order items for "Order Again" section
  Future<List<FoodItem>> fetchRecentOrderItems() async {
    try {
      // Use service client to make the request
      final response = await chopperClient.get(Uri.parse('/orders/recent-items'));

      if (response.isSuccessful && response.body != null) {
        final body = response.body as Map<String, dynamic>;
        final data = (body['data'] as List<dynamic>?) ?? [];

        // Extract food items from the response
        return data.map((item) {
          final foodItemData = item['foodItem'] as Map<String, dynamic>;
          return FoodItem.fromJson(foodItemData);
        }).toList();
      } else {
        // Return empty list for any error - global error handler will show network error page
        if (kDebugMode) {
          print('❌ Failed to load recent items: ${response.statusCode}');
        }
        return [];
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error fetching recent order items: $e');
      }
      // Return empty list - skeleton will continue showing until global error handler kicks in
      return [];
    }
  }

  /// Fetch food deals (items with active discounts)
  Future<List<FoodItem>> fetchDeals() async {
    try {
      final response = await service.getDeals();

      if (response.isSuccessful && response.body != null) {
        final body = response.body as Map<String, dynamic>;
        final data = (body['data'] as List<dynamic>?) ?? [];

        return data.map((item) {
          return FoodItem.fromJson(item as Map<String, dynamic>);
        }).toList();
      } else {
        if (kDebugMode) {
          print('❌ Failed to load deals: ${response.statusCode}');
        }
        return [];
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error fetching deals: $e');
      }
      return [];
    }
  }

  /// Fetch promotional banners
  Future<List<PromotionalBanner>> fetchPromotionalBanners() async {
    try {
      final response = await service.getPromotionalBanners();

      if (response.isSuccessful && response.body != null) {
        final body = response.body as Map<String, dynamic>;
        final data = (body['data'] as List<dynamic>?) ?? [];

        return data.map((item) {
          return PromotionalBanner.fromJson(item as Map<String, dynamic>);
        }).toList();
      } else {
        if (kDebugMode) {
          print('❌ Failed to load promotional banners: ${response.statusCode}');
        }
        return [];
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error fetching promotional banners: $e');
      }
      return [];
    }
  }

  /// Fetch order history for Order Again section
  Future<List<FoodItem>> fetchOrderHistory() async {
    try {
      final response = await service.getOrderHistory();

      if (response.isSuccessful && response.body != null) {
        final body = response.body as Map<String, dynamic>;
        final data = (body['data'] as List<dynamic>?) ?? [];

        return data.map((item) {
          return FoodItem.fromJson(item as Map<String, dynamic>);
        }).toList();
      } else {
        if (kDebugMode) {
          print('❌ Failed to load order history: ${response.statusCode}');
        }
        return [];
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error fetching order history: $e');
      }
      return [];
    }
  }

  /// Fetch popular food items sorted by order count
  Future<List<FoodItem>> fetchPopularItems({int limit = 10}) async {
    try {
      final response = await service.getPopularItems(limit);

      if (response.isSuccessful && response.body != null) {
        final data = response.body as Map<String, dynamic>;
        if (data['success'] == true && data['data'] != null) {
          return (data['data'] as List).map((json) => FoodItem.fromJson(json)).toList();
        }
      }

      if (kDebugMode) {
        print('❌ Failed to fetch popular items: ${response.error}');
      }
      return [];
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error fetching popular items: $e');
      }
      return [];
    }
  }

  /// Fetch top-rated food items sorted by rating
  Future<List<FoodItem>> fetchTopRatedItems({int limit = 10, double minRating = 4.5}) async {
    try {
      final response = await service.getTopRatedItems(limit, minRating);

      if (response.isSuccessful && response.body != null) {
        final data = response.body as Map<String, dynamic>;
        if (data['success'] == true && data['data'] != null) {
          return (data['data'] as List).map((json) => FoodItem.fromJson(json)).toList();
        }
      }

      if (kDebugMode) {
        print('❌ Failed to fetch top rated items: ${response.error}');
      }
      return [];
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error fetching top rated items: $e');
      }
      return [];
    }
  }
}
