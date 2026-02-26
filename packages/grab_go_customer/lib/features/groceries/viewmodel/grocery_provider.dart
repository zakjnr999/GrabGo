import 'package:flutter/foundation.dart';
import 'package:grab_go_customer/features/groceries/model/grocery_category.dart';
import 'package:grab_go_customer/features/groceries/model/grocery_item.dart';
import 'package:grab_go_customer/features/groceries/model/grocery_store.dart';
import 'package:grab_go_customer/features/groceries/model/store_special.dart';
import 'package:grab_go_customer/features/groceries/repository/grocery_repository.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:grab_go_shared/shared/services/cache_service.dart';

class GroceryProvider extends ChangeNotifier {
  final GroceryRepository _repository = GroceryRepository();

  // Stores
  List<GroceryStore> _stores = [];
  bool _isLoadingStores = false;

  // Categories
  List<GroceryCategory> _categories = [];
  bool _isLoadingCategories = false;

  // Items
  List<GroceryItem> _items = [];
  bool _isLoadingItems = false;

  // Deals
  List<GroceryItem> _deals = [];
  bool _isLoadingDeals = false;

  // Fresh Arrivals
  List<GroceryItem> _freshArrivals = [];
  bool _isLoadingFreshArrivals = false;

  List<GroceryItem> _buyAgainItems = [];
  bool _isLoadingBuyAgain = false;

  // Store Specials
  List<StoreSpecial> _storeSpecials = [];
  bool _isLoadingStoreSpecials = false;

  // Popular items
  List<GroceryItem> _popularItems = [];
  bool _isLoadingPopular = false;

  // Recommended items
  List<GroceryItem> _recommendedItems = [];
  bool _isLoadingRecommended = false;
  int _recommendedPage = 1;
  bool _hasMoreRecommended = true;

  // Final fetch state
  bool _hasAttemptedFetch = false;
  bool get hasAttemptedFetch => _hasAttemptedFetch;

  // Getters
  List<GroceryStore> get stores => _stores;
  bool get isLoadingStores => _isLoadingStores;

  List<GroceryCategory> get categories => _categories;
  bool get isLoadingCategories => _isLoadingCategories;

  List<GroceryItem> get items => _items;
  bool get isLoadingItems => _isLoadingItems;

  List<GroceryItem> get deals => _deals;
  bool get isLoadingDeals => _isLoadingDeals;

  List<GroceryItem> get freshArrivals => _freshArrivals;
  bool get isLoadingFreshArrivals => _isLoadingFreshArrivals;

  List<GroceryItem> get buyAgainItems => _buyAgainItems;
  bool get isLoadingBuyAgain => _isLoadingBuyAgain;

  List<StoreSpecial> get storeSpecials => _storeSpecials;
  bool get isLoadingStoreSpecials => _isLoadingStoreSpecials;

  List<GroceryItem> get popularItems => _popularItems;
  bool get isLoadingPopular => _isLoadingPopular;

  List<GroceryItem> get recommendedItems => _recommendedItems;
  bool get isLoadingRecommended => _isLoadingRecommended;
  int get recommendedPage => _recommendedPage;
  bool get hasMoreRecommended => _hasMoreRecommended;

  // Top rated items
  List<GroceryItem> _topRatedItems = [];
  List<GroceryItem> get topRatedItems => _topRatedItems;

  bool _isLoadingTopRated = false;
  bool get isLoadingTopRated => _isLoadingTopRated;

