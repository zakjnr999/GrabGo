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
      final items = await _repository.fetchRecentOrderItems();
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
      final items = await _repository.fetchOrderHistory();
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
    // Skip if already loading
    if (_state.isLoadingPopular) return;

    // Try loading from cache ONLY if we have no data yet and not force refreshing
    if (!forceRefresh && _state.popularItems.isEmpty) {
      if (CacheService.isPopularItemsCacheValid()) {
        await _loadPopularFromCache();
        if (_state.popularItems.isNotEmpty) {
          return; // Cache hit, we're done
        }
      }
    }

    _updateState(_state.copyWith(isLoadingPopular: true));

    try {
      final items = await _repository.fetchPopularItems(limit: 10);
      _updateState(_state.copyWith(popularItems: items, isLoadingPopular: false));
      await _savePopularToCache();
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching popular items: $e');
      }

      // If we have existing data, keep it. Otherwise try cache
      if (_state.popularItems.isEmpty) {
        await _loadPopularFromCache();
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
    // Skip if already loading
    if (_state.isLoadingTopRated) return;

    // Try loading from cache ONLY if we have no data yet and not force refreshing
    if (!forceRefresh && _state.topRatedItems.isEmpty) {
      if (CacheService.isTopRatedItemsCacheValid()) {
        await _loadTopRatedFromCache();
        if (_state.topRatedItems.isNotEmpty) {
          return; // Cache hit, we're done
        }
      }
    }

    _updateState(_state.copyWith(isLoadingTopRated: true));

    try {
      final items = await _repository.fetchTopRatedItems(limit: 10, minRating: 4.5);
      _updateState(_state.copyWith(topRatedItems: items, isLoadingTopRated: false));
      await _saveTopRatedToCache();
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching top rated items: $e');
      }

      // If we have existing data, keep it. Otherwise try cache
      if (_state.topRatedItems.isEmpty) {
        await _loadTopRatedFromCache();
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

  /// Private: Update state and notify listeners
  void _updateState(FoodDiscoveryState newState) {
    _state = newState;
    notifyListeners();
  }
}
