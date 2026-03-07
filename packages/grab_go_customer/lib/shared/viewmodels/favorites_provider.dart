import 'dart:convert';

import 'package:chopper/chopper.dart';
import 'package:flutter/foundation.dart';
import 'package:grab_go_customer/core/api/api_client.dart';
import 'package:grab_go_customer/features/home/model/food_category.dart';
import 'package:grab_go_customer/shared/viewmodels/base_provider.dart';
import 'package:grab_go_shared/shared/services/cache_service.dart';

enum FavoriteVendorType {
  restaurant,
  groceryStore,
  pharmacyStore,
  grabMartStore,
}

class FavoriteVendor {
  final String id;
  final String name;
  final String image;
  final List<String> bannerImages;
  final String? address;
  final String? city;
  final String? area;
  final String status;
  final bool isOpen;
  final bool isAcceptingOrders;
  final bool isVerified;
  final bool featured;
  final double deliveryFee;
  final double minOrder;
  final double rating;
  final int totalReviews;
  final List<String> categories;
  final int averageDeliveryTime;
  final bool isGrabGoExclusiveActive;
  final DateTime? lastOnlineAt;
  final DateTime? addedAt;
  final FavoriteVendorType type;

  const FavoriteVendor({
    required this.id,
    required this.name,
    required this.image,
    this.bannerImages = const [],
    this.address,
    this.city,
    this.area,
    required this.status,
    required this.isOpen,
    required this.isAcceptingOrders,
    required this.isVerified,
    required this.featured,
    this.deliveryFee = 0,
    this.minOrder = 0,
    this.rating = 4.0,
    this.totalReviews = 0,
    this.categories = const [],
    this.averageDeliveryTime = 30,
    this.isGrabGoExclusiveActive = false,
    this.lastOnlineAt,
    this.addedAt,
    required this.type,
  });

  String get typeLabel {
    switch (type) {
      case FavoriteVendorType.restaurant:
        return 'Restaurant';
      case FavoriteVendorType.groceryStore:
        return 'Grocery Store';
      case FavoriteVendorType.pharmacyStore:
        return 'Pharmacy';
      case FavoriteVendorType.grabMartStore:
        return 'GrabMart';
    }
  }

  bool get isOperational =>
      status.toLowerCase() == 'approved' && isOpen && isAcceptingOrders;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'image': image,
    'bannerImages': bannerImages,
    'address': address,
    'city': city,
    'area': area,
    'status': status,
    'isOpen': isOpen,
    'isAcceptingOrders': isAcceptingOrders,
    'isVerified': isVerified,
    'featured': featured,
    'deliveryFee': deliveryFee,
    'minOrder': minOrder,
    'rating': rating,
    'totalReviews': totalReviews,
    'categories': categories,
    'averageDeliveryTime': averageDeliveryTime,
    'isGrabGoExclusiveActive': isGrabGoExclusiveActive,
    'lastOnlineAt': lastOnlineAt?.toIso8601String(),
    'addedAt': addedAt?.toIso8601String(),
    'type': type.name,
  };

  factory FavoriteVendor.fromJson(Map<String, dynamic> json) {
    final typeValue = json['type']?.toString().trim() ?? '';
    final type = FavoriteVendorType.values.firstWhere(
      (entry) => entry.name == typeValue,
      orElse: () => FavoriteVendorType.restaurant,
    );

    return FavoriteVendor(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Unknown Vendor',
      image: json['image']?.toString() ?? '',
      bannerImages:
          (json['bannerImages'] as List<dynamic>?)
              ?.map((entry) => entry.toString())
              .where((entry) => entry.trim().isNotEmpty)
              .toList(growable: false) ??
          const [],
      address: json['address']?.toString(),
      city: json['city']?.toString(),
      area: json['area']?.toString(),
      status: json['status']?.toString() ?? 'approved',
      isOpen: _parseBool(json['isOpen'], defaultValue: true),
      isAcceptingOrders: _parseBool(
        json['isAcceptingOrders'],
        defaultValue: true,
      ),
      isVerified: _parseBool(json['isVerified'], defaultValue: false),
      featured: _parseBool(json['featured'], defaultValue: false),
      deliveryFee: _parseDouble(json['deliveryFee']),
      minOrder: _parseDouble(json['minOrder']),
      rating: _parseDouble(json['rating'], defaultValue: 4.0),
      totalReviews: _parseInt(json['totalReviews']),
      categories:
          (json['categories'] as List<dynamic>?)
              ?.map((entry) => entry.toString())
              .where((entry) => entry.trim().isNotEmpty)
              .toList(growable: false) ??
          const [],
      averageDeliveryTime: _parseInt(
        json['averageDeliveryTime'],
        defaultValue: 30,
      ),
      isGrabGoExclusiveActive: _parseBool(
        json['isGrabGoExclusiveActive'],
        defaultValue: false,
      ),
      lastOnlineAt: json['lastOnlineAt'] != null
          ? DateTime.tryParse(json['lastOnlineAt'].toString())
          : null,
      addedAt: json['addedAt'] != null
          ? DateTime.tryParse(json['addedAt'].toString())
          : null,
      type: type,
    );
  }
}

