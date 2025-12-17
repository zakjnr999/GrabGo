import 'package:flutter/foundation.dart';
import 'package:grab_go_customer/core/api/api_client.dart' as chopper_client_service;
import 'package:grab_go_customer/features/groceries/model/grocery_category.dart';
import 'package:grab_go_customer/features/groceries/model/grocery_item.dart';
import 'package:grab_go_customer/features/groceries/model/grocery_store.dart';
import 'package:grab_go_customer/features/groceries/model/store_special.dart';
import 'package:grab_go_customer/features/groceries/service/grocery_service.dart';

class GroceryRepository {
  final GroceryService _groceryService;

  GroceryRepository() : _groceryService = GroceryService.create(chopper_client_service.chopperClient);

  /// Fetch all grocery stores
  Future<List<GroceryStore>> fetchStores() async {
    try {
      final response = await _groceryService.getStores();

      if (response.isSuccessful && response.body != null) {
        final data = response.body as Map<String, dynamic>;
        if (data['success'] == true && data['data'] != null) {
          final stores = (data['data'] as List).map((json) => GroceryStore.fromJson(json)).toList();
          return stores;
        }
      }

      if (kDebugMode) {
        print('❌ Failed to fetch grocery stores: ${response.error}');
      }
      return [];
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error fetching grocery stores: $e');
      }
      return [];
    }
  }

  /// Fetch all grocery categories
  Future<List<GroceryCategory>> fetchCategories() async {
    try {
      final response = await _groceryService.getCategories();

      if (response.isSuccessful && response.body != null) {
        final data = response.body as Map<String, dynamic>;
        if (data['success'] == true && data['data'] != null) {
          final categories = (data['data'] as List).map((json) => GroceryCategory.fromJson(json)).toList();
          return categories;
        }
      }

      if (kDebugMode) {
        print('❌ Failed to fetch grocery categories: ${response.error}');
      }
      return [];
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error fetching grocery categories: $e');
      }
      return [];
    }
  }

  /// Fetch grocery items with optional filters
  Future<List<GroceryItem>> fetchItems({
    String? category,
    String? store,
    String? minPrice,
    String? maxPrice,
    String? tags,
  }) async {
    try {
      final response = await _groceryService.getItems(
        category: category,
        store: store,
        minPrice: minPrice,
        maxPrice: maxPrice,
        tags: tags,
      );

      if (response.isSuccessful && response.body != null) {
        final data = response.body as Map<String, dynamic>;
        if (data['success'] == true && data['data'] != null) {
          final items = (data['data'] as List).map((json) => GroceryItem.fromJson(json)).toList();
          return items;
        }
      }

      if (kDebugMode) {
        print('❌ Failed to fetch grocery items: ${response.error}');
      }
      return [];
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error fetching grocery items: $e');
      }
      return [];
    }
  }

  /// Search grocery items
  Future<List<GroceryItem>> searchItems(String query) async {
    try {
      final response = await _groceryService.searchItems(query);

      if (response.isSuccessful && response.body != null) {
        final data = response.body as Map<String, dynamic>;
        if (data['success'] == true && data['data'] != null) {
          final items = (data['data'] as List).map((json) => GroceryItem.fromJson(json)).toList();
          return items;
        }
      }

      if (kDebugMode) {
        print('❌ Failed to search grocery items: ${response.error}');
      }
      return [];
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error searching grocery items: $e');
      }
      return [];
    }
  }

  /// Fetch grocery deals (items with discounts)
  Future<List<GroceryItem>> fetchDeals() async {
    try {
      final response = await _groceryService.getDeals();

      if (response.isSuccessful && response.body != null) {
        final data = response.body as Map<String, dynamic>;
        if (data['success'] == true && data['data'] != null) {
          final deals = (data['data'] as List).map((json) => GroceryItem.fromJson(json)).toList();
          return deals;
        }
      }

      if (kDebugMode) {
        print('❌ Failed to fetch grocery deals: ${response.error}');
      }
      return [];
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error fetching grocery deals: $e');
      }
      return [];
    }
  }

  /// Fetch items from a specific store
  Future<List<GroceryItem>> fetchStoreItems(String storeId) async {
    try {
      final response = await _groceryService.getStoreItems(storeId);

      if (response.isSuccessful && response.body != null) {
        final data = response.body as Map<String, dynamic>;
        if (data['success'] == true && data['data'] != null) {
          final items = (data['data'] as List).map((json) => GroceryItem.fromJson(json)).toList();
          return items;
        }
      }

      if (kDebugMode) {
        print('❌ Failed to fetch store items: ${response.error}');
      }
      return [];
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error fetching store items: $e');
      }
      return [];
    }
  }

  /// Fetch grocery order history for Buy Again section
  Future<List<GroceryItem>> fetchOrderHistory() async {
    try {
      final response = await _groceryService.getOrderHistory();

      if (response.isSuccessful && response.body != null) {
        final data = response.body as Map<String, dynamic>;
        final items = data['data'] as List;

        return items.map((json) => GroceryItem.fromJson(json as Map<String, dynamic>)).toList();
      }

      return [];
    } catch (e) {
      if (kDebugMode) {
        print('❌ Repository: Error fetching order history: $e');
      }
      return [];
    }
  }

  /// Fetch store specials (items with active discounts grouped by store)
  Future<List<StoreSpecial>> fetchStoreSpecials() async {
    try {
      final response = await _groceryService.getStoreSpecials();

      if (response.isSuccessful && response.body != null) {
        final data = response.body as Map<String, dynamic>;
        if (data['success'] == true && data['data'] != null) {
          final specials = (data['data'] as List).map((json) => StoreSpecial.fromJson(json)).toList();
          return specials;
        }
      }

      if (kDebugMode) {
        print('❌ Failed to fetch store specials: ${response.error}');
      }
      return [];
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error fetching store specials: $e');
      }
      return [];
    }
  }

  /// Fetch popular grocery items sorted by order count
  Future<List<GroceryItem>> fetchPopularItems({int limit = 10}) async {
    try {
      final response = await _groceryService.getPopularItems(limit);

      if (response.isSuccessful && response.body != null) {
        final data = response.body as Map<String, dynamic>;
        if (data['success'] == true && data['data'] != null) {
          return (data['data'] as List).map((json) => GroceryItem.fromJson(json)).toList();
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

  /// Fetch top-rated grocery items sorted by rating
  Future<List<GroceryItem>> fetchTopRatedItems({int limit = 10, double minRating = 4.5}) async {
    try {
      final response = await _groceryService.getTopRatedItems(limit, minRating);

      if (response.isSuccessful && response.body != null) {
        final data = response.body as Map<String, dynamic>;
        if (data['success'] == true && data['data'] != null) {
          return (data['data'] as List).map((json) => GroceryItem.fromJson(json)).toList();
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
