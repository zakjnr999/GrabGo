import 'package:flutter/foundation.dart';
import 'package:grab_go_customer/features/grabmart/model/grabmart_category.dart';
import 'package:grab_go_customer/features/grabmart/model/grabmart_item.dart';
import 'package:grab_go_customer/features/grabmart/repository/grabmart_repository.dart';
import 'package:grab_go_customer/features/services/model/service_hub_feed.dart';
import 'package:grab_go_shared/shared/services/cache_service.dart';

class GrabMartProvider extends ChangeNotifier {
  final GrabMartRepository _repository = GrabMartRepository();

  // Categories
  List<GrabMartCategory> _categories = [];
  bool _isLoadingCategories = false;

  // Items
  List<GrabMartItem> _items = [];
  bool _isLoadingItems = false;

  // Special Offers (on sale)
  List<GrabMartItem> _specialOffers = [];
  bool _isLoadingSpecialOffers = false;

  // Quick Picks (popular items)
  List<GrabMartItem> _quickPicks = [];
  bool _isLoadingQuickPicks = false;

  // Top Rated items
  List<GrabMartItem> _topRatedItems = [];

  // Recommended items
  List<GrabMartItem> _recommendedItems = [];
  bool _isLoadingRecommended = false;
  int _recommendedPage = 1;
  bool _hasMoreRecommended = true;

  // Final fetch state
  bool _hasAttemptedFetch = false;
  bool get hasAttemptedFetch => _hasAttemptedFetch;

  // Getters
  List<GrabMartCategory> get categories => _categories;
  bool get isLoadingCategories => _isLoadingCategories;

  List<GrabMartItem> get items => _items;
  bool get isLoadingItems => _isLoadingItems;

  List<GrabMartItem> get specialOffers => _specialOffers;
  bool get isLoadingSpecialOffers => _isLoadingSpecialOffers;

  List<GrabMartItem> get quickPicks => _quickPicks;
  bool get isLoadingQuickPicks => _isLoadingQuickPicks;

  // Top Rated items
  List<GrabMartItem> get topRatedItems => _topRatedItems;
  List<GrabMartItem> get recommendedItems => _recommendedItems;
  bool get isLoadingRecommended => _isLoadingRecommended;
  int get recommendedPage => _recommendedPage;
  bool get hasMoreRecommended => _hasMoreRecommended;

  Future<void> hydrateFromServiceHubFeed(ServiceHubFeed feed) async {
    final categories = feed.categories
        .map(GrabMartCategory.fromJson)
        .toList(growable: false);
    final items = feed.items.map(GrabMartItem.fromJson).toList(growable: false);
    final deals = feed.deals.map(GrabMartItem.fromJson).toList(growable: false);
    final popular = feed.popular
        .map(GrabMartItem.fromJson)
        .toList(growable: false);
    final topRated = feed.topRated
        .map(GrabMartItem.fromJson)
        .toList(growable: false);
    final recommended = feed.recommended.items
        .map(GrabMartItem.fromJson)
        .toList(growable: false);

    final mergedItems = <String, GrabMartItem>{};
    for (final list in [items, deals, popular, topRated, recommended]) {
      for (final item in list) {
        mergedItems[item.id] = item;
      }
    }

    _categories = categories;
    _items = mergedItems.values.toList(growable: false);
    _specialOffers = deals.isNotEmpty
        ? deals
        : (_items.where((item) => item.hasDiscount).toList()..sort(
            (a, b) => b.discountPercentage.compareTo(a.discountPercentage),
          ));
    _quickPicks = popular.isNotEmpty
        ? popular
        : (_items.where((item) => item.orderCount > 0).toList()
            ..sort((a, b) => b.orderCount.compareTo(a.orderCount)));
    _topRatedItems = topRated.isNotEmpty
        ? topRated
        : (_items.where((item) => item.rating >= 4.5).toList()
            ..sort((a, b) => b.rating.compareTo(a.rating)));
    _recommendedItems = recommended;
    _recommendedPage = feed.recommended.page;
    _hasMoreRecommended = feed.recommended.hasMore;
    _hasAttemptedFetch = true;

    _isLoadingCategories = false;
    _isLoadingItems = false;
    _isLoadingSpecialOffers = false;
    _isLoadingQuickPicks = false;
    _isLoadingRecommended = false;

    await Future.wait([
      CacheService.saveGrabMartCategories(
        _categories.map((category) => category.toJson()).toList(),
      ),
      CacheService.saveGrabMartItems(
        _items.map((item) => item.toJson()).toList(),
      ),
    ]);

    notifyListeners();
  }

  /// Fetch all GrabMart categories
  Future<void> fetchCategories({bool forceRefresh = false}) async {
    // Always load from cache first if empty, even if forcing refresh,
    // to show something while fetching
    if (_categories.isEmpty) {
      final cached = CacheService.getGrabMartCategories();
      if (cached.isNotEmpty) {
        _categories = cached
            .map((json) => GrabMartCategory.fromJson(json))
            .toList();
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

      final categories = await _repository.fetchCategories(
        userLat: userLat,
        userLng: userLng,
      );
      _categories = categories;
      await CacheService.saveGrabMartCategories(
        _categories.map((c) => c.toJson()).toList(),
      );
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error fetching GrabMart categories: $e');
      }
    } finally {
      _isLoadingCategories = false;
      notifyListeners();
    }
  }

