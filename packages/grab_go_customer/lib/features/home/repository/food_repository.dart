import 'package:chopper/chopper.dart';
import 'package:grab_go_customer/core/api/api_client.dart';
import 'package:grab_go_customer/features/home/model/food_category.dart';
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
    // Fetch categories
    final categories = await fetchCategories();

    if (categories.isEmpty) {
      return [];
    }

    // Fetch foods for each category and populate items
    final List<FoodCategoryModel> categoriesWithFoods = [];
    for (final category in categories) {
      try {
        final categoryFoods = await fetchFoods(categoryId: category.id);
        categoriesWithFoods.add(
          FoodCategoryModel(id: category.id, name: category.name, emoji: category.emoji, items: categoryFoods),
        );
      } catch (e) {
        // If fetching foods for a category fails, add category with empty items
        categoriesWithFoods.add(
          FoodCategoryModel(id: category.id, name: category.name, emoji: category.emoji, items: []),
        );
      }
    }

    return categoriesWithFoods;
  }
}
