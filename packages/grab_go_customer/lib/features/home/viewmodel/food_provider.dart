import 'package:flutter/foundation.dart';
import 'package:grab_go_customer/features/home/repository/food_repository.dart';
import 'package:grab_go_customer/features/home/model/food_category.dart';
import 'package:grab_go_customer/shared/services/cache_service.dart';

class FoodProvider with ChangeNotifier {
  List<FoodCategoryModel> _categories = [];
  List<FoodCategoryModel> get categories => _categories;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  Future<void> fetchCategories() async {
    if (_categories.isNotEmpty || _isLoading) return;

    if (_categories.isEmpty && CacheService.isFoodCategoriesCacheValid()) {
      _loadCategoriesFromCache();
      if (_categories.isNotEmpty) {
        notifyListeners();
        return;
      }
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      if (kDebugMode) {
        print('🔄 Fetching categories with foods...');
      }
      // Fetch categories with their associated foods
      _categories = await FoodRepository().fetchCategoriesWithFoods();

      if (kDebugMode) {
        print('✅ Loaded ${_categories.length} categories with foods');
        for (var cat in _categories) {
          print('   - ${cat.name}: ${cat.items.length} items');
        }
      }

      _saveCategoriesToCache();
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error fetching categories with foods: $e');
      }
      _error = "Failed to load categories: ${e.toString()}";
      // Fallback to categories without foods if the combined fetch fails
      try {
        if (kDebugMode) {
          print('🔄 Fallback: Fetching categories without foods...');
        }
        _categories = await FoodRepository().fetchCategories();
        if (kDebugMode) {
          print('✅ Loaded ${_categories.length} categories (without foods)');
        }
      } catch (fallbackError) {
        if (kDebugMode) {
          print('❌ Fallback also failed: $fallbackError');
        }
        _error = "Failed to load categories: ${fallbackError.toString()}";
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshCategories() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Fetch categories with their associated foods
      _categories = await FoodRepository().fetchCategoriesWithFoods();

      _saveCategoriesToCache();
    } catch (e) {
      _error = "Failed to refresh categories: ${e.toString()}";
      // Fallback to categories without foods if the combined fetch fails
      try {
        _categories = await FoodRepository().fetchCategories();
      } catch (fallbackError) {
        _error = "Failed to refresh categories: ${fallbackError.toString()}";
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearCategories() {
    _categories = [];
    notifyListeners();
  }

  void _loadCategoriesFromCache() {
    try {
      final cachedCategories = CacheService.getFoodCategories();
      _categories = cachedCategories.map((json) => FoodCategoryModel.fromJson(json)).toList();

      if (kDebugMode) {
        print('Loaded ${_categories.length} food categories from cache');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading food categories from cache: $e');
      }
      _categories = [];
    }
  }

  void _saveCategoriesToCache() {
    try {
      final categoriesJson = _categories.map((category) => category.toJson()).toList();
      CacheService.saveFoodCategories(categoriesJson);

      if (kDebugMode) {
        print('Saved ${_categories.length} food categories to cache');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error saving food categories to cache: $e');
      }
    }
  }

  /// Get all foods from all categories
  List<FoodItem> getAllFoods() {
    return _categories.expand((cat) => cat.items).toList();
  }

  /// Get random foods
  List<FoodItem> getRandomFoods({int count = 5}) {
    final allFoods = getAllFoods();
    if (allFoods.isEmpty) return [];

    allFoods.shuffle();
    return allFoods.take(count).toList();
  }

  /// Fetch foods for a specific category
  Future<void> fetchFoodsForCategory(String categoryId) async {
    try {
      final categoryFoods = await FoodRepository().fetchFoods(categoryId: categoryId);

      // Update the category with fetched foods
      final categoryIndex = _categories.indexWhere((cat) => cat.id == categoryId);
      if (categoryIndex >= 0) {
        _categories[categoryIndex] = FoodCategoryModel(
          id: _categories[categoryIndex].id,
          name: _categories[categoryIndex].name,
          emoji: _categories[categoryIndex].emoji,
          items: categoryFoods,
        );
        notifyListeners();
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching foods for category $categoryId: $e');
      }
    }
  }
}
