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
      _categories = await FoodRepository().fetchCategoriesWithFoods();

      _saveCategoriesToCache();
    } catch (e) {
      _error = "Failed to load categories: ${e.toString()}";
      try {
        _categories = await FoodRepository().fetchCategories();
      } catch (fallbackError) {
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
      _categories = await FoodRepository().fetchCategoriesWithFoods();

      _saveCategoriesToCache();
    } catch (e) {
      _error = "Failed to refresh categories: ${e.toString()}";
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
    } catch (e) {
      _categories = [];
    }
  }

  void _saveCategoriesToCache() {
    final categoriesJson = _categories.map((category) => category.toJson()).toList();
    CacheService.saveFoodCategories(categoriesJson);
  }

  List<FoodItem> getAllFoods() {
    return _categories.expand((cat) => cat.items).toList();
  }

  List<FoodItem> getRandomFoods({int count = 5}) {
    final allFoods = getAllFoods();
    if (allFoods.isEmpty) return [];

    allFoods.shuffle();
    return allFoods.take(count).toList();
  }

  Future<void> fetchFoodsForCategory(String categoryId) async {
    final categoryFoods = await FoodRepository().fetchFoods(categoryId: categoryId);

    final categoryIndex = _categories.indexWhere((cat) => cat.id == categoryId);
    if (categoryIndex >= 0) {
      _categories[categoryIndex] = FoodCategoryModel(
        id: _categories[categoryIndex].id,
        name: _categories[categoryIndex].name,
        description: _categories[categoryIndex].description,
        isActive: _categories[categoryIndex].isActive,
        emoji: _categories[categoryIndex].emoji,
        items: categoryFoods,
      );
      notifyListeners();
    }
  }
}
