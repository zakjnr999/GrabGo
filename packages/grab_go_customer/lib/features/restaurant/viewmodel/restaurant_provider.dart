import 'package:flutter/foundation.dart';
import 'package:grab_go_customer/features/restaurant/model/restaurants_model.dart';
import 'package:grab_go_customer/features/restaurant/model/restaurant_response.dart' as response;
import 'package:grab_go_customer/core/api/api_client.dart';
import 'package:grab_go_customer/shared/services/cache_service.dart';

class RestaurantProvider extends ChangeNotifier {
  List<RestaurantModel> _restaurants = [];
  bool _isLoading = false;
  String? _error;

  List<RestaurantModel> get restaurants => _restaurants;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetchRestaurants() async {
    if (_restaurants.isNotEmpty || _isLoading) return;

    if (_restaurants.isEmpty && CacheService.isRestaurantsCacheValid()) {
      _loadRestaurantsFromCache();
      if (_restaurants.isNotEmpty) {
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
        print('Restaurant API Response: ${apiResponse.body}');
        print('Response Type: ${apiResponse.body.runtimeType}');
      }

      if (apiResponse.isSuccessful) {
        if (apiResponse.body is List<response.RestaurantData>) {
          final List<response.RestaurantData> restaurantData = apiResponse.body!;
          _restaurants = restaurantData.map((data) => _convertRestaurantDataToModel(data)).toList();
        } else if (apiResponse.body is Map<String, dynamic>) {
          final Map<String, dynamic> responseData = apiResponse.body as Map<String, dynamic>;
          if (responseData.containsKey('data')) {
            final restaurantData = responseData['data'];
            if (restaurantData is List) {
              _restaurants = restaurantData.map((json) => RestaurantModel.fromJson(json)).toList();
            } else if (restaurantData is Map<String, dynamic>) {
              _restaurants = [RestaurantModel.fromJson(restaurantData)];
            }
          } else {
            _restaurants = [RestaurantModel.fromJson(responseData)];
          }
        } else if (apiResponse.body is List) {
          final List<dynamic> data = apiResponse.body as List<dynamic>;
          _restaurants = data.map((json) => RestaurantModel.fromJson(json)).toList();
        }

        _saveRestaurantsToCache();

        if (kDebugMode) {
          print('Parsed ${_restaurants.length} restaurants');
          if (_restaurants.isNotEmpty) {
            print('First restaurant: ${_restaurants.first.name}');
          }
        }
      } else {
        _error = 'Failed to fetch restaurants: ${apiResponse.statusCode}';
      }
    } catch (e) {
      _error = 'Error fetching restaurants: $e';
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
    notifyListeners();

    try {
      final apiResponse = await restaurantService.getRestaurants();

      if (kDebugMode) {
        print('Restaurant API Response (Refresh): ${apiResponse.body}');
        print('Response Type: ${apiResponse.body.runtimeType}');
      }

      if (apiResponse.isSuccessful) {
        if (apiResponse.body is List<response.RestaurantData>) {
          final List<response.RestaurantData> restaurantData = apiResponse.body!;
          _restaurants = restaurantData.map((data) => _convertRestaurantDataToModel(data)).toList();
        } else if (apiResponse.body is Map<String, dynamic>) {
          final Map<String, dynamic> responseData = apiResponse.body as Map<String, dynamic>;
          if (responseData.containsKey('data')) {
            final restaurantData = responseData['data'];
            if (restaurantData is List) {
              _restaurants = restaurantData.map((json) => RestaurantModel.fromJson(json)).toList();
            } else if (restaurantData is Map<String, dynamic>) {
              _restaurants = [RestaurantModel.fromJson(restaurantData)];
            }
          } else {
            _restaurants = [RestaurantModel.fromJson(responseData)];
          }
        } else if (apiResponse.body is List) {
          final List<dynamic> data = apiResponse.body as List<dynamic>;
          _restaurants = data.map((json) => RestaurantModel.fromJson(json)).toList();
        }

        if (kDebugMode) {
          print('Refreshed ${_restaurants.length} restaurants');
          if (_restaurants.isNotEmpty) {
            print('First restaurant: ${_restaurants.first.name}');
          }
        }
      } else {
        _error = 'Failed to refresh restaurants: ${apiResponse.statusCode}';
      }
    } catch (e) {
      _error = 'Error refreshing restaurants: $e';
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
      _restaurants = cachedRestaurants.map((json) => RestaurantModel.fromJson(json)).toList();

      if (kDebugMode) {
        print('Loaded ${_restaurants.length} restaurants from cache');
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
      id: int.tryParse(data.id.substring(data.id.length - 6)) ?? 0,
      name: data.restaurantName,
      city: data.city,
      foodType: data.foodType ?? 'Food',
      imageUrl: data.logo ?? '',
      bannerImages: data.bannerImages ?? [],
      distance: 0.0,
      rating: data.rating,
      totalReviews: data.totalReviews,
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
      isOpen: data.isOpen,
      paymentMethods: data.paymentMethods ?? [],
      socials: Socials(facebook: data.socials?.facebook ?? '', instagram: data.socials?.instagram ?? ''),
      foods: [],
    );
  }
}
