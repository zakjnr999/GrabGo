import 'package:flutter/foundation.dart';
import 'package:grab_go_customer/features/home/model/food_category.dart';
import 'package:grab_go_customer/features/home/repository/food_repository.dart';
import 'package:grab_go_customer/shared/viewmodels/base_provider.dart';
import 'package:grab_go_shared/shared/services/cache_service.dart';

/// State for food discovery features (popular, top-rated, order history, recent orders)
class FoodDiscoveryState {
  final List<FoodItem> recentOrderItems;
  final bool isLoadingRecentItems;
  final String? recentItemsError;

  final List<FoodItem> orderHistoryItems;
  final bool isLoadingOrderHistory;

  final List<FoodItem> popularItems;
  final bool isLoadingPopular;

  final List<FoodItem> topRatedItems;
  final bool isLoadingTopRated;

  final List<FoodItem> recommendedItems;
  final bool isLoadingRecommended;
  final int recommendedPage;
  final bool hasMoreRecommended;

  const FoodDiscoveryState({
    this.recentOrderItems = const [],
    this.isLoadingRecentItems = false,
    this.recentItemsError,
    this.orderHistoryItems = const [],
    this.isLoadingOrderHistory = false,
    this.popularItems = const [],
    this.isLoadingPopular = false,
    this.topRatedItems = const [],
    this.isLoadingTopRated = false,
    this.recommendedItems = const [],
    this.isLoadingRecommended = false,
    this.recommendedPage = 1,
    this.hasMoreRecommended = true,
  });

  FoodDiscoveryState copyWith({
    List<FoodItem>? recentOrderItems,
    bool? isLoadingRecentItems,
    String? recentItemsError,
    List<FoodItem>? orderHistoryItems,
    bool? isLoadingOrderHistory,
    List<FoodItem>? popularItems,
    bool? isLoadingPopular,
    List<FoodItem>? topRatedItems,
    bool? isLoadingTopRated,
    List<FoodItem>? recommendedItems,
    bool? isLoadingRecommended,
    int? recommendedPage,
    bool? hasMoreRecommended,
  }) {
    return FoodDiscoveryState(
      recentOrderItems: recentOrderItems ?? this.recentOrderItems,
      isLoadingRecentItems: isLoadingRecentItems ?? this.isLoadingRecentItems,
      recentItemsError: recentItemsError,
      orderHistoryItems: orderHistoryItems ?? this.orderHistoryItems,
      isLoadingOrderHistory: isLoadingOrderHistory ?? this.isLoadingOrderHistory,
      popularItems: popularItems ?? this.popularItems,
      isLoadingPopular: isLoadingPopular ?? this.isLoadingPopular,
      topRatedItems: topRatedItems ?? this.topRatedItems,
      isLoadingTopRated: isLoadingTopRated ?? this.isLoadingTopRated,
      recommendedItems: recommendedItems ?? this.recommendedItems,
      isLoadingRecommended: isLoadingRecommended ?? this.isLoadingRecommended,
      recommendedPage: recommendedPage ?? this.recommendedPage,
      hasMoreRecommended: hasMoreRecommended ?? this.hasMoreRecommended,
    );
  }
}

/// Provider for food discovery features
class FoodDiscoveryProvider extends ChangeNotifier with CacheMixin {
  FoodDiscoveryState _state = const FoodDiscoveryState();
  FoodDiscoveryState get state => _state;

  final FoodRepository _repository = FoodRepository();

  // Convenience getters for backward compatibility
  List<FoodItem> get recentOrderItems => _state.recentOrderItems;
  bool get isLoadingRecentItems => _state.isLoadingRecentItems;
  String? get recentItemsError => _state.recentItemsError;

  List<FoodItem> get orderHistoryItems => _state.orderHistoryItems;
  bool get isLoadingOrderHistory => _state.isLoadingOrderHistory;

  List<FoodItem> get popularItems => _state.popularItems;
  bool get isLoadingPopular => _state.isLoadingPopular;

  List<FoodItem> get topRatedItems => _state.topRatedItems;
  bool get isLoadingTopRated => _state.isLoadingTopRated;