class FavoritesState {
  final Set<FoodItem> items;
  final List<FavoriteVendor> vendors;
  final bool isLoading;
  final bool isSyncing;
  final String? error;

  const FavoritesState({
    this.items = const {},
    this.vendors = const [],
    this.isLoading = false,
    this.isSyncing = false,
    this.error,
  });

  FavoritesState copyWith({
    Set<FoodItem>? items,
    List<FavoriteVendor>? vendors,
    bool? isLoading,
    bool? isSyncing,
    String? error,
    bool clearError = false,
  }) {
    return FavoritesState(
      items: items ?? this.items,
      vendors: vendors ?? this.vendors,
      isLoading: isLoading ?? this.isLoading,
      isSyncing: isSyncing ?? this.isSyncing,
      error: clearError ? null : (error ?? this.error),
    );
  }

  int get count => items.length;
  int get vendorCount => vendors.length;
  int get totalCount => count + vendorCount;
  bool get hasFavorites => items.isNotEmpty;
  bool get hasAnyFavorites => totalCount > 0;
  List<FoodItem> get asList => items.toList();
}

class FavoritesProvider extends ChangeNotifier with CacheMixin {
  static const String _vendorsCacheKey = 'favorite_vendors_v1';

  FavoritesState _state = const FavoritesState();
  FavoritesState get state => _state;

  Set<FoodItem> get favoriteItems => _state.items;
  List<FavoriteVendor> get favoriteVendors => _state.vendors;
  int get favoritesCount => _state.count;
  bool get hasFavorites => _state.hasFavorites;
  bool get hasAnyFavorites => _state.hasAnyFavorites;

  FavoritesProvider() {
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await _loadFavoritesFromCache();
    await syncFromBackend();
  }

  bool isFavorite(FoodItem item) {
    return _state.items.any((entry) => _isSameFavoriteItem(entry, item));
  }

  Future<void> addToFavorites(FoodItem item) async {
    if (isFavorite(item)) return;

    final previousItems = Set<FoodItem>.from(_state.items);
    final nextItems = Set<FoodItem>.from(_state.items)..add(item);
    _updateState(_state.copyWith(items: nextItems, clearError: true));
    await _saveFavoriteItemsToCache();

    try {
      await _addItemFavoriteOnBackend(item);
    } catch (error) {
      _updateState(
        _state.copyWith(items: previousItems, error: error.toString()),
      );
      await _saveFavoriteItemsToCache();
      rethrow;
    }
  }

  Future<void> removeFromFavorites(FoodItem item) async {
    if (!isFavorite(item)) return;

    final previousItems = Set<FoodItem>.from(_state.items);
    final nextItems = _state.items
        .where((entry) => !_isSameFavoriteItem(entry, item))
        .toSet();
    _updateState(_state.copyWith(items: nextItems, clearError: true));
    await _saveFavoriteItemsToCache();

    try {
      await _removeItemFavoriteOnBackend(item);
    } catch (error) {
      _updateState(
        _state.copyWith(items: previousItems, error: error.toString()),
      );
      await _saveFavoriteItemsToCache();
      rethrow;
    }
  }

