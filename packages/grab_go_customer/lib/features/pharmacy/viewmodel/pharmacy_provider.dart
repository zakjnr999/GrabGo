import 'package:flutter/foundation.dart';
import 'package:grab_go_customer/features/pharmacy/model/pharmacy_category.dart';
import 'package:grab_go_customer/features/pharmacy/model/pharmacy_item.dart';
import 'package:grab_go_customer/features/pharmacy/repository/pharmacy_repository.dart';
import 'package:grab_go_customer/features/services/model/service_hub_feed.dart';
import 'package:grab_go_shared/shared/services/cache_service.dart';

class PharmacyProvider extends ChangeNotifier {
  final PharmacyRepository _repository = PharmacyRepository();

  // Categories
  List<PharmacyCategory> _categories = [];
  bool _isLoadingCategories = false;

  // Items
  List<PharmacyItem> _items = [];
  bool _isLoadingItems = false;

  // On Sale items
  List<PharmacyItem> _onSaleItems = [];
  final bool _isLoadingOnSale = false;

  // Popular items
  List<PharmacyItem> _popularItems = [];
  final bool _isLoadingPopular = false;

  // Recommended items
  List<PharmacyItem> _recommendedItems = [];
  bool _isLoadingRecommended = false;
  int _recommendedPage = 1;
  bool _hasMoreRecommended = true;

  // Final fetch state
  bool _hasAttemptedFetch = false;
  bool get hasAttemptedFetch => _hasAttemptedFetch;

  // Getters
  List<PharmacyCategory> get categories => _categories;
  bool get isLoadingCategories => _isLoadingCategories;

  List<PharmacyItem> get items => _items;
  bool get isLoadingItems => _isLoadingItems;

  List<PharmacyItem> get onSaleItems => _onSaleItems;
  bool get isLoadingOnSale => _isLoadingOnSale;

  List<PharmacyItem> get popularItems => _popularItems;
  bool get isLoadingPopular => _isLoadingPopular;

  List<PharmacyItem> get recommendedItems => _recommendedItems;
  bool get isLoadingRecommended => _isLoadingRecommended;
  int get recommendedPage => _recommendedPage;
  bool get hasMoreRecommended => _hasMoreRecommended;

  // Top Rated items
  List<PharmacyItem> _topRatedItems = [];
  List<PharmacyItem> get topRatedItems => _topRatedItems;

  Future<void> hydrateFromServiceHubFeed(ServiceHubFeed feed) async {
    final categories = feed.categories
        .map(PharmacyCategory.fromJson)
        .toList(growable: false);
    final items = feed.items.map(PharmacyItem.fromJson).toList(growable: false);
    final deals = feed.deals.map(PharmacyItem.fromJson).toList(growable: false);
    final popular = feed.popular
        .map(PharmacyItem.fromJson)
        .toList(growable: false);
    final topRated = feed.topRated
        .map(PharmacyItem.fromJson)
        .toList(growable: false);
    final recommended = feed.recommended.items
        .map(PharmacyItem.fromJson)
        .toList(growable: false);

    final mergedItems = <String, PharmacyItem>{};
    for (final list in [items, deals, popular, topRated, recommended]) {
      for (final item in list) {
        mergedItems[item.id] = item;
      }
    }

    _categories = categories;
    _items = mergedItems.values.toList(growable: false);
    _onSaleItems = deals.isNotEmpty
        ? deals
        : (_items.where((item) => item.hasDiscount).toList()..sort(
            (a, b) => b.discountPercentage.compareTo(a.discountPercentage),
          ));
    _popularItems = popular.isNotEmpty
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
    _isLoadingRecommended = false;

    await Future.wait([
      CacheService.savePharmacyCategories(
        _categories.map((category) => category.toJson()).toList(),
      ),
      CacheService.savePharmacyItems(
        _items.map((item) => item.toJson()).toList(),
      ),
    ]);

    notifyListeners();
  }

