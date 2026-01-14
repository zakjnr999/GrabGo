import 'package:flutter/foundation.dart';
import 'package:grab_go_customer/features/home/model/food_category.dart';
import 'package:grab_go_customer/shared/viewmodels/base_provider.dart';
import 'package:grab_go_shared/shared/services/cache_service.dart';

/// State for favorites
class FavoritesState {
  final Set<FoodItem> items;
  final bool isLoading;
  final String? error;

  const FavoritesState({
    this.items = const {},
    this.isLoading = false,
    this.error,
  });

  FavoritesState copyWith({
    Set<FoodItem>? items,
    bool? isLoading,
    String? error,
  }) {
    return FavoritesState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  // Computed properties
  int get count => items.length;
  bool get hasFavorites => items.isNotEmpty;
  List<FoodItem> get asList => items.toList();
}

/// Provider for managing favorite food items
/// 
/// Features:
/// - ✅ Optimistic updates (instant UI feedback)
/// - ✅ Automatic cache persistence
/// - ✅ Search and filter capabilities
/// - ✅ State pattern for better testing
class FavoritesProvider extends ChangeNotifier with CacheMixin {
  FavoritesState _state = const FavoritesState();
  FavoritesState get state => _state;

  // Convenience getters for backward compatibility
  Set<FoodItem> get favoriteItems => _state.items;
  int get favoritesCount => _state.count;
  bool get hasFavorites => _state.hasFavorites;

  FavoritesProvider() {
    _loadFavorites();
  }

  /// Check if item is favorite
  bool isFavorite(FoodItem item) {
    return _state.items.contains(item);
  }

  /// Add item to favorites (with optimistic update)
  Future<void> addToFavorites(FoodItem item) async {
    if (_state.items.contains(item)) return;

    // Optimistic update - update UI immediately
    final newItems = Set<FoodItem>.from(_state.items)..add(item);
    _updateState(_state.copyWith(items: newItems));

    // Persist to cache
    await _saveFavorites();

    // TODO: Sync to backend if you have a favorites API
    // try {
    //   await _syncToBackend(item, action: 'add');
    // } catch (e) {
    //   // Rollback on error
    //   final rollbackItems = Set<FoodItem>.from(_state.items)..remove(item);
    //   _updateState(_state.copyWith(items: rollbackItems));
    //   rethrow;
    // }
  }

  /// Remove item from favorites (with optimistic update)
  Future<void> removeFromFavorites(FoodItem item) async {
    if (!_state.items.contains(item)) return;

    // Optimistic update - update UI immediately
    final newItems = Set<FoodItem>.from(_state.items)..remove(item);
    _updateState(_state.copyWith(items: newItems));

    // Persist to cache
    await _saveFavorites();

    // TODO: Sync to backend if you have a favorites API
    // try {
    //   await _syncToBackend(item, action: 'remove');
    // } catch (e) {
    //   // Rollback on error
    //   final rollbackItems = Set<FoodItem>.from(_state.items)..add(item);
    //   _updateState(_state.copyWith(items: rollbackItems));
    //   rethrow;
    // }
  }

  /// Toggle favorite status
  Future<void> toggleFavorite(FoodItem item) async {
    if (isFavorite(item)) {
      await removeFromFavorites(item);
    } else {
      await addToFavorites(item);
    }
  }

  /// Clear all favorites
  Future<void> clearFavorites() async {
    // Store old items for potential rollback
    final oldItems = _state.items;

    // Optimistic update
    _updateState(_state.copyWith(items: {}));

    try {
      await _saveFavorites();
      
      // TODO: Sync to backend
      // await _clearFavoritesOnBackend();
    } catch (e) {
      // Rollback on error
      _updateState(_state.copyWith(items: oldItems));
      if (kDebugMode) {
        print('❌ Error clearing favorites: $e');
      }
      rethrow;
    }
  }

