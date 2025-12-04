import 'package:flutter/foundation.dart';
import 'package:grab_go_customer/features/home/model/food_category.dart';
import 'package:grab_go_shared/shared/services/cache_service.dart';

class FavoritesProvider extends ChangeNotifier {
  final Set<FoodItem> _favoriteItems = {};

  Set<FoodItem> get favoriteItems => _favoriteItems;
  int get favoritesCount => _favoriteItems.length;
  bool get hasFavorites => _favoriteItems.isNotEmpty;

  FavoritesProvider() {
    _loadFavorites();
  }

  /// Load favorites from cache
  Future<void> _loadFavorites() async {
    try {
      final cachedFavorites = CacheService.getFavoriteFoods();
      _favoriteItems.clear();

      for (final favoriteJson in cachedFavorites) {
        try {
          final foodItem = FoodItem.fromJson(favoriteJson);
          _favoriteItems.add(foodItem);
        } catch (e) {
          if (kDebugMode) {
            print('Error loading favorite item: $e');
          }
        }
      }

      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('Error loading favorites: $e');
      }
    }
  }

  /// Save favorites to cache
  Future<void> _saveFavorites() async {
    try {
      final favoritesJson = _favoriteItems.map((item) => item.toJson()).toList();
      await CacheService.saveFavoriteFoods(favoritesJson);
    } catch (e) {
      if (kDebugMode) {
        print('Error saving favorites: $e');
      }
    }
  }

  /// Add item to favorites
  Future<void> addToFavorites(FoodItem item) async {
    if (_favoriteItems.contains(item)) return;

    _favoriteItems.add(item);
    await _saveFavorites();
    notifyListeners();
  }

  /// Remove item from favorites
  Future<void> removeFromFavorites(FoodItem item) async {
    if (!_favoriteItems.contains(item)) return;

    _favoriteItems.remove(item);
    await _saveFavorites();
    notifyListeners();
  }

  /// Toggle favorite status
  Future<void> toggleFavorite(FoodItem item) async {
    if (isFavorite(item)) {
      await removeFromFavorites(item);
    } else {
      await addToFavorites(item);
    }
  }

  /// Check if item is favorite
  bool isFavorite(FoodItem item) {
    return _favoriteItems.contains(item);
  }

  /// Clear all favorites
  Future<void> clearFavorites() async {
    _favoriteItems.clear();
    await _saveFavorites();
    notifyListeners();
  }

  /// Get favorites by category
  List<FoodItem> getFavoritesByCategory(String category) {
    return _favoriteItems.where((item) => item.name.toLowerCase().contains(category.toLowerCase())).toList();
  }

  /// Search favorites
  List<FoodItem> searchFavorites(String query) {
    if (query.isEmpty) return _favoriteItems.toList();

    final lowercaseQuery = query.toLowerCase();
    return _favoriteItems.where((item) {
      return item.name.toLowerCase().contains(lowercaseQuery) ||
          item.description.toLowerCase().contains(lowercaseQuery) ||
          item.sellerName.toLowerCase().contains(lowercaseQuery);
    }).toList();
  }
}