  Future<void> toggleFavorite(FoodItem item) async {
    if (isFavorite(item)) {
      await removeFromFavorites(item);
    } else {
      await addToFavorites(item);
    }
  }

  bool isVendorFavorite(FavoriteVendor vendor) {
    return isVendorFavoriteById(vendor.id, vendor.type);
  }

  bool isVendorFavoriteById(String vendorId, FavoriteVendorType type) {
    return _state.vendors.any(
      (entry) => entry.id == vendorId && entry.type == type,
    );
  }

  Future<void> addVendorToFavorites(FavoriteVendor vendor) async {
    if (isVendorFavorite(vendor)) return;

    final previousVendors = List<FavoriteVendor>.from(_state.vendors);
    final nextVendors = List<FavoriteVendor>.from(_state.vendors)..add(vendor);
    _updateState(_state.copyWith(vendors: nextVendors, clearError: true));
    await _saveFavoriteVendorsToCache();

    try {
      await _addVendorFavoriteOnBackend(vendor);
    } catch (error) {
      _updateState(
        _state.copyWith(vendors: previousVendors, error: error.toString()),
      );
      await _saveFavoriteVendorsToCache();
      rethrow;
    }
  }

  Future<void> toggleVendorFavorite(FavoriteVendor vendor) async {
    if (isVendorFavorite(vendor)) {
      await removeVendorFromFavorites(vendor);
    } else {
      await addVendorToFavorites(vendor);
    }
  }

  Future<void> removeVendorFromFavorites(FavoriteVendor vendor) async {
    final exists = _state.vendors.any(
      (entry) => entry.id == vendor.id && entry.type == vendor.type,
    );
    if (!exists) return;

    final previousVendors = List<FavoriteVendor>.from(_state.vendors);
    final nextVendors = _state.vendors
        .where((entry) => !(entry.id == vendor.id && entry.type == vendor.type))
        .toList(growable: false);
    _updateState(_state.copyWith(vendors: nextVendors, clearError: true));
    await _saveFavoriteVendorsToCache();

    try {
      await _removeVendorFavoriteOnBackend(vendor);
    } catch (error) {
      _updateState(
        _state.copyWith(vendors: previousVendors, error: error.toString()),
      );
      await _saveFavoriteVendorsToCache();
      rethrow;
    }
  }

  Future<void> clearFavorites() async {
    final previousItems = Set<FoodItem>.from(_state.items);
    final previousVendors = List<FavoriteVendor>.from(_state.vendors);

    _updateState(
      _state.copyWith(items: {}, vendors: const [], clearError: true),
    );
    await _saveFavoritesToCache();

    try {
      final response = await _sendRequest('DELETE', '/favorites');
      if (!response.isSuccessful) {
        throw Exception(
          _extractApiError(
            response,
            fallback: 'Failed to clear favorites on backend',
          ),
        );
      }
    } catch (error) {
      _updateState(
        _state.copyWith(
          items: previousItems,
          vendors: previousVendors,
          error: error.toString(),
        ),
      );
      await _saveFavoritesToCache();
      rethrow;
    }
  }

  Future<void> syncFromBackend({bool showLoading = false}) async {
    if (_state.isSyncing) return;

    _updateState(
      _state.copyWith(
        isLoading: showLoading ? true : _state.isLoading,
        isSyncing: true,
        clearError: true,
      ),
    );

    try {
      final authToken = await CacheService.getAuthToken();
      if (authToken == null || authToken.trim().isEmpty) {
        _updateState(
          _state.copyWith(isLoading: false, isSyncing: false, clearError: true),
        );
        return;
      }

      final response = await _sendRequest('GET', '/favorites');
      if (!response.isSuccessful) {
        throw Exception(
          _extractApiError(response, fallback: 'Failed to fetch favorites'),
        );
      }

      final payload = _extractBodyMap(response.body);
      final data = payload['data'] is Map
          ? Map<String, dynamic>.from(payload['data'] as Map)
          : payload;

      final items = _parseFavoriteItems(data);
      final vendors = _parseFavoriteVendors(data);

      _updateState(
        _state.copyWith(
          items: items,
          vendors: vendors,
          isLoading: false,
          isSyncing: false,
          clearError: true,
        ),
      );
      await _saveFavoritesToCache();
    } catch (error) {
      if (kDebugMode) {
        print('❌ Error syncing favorites from backend: $error');
      }
      _updateState(
        _state.copyWith(isLoading: false, isSyncing: false, error: '$error'),
      );
    }
  }

