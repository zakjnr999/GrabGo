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
      _categories = await FoodRepository().fetchCategories();

      _saveCategoriesToCache();
    } catch (e) {
      _error = "Failed to load categories: ${e.toString()}";
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
      _categories = await FoodRepository().fetchCategories();

      _saveCategoriesToCache();
    } catch (e) {
      _error = "Failed to refresh categories: ${e.toString()}";
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
}
