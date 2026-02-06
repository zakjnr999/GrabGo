import 'package:flutter/foundation.dart';
import 'package:grab_go_customer/features/home/model/food_category.dart';
import 'package:grab_go_customer/features/home/repository/food_repository.dart';
import 'package:grab_go_customer/shared/services/restaurant_detail_service.dart';
import 'package:grab_go_customer/shared/viewmodels/base_provider.dart';
import 'package:grab_go_shared/shared/services/cache_service.dart';

/// State for food categories
class FoodCategoryState {
  final List<FoodCategoryModel> categories;
  final bool isLoading;
  final String? error;
  final bool hasAttemptedFetch;

  const FoodCategoryState({
    this.categories = const [],
    this.isLoading = false,
    this.error,
    this.hasAttemptedFetch = false,
  });

  FoodCategoryState copyWith({
    List<FoodCategoryModel>? categories,
    bool? isLoading,
    String? error,
    bool? hasAttemptedFetch,
  }) {
    return FoodCategoryState(
      categories: categories ?? this.categories,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      hasAttemptedFetch: hasAttemptedFetch ?? this.hasAttemptedFetch,
    );
  }

  /// Get all food items from all categories
  List<FoodItem> get allFoods {
    return categories.expand((cat) => cat.items).toList();
  }

  /// Get random foods
  List<FoodItem> getRandomFoods({int count = 5}) {
    if (allFoods.isEmpty) return [];
    final shuffled = List<FoodItem>.from(allFoods)..shuffle();
    return shuffled.take(count).toList();
  }
}

/// Provider for managing food categories
class FoodCategoryProvider extends ChangeNotifier with CacheMixin {
  FoodCategoryState _state = const FoodCategoryState();
  FoodCategoryState get state => _state;

  final FoodRepository _repository = FoodRepository();

  // Convenience getters for backward compatibility
  List<FoodCategoryModel> get categories => _state.categories;
  bool get isLoading => _state.isLoading;
  String? get error => _state.error;
  bool get hasAttemptedFetch => _state.hasAttemptedFetch;

  /// Fetch categories with caching (Offline-First pattern)
  Future<void> fetchCategories() async {
    // If already loading, don't start another request
    if (_state.isLoading) return;

    // 1. Try loading from cache first (regardless of validity for immediate UI)
    if (_state.categories.isEmpty) {
      await _loadFromCache();
      // If we found cached data, we continue to fetch fresh data in background
    }

    // 2. Fetch fresh data from API
    await _fetchFromApi();
  }

  /// Refresh categories (force reload)
  Future<void> refreshCategories() async {
    await _fetchFromApi();
  }

  /// Clear categories
  void clearCategories() {
    _updateState(_state.copyWith(categories: []));
  }

  /// Fetch foods for a specific category
  Future<void> fetchFoodsForCategory(String categoryId) async {
    try {
      final categoryFoods = await _repository.fetchFoods(categoryId: categoryId);

      final categoryIndex = _state.categories.indexWhere((cat) => cat.id == categoryId);
      if (categoryIndex >= 0) {
        final updatedCategories = List<FoodCategoryModel>.from(_state.categories);
        updatedCategories[categoryIndex] = FoodCategoryModel(
          id: updatedCategories[categoryIndex].id,
          name: updatedCategories[categoryIndex].name,
          description: updatedCategories[categoryIndex].description,
          isActive: updatedCategories[categoryIndex].isActive,
          emoji: updatedCategories[categoryIndex].emoji,
          items: categoryFoods,
        );
        _updateState(_state.copyWith(categories: updatedCategories));
      }
    } catch (e) {
      _updateState(_state.copyWith(error: 'Failed to load foods for category: ${e.toString()}'));
      if (kDebugMode) {
        print('Error fetching foods for category $categoryId: $e');
      }
    }
  }

  /// Fetch from API
  Future<void> _fetchFromApi() async {
    _updateState(_state.copyWith(isLoading: true, error: null, hasAttemptedFetch: true));
    try {
      final locationData = CacheService.getUserLocation();
      final userLat = locationData?['latitude']?.toDouble();
      final userLng = locationData?['longitude']?.toDouble();

      final categories = await _repository.fetchCategoriesWithFoods(
        userLat: userLat,
        userLng: userLng,
      );

      // Enhance food items with restaurant details
      final enhancedCategories = await _enhanceFoodItemsWithRestaurantDetails(categories);
      _updateState(_state.copyWith(categories: enhancedCategories, isLoading: false, error: null));
      await _saveToCache();
    } catch (e) {
      if (_state.categories.isEmpty) {
        try {
          final locationData = CacheService.getUserLocation();
          final userLat = locationData?['latitude']?.toDouble();
          final userLng = locationData?['longitude']?.toDouble();

          final categories = await _repository.fetchCategories(
            userLat: userLat,
            userLng: userLng,
          );
          _updateState(
            _state.copyWith(categories: categories, isLoading: false, error: 'Loaded categories without items'),
          );
        } catch (fallbackError) {
          // Try loading from cache as last resort
          await _loadFromCache();
          _updateState(
            _state.copyWith(isLoading: false, error: 'Failed to load categories: ${fallbackError.toString()}'),
          );
        }
      } else {
        // Keep existing data, just update loading state and error
        _updateState(_state.copyWith(isLoading: false, error: 'Failed to refresh: ${e.toString()}'));
      }
    }
  }

  /// Private: Load from cache
  Future<void> _loadFromCache() async {
    try {
      final cachedCategories = CacheService.getFoodCategories();
      final categories = cachedCategories.map((json) => FoodCategoryModel.fromJson(json)).toList();
      _updateState(_state.copyWith(categories: categories));
    } catch (e) {
      if (kDebugMode) {
        print('Error loading categories from cache: $e');
      }
    }
  }

  /// Private: Save to cache
  Future<void> _saveToCache() async {
    try {
      final categoriesJson = _state.categories.map((category) => category.toJson()).toList();
      CacheService.saveFoodCategories(categoriesJson);
    } catch (e) {
      if (kDebugMode) {
        print('Error saving categories to cache: $e');
      }
    }
  }

  /// Private: Enhance food items with restaurant details
  Future<List<FoodCategoryModel>> _enhanceFoodItemsWithRestaurantDetails(List<FoodCategoryModel> categories) async {
    if (categories.isEmpty) return categories;

    try {
      if (kDebugMode) {
        print('Enhancing food items with restaurant details...');
      }

      final List<FoodCategoryModel> enhancedCategories = [];

      for (final category in categories) {
        final List<FoodItem> enhancedItems = [];

        for (final foodItem in category.items) {
          // Check if food item needs restaurant details
          if (foodItem.sellerName == 'Loading Restaurant...' && foodItem.restaurantId.isNotEmpty) {
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
                print('Enhanced ${foodItem.name} with restaurant: ${restaurantDetails['restaurant_name']}');
              }
            } else {
              enhancedItems.add(foodItem);
            }
          } else {
            enhancedItems.add(foodItem);
          }
        }

        // Create enhanced category
        enhancedCategories.add(
          FoodCategoryModel(
            id: category.id,
            name: category.name,
            description: category.description,
            isActive: category.isActive,
            emoji: category.emoji,
            items: enhancedItems,
          ),
        );
      }

      if (kDebugMode) {
        print('Completed enhancing food items with restaurant details');
      }

      return enhancedCategories;
    } catch (e) {
      if (kDebugMode) {
        print('Error enhancing food items with restaurant details: $e');
      }
      return categories;
    }
  }

  /// Private: Update state and notify listeners
  void _updateState(FoodCategoryState newState) {
    _state = newState;
    notifyListeners();
  }
}