  List<FoodItem> getFavoritesByCategory(String category) {
    return _state.items
        .where(
          (item) => item.name.toLowerCase().contains(category.toLowerCase()),
        )
        .toList();
  }

  List<FoodItem> searchFavorites(String query) {
    if (query.isEmpty) return _state.asList;

    final lowercaseQuery = query.toLowerCase();
    return _state.items.where((item) {
      return item.name.toLowerCase().contains(lowercaseQuery) ||
          item.description.toLowerCase().contains(lowercaseQuery) ||
          item.sellerName.toLowerCase().contains(lowercaseQuery);
    }).toList();
  }

  List<FavoriteVendor> searchFavoriteVendors(String query) {
    if (query.isEmpty) return List<FavoriteVendor>.from(_state.vendors);

    final lowercaseQuery = query.toLowerCase();
    return _state.vendors
        .where((vendor) {
          final location = '${vendor.city ?? ''} ${vendor.area ?? ''}'.trim();
          return vendor.name.toLowerCase().contains(lowercaseQuery) ||
              vendor.typeLabel.toLowerCase().contains(lowercaseQuery) ||
              location.toLowerCase().contains(lowercaseQuery);
        })
        .toList(growable: false);
  }

  List<FoodItem> getFavoritesSortedByPrice({bool ascending = true}) {
    final list = _state.asList;
    list.sort(
      (a, b) =>
          ascending ? a.price.compareTo(b.price) : b.price.compareTo(a.price),
    );
    return list;
  }

  List<FoodItem> getFavoritesSortedByRating({bool ascending = false}) {
    final list = _state.asList;
    list.sort(
      (a, b) => ascending
          ? a.rating.compareTo(b.rating)
          : b.rating.compareTo(a.rating),
    );
    return list;
  }

  Map<String, List<FoodItem>> getFavoritesByRestaurant() {
    final grouped = <String, List<FoodItem>>{};

    for (final item in _state.items) {
      final restaurantName = item.sellerName;
      if (!grouped.containsKey(restaurantName)) {
        grouped[restaurantName] = [];
      }
      grouped[restaurantName]!.add(item);
    }

    return grouped;
  }

  Future<void> _loadFavoritesFromCache() async {
    try {
      final cachedFavoriteItems = CacheService.getFavoriteFoods();
      final items = <FoodItem>{};

      for (final favoriteJson in cachedFavoriteItems) {
        try {
          items.add(FoodItem.fromJson(favoriteJson));
        } catch (error) {
          if (kDebugMode) {
            print('❌ Error loading favorite item from cache: $error');
          }
        }
      }

      final vendors = <FavoriteVendor>[];
      final vendorsJson = CacheService.getData(_vendorsCacheKey);
      if (vendorsJson != null && vendorsJson.isNotEmpty) {
        final decoded = jsonDecode(vendorsJson);
        if (decoded is List) {
          for (final entry in decoded) {
            if (entry is Map<String, dynamic>) {
              vendors.add(FavoriteVendor.fromJson(entry));
            } else if (entry is Map) {
              vendors.add(
                FavoriteVendor.fromJson(Map<String, dynamic>.from(entry)),
              );
            }
          }
        }
      }

      _updateState(_state.copyWith(items: items, vendors: vendors));
    } catch (error) {
      if (kDebugMode) {
        print('❌ Error loading favorites cache: $error');
      }
      _updateState(_state.copyWith(error: error.toString()));
    }
  }

