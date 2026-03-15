import 'package:flutter/foundation.dart';
import 'package:grab_go_customer/features/home/model/food_category.dart';
import 'package:grab_go_customer/features/home/model/home_feed.dart';
import 'package:grab_go_customer/features/home/model/promo_banner.dart';
import 'package:grab_go_customer/features/home/repository/food_repository.dart';
import 'package:grab_go_customer/features/home/viewmodel/food_category_provider.dart';
import 'package:grab_go_customer/features/home/viewmodel/food_banner_provider.dart';
import 'package:grab_go_customer/features/home/viewmodel/food_deals_provider.dart';
import 'package:grab_go_customer/features/home/viewmodel/food_discovery_provider.dart';
import 'package:grab_go_customer/features/vendors/model/vendor_model.dart';
import 'package:grab_go_shared/shared/services/cache_service.dart';

class FoodProvider with ChangeNotifier {
  static const String _homeNearbyVendorsCacheKey = 'home_nearby_food';
  static const String _homeFreeDeliveryVendorsCacheKey =
      'home_free_delivery_food';
  static const String _homeExclusiveVendorsCacheKey = 'home_exclusive_food';

  final FoodCategoryProvider _categoryProvider;
  final FoodBannerProvider _bannerProvider;
  final FoodDealsProvider _dealsProvider;
  final FoodDiscoveryProvider _discoveryProvider;
  final FoodRepository _repository = FoodRepository();
  List<VendorModel> _nearbyVendors = const [];
  List<VendorModel> _freeDeliveryNearbyVendors = const [];
  List<VendorModel> _exclusiveVendors = const [];
  bool _isRefreshingHomeFeed = false;
  String? _homeFeedError;

  FoodProvider({
    FoodCategoryProvider? categoryProvider,
    FoodBannerProvider? bannerProvider,
    FoodDealsProvider? dealsProvider,
    FoodDiscoveryProvider? discoveryProvider,
  }) : _categoryProvider = categoryProvider ?? FoodCategoryProvider(),
       _bannerProvider = bannerProvider ?? FoodBannerProvider(),
       _dealsProvider = dealsProvider ?? FoodDealsProvider(),
       _discoveryProvider = discoveryProvider ?? FoodDiscoveryProvider() {
    // Listen to all providers and notify when any changes
    _categoryProvider.addListener(notifyListeners);
    _bannerProvider.addListener(notifyListeners);
    _dealsProvider.addListener(notifyListeners);
    _discoveryProvider.addListener(notifyListeners);
  }

  @override
  void dispose() {
    _categoryProvider.removeListener(notifyListeners);
    _bannerProvider.removeListener(notifyListeners);
    _dealsProvider.removeListener(notifyListeners);
    _discoveryProvider.removeListener(notifyListeners);
    super.dispose();
  }

  // Categories Providers
  List<FoodCategoryModel> get categories => _categoryProvider.categories;
  bool get isLoading => _isRefreshingHomeFeed || _categoryProvider.isLoading;
  String? get error => _homeFeedError ?? _categoryProvider.error;
  bool get hasAttemptedFetch => _categoryProvider.hasAttemptedFetch;
  List<VendorModel> get nearbyVendors => _nearbyVendors;
  List<VendorModel> get homepageNearbyVendors {
    if (_nearbyVendors.isEmpty || freeDeliveryNearbyVendors.isEmpty) {
      return _nearbyVendors;
    }

    final featuredFreeDeliveryIds = freeDeliveryNearbyVendors
        .map((vendor) => vendor.id)
        .where((id) => id.trim().isNotEmpty)
        .toSet();
    if (featuredFreeDeliveryIds.isEmpty) {
      return _nearbyVendors;
    }

    final ordered = <VendorModel>[];
    final deferred = <VendorModel>[];

    for (final vendor in _nearbyVendors) {
      if (!featuredFreeDeliveryIds.contains(vendor.id)) {
        ordered.add(vendor);
      } else {
        deferred.add(vendor);
      }
    }

    if (deferred.isEmpty) {
      return _nearbyVendors;
    }

    return [...ordered, ...deferred];
  }

