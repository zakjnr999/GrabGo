import 'package:flutter/foundation.dart';
import 'package:grab_go_customer/features/restaurant/repository/restaurant_repository.dart';
import 'package:grab_go_customer/features/restaurant/model/restaurants_model.dart';
import 'package:grab_go_customer/shared/services/cache_service.dart';

class RestaurantProvider extends ChangeNotifier {
  List<RestaurantModel> _restaurants = [];
  bool _isLoading = false;
  String? _error;

  List<RestaurantModel> get restaurants => _restaurants;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetchRestaurants({bool forceRefresh = false}) async {
    // Don't fetch if already loading or if we have restaurants (unless force refresh)
    if (!forceRefresh && (_restaurants.isNotEmpty || _isLoading)) {
      if (kDebugMode) {
        print('⏭️ Skipping fetch: restaurants=${_restaurants.isNotEmpty}, loading=$_isLoading');
      }
      return;
    }

    // If force refresh, clear cache first
    if (forceRefresh) {
      try {
        await CacheService.clearRestaurantsCache();
        _restaurants = [];
      } catch (e) {
        if (kDebugMode) {
          print('Error clearing cache for force refresh: $e');
        }
      }
    }

    // Load from cache first for instant display (same as food items)
    bool cacheLoaded = false;
    if (!forceRefresh && _restaurants.isEmpty && CacheService.isRestaurantsCacheValid()) {
      if (kDebugMode) {
        print('📦 Attempting to load restaurants from cache...');
      }
      try {
        _loadRestaurantsFromCache();
        if (_restaurants.isNotEmpty) {
          cacheLoaded = true;
          if (kDebugMode) {
            print('✅ Loaded ${_restaurants.length} restaurants from cache');
          }
          notifyListeners();
          // Fetch fresh data in background without showing loading state
          _fetchRestaurantsInBackground();
        } else {
          if (kDebugMode) {
            print('⚠️ Cache is valid but restaurants list is empty');
          }
        }
      } catch (e) {
        if (kDebugMode) {
          print('❌ Error loading from cache: $e');
        }
        // Clear restaurants in case of error
        _restaurants = [];
      }
    }

    // If cache loading failed or returned empty, fetch from API
    if (!cacheLoaded && _restaurants.isEmpty) {
      if (kDebugMode) {
        print('🔄 Fetching restaurants from API...');
      }
      _isLoading = true;
      _error = null;
      notifyListeners();

      try {
        // Use repository pattern like food items
        _restaurants = await RestaurantRepository().fetchRestaurants();

        if (kDebugMode) {
          print('✅ Loaded ${_restaurants.length} restaurants from API');
        }

        // Save to cache asynchronously without blocking
        _saveRestaurantsToCacheAsync();
      } catch (e) {
        String errorMessage = 'Error fetching restaurants';
        if (e.toString().contains('SocketException') || e.toString().contains('Failed host lookup')) {
          errorMessage = 'Cannot connect to server. Please check your internet connection or try again later.';
        } else if (e.toString().contains('TimeoutException')) {
          errorMessage = 'Request timed out. Please try again.';
        } else {
          errorMessage = 'Error fetching restaurants: ${e.toString()}';
        }
        _error = errorMessage;
        if (kDebugMode) {
          print('❌ Restaurant fetch error: $e');
        }
        // Don't clear restaurants if we had cache data
        if (_restaurants.isEmpty) {
          _restaurants = [];
        }
      } finally {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  /// Fetch restaurants in background without showing loading state
  /// This is called after cache is loaded to refresh data silently
  Future<void> _fetchRestaurantsInBackground() async {
    try {
      if (kDebugMode) {
        print('🔄 Fetching fresh restaurants in background...');
      }
      final freshRestaurants = await RestaurantRepository().fetchRestaurants();

      if (freshRestaurants.isNotEmpty) {
        _restaurants = freshRestaurants;
        if (kDebugMode) {
          print('✅ Updated ${_restaurants.length} restaurants from background fetch');
        }
        // Save to cache asynchronously without blocking
        _saveRestaurantsToCacheAsync();
        notifyListeners();
      }
    } catch (e) {
      // Silently fail in background - we already have cache data
      if (kDebugMode) {
        print('Background restaurant fetch error (ignored): $e');
      }
    }
  }

  Future<void> refreshRestaurants() async {
    _isLoading = true;
    _error = null;
    // Clear cache and restaurants before refreshing to ensure fresh data
    _restaurants = [];
    try {
      // Clear the cache to force fresh fetch
      await CacheService.clearRestaurantsCache();
    } catch (e) {
      if (kDebugMode) {
        print('Error clearing restaurants cache: $e');
      }
    }
    notifyListeners();

    try {
      if (kDebugMode) {
        print('🔄 Refreshing restaurants...');
      }
      // Use repository pattern like food items
      _restaurants = await RestaurantRepository().fetchRestaurants();

      if (kDebugMode) {
        print('✅ Refreshed ${_restaurants.length} restaurants');
      }

      // Save to cache asynchronously without blocking
      _saveRestaurantsToCacheAsync();
    } catch (e) {
      String errorMessage = 'Error refreshing restaurants';
      if (e.toString().contains('SocketException') || e.toString().contains('Failed host lookup')) {
        errorMessage = 'Cannot connect to server. Please check your internet connection or try again later.';
      } else if (e.toString().contains('TimeoutException')) {
        errorMessage = 'Request timed out. Please try again.';
      } else {
        errorMessage = 'Error refreshing restaurants: ${e.toString()}';
      }
      _error = errorMessage;
      if (kDebugMode) {
        print('Restaurant refresh error: $e');
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearRestaurants() {
    _restaurants = [];
    _error = null;
    notifyListeners();
  }

  List<RestaurantModel> getRestaurantsByCity(String city) {
    if (city == 'All') {
      return _restaurants;
    }
    return _restaurants.where((restaurant) => restaurant.city == city).toList();
  }

  List<RestaurantModel> searchRestaurants(String query) {
    if (query.isEmpty) {
      return _restaurants;
    }

    final lowercaseQuery = query.toLowerCase();
    return _restaurants.where((restaurant) {
      return restaurant.name.toLowerCase().contains(lowercaseQuery) ||
          restaurant.foodType.toLowerCase().contains(lowercaseQuery) ||
          restaurant.city.toLowerCase().contains(lowercaseQuery) ||
          restaurant.description.toLowerCase().contains(lowercaseQuery);
    }).toList();
  }

  List<RestaurantModel> getRestaurantsByCityAndSearch(String city, String searchQuery) {
    List<RestaurantModel> filteredRestaurants = getRestaurantsByCity(city);

    if (searchQuery.isEmpty) {
      return filteredRestaurants;
    }

    final lowercaseQuery = searchQuery.toLowerCase();
    return filteredRestaurants.where((restaurant) {
      return restaurant.name.toLowerCase().contains(lowercaseQuery) ||
          restaurant.foodType.toLowerCase().contains(lowercaseQuery) ||
          restaurant.city.toLowerCase().contains(lowercaseQuery) ||
          restaurant.description.toLowerCase().contains(lowercaseQuery);
    }).toList();
  }

  void _loadRestaurantsFromCache() {
    try {
      final cachedRestaurants = CacheService.getRestaurants();
      if (kDebugMode) {
        print('📦 Cache contains ${cachedRestaurants.length} restaurants');
      }

      // Filter to only approved restaurants from cache (extra safety)
      // If status is missing, assume approved (for backward compatibility with old cache)
      final approvedCached = cachedRestaurants.where((json) {
        try {
          final status = json['status']?.toString().toLowerCase() ?? '';
          // If status is empty (missing), assume approved (backward compatibility)
          // Otherwise, only include if explicitly approved
          return status.isEmpty || status == 'approved';
        } catch (e) {
          return false;
        }
      }).toList();

      if (kDebugMode) {
        print('📦 Found ${approvedCached.length} approved restaurants in cache');
      }

      // Parse restaurants one by one, skipping invalid ones
      final List<RestaurantModel> loadedRestaurants = [];
      for (final json in approvedCached) {
        try {
          final restaurant = RestaurantModel.fromJson(json);
          loadedRestaurants.add(restaurant);
        } catch (e) {
          if (kDebugMode) {
            print('⚠️ Skipping invalid restaurant from cache: $e');
          }
          continue;
        }
      }

      _restaurants = loadedRestaurants;

      if (kDebugMode) {
        print('✅ Successfully loaded ${_restaurants.length} restaurants from cache');
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('❌ Error loading restaurants from cache: $e');
        print('Stack trace: $stackTrace');
      }
      _restaurants = [];
      rethrow; // Rethrow to let caller know cache loading failed
    }
  }

  /// Save restaurants to cache asynchronously without blocking the UI
  void _saveRestaurantsToCacheAsync() {
    // Schedule cache saving in the next microtask to avoid blocking
    Future.microtask(() async {
      try {
        final restaurantsJson = _restaurants
            .map(
              (restaurant) => {
                'id': restaurant.id,
                'backendId': restaurant.backendId,
                'name': restaurant.name,
                'city': restaurant.city,
                'foodType': restaurant.foodType,
                'imageUrl': restaurant.imageUrl,
                'bannerImages': restaurant.bannerImages,
                'distance': restaurant.distance,
                'rating': restaurant.rating,
                'totalReviews': restaurant.totalReviews,
                'averageDeliveryTime': restaurant.averageDeliveryTime,
                'deliveryFee': restaurant.deliveryFee,
                'minOrder': restaurant.minOrder,
                'description': restaurant.description,
                'phone': restaurant.phone,
                'email': restaurant.email,
                'address': restaurant.address,
                'latitude': restaurant.latitude,
                'longitude': restaurant.longitude,
                'openingHours': restaurant.openingHours,
                'isOpen': restaurant.isOpen,
                'paymentMethods': restaurant.paymentMethods,
                'socials': {'facebook': restaurant.socials.facebook, 'instagram': restaurant.socials.instagram},
                'status': 'approved', // Include status field for cache filtering
                'foods': restaurant.foods
                    .map(
                      (food) => {
                        'id': food.id,
                        'backendId': food.backendId,
                        'name': food.name,
                        'description': food.description,
                        'price': food.price,
                        'imageUrl': food.imageUrl,
                        'category': food.category,
                        'sellerId': food.sellerId,
                        'sellerName': food.sellerName,
                        'restaurantId': food.restaurantId,
                      },
                    )
                    .toList(),
              },
            )
            .toList();

        await CacheService.saveRestaurants(restaurantsJson);
      } catch (e) {
        if (kDebugMode) {
          print('Error saving restaurants to cache: $e');
        }
      }
    });
  }
}