  Future<void> _saveFavoritesToCache() async {
    await Future.wait([
      _saveFavoriteItemsToCache(),
      _saveFavoriteVendorsToCache(),
    ]);
  }

  Future<void> _saveFavoriteItemsToCache() async {
    try {
      final favoritesJson = _state.items.map((item) => item.toJson()).toList();
      await CacheService.saveFavoriteFoods(favoritesJson);
    } catch (error) {
      if (kDebugMode) {
        print('❌ Error saving favorite items cache: $error');
      }
    }
  }

  Future<void> _saveFavoriteVendorsToCache() async {
    try {
      final vendorsJson = jsonEncode(
        _state.vendors.map((vendor) => vendor.toJson()).toList(),
      );
      await CacheService.saveData(_vendorsCacheKey, vendorsJson);
    } catch (error) {
      if (kDebugMode) {
        print('❌ Error saving favorite vendors cache: $error');
      }
    }
  }

  void _updateState(FavoritesState newState) {
    _state = newState;
    notifyListeners();
  }

  Future<Response<dynamic>> _sendRequest(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final request = Request(
      method.toUpperCase(),
      Uri.parse(path),
      chopperClient.baseUrl,
      body: body,
    );

    return chopperClient.send<dynamic, dynamic>(request);
  }

  Future<void> _addItemFavoriteOnBackend(FoodItem item) async {
    final response = await _sendRequest('POST', _itemFavoritePath(item));
    if (!response.isSuccessful) {
      throw Exception(
        _extractApiError(
          response,
          fallback: 'Failed to add favorite item on backend',
        ),
      );
    }
  }

  Future<void> _removeItemFavoriteOnBackend(FoodItem item) async {
    final response = await _sendRequest('DELETE', _itemFavoritePath(item));
    if (!response.isSuccessful) {
      throw Exception(
        _extractApiError(
          response,
          fallback: 'Failed to remove favorite item on backend',
        ),
      );
    }
  }

  Future<void> _removeVendorFavoriteOnBackend(FavoriteVendor vendor) async {
    final response = await _sendRequest('DELETE', _vendorFavoritePath(vendor));
    if (!response.isSuccessful) {
      throw Exception(
        _extractApiError(
          response,
          fallback: 'Failed to remove vendor favorite on backend',
        ),
      );
    }
  }

  Future<void> _addVendorFavoriteOnBackend(FavoriteVendor vendor) async {
    final response = await _sendRequest('POST', _vendorFavoritePath(vendor));
    if (!response.isSuccessful) {
      throw Exception(
        _extractApiError(
          response,
          fallback: 'Failed to add vendor favorite on backend',
        ),
      );
    }
  }

  String _itemFavoritePath(FoodItem item) {
    final sourceType = item.favoriteItemType.trim().toLowerCase();

    switch (sourceType) {
      case 'grocery':
      case 'grocery_item':
      case 'groceryitem':
        return '/favorites/grocery/${item.id}';
      case 'pharmacy':
      case 'pharmacy_item':
      case 'pharmacyitem':
        return '/favorites/pharmacy-item/${item.id}';
      case 'grabmart':
      case 'grabmart_item':
      case 'grabmartitem':
        return '/favorites/grabmart-item/${item.id}';
      case 'food':
      default:
        return '/favorites/food/${item.id}';
    }
  }

  String _vendorFavoritePath(FavoriteVendor vendor) {
    switch (vendor.type) {
      case FavoriteVendorType.restaurant:
        return '/favorites/restaurant/${vendor.id}';
      case FavoriteVendorType.groceryStore:
        return '/favorites/store/${vendor.id}';
      case FavoriteVendorType.pharmacyStore:
        return '/favorites/pharmacy/${vendor.id}';
      case FavoriteVendorType.grabMartStore:
        return '/favorites/grabmart-store/${vendor.id}';
    }
  }

