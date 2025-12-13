import 'package:flutter/foundation.dart';
import 'package:grab_go_customer/features/home/repository/food_repository.dart';
import 'package:grab_go_customer/features/home/model/food_category.dart';
import 'package:grab_go_customer/features/home/model/promotional_banner.dart';
import 'package:grab_go_customer/shared/services/restaurant_detail_service.dart';
import 'package:grab_go_shared/shared/services/cache_service.dart';

class FoodProvider with ChangeNotifier {
  List<FoodCategoryModel> _categories = [];
  List<FoodCategoryModel> get categories => _categories;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  List<FoodItem> _recentOrderItems = [];
  List<FoodItem> get recentOrderItems => _recentOrderItems;

  bool _isLoadingRecentItems = false;
  bool get isLoadingRecentItems => _isLoadingRecentItems;

  String? _recentItemsError;
  String? get recentItemsError => _recentItemsError;

  List<PromotionalBanner> _promotionalBanners = [];
  List<PromotionalBanner> get promotionalBanners => _promotionalBanners;

  bool _isLoadingBanners = false;
  bool get isLoadingBanners => _isLoadingBanners;

  List<FoodItem> _dealItems = [];
  List<FoodItem> get dealItems => _dealItems;

  bool _isLoadingDeals = false;
  bool get isLoadingDeals => _isLoadingDeals;

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

      // Enhance food items with restaurant details
      await _enhanceFoodItemsWithRestaurantDetails();

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

      await _enhanceFoodItemsWithRestaurantDetails();

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
    try {
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
    } catch (e) {
      _error = "Failed to load foods for category: ${e.toString()}";
      if (kDebugMode) {
        print('❌ Error fetching foods for category $categoryId: $e');
      }
      notifyListeners();
    }
  }

  /// Enhance food items with restaurant details for items that only have restaurant IDs
  Future<void> _enhanceFoodItemsWithRestaurantDetails() async {
    if (_categories.isEmpty) return;

    try {
      if (kDebugMode) {
        print('🔄 Enhancing food items with restaurant details...');
      }

      for (int categoryIndex = 0; categoryIndex < _categories.length; categoryIndex++) {
        final category = _categories[categoryIndex];
        final List<FoodItem> enhancedItems = [];

        for (final foodItem in category.items) {
          // Check if food item needs restaurant details
          if (foodItem.sellerName == 'Loading Restaurant...' && foodItem.restaurantId.isNotEmpty) {
            if (kDebugMode) {
              print('🔍 Food item "${foodItem.name}" needs restaurant details for ID: ${foodItem.restaurantId}');
            }

            // Fetch restaurant details
            final restaurantDetails = await RestaurantDetailService.getRestaurantDetails(foodItem.restaurantId);

            if (restaurantDetails != null) {
              // Create updated food item with restaurant details
              final enhancedItem = FoodItem(
                id: foodItem.id,
                name: foodItem.name,
                image: foodItem.image,
                description: foodItem.description,
                sellerName: restaurantDetails['restaurant_name'] ?? foodItem.sellerName,
                sellerId: foodItem.sellerId,
                restaurantId: foodItem.restaurantId,
                restaurantImage: restaurantDetails['logo'] ?? foodItem.restaurantImage,
                price: foodItem.price,
                rating: foodItem.rating,
                prepTimeMinutes: foodItem.prepTimeMinutes,
                calories: foodItem.calories,
                dietaryTags: foodItem.dietaryTags,
                deliveryTimeMinutes: foodItem.deliveryTimeMinutes,
                isAvailable: foodItem.isAvailable,
                discountPercentage: foodItem.discountPercentage,
              );
              enhancedItems.add(enhancedItem);

              if (kDebugMode) {
                print('✅ Enhanced ${foodItem.name} with restaurant: ${restaurantDetails['restaurant_name']}');
              }
            } else {
              enhancedItems.add(foodItem);
            }
          } else {
            enhancedItems.add(foodItem);
          }
        }

        // Update category with enhanced items
        _categories[categoryIndex] = FoodCategoryModel(
          id: category.id,
          name: category.name,
          description: category.description,
          isActive: category.isActive,
          emoji: category.emoji,
          items: enhancedItems,
        );
      }

      notifyListeners();

      if (kDebugMode) {
        print('✅ Completed enhancing food items with restaurant details');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error enhancing food items with restaurant details: $e');
      }
    }
  }

  /// Fetch user's recent order items for "Order Again" section
  Future<void> fetchRecentOrderItems() async {
    _isLoadingRecentItems = true;
    notifyListeners();

    try {
      _recentOrderItems = await FoodRepository().fetchRecentOrderItems();
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error fetching recent order items: $e');
      }
      _recentOrderItems = [];
      // Keep loading state true - skeleton will continue showing
      // Global error handler will show network error page
    } finally {
      _isLoadingRecentItems = false;
      notifyListeners();
    }
  }

  /// Fetch promotional banners
  Future<void> fetchPromotionalBanners() async {
    _isLoadingBanners = true;
    notifyListeners();

    try {
      _promotionalBanners = await FoodRepository().fetchPromotionalBanners();
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error fetching promotional banners: $e');
      }
      _promotionalBanners = [];
    } finally {
      _isLoadingBanners = false;
      notifyListeners();
    }
  }

  /// Fetch food deals
  Future<void> fetchDeals() async {
    _isLoadingDeals = true;
    notifyListeners();

    try {
      _dealItems = await FoodRepository().fetchDeals();
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error fetching deals: $e');
      }
      _dealItems = [];
    } finally {
      _isLoadingDeals = false;
      notifyListeners();
    }
  }
}
