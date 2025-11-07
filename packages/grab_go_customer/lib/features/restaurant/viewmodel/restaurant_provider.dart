import 'package:flutter/foundation.dart';
import 'package:grab_go_customer/core/api/api_client.dart';
import 'package:grab_go_customer/features/restaurant/model/restaurants_model.dart';
import 'package:grab_go_customer/features/restaurant/model/restaurant_response.dart' as response;
import 'package:grab_go_customer/shared/services/cache_service.dart';

class RestaurantProvider extends ChangeNotifier {
  List<RestaurantModel> _restaurants = [];
  bool _isLoading = false;
  String? _error;

  List<RestaurantModel> get restaurants => _restaurants;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetchRestaurants({bool forceRefresh = false}) async {
    if (!forceRefresh && (_restaurants.isNotEmpty || _isLoading)) return;

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

    if (!forceRefresh && _restaurants.isEmpty && CacheService.isRestaurantsCacheValid()) {
      _loadRestaurantsFromCache();
      if (_restaurants.isNotEmpty) {
        if (kDebugMode) {
          print('📦 Loaded ${_restaurants.length} restaurants from cache');
        }
        notifyListeners();
        return;
      }
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final apiResponse = await restaurantService.getRestaurants();

      if (kDebugMode) {
        print('🔄 Restaurant API Response: ${apiResponse.body}');
        print('📊 Response Type: ${apiResponse.body.runtimeType}');
        print('✅ Response Status: ${apiResponse.statusCode}');

        // Check if the specific restaurant is in the response
        if (apiResponse.body is Map<String, dynamic>) {
          final responseData = apiResponse.body as Map<String, dynamic>;
          if (responseData.containsKey('data') && responseData['data'] is List) {
            final allData = responseData['data'] as List;
            final targetRestaurant = allData.firstWhere(
              (r) => r is Map<String, dynamic> && r['_id']?.toString() == '690de37b36aa959e581c5582',
              orElse: () => null,
            );
            if (targetRestaurant != null) {
              print('🔎 Found "Adepa Resraurant" in API response');
              print('   Status: ${(targetRestaurant as Map<String, dynamic>)['status']}');
            } else {
              print('❌ "Adepa Resraurant" (ID: 690de37b36aa959e581c5582) NOT found in API response');
              print('   Total restaurants in response: ${allData.length}');
            }
          }
        }
      }

      if (apiResponse.isSuccessful) {
        List<RestaurantModel> allRestaurants = [];

        if (apiResponse.body is List<response.RestaurantData>) {
          final List<response.RestaurantData> restaurantData = apiResponse.body!;
          // Filter to only approved restaurants before converting
          final approvedRestaurants = restaurantData.where((data) => data.status.toLowerCase() == 'approved').toList();
          allRestaurants = approvedRestaurants.map((data) => _convertRestaurantDataToModel(data)).toList();
        } else if (apiResponse.body is Map<String, dynamic>) {
          final Map<String, dynamic> responseData = apiResponse.body as Map<String, dynamic>;
          if (responseData.containsKey('data')) {
            final restaurantData = responseData['data'];
            if (restaurantData is List) {
              // Filter approved restaurants from raw JSON
              final approvedList = restaurantData.where((json) {
                if (json is Map<String, dynamic>) {
                  final status = json['status']?.toString().toLowerCase() ?? '';
                  return status == 'approved';
                }
                return false;
              }).toList();
              allRestaurants = approvedList
                  .map((json) => RestaurantModel.fromJson(json as Map<String, dynamic>))
                  .toList();
            } else if (restaurantData is Map<String, dynamic>) {
              final status = restaurantData['status']?.toString().toLowerCase() ?? '';
              if (status == 'approved') {
                allRestaurants = [RestaurantModel.fromJson(restaurantData)];
              }
            }
          } else {
            final status = responseData['status']?.toString().toLowerCase() ?? '';
            if (status == 'approved') {
              allRestaurants = [RestaurantModel.fromJson(responseData)];
            }
          }
        } else if (apiResponse.body is List) {
          final List<dynamic> data = apiResponse.body as List<dynamic>;
          // Filter approved restaurants from raw list
          final approvedList = data.where((json) {
            if (json is Map<String, dynamic>) {
              final status = json['status']?.toString().toLowerCase() ?? '';
              return status == 'approved';
            }
            return false;
          }).toList();
          allRestaurants = approvedList.map((json) => RestaurantModel.fromJson(json as Map<String, dynamic>)).toList();
        }

        _restaurants = allRestaurants;
        _saveRestaurantsToCache();

        if (kDebugMode) {
          print('✅ Parsed ${_restaurants.length} approved restaurants');
          if (_restaurants.isNotEmpty) {
            print('📋 Restaurants found:');
            for (var restaurant in _restaurants) {
              print('   - ${restaurant.name} (ID: ${restaurant.id})');
            }
          } else {
            print('⚠️ No approved restaurants found in response');
          }
        }
      } else {
        _error = 'Failed to fetch restaurants: ${apiResponse.statusCode}';
      }
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
        print('Restaurant fetch error: $e');
      }
    } finally {
      _isLoading = false;
      notifyListeners();
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
      final apiResponse = await restaurantService.getRestaurants();

      if (kDebugMode) {
        print('🔄 Restaurant API Response (Refresh): ${apiResponse.body}');
        print('📊 Response Type: ${apiResponse.body.runtimeType}');
        print('✅ Response Status: ${apiResponse.statusCode}');
      }

      if (apiResponse.isSuccessful) {
        List<RestaurantModel> allRestaurants = [];

        if (apiResponse.body is List<response.RestaurantData>) {
          final List<response.RestaurantData> restaurantData = apiResponse.body!;
          // Filter to only approved restaurants before converting
          final approvedRestaurants = restaurantData.where((data) => data.status.toLowerCase() == 'approved').toList();
          allRestaurants = approvedRestaurants.map((data) => _convertRestaurantDataToModel(data)).toList();
        } else if (apiResponse.body is Map<String, dynamic>) {
          final Map<String, dynamic> responseData = apiResponse.body as Map<String, dynamic>;
          if (responseData.containsKey('data')) {
            final restaurantData = responseData['data'];
            if (restaurantData is List) {
              // Filter approved restaurants from raw JSON
              final approvedList = restaurantData.where((json) {
                if (json is Map<String, dynamic>) {
                  final status = json['status']?.toString().toLowerCase() ?? '';
                  return status == 'approved';
                }
                return false;
              }).toList();
              allRestaurants = approvedList
                  .map((json) => RestaurantModel.fromJson(json as Map<String, dynamic>))
                  .toList();
            } else if (restaurantData is Map<String, dynamic>) {
              final status = restaurantData['status']?.toString().toLowerCase() ?? '';
              if (status == 'approved') {
                allRestaurants = [RestaurantModel.fromJson(restaurantData)];
              }
            }
          } else {
            final status = responseData['status']?.toString().toLowerCase() ?? '';
            if (status == 'approved') {
              allRestaurants = [RestaurantModel.fromJson(responseData)];
            }
          }
        } else if (apiResponse.body is List) {
          final List<dynamic> data = apiResponse.body as List<dynamic>;
          // Filter approved restaurants from raw list
          final approvedList = data.where((json) {
            if (json is Map<String, dynamic>) {
              final status = json['status']?.toString().toLowerCase() ?? '';
              return status == 'approved';
            }
            return false;
          }).toList();
          allRestaurants = approvedList.map((json) => RestaurantModel.fromJson(json as Map<String, dynamic>)).toList();
        }

        _restaurants = allRestaurants;
        _saveRestaurantsToCache();

        if (kDebugMode) {
          print('✅ Refreshed ${_restaurants.length} approved restaurants');
          if (_restaurants.isNotEmpty) {
            print('📋 Restaurants found:');
            for (var restaurant in _restaurants) {
              print('   - ${restaurant.name} (ID: ${restaurant.id})');
            }
          } else {
            print('⚠️ No approved restaurants found after refresh');
            print('🔍 Checking if restaurant with ID 690de37b36aa959e581c5582 is in response...');
            if (apiResponse.body is Map<String, dynamic>) {
              final responseData = apiResponse.body as Map<String, dynamic>;
              if (responseData.containsKey('data') && responseData['data'] is List) {
                final allData = responseData['data'] as List;
                final targetRestaurant = allData.firstWhere(
                  (r) => r['_id']?.toString() == '690de37b36aa959e581c5582',
                  orElse: () => null,
                );
                if (targetRestaurant != null) {
                  print('🔎 Found restaurant in response: ${targetRestaurant['restaurant_name']}');
                  print('   Status: ${targetRestaurant['status']}');
                } else {
                  print('❌ Restaurant not found in API response');
                }
              }
            }
          }
        }
      } else {
        _error = 'Failed to refresh restaurants: ${apiResponse.statusCode}';
      }
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
      // Filter to only approved restaurants from cache (extra safety)
      final approvedCached = cachedRestaurants.where((json) {
        final status = json['status']?.toString().toLowerCase() ?? '';
        return status == 'approved';
      }).toList();
      _restaurants = approvedCached.map((json) => RestaurantModel.fromJson(json)).toList();

      if (kDebugMode) {
        print('Loaded ${_restaurants.length} approved restaurants from cache');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading restaurants from cache: $e');
      }
      _restaurants = [];
    }
  }

  void _saveRestaurantsToCache() {
    try {
      final restaurantsJson = _restaurants
          .map(
            (restaurant) => {
              'id': restaurant.id,
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
              'foods': restaurant.foods
                  .map(
                    (food) => {
                      'id': food.id,
                      'name': food.name,
                      'description': food.description,
                      'price': food.price,
                      'imageUrl': food.imageUrl,
                      'category': food.category,
                      'sellerId': food.sellerId,
                      'sellerName': food.sellerName,
                    },
                  )
                  .toList(),
            },
          )
          .toList();

      CacheService.saveRestaurants(restaurantsJson);

      if (kDebugMode) {
        print('Saved ${_restaurants.length} restaurants to cache');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error saving restaurants to cache: $e');
      }
    }
  }

  RestaurantModel _convertRestaurantDataToModel(response.RestaurantData data) {
    return RestaurantModel(
      id: int.tryParse(data.id.length > 6 ? data.id.substring(data.id.length - 6) : data.id) ?? 0,
      name: data.restaurantName,
      city: data.city,
      foodType: data.foodType ?? 'Food',
      imageUrl: data.logo ?? '',
      bannerImages: data.bannerImages ?? [],
      distance: 0.0,
      rating: data.rating,
      totalReviews: data.totalReviews ?? 0,
      averageDeliveryTime: data.averageDeliveryTime ?? '30 mins',
      deliveryFee: data.deliveryFee ?? 0.0,
      minOrder: data.minOrder ?? 0.0,
      description: data.description ?? '',
      phone: data.phone,
      email: data.email,
      address: data.address,
      latitude: data.latitude ?? 0.0,
      longitude: data.longitude ?? 0.0,
      openingHours: data.openingHours ?? '9:00 AM - 10:00 PM',
      isOpen: data.isOpen ?? true,
      paymentMethods: data.paymentMethods ?? [],
      socials: Socials(facebook: data.socials?.facebook ?? '', instagram: data.socials?.instagram ?? ''),
      foods: [],
    );
  }
}