  Set<FoodItem> _parseFavoriteItems(Map<String, dynamic> data) {
    final items = <FoodItem>{};

    void addEntries(String key, String sourceType) {
      final entries = _resolveList(data, key);
      for (final rawEntry in entries) {
        if (rawEntry is! Map) continue;
        final entry = Map<String, dynamic>.from(rawEntry);
        final rawItem = entry['item'];
        if (rawItem is! Map) continue;
        final item = _mapFavoriteItem(
          Map<String, dynamic>.from(rawItem),
          sourceType: sourceType,
        );
        if (item != null) {
          items.add(item);
        }
      }
    }

    addEntries('foodItems', 'food');
    addEntries('groceryItems', 'grocery');
    addEntries('pharmacyItems', 'pharmacy_item');
    addEntries('grabMartItems', 'grabmart_item');

    return items;
  }

  List<FavoriteVendor> _parseFavoriteVendors(Map<String, dynamic> data) {
    final vendors = <FavoriteVendor>[];

    void addEntries(String key, String entityKey, FavoriteVendorType type) {
      final entries = _resolveList(data, key);
      for (final rawEntry in entries) {
        if (rawEntry is! Map) continue;
        final entry = Map<String, dynamic>.from(rawEntry);
        final vendor = _mapFavoriteVendor(
          entry: entry,
          entityKey: entityKey,
          type: type,
        );
        if (vendor != null) {
          vendors.add(vendor);
        }
      }
    }

    addEntries('restaurants', 'restaurant', FavoriteVendorType.restaurant);
    addEntries('groceryStores', 'store', FavoriteVendorType.groceryStore);
    addEntries('pharmacies', 'pharmacy', FavoriteVendorType.pharmacyStore);
    addEntries('grabMartStores', 'store', FavoriteVendorType.grabMartStore);

    return vendors;
  }

  List<dynamic> _resolveList(Map<String, dynamic> payload, String key) {
    if (payload[key] is List) {
      return payload[key] as List;
    }

    final nestedItems = payload['items'];
    if (nestedItems is Map && nestedItems[key] is List) {
      return nestedItems[key] as List;
    }

    final nestedVendors = payload['vendors'];
    if (nestedVendors is Map && nestedVendors[key] is List) {
      return nestedVendors[key] as List;
    }

    return const [];
  }

  FoodItem? _mapFavoriteItem(
    Map<String, dynamic> item, {
    required String sourceType,
  }) {
    final id = item['id']?.toString() ?? item['_id']?.toString() ?? '';
    if (id.isEmpty) return null;

    Map<String, dynamic>? vendor;
    if (item['restaurant'] is Map) {
      vendor = Map<String, dynamic>.from(item['restaurant'] as Map);
    } else if (item['store'] is Map) {
      vendor = Map<String, dynamic>.from(item['store'] as Map);
    }

    final vendorId =
        vendor?['id']?.toString() ??
        item['restaurantId']?.toString() ??
        item['storeId']?.toString() ??
        '';
    final vendorName =
        vendor?['restaurantName']?.toString() ??
        vendor?['restaurant_name']?.toString() ??
        vendor?['storeName']?.toString() ??
        vendor?['store_name']?.toString() ??
        item['sellerName']?.toString() ??
        'Unknown Vendor';
    final vendorLogo =
        vendor?['logo']?.toString() ??
        vendor?['image']?.toString() ??
        item['restaurantImage']?.toString() ??
        '';

    final enrichedItem = Map<String, dynamic>.from(item)
      ..['sellerName'] = vendorName
      ..['restaurantId'] = vendorId
      ..['sellerId'] = vendorId
      ..['restaurantImage'] = vendorLogo
      ..['favoriteItemType'] = sourceType
      ..['isRestaurantOpen'] = vendor?['isOpen'] ?? item['isRestaurantOpen']
      ..['estimatedDeliveryTime'] =
          item['estimatedDeliveryTime']?.toString().trim().isNotEmpty == true
          ? item['estimatedDeliveryTime']
          : '${_parseInt(vendor?['averageDeliveryTime'], defaultValue: 25)}-${_parseInt(vendor?['averageDeliveryTime'], defaultValue: 25) + 10} min';

    return FoodItem.fromJson(enrichedItem);
  }

