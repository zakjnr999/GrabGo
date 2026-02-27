import 'package:flutter/foundation.dart';
import 'package:grab_go_customer/features/home/model/food_category.dart';
import 'package:grab_go_customer/features/home/model/promo_banner.dart';
import 'package:grab_go_customer/features/home/viewmodel/food_category_provider.dart';
import 'package:grab_go_customer/features/home/viewmodel/food_banner_provider.dart';
import 'package:grab_go_customer/features/home/viewmodel/food_deals_provider.dart';
import 'package:grab_go_customer/features/home/viewmodel/food_discovery_provider.dart';

class FoodProvider with ChangeNotifier {
  final FoodCategoryProvider _categoryProvider;
  final FoodBannerProvider _bannerProvider;
  final FoodDealsProvider _dealsProvider;
  final FoodDiscoveryProvider _discoveryProvider;

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
  bool get isLoading => _categoryProvider.isLoading;
  String? get error => _categoryProvider.error;
  bool get hasAttemptedFetch => _categoryProvider.hasAttemptedFetch;

  Future<void> fetchCategories() => _categoryProvider.fetchCategories();
  Future<void> refreshCategories() => _categoryProvider.refreshCategories();
  void clearCategories() => _categoryProvider.clearCategories();
  Future<void> fetchFoodsForCategory(String categoryId) => _categoryProvider.fetchFoodsForCategory(categoryId);

  List<FoodItem> getAllFoods() => _categoryProvider.state.allFoods;
  List<FoodItem> getRandomFoods({int count = 5}) => _categoryProvider.state.getRandomFoods(count: count);

  /// Get items from the same seller (restaurant), excluding the current item
  List<FoodItem> getItemsFromSeller(int sellerId, {String? excludeItemId, int? limit}) {
    final allFoods = getAllFoods();
    final sellerItems = allFoods.where((item) => item.sellerId == sellerId && item.id != excludeItemId).toList();

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

  /// Get similar items from the same category, excluding the current item
  List<FoodItem> getSimilarItems(String categoryId, {String? excludeItemId, int limit = 5}) {
    for (var category in categories) {
      if (category.id == categoryId) {
        final similarItems = category.items.where((item) => item.id != excludeItemId).toList();
        return similarItems.take(limit).toList();
      }
    }
    return [];
  }

  /// Get "You May Like" items - items from same seller, sorted by popularity
  List<FoodItem> getYouMayLikeItems(FoodItem currentItem, {int limit = 5}) {
    final allFoods = getAllFoods();

    // Get items from same seller, sorted by order count (popularity)
    final sellerItems = allFoods
        .where((item) => item.sellerId == currentItem.sellerId && item.id != currentItem.id)
        .toList();
    sellerItems.sort((a, b) => b.orderCount.compareTo(a.orderCount));

    return sellerItems.take(limit).toList();
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
  List<FoodItem> getItemsFromSameCategory(FoodItem currentItem, {int limit = 5}) {
    final category = getCategoryForItem(currentItem);
    if (category == null) return [];

    return category.items.where((item) => item.id != currentItem.id).take(limit).toList();
  }

  /// Refresh all data from all providers (cache-first on initial load)
  Future<void> refreshAll({bool forceRefresh = false}) async {
    await Future.wait([
      forceRefresh ? _categoryProvider.refreshCategories() : _categoryProvider.fetchCategories(),
      forceRefresh ? _bannerProvider.refreshBanners() : _bannerProvider.fetchPromotionalBanners(),
      forceRefresh ? _dealsProvider.refreshDeals() : _dealsProvider.fetchDeals(),
      _discoveryProvider.fetchOrderHistory(forceRefresh: forceRefresh),
      _discoveryProvider.fetchRecentOrderItems(forceRefresh: forceRefresh),
      forceRefresh ? _discoveryProvider.refreshPopularItems() : _discoveryProvider.fetchPopularItems(),
      forceRefresh ? _discoveryProvider.refreshTopRatedItems() : _discoveryProvider.fetchTopRatedItems(),
      forceRefresh ? _discoveryProvider.refreshRecommendedItems() : _discoveryProvider.fetchRecommendedItems(),
    ]);
  }

  // Banners Provider
  List<PromoBanner> get promotionalBanners => _bannerProvider.promotionalBanners;
  bool get isLoadingBanners => _bannerProvider.isLoadingBanners;

  Future<void> fetchPromotionalBanners() => _bannerProvider.fetchPromotionalBanners();

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

  Future<void> fetchRecentOrderItems() => _discoveryProvider.fetchRecentOrderItems();
  Future<void> fetchOrderHistory() => _discoveryProvider.fetchOrderHistory();
  Future<void> fetchPopularItems() => _discoveryProvider.fetchPopularItems();
  Future<void> fetchTopRatedItems() => _discoveryProvider.fetchTopRatedItems();
  Future<void> fetchRecommendedItems() => _discoveryProvider.fetchRecommendedItems();
  Future<void> loadMoreRecommendedItems() => _discoveryProvider.loadMoreRecommendedItems();
}