  List<VendorModel> get exclusiveVendors => _exclusiveVendors;
  List<VendorModel> get freeDeliveryNearbyVendors {
    if (_freeDeliveryNearbyVendors.isNotEmpty) {
      return _freeDeliveryNearbyVendors;
    }

    final vendors = _nearbyVendors
        .where((vendor) => vendor.deliveryFee <= 0.001)
        .toList(growable: false);

    if (vendors.isEmpty) return const <VendorModel>[];

    final sorted = [...vendors]
      ..sort((a, b) {
        final featuredCompare = _featuredPriority(
          b,
        ).compareTo(_featuredPriority(a));
        if (featuredCompare != 0) return featuredCompare;

        final availabilityCompare = _availabilityPriority(
          b,
        ).compareTo(_availabilityPriority(a));
        if (availabilityCompare != 0) return availabilityCompare;

        final distanceCompare = _distanceValue(a).compareTo(_distanceValue(b));
        if (distanceCompare != 0) return distanceCompare;

        final ratingCompare = b.rating.compareTo(a.rating);
        if (ratingCompare != 0) return ratingCompare;

        return a.displayName.toLowerCase().compareTo(
          b.displayName.toLowerCase(),
        );
      });

    return sorted;
  }

  Future<void> fetchCategories() => _categoryProvider.fetchCategories();
  Future<void> refreshCategories() => _categoryProvider.refreshCategories();
  void clearCategories() => _categoryProvider.clearCategories();
  Future<void> fetchFoodsForCategory(String categoryId) =>
      _categoryProvider.fetchFoodsForCategory(categoryId);

  List<FoodItem> getAllFoods() => _categoryProvider.state.allFoods;
  List<FoodItem> getRandomFoods({int count = 5}) =>
      _categoryProvider.state.getRandomFoods(count: count);

  /// Get items from the same seller (restaurant), excluding the current item
  List<FoodItem> getItemsFromSeller(
    int sellerId, {
    String? excludeItemId,
    int? limit,
  }) {
    final allFoods = getAllFoods();
    final sellerItems = allFoods
        .where((item) => item.sellerId == sellerId && item.id != excludeItemId)
        .toList();

    if (limit != null && sellerItems.length > limit) {
      return sellerItems.take(limit).toList();
    }
    return sellerItems;
  }

  /// Get items from the same restaurant with strict ID matching first.
  List<FoodItem> getItemsFromRestaurant({
    required String restaurantId,
    int? sellerId,
    String? sellerName,
    String? excludeItemId,
    int? limit,
  }) {
    final allFoods = getAllFoods();
    final normalizedRestaurantId = restaurantId.trim();
    final normalizedSellerName = sellerName?.trim().toLowerCase();

    bool matches(FoodItem item) {
      if (excludeItemId != null && item.id == excludeItemId) return false;

      if (normalizedRestaurantId.isNotEmpty) {
        return item.restaurantId.trim() == normalizedRestaurantId;
      }

      if (sellerId != null && sellerId != 0) {
        return item.sellerId == sellerId;
      }

      if (normalizedSellerName != null && normalizedSellerName.isNotEmpty) {
        return item.sellerName.trim().toLowerCase() == normalizedSellerName;
      }

      return false;
    }

    final restaurantItems = allFoods.where(matches).toList();
    if (limit != null && restaurantItems.length > limit) {
      return restaurantItems.take(limit).toList();
    }
    return restaurantItems;
  }