  FavoriteVendor? _mapFavoriteVendor({
    required Map<String, dynamic> entry,
    required String entityKey,
    required FavoriteVendorType type,
  }) {
    final rawEntity = entry[entityKey];
    if (rawEntity is! Map) return null;

    final entity = Map<String, dynamic>.from(rawEntity);
    final id = entity['id']?.toString() ?? entry['id']?.toString() ?? '';
    if (id.isEmpty) return null;

    final name =
        entity['restaurantName']?.toString() ??
        entity['restaurant_name']?.toString() ??
        entity['storeName']?.toString() ??
        entity['store_name']?.toString() ??
        'Unknown Vendor';

    return FavoriteVendor(
      id: id,
      name: name,
      image: entity['logo']?.toString() ?? entity['image']?.toString() ?? '',
      bannerImages:
          (entity['bannerImages'] as List<dynamic>?)
              ?.map((entry) => entry.toString())
              .where((entry) => entry.trim().isNotEmpty)
              .toList(growable: false) ??
          const [],
      address: entity['address']?.toString(),
      city: entity['city']?.toString(),
      area: entity['area']?.toString(),
      status: entity['status']?.toString() ?? 'approved',
      isOpen: _parseBool(entity['isOpen'], defaultValue: true),
      isAcceptingOrders: _parseBool(
        entity['isAcceptingOrders'],
        defaultValue: true,
      ),
      isVerified: _parseBool(entity['isVerified'], defaultValue: false),
      featured: _parseBool(entity['featured'], defaultValue: false),
      deliveryFee: _parseDouble(entity['deliveryFee']),
      minOrder: _parseDouble(entity['minOrder']),
      rating: _parseDouble(entity['rating'], defaultValue: 4.0),
      totalReviews: _parseInt(entity['totalReviews']),
      categories:
          (entity['categories'] as List<dynamic>?)
              ?.map((entry) => entry.toString())
              .where((entry) => entry.trim().isNotEmpty)
              .toList(growable: false) ??
          const [],
      averageDeliveryTime: _parseInt(
        entity['averageDeliveryTime'],
        defaultValue: 30,
      ),
      isGrabGoExclusiveActive: _parseBool(
        entity['isGrabGoExclusiveActive'],
        defaultValue: false,
      ),
      lastOnlineAt: entity['lastOnlineAt'] != null
          ? DateTime.tryParse(entity['lastOnlineAt'].toString())
          : null,
      addedAt: entry['addedAt'] != null
          ? DateTime.tryParse(entry['addedAt'].toString())
          : null,
      type: type,
    );
  }

  bool _isSameFavoriteItem(FoodItem left, FoodItem right) {
    return left.id == right.id &&
        left.favoriteItemType.trim().toLowerCase() ==
            right.favoriteItemType.trim().toLowerCase();
  }

  Map<String, dynamic> _extractBodyMap(dynamic body) {
    if (body is Map<String, dynamic>) return body;
    if (body is Map) return Map<String, dynamic>.from(body);
    return const {};
  }

  String _extractApiError(Response response, {required String fallback}) {
    final body = _extractBodyMap(response.body);
    final bodyMessage = body['message']?.toString();
    if (bodyMessage != null && bodyMessage.trim().isNotEmpty) {
      return bodyMessage.trim();
    }

    final errorBody = _extractBodyMap(response.error);
    final errorMessage = errorBody['message']?.toString();
    if (errorMessage != null && errorMessage.trim().isNotEmpty) {
      return errorMessage.trim();
    }

    final rawError = response.error?.toString();
    if (rawError != null && rawError.trim().isNotEmpty) {
      return rawError.trim();
    }

    return fallback;
  }
}

double _parseDouble(dynamic value, {double defaultValue = 0.0}) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? defaultValue;
  return defaultValue;
}

int _parseInt(dynamic value, {int defaultValue = 0}) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? defaultValue;
  return defaultValue;
}

bool _parseBool(dynamic value, {bool defaultValue = true}) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final normalized = value.toLowerCase().trim();
    if (['true', '1', 'yes', 'y'].contains(normalized)) return true;
    if (['false', '0', 'no', 'n'].contains(normalized)) return false;
  }
  return defaultValue;
}