  /// Fetch GrabMart items with optional filters
  Future<void> fetchItems({
    String? category,
    String? store,
    String? minPrice,
    String? maxPrice,
    String? tags,
    bool forceRefresh = false,
  }) async {
    final isBaseFetch =
        category == null &&
        store == null &&
        minPrice == null &&
        maxPrice == null &&
        tags == null;

    if (isBaseFetch && _items.isEmpty) {
      final cached = CacheService.getGrabMartItems();
      if (cached.isNotEmpty) {
        _items = cached.map((json) => GrabMartItem.fromJson(json)).toList();
        notifyListeners();
        // Load sub-sections from cached items
        _loadSpecialOffers();
        _loadQuickPicks();
        _loadTopRatedItems();
      }
    }

    if (!forceRefresh && isBaseFetch && _items.isNotEmpty) return;

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
        print('🌍 [GRABMART] Fetching items with location:');
        print('   📍 Latitude: $userLat');
        print('   📍 Longitude: $userLng');
        print('   📦 Category: $category, Store: $store');
      }

      final items = await _repository.fetchItems(
        category: category,
        store: store,
        minPrice: minPrice,
        maxPrice: maxPrice,
        tags: tags,
        userLat: userLat,
        userLng: userLng,
      );

      _items = items;

      if (kDebugMode) {
        print('✅ [GRABMART] Received ${items.length} items from API');
      }

      if (isBaseFetch) {
        await CacheService.saveGrabMartItems(
          _items.map((i) => i.toJson()).toList(),
        );
        _loadSpecialOffers();
        _loadQuickPicks();
        _loadTopRatedItems();
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error fetching GrabMart items: $e');
      }
    } finally {
      _isLoadingItems = false;
      _hasAttemptedFetch = true;
      notifyListeners();
    }
  }

  /// Load special offers from existing items
  void _loadSpecialOffers() {
    _specialOffers = _items.where((item) => item.hasDiscount).toList()
      ..sort((a, b) => b.discountPercentage.compareTo(a.discountPercentage));
    notifyListeners();
  }

  /// Load quick picks from existing items
  void _loadQuickPicks() {
    _quickPicks = _items.where((item) => item.orderCount > 0).toList()
      ..sort((a, b) => b.orderCount.compareTo(a.orderCount));
    notifyListeners();
  }

  /// Load top-rated items (4.5+ rating)
  void _loadTopRatedItems() {
    _topRatedItems = _items.where((item) => item.rating >= 4.5).toList()
      ..sort((a, b) => b.rating.compareTo(a.rating));
    notifyListeners();
  }

  /// Clear all GrabMart data
  void clearData() {
    _categories = [];
    _items = [];
    _specialOffers = [];
    _quickPicks = [];
    _topRatedItems = [];
    _recommendedItems = [];
    _recommendedPage = 1;
    _hasMoreRecommended = true;
    notifyListeners();
  }

  /// Refresh all GrabMart data
  Future<void> refreshAll({bool forceRefresh = false}) async {
    // Smart caching: Check if cache is stale (> 5 minutes)
    final cacheIsStale = CacheService.isCacheStale(
      CacheService.grabmartItemsTimestampKey,
      const Duration(minutes: 5),
    );

    // ONLY show loading states (skeletons) if data is actually empty
    // This prevents skeletons from showing during pull-to-refresh when data is already visible
    if (_items.isEmpty) {
      _isLoadingCategories = true;
      _isLoadingItems = true;
      notifyListeners();
    }

    await Future.wait([
      fetchCategories(forceRefresh: forceRefresh || cacheIsStale),
      fetchItems(forceRefresh: forceRefresh || cacheIsStale),
      fetchRecommendedItems(forceRefresh: forceRefresh || cacheIsStale),
    ]);
  }

  /// Check if we should show skeleton loader based on cache age
  bool shouldShowSkeleton() {
    final cacheIsStale = CacheService.isCacheStale(
      CacheService.grabmartItemsTimestampKey,
      const Duration(minutes: 5),
    );
    return cacheIsStale && _items.isEmpty;
  }

  /// Fetch recommended GrabMart items (resets pagination)
  Future<void> fetchRecommendedItems({bool forceRefresh = false}) async {
    if (_isLoadingRecommended) return;
    if (!forceRefresh && _recommendedItems.isNotEmpty) return;

    _recommendedPage = 1;
    _hasMoreRecommended = true;
    _recommendedItems = [];
    await _fetchRecommendedPage(page: 1, append: false);
  }

  /// Load more recommended GrabMart items
  Future<void> loadMoreRecommendedItems() async {
    if (_isLoadingRecommended || !_hasMoreRecommended) return;
    final nextPage = _recommendedPage + 1;
    await _fetchRecommendedPage(page: nextPage, append: true);
  }

  Future<void> _fetchRecommendedPage({
    required int page,
    required bool append,
  }) async {
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
      final uniqueById = <String, GrabMartItem>{};
      for (final item in combined) {
        uniqueById[item.id] = item;
      }

      _recommendedItems = uniqueById.values.toList();
      _recommendedPage = page;
      _hasMoreRecommended = items.length >= 20;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error fetching GrabMart recommended items: $e');
      }
    } finally {
      _isLoadingRecommended = false;
      notifyListeners();
    }
  }
}