  /// Fetch all grocery stores
  Future<void> fetchStores({bool forceRefresh = false}) async {
    // Load from cache first if empty for immediate UI
    if (_stores.isEmpty) {
      final cached = CacheService.getGroceryStores();
      if (cached.isNotEmpty) {
        _stores = cached.map((json) => GroceryStore.fromJson(json)).toList();
        notifyListeners();
      }
    }

    // Always fetch fresh data if forcing refresh or if we want background update
    if (!forceRefresh && _stores.isNotEmpty) return;

    // Only show loading state if we have no data
    if (_stores.isEmpty) {
      _isLoadingStores = true;
      notifyListeners();
    }

    try {
      final freshStores = await _repository.fetchStores();
      _stores = freshStores;
      // Save to cache
      await CacheService.saveGroceryStores(freshStores.map((s) => s.toJson()).toList());
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error in fetchStores: $e');
      }
      // Keep cached data on error
    } finally {
      _isLoadingStores = false;
      notifyListeners();
    }
  }

  /// Fetch all grocery categories
  Future<void> fetchCategories({bool forceRefresh = false}) async {
    if (_categories.isEmpty) {
      final cached = CacheService.getGroceryCategories();
      if (cached.isNotEmpty) {
        _categories = cached.map((json) => GroceryCategory.fromJson(json)).toList();
        notifyListeners();
      }
    }

    if (!forceRefresh && _categories.isNotEmpty) return;

    // Only show loading state if we have no data
    if (_categories.isEmpty) {
      _isLoadingCategories = true;
      notifyListeners();
    }

    try {
      final locationData = CacheService.getUserLocation();
      final userLat = locationData?['latitude']?.toDouble();
      final userLng = locationData?['longitude']?.toDouble();

      final freshCategories = await _repository.fetchCategories(
        userLat: userLat,
        userLng: userLng,
      );
      _categories = freshCategories;
      await CacheService.saveGroceryCategories(freshCategories.map((c) => c.toJson()).toList());
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error in fetchCategories: $e');
      }
    } finally {
      _isLoadingCategories = false;
      notifyListeners();
    }
  }

  /// Fetch grocery items with optional filters
  Future<void> fetchItems({
    String? category,
    String? store,
    String? minPrice,
    String? maxPrice,
    String? tags,
    bool forceRefresh = false,
  }) async {
    final isBaseFetch = category == null && store == null && minPrice == null && maxPrice == null && tags == null;

    if (isBaseFetch && _items.isEmpty) {
      final cached = CacheService.getGroceryItems();
      if (cached.isNotEmpty) {
        _items = cached.map((json) => GroceryItem.fromJson(json)).toList();
        notifyListeners();
        fetchFreshArrivals();
      }
    }

    if (!forceRefresh && isBaseFetch && _items.isNotEmpty) {
      // Still need to trigger secondary fetches if items exist but lists don't
      if (_freshArrivals.isEmpty) fetchFreshArrivals();
      if (_buyAgainItems.isEmpty) fetchBuyAgainItems();
      if (_storeSpecials.isEmpty) fetchStoreSpecials();
      return;
    }

    // Only show loading state if we have no data
    if (_items.isEmpty) {
      _isLoadingItems = true;
      notifyListeners();
    }

    try {
      // Get user location from cache
      final locationData = CacheService.getUserLocation();
      final userLat = locationData?['latitude']?.toDouble();
      final userLng = locationData?['longitude']?.toDouble();

      if (kDebugMode) {
        print('🌍 [GROCERY] Fetching items with location:');
        print('   📍 Latitude: $userLat');
        print('   📍 Longitude: $userLng');
        print('   📦 Category: $category, Store: $store');
      }

      final freshItems = await _repository.fetchItems(
        category: category,
        store: store,
        minPrice: minPrice,
        maxPrice: maxPrice,
        tags: tags,
        userLat: userLat,
        userLng: userLng,
      );
      _items = freshItems;

      if (kDebugMode) {
        print('✅ [GROCERY] Received ${freshItems.length} items from API');
      }

      if (isBaseFetch) {
        await CacheService.saveGroceryItems(freshItems.map((i) => i.toJson()).toList());
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error in fetchItems: $e');
      }
    } finally {
      _isLoadingItems = false;
      _hasAttemptedFetch = true;
      notifyListeners();

      fetchFreshArrivals();
      fetchBuyAgainItems();
      fetchStoreSpecials();
    }
  }

  /// Search grocery items
  Future<List<GroceryItem>> searchItems(String query) async {
    try {
      return await _repository.searchItems(query);
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error in searchItems: $e');
      }
      return [];
    }
  }

  /// Fetch grocery deals
  Future<void> fetchDeals({bool forceRefresh = false}) async {
    var loadedFromCache = false;
    if (_deals.isEmpty) {
      final cached = CacheService.getGroceryDeals();
      if (cached.isNotEmpty) {
        _deals = cached.map((json) => GroceryItem.fromJson(json)).toList();
        loadedFromCache = true;
        notifyListeners();
      }
    }

    if (!forceRefresh && _deals.isNotEmpty && !loadedFromCache) return;

    // Only show loading state if no deals are rendered yet.
    if (_deals.isEmpty && !loadedFromCache) {
      _isLoadingDeals = true;
      notifyListeners();
    }

    try {
      // Get user location from cache
      final locationData = CacheService.getUserLocation();
      final userLat = locationData?['latitude']?.toDouble();
      final userLng = locationData?['longitude']?.toDouble();

      if (kDebugMode) {
        print('🌍 [GROCERY DEALS] Fetching with location: ($userLat, $userLng)');
      }

      final freshDeals = await _repository.fetchDeals(
        userLat: userLat,
        userLng: userLng,
      );
      _deals = freshDeals;
      
      if (kDebugMode) {
        print('✅ [GROCERY DEALS] Received ${freshDeals.length} deals');
      }
      await CacheService.saveGroceryDeals(freshDeals.map((d) => d.toJson()).toList());
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error in fetchDeals: $e');
      }
    } finally {
      _isLoadingDeals = false;
      notifyListeners();
    }
  }

  /// Fetch fresh arrivals (items added in last 7 days)
  Future<void> fetchFreshArrivals() async {
    _isLoadingFreshArrivals = true;
    notifyListeners();

    try {
      // Filter items that are new (< 7 days old)
      _freshArrivals = _items.where((item) => item.isNew).take(10).toList();
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error in fetchFreshArrivals: $e');
      }
      _freshArrivals = [];
    } finally {
      _isLoadingFreshArrivals = false;
      notifyListeners();
    }
  }

  /// Fetch buy again items (order history)
  Future<void> fetchBuyAgainItems({bool forceRefresh = false}) async {
    if (!forceRefresh && _buyAgainItems.isEmpty) {
      final cached = CacheService.getGroceryBuyAgainItems();
      if (cached.isNotEmpty) {
        _buyAgainItems = cached.map((json) => GroceryItem.fromJson(json)).toList();
        notifyListeners();
      }
    }

    _isLoadingBuyAgain = true;
    notifyListeners();

    try {
      final items = await _repository.fetchOrderHistory();
      _buyAgainItems = items;
      await CacheService.saveGroceryBuyAgainItems(items.map((i) => i.toJson()).toList());
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error in fetchBuyAgainItems: $e');
      }
    } finally {
      _isLoadingBuyAgain = false;
      notifyListeners();
    }
  }

  /// Refresh all grocery data
  Future<void> refreshAll({bool forceRefresh = false}) async {
    // Smart caching: Check if cache is stale (> 5 minutes)
    final cacheIsStale = CacheService.isCacheStale(
      CacheService.groceryItemsTimestampKey,
      const Duration(minutes: 5),
    );

    // ONLY show loading states (skeletons) if data is actually empty
    // This prevents skeletons from showing during pull-to-refresh when data is already visible
    if (_items.isEmpty) {
      _isLoadingStores = true;
      _isLoadingCategories = true;
      _isLoadingItems = true;
      _isLoadingDeals = true;
      _isLoadingFreshArrivals = true;
      _isLoadingBuyAgain = true;
      _isLoadingStoreSpecials = true;
      _isLoadingPopular = true;
      _isLoadingTopRated = true;
      notifyListeners();
    }

    await Future.wait([
      fetchStores(forceRefresh: forceRefresh || cacheIsStale),
      fetchCategories(forceRefresh: forceRefresh || cacheIsStale),
      fetchItems(forceRefresh: forceRefresh || cacheIsStale),
      fetchDeals(forceRefresh: forceRefresh || cacheIsStale),
    ]);

    // Fetch dependent sections after base data is updated
    await Future.wait([
      fetchFreshArrivals(),
      fetchBuyAgainItems(forceRefresh: forceRefresh || cacheIsStale),
      fetchStoreSpecials(forceRefresh: forceRefresh || cacheIsStale),
      fetchPopularItems(forceRefresh: forceRefresh || cacheIsStale),
      fetchTopRatedItems(forceRefresh: forceRefresh || cacheIsStale),
      fetchRecommendedItems(forceRefresh: forceRefresh || cacheIsStale),
    ]);
  }

  /// Check if we should show skeleton loader based on cache age
  bool shouldShowSkeleton() {
    // Show skeleton if cache is older than 5 minutes and we have no data
    final cacheIsStale = CacheService.isCacheStale(
      CacheService.groceryItemsTimestampKey,
      const Duration(minutes: 5),
    );
    return cacheIsStale && _items.isEmpty;
  }

  /// Clear all data
  void clearAll() {
    _stores = [];
    _categories = [];
    _items = [];
    _deals = [];
    _recommendedItems = [];
    _recommendedPage = 1;
    _hasMoreRecommended = true;
    notifyListeners();
  }

  /// Fetch store specials (items with active discounts grouped by store)
  Future<void> fetchStoreSpecials({bool forceRefresh = false}) async {
    if (!forceRefresh && _storeSpecials.isEmpty) {
      final cached = CacheService.getGroceryStoreSpecials();
      if (cached.isNotEmpty) {
        _storeSpecials = cached.map((json) => StoreSpecial.fromJson(json)).toList();
        notifyListeners();
      }
    }

    _isLoadingStoreSpecials = true;
    notifyListeners();

    try {
      final specials = await _repository.fetchStoreSpecials();
      _storeSpecials = specials;
      await CacheService.saveGroceryStoreSpecials(specials.map((s) => s.toJson()).toList());
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error fetching store specials: $e');
      }
    } finally {
      _isLoadingStoreSpecials = false;
      notifyListeners();
    }
  }

  /// Fetch popular grocery items sorted by order count
  Future<void> fetchPopularItems({bool forceRefresh = false}) async {
    if (!forceRefresh && _popularItems.isEmpty) {
      final cached = CacheService.getGroceryPopularItems();
      if (cached.isNotEmpty) {
        _popularItems = cached.map((json) => GroceryItem.fromJson(json)).toList();
        notifyListeners();
      }
    }

    _isLoadingPopular = true;
    notifyListeners();

    try {
      // Get user location from cache
      final locationData = CacheService.getUserLocation();
      final userLat = locationData?['latitude']?.toDouble();
      final userLng = locationData?['longitude']?.toDouble();

      if (kDebugMode) {
        print('🌍 [GROCERY POPULAR] Fetching with location: ($userLat, $userLng)');
      }

      final items = await _repository.fetchPopularItems(
        limit: 10,
        userLat: userLat,
        userLng: userLng,
      );
      _popularItems = items;
      
      if (kDebugMode) {
        print('✅ [GROCERY POPULAR] Received ${items.length} popular items');
      }
      await CacheService.saveGroceryPopularItems(items.map((i) => i.toJson()).toList());
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error fetching popular items: $e');
      }
    } finally {
      _isLoadingPopular = false;
      notifyListeners();
    }
  }

  /// Fetch top-rated grocery items sorted by rating
  Future<void> fetchTopRatedItems({bool forceRefresh = false}) async {
    if (!forceRefresh && _topRatedItems.isEmpty) {
      final cached = CacheService.getGroceryTopRatedItems();
      if (cached.isNotEmpty) {
        _topRatedItems = cached.map((json) => GroceryItem.fromJson(json)).toList();
        notifyListeners();
      }
    }

    _isLoadingTopRated = true;
    notifyListeners();

    try {
      final items = await _repository.fetchTopRatedItems(limit: 10, minRating: 4.5);
      _topRatedItems = items;
      await CacheService.saveGroceryTopRatedItems(items.map((i) => i.toJson()).toList());
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error fetching top rated items: $e');
      }
    } finally {
      _isLoadingTopRated = false;
      notifyListeners();
    }
  }

  /// Fetch recommended grocery items (resets pagination)
  Future<void> fetchRecommendedItems({bool forceRefresh = false}) async {
    if (_isLoadingRecommended) return;
    if (!forceRefresh && _recommendedItems.isNotEmpty) return;

    _recommendedPage = 1;
    _hasMoreRecommended = true;
    _recommendedItems = [];
    await _fetchRecommendedPage(page: 1, append: false);
  }

  /// Load more recommended grocery items
  Future<void> loadMoreRecommendedItems() async {
    if (_isLoadingRecommended || !_hasMoreRecommended) return;
    final nextPage = _recommendedPage + 1;
    await _fetchRecommendedPage(page: nextPage, append: true);
  }

  Future<void> _fetchRecommendedPage({required int page, required bool append}) async {
    _isLoadingRecommended = true;
    notifyListeners();

    try {
      final locationData = CacheService.getUserLocation();
      final userLat = locationData?['latitude']?.toDouble();
      final userLng = locationData?['longitude']?.toDouble();

      final items = await _repository.fetchRecommendedItems(
        limit: 20,
        page: page,
        userLat: userLat,
        userLng: userLng,
      );

      final combined = append ? [..._recommendedItems, ...items] : items;
      final uniqueById = <String, GroceryItem>{};
      for (final item in combined) {
        uniqueById[item.id] = item;
      }

      _recommendedItems = uniqueById.values.toList();
      _recommendedPage = page;
      _hasMoreRecommended = items.length >= 20;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error fetching grocery recommended items: $e');
      }
    } finally {
      _isLoadingRecommended = false;
      notifyListeners();
    }
  }
}