  /// Fetch all pharmacy categories
  Future<void> fetchCategories({bool forceRefresh = false}) async {
    if (_categories.isEmpty) {
      final cached = CacheService.getPharmacyCategories();
      if (cached.isNotEmpty) {
        _categories = cached
            .map((json) => PharmacyCategory.fromJson(json))
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
      await CacheService.savePharmacyCategories(
        _categories.map((c) => c.toJson()).toList(),
      );
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error fetching pharmacy categories: $e');
      }
    } finally {
      _isLoadingCategories = false;
      notifyListeners();
    }
  }

  /// Fetch pharmacy items with optional filters
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
      final cached = CacheService.getPharmacyItems();
      if (cached.isNotEmpty) {
        _items = cached.map((json) => PharmacyItem.fromJson(json)).toList();
        notifyListeners();
        // Load sub-sections from cached items
        _loadOnSaleItems();
        _loadPopularItems();
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
        print('🌍 [PHARMACY] Fetching items with location:');
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
        print('✅ [PHARMACY] Received ${items.length} items from API');
      }

      if (isBaseFetch) {
        await CacheService.savePharmacyItems(
          _items.map((i) => i.toJson()).toList(),
        );
        _loadOnSaleItems();
        _loadPopularItems();
        _loadTopRatedItems();
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error fetching pharmacy items: $e');
      }
    } finally {
      _isLoadingItems = false;
      _hasAttemptedFetch = true;
      notifyListeners();
    }
  }

  /// Load on sale items from existing items
  void _loadOnSaleItems() {
    _onSaleItems = _items.where((item) => item.hasDiscount).toList()
      ..sort((a, b) => b.discountPercentage.compareTo(a.discountPercentage));
    notifyListeners();
  }

  /// Load popular items from existing items
  void _loadPopularItems() {
    _popularItems = _items.where((item) => item.orderCount > 0).toList()
      ..sort((a, b) => b.orderCount.compareTo(a.orderCount));
    notifyListeners();
  }

  /// Load top-rated items (4.5+ rating)
  void _loadTopRatedItems() {
    _topRatedItems = _items.where((item) => item.rating >= 4.5).toList()
      ..sort((a, b) => b.rating.compareTo(a.rating));
    notifyListeners();
  }

  /// Clear all pharmacy data
  void clearData() {
    _categories = [];
    _items = [];
    _onSaleItems = [];
    _popularItems = [];
    _topRatedItems = [];
    _recommendedItems = [];
    _recommendedPage = 1;
    _hasMoreRecommended = true;
    notifyListeners();
  }

  /// Refresh all pharmacy data
  Future<void> refreshAll({bool forceRefresh = false}) async {
    // Smart caching: Check if cache is stale (> 5 minutes)
    final cacheIsStale = CacheService.isCacheStale(
      CacheService.pharmacyItemsTimestampKey,
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
      CacheService.pharmacyItemsTimestampKey,
      const Duration(minutes: 5),
    );
    return cacheIsStale && _items.isEmpty;
  }

  /// Fetch recommended pharmacy items (resets pagination)
  Future<void> fetchRecommendedItems({bool forceRefresh = false}) async {
    if (_isLoadingRecommended) return;
    if (!forceRefresh && _recommendedItems.isNotEmpty) return;

    _recommendedPage = 1;
    _hasMoreRecommended = true;
    _recommendedItems = [];
    await _fetchRecommendedPage(page: 1, append: false);
  }

  /// Load more recommended pharmacy items
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
      final uniqueById = <String, PharmacyItem>{};
      for (final item in combined) {
        uniqueById[item.id] = item;
      }

      _recommendedItems = uniqueById.values.toList();
      _recommendedPage = page;
      _hasMoreRecommended = items.length >= 20;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error fetching pharmacy recommended items: $e');
      }
    } finally {
      _isLoadingRecommended = false;
      notifyListeners();
    }
  }
}