  /// Get favorites by category
  List<FoodItem> getFavoritesByCategory(String category) {
    return _state.items
        .where((item) => item.name.toLowerCase().contains(category.toLowerCase()))
        .toList();
  }

  /// Search favorites
  List<FoodItem> searchFavorites(String query) {
    if (query.isEmpty) return _state.asList;

    final lowercaseQuery = query.toLowerCase();
    return _state.items.where((item) {
      return item.name.toLowerCase().contains(lowercaseQuery) ||
          item.description.toLowerCase().contains(lowercaseQuery) ||
          item.sellerName.toLowerCase().contains(lowercaseQuery);
    }).toList();
  }

  /// Get favorites sorted by price
  List<FoodItem> getFavoritesSortedByPrice({bool ascending = true}) {
    final list = _state.asList;
    list.sort((a, b) => ascending 
        ? a.price.compareTo(b.price) 
        : b.price.compareTo(a.price));
    return list;
  }

  /// Get favorites sorted by rating
  List<FoodItem> getFavoritesSortedByRating({bool ascending = false}) {
    final list = _state.asList;
    list.sort((a, b) => ascending 
        ? a.rating.compareTo(b.rating) 
        : b.rating.compareTo(a.rating));
    return list;
  }

  /// Get favorites by restaurant
  Map<String, List<FoodItem>> getFavoritesByRestaurant() {
    final Map<String, List<FoodItem>> grouped = {};
    
    for (final item in _state.items) {
      final restaurantName = item.sellerName;
      if (!grouped.containsKey(restaurantName)) {
        grouped[restaurantName] = [];
      }
      grouped[restaurantName]!.add(item);
    }
    
    return grouped;
  }

  /// Private: Load favorites from cache
  Future<void> _loadFavorites() async {
    try {
      final cachedFavorites = CacheService.getFavoriteFoods();
      final Set<FoodItem> items = {};

      for (final favoriteJson in cachedFavorites) {
        try {
          final foodItem = FoodItem.fromJson(favoriteJson);
          items.add(foodItem);
        } catch (e) {
          if (kDebugMode) {
            print('❌ Error loading favorite item: $e');
          }
        }
      }

      _updateState(_state.copyWith(items: items));
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error loading favorites: $e');
      }
      _updateState(_state.copyWith(error: e.toString()));
    }
  }

  /// Private: Save favorites to cache
  Future<void> _saveFavorites() async {
    try {
      final favoritesJson = _state.items.map((item) => item.toJson()).toList();
      await CacheService.saveFavoriteFoods(favoritesJson);
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error saving favorites: $e');
      }
    }
  }

  /// Private: Update state and notify listeners
  void _updateState(FavoritesState newState) {
    _state = newState;
    notifyListeners();
  }

  // TODO: Implement backend sync methods when you have a favorites API
  // 
  // Future<void> _syncToBackend(FoodItem item, {required String action}) async {
  //   final response = await ApiClient().post('/favorites', {
  //     'food_id': item.id,
  //     'action': action, // 'add' or 'remove'
  //   });
  //   
  //   if (!response.isSuccessful) {
  //     throw Exception('Failed to sync favorite to backend');
  //   }
  // }
  //
  // Future<void> _clearFavoritesOnBackend() async {
  //   final response = await ApiClient().delete('/favorites/all');
  //   
  //   if (!response.isSuccessful) {
  //     throw Exception('Failed to clear favorites on backend');
  //   }
  // }
  //
  // Future<void> syncFromBackend() async {
  //   try {
  //     final response = await ApiClient().get('/favorites');
  //     final List<dynamic> favoritesData = response.body['favorites'];
  //     
  //     final Set<FoodItem> items = {};
  //     for (final data in favoritesData) {
  //       items.add(FoodItem.fromJson(data));
  //     }
  //     
  //     _updateState(_state.copyWith(items: items));
  //     await _saveFavorites();
  //   } catch (e) {
  //     if (kDebugMode) {
  //       print('❌ Error syncing favorites from backend: $e');
  //     }
  //   }
  // }
}