  List<FoodItem> getRecommendedItemsFromRestaurant({
    required String restaurantId,
    int? sellerId,
    String? sellerName,
    Set<String> excludedItemIds = const <String>{},
    int limit = 8,
  }) {
    final normalizedRestaurantId = restaurantId.trim();
    final normalizedSellerName = sellerName?.trim().toLowerCase();
    final normalizedExcludedIds = excludedItemIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet();

    bool matchesRestaurant(FoodItem item) {
      final itemId = item.id.trim();
      if (itemId.isEmpty || normalizedExcludedIds.contains(itemId)) {
        return false;
      }

      if (normalizedRestaurantId.isNotEmpty) {
        return item.restaurantId.trim() == normalizedRestaurantId;
      }

      if (sellerId != null && sellerId != 0) {
        return item.sellerId == sellerId;
      }

      if (normalizedSellerName != null && normalizedSellerName.isNotEmpty) {
        return item.sellerName.trim().toLowerCase() == normalizedSellerName;
      }

      return false;
    }

    final matchingItems = _buildYouMayLikePool()
        .where(matchesRestaurant)
        .toList(growable: false);

    if (matchingItems.isEmpty) return const <FoodItem>[];

    final sortedItems = [...matchingItems]
      ..sort((a, b) {
        final bundleCompare = _bundlePriority(b).compareTo(_bundlePriority(a));
        if (bundleCompare != 0) return bundleCompare;

        final discountCompare = b.discountPercentage.compareTo(
          a.discountPercentage,
        );
        if (discountCompare != 0) return discountCompare;

        final orderCompare = b.orderCount.compareTo(a.orderCount);
        if (orderCompare != 0) return orderCompare;

        final ratingCompare = b.rating.compareTo(a.rating);
        if (ratingCompare != 0) return ratingCompare;

        final reviewCompare = b.reviewCount.compareTo(a.reviewCount);
        if (reviewCompare != 0) return reviewCompare;

        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

    return sortedItems.take(limit).toList(growable: false);
  }

  /// Get similar items from the same category, excluding the current item
  List<FoodItem> getSimilarItems(
    String categoryId, {
    String? excludeItemId,
    int limit = 5,
  }) {
    for (var category in categories) {
      if (category.id == categoryId) {
        final similarItems = category.items
            .where((item) => item.id != excludeItemId)
            .toList();
        return similarItems.take(limit).toList();
      }
    }
    return [];
  }

  /// Get "You May Like" items - items from same seller, sorted by popularity
  List<FoodItem> getYouMayLikeItems(FoodItem currentItem, {int limit = 5}) {
    final pool = _buildYouMayLikePool();
    if (pool.isEmpty) return [];

    final candidates = pool
        .where((item) => item.id.trim().isNotEmpty && item.id != currentItem.id)
        .toList(growable: false);
    if (candidates.isEmpty) return [];

    final sameProviderItems = candidates
        .where((item) => _isSameProviderItem(item, currentItem))
        .toList(growable: false);
    final selected = sameProviderItems.isNotEmpty
        ? sameProviderItems
        : candidates;

    final sorted = [...selected]
      ..sort((a, b) {
        final byOrders = b.orderCount.compareTo(a.orderCount);
        if (byOrders != 0) return byOrders;
        final byRating = b.rating.compareTo(a.rating);
        if (byRating != 0) return byRating;
        final byReviews = b.reviewCount.compareTo(a.reviewCount);
        if (byReviews != 0) return byReviews;
        final byDiscount = b.discountPercentage.compareTo(a.discountPercentage);
        if (byDiscount != 0) return byDiscount;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

    return sorted.take(limit).toList(growable: false);
  }

  List<FoodItem> _buildYouMayLikePool() {
    final allCandidates = <FoodItem>[
      ...getAllFoods(),
      ...dealItems,
      ...popularItems,
      ...topRatedItems,
      ...recommendedItems,
    ];
    final byId = <String, FoodItem>{};
    for (final item in allCandidates) {
      final id = item.id.trim();
      if (id.isEmpty) continue;
      byId.putIfAbsent(id, () => item);
    }
    return byId.values.toList(growable: false);
  }

  bool _isSameProviderItem(FoodItem item, FoodItem currentItem) {
    final itemRestaurantId = item.restaurantId.trim();
    final currentRestaurantId = currentItem.restaurantId.trim();
    if (currentRestaurantId.isNotEmpty && itemRestaurantId.isNotEmpty) {
      return itemRestaurantId == currentRestaurantId;
    }

    if (currentItem.sellerId != 0 && item.sellerId != 0) {
      return item.sellerId == currentItem.sellerId;
    }

    final currentSellerName = currentItem.sellerName.trim().toLowerCase();
    final itemSellerName = item.sellerName.trim().toLowerCase();
    if (currentSellerName.isNotEmpty && itemSellerName.isNotEmpty) {
      return itemSellerName == currentSellerName;
    }

    return false;
  }

  int _bundlePriority(FoodItem item) {
    final name = item.name.toLowerCase();
    final description = item.description.toLowerCase();
    final categoryName = item.categoryName?.toLowerCase() ?? '';
    const bundleKeywords = <String>[
      'bundle',
      'combo',
      'meal for two',
      'platter',
    ];

    final haystack = '$name $description $categoryName';
    return bundleKeywords.any(haystack.contains) ? 1 : 0;
  }

  int _featuredPriority(VendorModel vendor) => vendor.featured == true ? 1 : 0;

  int _availabilityPriority(VendorModel vendor) {
    final accepting = vendor.isAcceptingOrders;
    final open = vendor.isOpen;
    if (open && accepting) return 2;
    if (open) return 1;
    return 0;
  }

  double _distanceValue(VendorModel vendor) {
    final distance = vendor.distance;
    if (distance == null || distance.isNaN) return double.infinity;
    return distance;
  }

  /// Find which category contains a food item
  FoodCategoryModel? getCategoryForItem(FoodItem item) {
    for (var category in categories) {
      if (category.items.any((i) => i.id == item.id)) {
        return category;
      }
    }
    return null;
  }

  /// Get items from same category as the given item
  List<FoodItem> getItemsFromSameCategory(
    FoodItem currentItem, {
    int limit = 5,
  }) {
    final category = getCategoryForItem(currentItem);
    if (category == null) return [];

    return category.items
        .where((item) => item.id != currentItem.id)
        .take(limit)
        .toList();
  }

  /// Refresh all data from all providers (cache-first on initial load)
  Future<void> refreshAll({
    bool forceRefresh = false,
    bool includeRecentOrderItems = false,
  }) async {
    if (_isRefreshingHomeFeed) return;

    if (!forceRefresh) {
      await _primeCachedSections();
    }

    _homeFeedError = null;
    _isRefreshingHomeFeed = true;
    _categoryProvider.setHomeFeedLoading(true);
    notifyListeners();

    try {
      final locationData = CacheService.getUserLocation();
      final userLat = locationData?['latitude']?.toDouble();
      final userLng = locationData?['longitude']?.toDouble();
      final feed = await _repository.fetchHomeFeed(
        userLat: userLat,
        userLng: userLng,
      );
      await _applyHomeFeed(feed);
      if (includeRecentOrderItems) {
        await _discoveryProvider.fetchRecentOrderItems(
          forceRefresh: forceRefresh,
        );
      }
    } catch (error) {
      _homeFeedError = error.toString();
      if (kDebugMode) {
        print(
          '[FoodProvider] Home feed request failed, using legacy fan-out: $error',
        );
      }
      _categoryProvider.setHomeFeedLoading(false);
      await _refreshAllLegacy(
        forceRefresh: forceRefresh,
        includeRecentOrderItems: includeRecentOrderItems,
      );
    } finally {
      _isRefreshingHomeFeed = false;
      _categoryProvider.setHomeFeedLoading(false);
      notifyListeners();
    }
  }

  Future<void> _primeCachedSections() async {
    await Future.wait([
      _categoryProvider.primeFromCache(),
      _bannerProvider.primeFromCache(),
      _dealsProvider.primeFromCache(),
      _discoveryProvider.primeFromCache(),
    ]);
    _loadHomeVendorsFromCache();
  }

  void _loadHomeVendorsFromCache() {
    try {
      final cachedNearby = CacheService.getVendorsByType(
        _homeNearbyVendorsCacheKey,
      );
      final cachedFreeDelivery = CacheService.getVendorsByType(
        _homeFreeDeliveryVendorsCacheKey,
      );
      final cachedExclusive = CacheService.getVendorsByType(
        _homeExclusiveVendorsCacheKey,
      );

      final nearbyVendors = cachedNearby
          .map((json) => VendorModel.fromJson(json))
          .toList(growable: false);
      final freeDeliveryNearbyVendors = cachedFreeDelivery
          .map((json) => VendorModel.fromJson(json))
          .toList(growable: false);
      final exclusiveVendors = cachedExclusive
          .map((json) => VendorModel.fromJson(json))
          .toList(growable: false);

      final hasChanged =
          !_sameVendorIds(_nearbyVendors, nearbyVendors) ||
          !_sameVendorIds(
            _freeDeliveryNearbyVendors,
            freeDeliveryNearbyVendors,
          ) ||
          !_sameVendorIds(_exclusiveVendors, exclusiveVendors);

      _nearbyVendors = nearbyVendors;
      _freeDeliveryNearbyVendors = freeDeliveryNearbyVendors;
      _exclusiveVendors = exclusiveVendors;

      if (hasChanged) {
        notifyListeners();
      }
    } catch (error) {
      if (kDebugMode) {
        print('Error loading home vendor sections from cache: $error');
      }
    }
  }

  Future<void> _saveHomeVendorsToCache() async {
    try {
      await Future.wait([
        CacheService.saveVendorsByType(
          _homeNearbyVendorsCacheKey,
          _nearbyVendors
              .map((vendor) => vendor.toJson())
              .toList(growable: false),
        ),
        CacheService.saveVendorsByType(
          _homeFreeDeliveryVendorsCacheKey,
          _freeDeliveryNearbyVendors
              .map((vendor) => vendor.toJson())
              .toList(growable: false),
        ),
        CacheService.saveVendorsByType(
          _homeExclusiveVendorsCacheKey,
          _exclusiveVendors
              .map((vendor) => vendor.toJson())
              .toList(growable: false),
        ),
      ]);
    } catch (error) {
      if (kDebugMode) {
        print('Error saving home vendor sections to cache: $error');
      }
    }
  }

  bool _sameVendorIds(List<VendorModel> a, List<VendorModel> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id) return false;
    }
    return true;
  }

  Future<void> _applyHomeFeed(FoodHomeFeed feed) async {
    await Future.wait([
      _categoryProvider.hydrateFromHomeFeed(feed.categories),
      _bannerProvider.hydrateFromHomeFeed(feed.promoBanners),
      _dealsProvider.hydrateFromHomeFeed(feed.deals),
      _discoveryProvider.hydrateFromHomeFeed(
        orderHistoryItems: feed.orderHistory,
        popularItems: feed.popular,
        topRatedItems: feed.topRated,
        recommendedItems: feed.recommended.items,
        recommendedPage: feed.recommended.page,
        hasMoreRecommended: feed.recommended.hasMore,
      ),
    ]);

    _nearbyVendors = feed.nearbyVendors;
    _freeDeliveryNearbyVendors = feed.freeDeliveryNearbyVendors;
    _exclusiveVendors = feed.exclusiveVendors;
    await _saveHomeVendorsToCache();
    notifyListeners();
  }

  Future<void> _refreshAllLegacy({
    required bool forceRefresh,
    required bool includeRecentOrderItems,
  }) async {
    final futures = <Future<void>>[
      forceRefresh
          ? _categoryProvider.refreshCategories()
          : _categoryProvider.fetchCategories(),
      forceRefresh
          ? _bannerProvider.refreshBanners()
          : _bannerProvider.fetchPromotionalBanners(),
      forceRefresh
          ? _dealsProvider.refreshDeals()
          : _dealsProvider.fetchDeals(),
      _discoveryProvider.fetchOrderHistory(forceRefresh: forceRefresh),
      forceRefresh
          ? _discoveryProvider.refreshPopularItems()
          : _discoveryProvider.fetchPopularItems(),
      forceRefresh
          ? _discoveryProvider.refreshTopRatedItems()
          : _discoveryProvider.fetchTopRatedItems(),
      forceRefresh
          ? _discoveryProvider.refreshRecommendedItems()
          : _discoveryProvider.fetchRecommendedItems(),
    ];

    if (includeRecentOrderItems) {
      futures.add(
        _discoveryProvider.fetchRecentOrderItems(forceRefresh: forceRefresh),
      );
    }

    await Future.wait(futures);
  }

  // Banners Provider
  List<PromoBanner> get promotionalBanners =>
      _bannerProvider.promotionalBanners;
  bool get isLoadingBanners => _bannerProvider.isLoadingBanners;

  Future<void> fetchPromotionalBanners() =>
      _bannerProvider.fetchPromotionalBanners();

  // Deals Provider
  List<FoodItem> get dealItems => _dealsProvider.dealItems;
  bool get isLoadingDeals => _dealsProvider.isLoadingDeals;

  Future<void> fetchDeals() => _dealsProvider.fetchDeals();

  // Discovery Provider
  List<FoodItem> get recentOrderItems => _discoveryProvider.recentOrderItems;
  bool get isLoadingRecentItems => _discoveryProvider.isLoadingRecentItems;
  String? get recentItemsError => _discoveryProvider.recentItemsError;

  List<FoodItem> get orderHistoryItems => _discoveryProvider.orderHistoryItems;
  bool get isLoadingOrderHistory => _discoveryProvider.isLoadingOrderHistory;

  List<FoodItem> get popularItems => _discoveryProvider.popularItems;
  bool get isLoadingPopular => _discoveryProvider.isLoadingPopular;

  List<FoodItem> get topRatedItems => _discoveryProvider.topRatedItems;
  bool get isLoadingTopRated => _discoveryProvider.isLoadingTopRated;

  List<FoodItem> get recommendedItems => _discoveryProvider.recommendedItems;
  bool get isLoadingRecommended => _discoveryProvider.isLoadingRecommended;
  int get recommendedPage => _discoveryProvider.recommendedPage;
  bool get hasMoreRecommended => _discoveryProvider.hasMoreRecommended;

  Future<void> fetchRecentOrderItems() =>
      _discoveryProvider.fetchRecentOrderItems();
  Future<void> fetchOrderHistory() => _discoveryProvider.fetchOrderHistory();
  Future<void> fetchPopularItems() => _discoveryProvider.fetchPopularItems();
  Future<void> fetchTopRatedItems() => _discoveryProvider.fetchTopRatedItems();
  Future<void> fetchRecommendedItems() =>
      _discoveryProvider.fetchRecommendedItems();
  Future<void> loadMoreRecommendedItems() =>
      _discoveryProvider.loadMoreRecommendedItems();
}