  List<FoodItem> get recommendedItems => _state.recommendedItems;
  bool get isLoadingRecommended => _state.isLoadingRecommended;
  int get recommendedPage => _state.recommendedPage;
  bool get hasMoreRecommended => _state.hasMoreRecommended;

  /// Fetch recent order items
  Future<void> fetchRecentOrderItems({bool forceRefresh = false}) async {
    // Try loading from cache first if we have no data and not force refreshing
    if (!forceRefresh && _state.recentOrderItems.isEmpty) {
      await _loadRecentOrderItemsFromCache();
    }

    // Skip if already loading
    if (_state.isLoadingRecentItems) return;

    _updateState(_state.copyWith(isLoadingRecentItems: true));

    try {
      // Get user location from cache for distance-based delivery time calculation
      final locationData = CacheService.getUserLocation();
      final userLat = locationData?['latitude']?.toDouble();
      final userLng = locationData?['longitude']?.toDouble();

      final items = await _repository.fetchRecentOrderItems(
        userLat: userLat,
        userLng: userLng,
      );
      _updateState(_state.copyWith(recentOrderItems: items, isLoadingRecentItems: false));
      await _saveRecentOrderItemsToCache();
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching recent order items: $e');
      }

      // Keep existing data on error, or try cache if empty
      if (_state.recentOrderItems.isEmpty) {
        await _loadRecentOrderItemsFromCache();
      }

      _updateState(_state.copyWith(isLoadingRecentItems: false, recentItemsError: e.toString()));
    }
  }

  /// Fetch order history
  Future<void> fetchOrderHistory({bool forceRefresh = false}) async {
    // Try loading from cache first if we have no data and not force refreshing
    if (!forceRefresh && _state.orderHistoryItems.isEmpty) {
      await _loadOrderHistoryFromCache();
      if (_state.orderHistoryItems.isNotEmpty) {
        if (kDebugMode) {
          print('[FoodDiscoveryProvider] Loaded order history from cache');
        }
      }
    }

    if (kDebugMode) {
      print('[FoodDiscoveryProvider] Fetching order history... (force: $forceRefresh)');
    }

    _updateState(_state.copyWith(isLoadingOrderHistory: true));

    try {
      // Get user location from cache for distance-based delivery time calculation
      final locationData = CacheService.getUserLocation();
      final userLat = locationData?['latitude']?.toDouble();
      final userLng = locationData?['longitude']?.toDouble();

      final items = await _repository.fetchOrderHistory(
        userLat: userLat,
        userLng: userLng,
      );
      _updateState(_state.copyWith(orderHistoryItems: items, isLoadingOrderHistory: false));

      await _saveOrderHistoryToCache();

      if (kDebugMode) {
        print('[FoodDiscoveryProvider] Order history fetched: ${items.length} items');
      }
    } catch (e) {
      if (kDebugMode) {
        print('[FoodDiscoveryProvider] Error fetching order history: $e');
      }

      // If we have no existing data, try cache as fallback (though we should have it already)
      if (_state.orderHistoryItems.isEmpty) {
        await _loadOrderHistoryFromCache();
      }

      _updateState(_state.copyWith(isLoadingOrderHistory: false));
    }
  }

  /// Fetch popular items
  Future<void> fetchPopularItems({bool forceRefresh = false}) async {
    if (_state.isLoadingPopular) return;

    // 1. Try loading from cache first if we have no data
    if (!forceRefresh && _state.popularItems.isEmpty) {
      await _loadPopularFromCache();
    }

    // 2. Fetch fresh data from API
    await _fetchFromApiPopular();
  }

  Future<void> _fetchFromApiPopular() async {
    _updateState(_state.copyWith(isLoadingPopular: true));

    try {
      // Get user location from cache for distance-based delivery time calculation
      final locationData = CacheService.getUserLocation();
      final userLat = locationData?['latitude']?.toDouble();
      final userLng = locationData?['longitude']?.toDouble();

      final items = await _repository.fetchPopularItems(
        limit: 10,
        userLat: userLat,
        userLng: userLng,
      );
      _updateState(_state.copyWith(popularItems: items, isLoadingPopular: false));
      await _savePopularToCache();
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching popular items: $e');
      }
      _updateState(_state.copyWith(isLoadingPopular: false));
    }
  }

  /// Force refresh popular items (for pull-to-refresh)
  Future<void> refreshPopularItems() async {
    await fetchPopularItems(forceRefresh: true);
  }

  /// Fetch top-rated items
  Future<void> fetchTopRatedItems({bool forceRefresh = false}) async {
    if (_state.isLoadingTopRated) return;

    // 1. Try loading from cache first if we have no data
    if (!forceRefresh && _state.topRatedItems.isEmpty) {
      await _loadTopRatedFromCache();
    }

    // 2. Fetch fresh data from API
    await _fetchFromApiTopRated();
  }

  Future<void> _fetchFromApiTopRated() async {
    _updateState(_state.copyWith(isLoadingTopRated: true));

    try {
      // Get user location from cache for distance-based delivery time calculation
      final locationData = CacheService.getUserLocation();
      final userLat = locationData?['latitude']?.toDouble();
      final userLng = locationData?['longitude']?.toDouble();

      final items = await _repository.fetchTopRatedItems(
        limit: 10, 
        minRating: 4.5,
        userLat: userLat,
        userLng: userLng,
      );
      _updateState(_state.copyWith(topRatedItems: items, isLoadingTopRated: false));
      await _saveTopRatedToCache();
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching top rated items: $e');
      }
      _updateState(_state.copyWith(isLoadingTopRated: false));
    }
  }

  /// Force refresh top-rated items (for pull-to-refresh)
  Future<void> refreshTopRatedItems() async {
    await fetchTopRatedItems(forceRefresh: true);
  }

  /// Private: Load popular items from cache
  Future<void> _loadPopularFromCache() async {
    try {
      final cached = CacheService.getPopularItems();
      if (cached.isNotEmpty) {
        final items = cached.map((json) => FoodItem.fromJson(json)).toList();
        _updateState(_state.copyWith(popularItems: items));
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading popular items from cache: $e');
      }
    }
  }

  /// Private: Save popular items to cache
  Future<void> _savePopularToCache() async {
    try {
      final itemsJson = _state.popularItems.map((item) => item.toJson()).toList();
      CacheService.savePopularItems(itemsJson);
    } catch (e) {
      if (kDebugMode) {
        print('Error saving popular items to cache: $e');
      }
    }
  }

  /// Private: Load top-rated items from cache
  Future<void> _loadTopRatedFromCache() async {
    try {
      final cached = CacheService.getTopRatedItems();
      if (cached.isNotEmpty) {
        final items = cached.map((json) => FoodItem.fromJson(json)).toList();
        _updateState(_state.copyWith(topRatedItems: items));
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading top-rated items from cache: $e');
      }
    }
  }

  /// Private: Save top-rated items to cache
  Future<void> _saveTopRatedToCache() async {
    try {
      final itemsJson = _state.topRatedItems.map((item) => item.toJson()).toList();
      CacheService.saveTopRatedItems(itemsJson);
    } catch (e) {
      if (kDebugMode) {
        print('Error saving top-rated items to cache: $e');
      }
    }
  }

  /// Private: Load order history from cache
  Future<void> _loadOrderHistoryFromCache() async {
    try {
      final cached = CacheService.getOrderHistory();
      if (cached.isNotEmpty) {
        final items = cached.map((json) => FoodItem.fromJson(json)).toList();
        _updateState(_state.copyWith(orderHistoryItems: items));
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading order history from cache: $e');
      }
    }
  }

  /// Private: Save order history to cache
  Future<void> _saveOrderHistoryToCache() async {
    try {
      final itemsJson = _state.orderHistoryItems.map((item) => item.toJson()).toList();
      CacheService.saveOrderHistory(itemsJson);
    } catch (e) {
      if (kDebugMode) {
        print('Error saving order history to cache: $e');
      }
    }
  }

  /// Private: Load recent order items from cache
  Future<void> _loadRecentOrderItemsFromCache() async {
    try {
      final cached = CacheService.getRecentOrderItems();
      if (cached.isNotEmpty) {
        final items = cached.map((json) => FoodItem.fromJson(json)).toList();
        _updateState(_state.copyWith(recentOrderItems: items));
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading recent order items from cache: $e');
      }
    }
  }

  /// Private: Save recent order items to cache
  Future<void> _saveRecentOrderItemsToCache() async {
    try {
      final itemsJson = _state.recentOrderItems.map((item) => item.toJson()).toList();
      CacheService.saveRecentOrderItems(itemsJson);
    } catch (e) {
      if (kDebugMode) {
        print('Error saving recent order items to cache: $e');
      }
    }
  }

  /// Fetch recommended items (resets pagination)
  Future<void> fetchRecommendedItems({bool forceRefresh = false}) async {
    if (_state.isLoadingRecommended) return;

    // Try loading from cache first if we have no data
    if (!forceRefresh && _state.recommendedItems.isEmpty) {
      await _loadRecommendedFromCache();
    }

    // Reset pagination and fetch first page
    _updateState(_state.copyWith(
      recommendedPage: 1,
      hasMoreRecommended: true,
      recommendedItems: [], // Clear existing items
    ));

    // Fetch fresh data from API (page 1)
    await _fetchFromApiRecommended(page: 1);
  }

  /// Load more recommended items (pagination)
  Future<void> loadMoreRecommendedItems() async {
    // Don't load if already loading or no more items
    if (_state.isLoadingRecommended || !_state.hasMoreRecommended) return;

    final nextPage = _state.recommendedPage + 1;
    await _fetchFromApiRecommended(page: nextPage, append: true);
  }

  /// Private: Internal fetch for recommended items
  Future<void> _fetchFromApiRecommended({int page = 1, bool append = false}) async {
    _updateState(_state.copyWith(isLoadingRecommended: true));

    try {
      // Get user location from cache for distance-based delivery time calculation
      final locationData = CacheService.getUserLocation();
      final userLat = locationData?['latitude']?.toDouble();
      final userLng = locationData?['longitude']?.toDouble();

      final items = await _repository.fetchRecommendedItems(
        limit: 20, 
        page: page,
        userLat: userLat,
        userLng: userLng,
      );
      
      // Append or replace items
      final newItems = append ? [..._state.recommendedItems, ...items] : items;
      
      // Update hasMore flag (if we got less than requested, no more items)
      final hasMore = items.length >= 20;
      
      _updateState(_state.copyWith(
        recommendedItems: newItems,
        isLoadingRecommended: false,
        recommendedPage: page,
        hasMoreRecommended: hasMore,
      ));
      
      if (!append) {
        await _saveRecommendedToCache();
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching recommended items: $e');
      }
      _updateState(_state.copyWith(isLoadingRecommended: false));
    }
  }

  /// Force refresh recommended items (for pull-to-refresh)
  Future<void> refreshRecommendedItems() async {
    await fetchRecommendedItems(forceRefresh: true);
  }

  /// Private: Load recommended items from cache
  Future<void> _loadRecommendedFromCache() async {
    try {
      final cached = CacheService.getRecommendedItems();
      if (cached.isNotEmpty) {
        final items = cached.map((json) => FoodItem.fromJson(json)).toList();
        _updateState(_state.copyWith(recommendedItems: items));
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading recommended items from cache: $e');
      }
    }
  }

  /// Private: Save recommended items to cache
  Future<void> _saveRecommendedToCache() async {
    try {
      final itemsJson = _state.recommendedItems.map((item) => item.toJson()).toList();
      CacheService.saveRecommendedItems(itemsJson);
    } catch (e) {
      if (kDebugMode) {
        print('Error saving recommended items to cache: $e');
      }
    }
  }

  /// Private: Update state and notify listeners
  void _updateState(FoodDiscoveryState newState) {
    _state = newState;
    notifyListeners();
  }
}
