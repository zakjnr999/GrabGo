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

  Future<void> fetchCategories() => _categoryProvider.fetchCategories();
  Future<void> refreshCategories() => _categoryProvider.refreshCategories();
  void clearCategories() => _categoryProvider.clearCategories();
  Future<void> fetchFoodsForCategory(String categoryId) => _categoryProvider.fetchFoodsForCategory(categoryId);

  List<FoodItem> getAllFoods() => _categoryProvider.state.allFoods;
  List<FoodItem> getRandomFoods({int count = 5}) => _categoryProvider.state.getRandomFoods(count: count);

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

  Future<void> fetchRecentOrderItems() => _discoveryProvider.fetchRecentOrderItems();
  Future<void> fetchOrderHistory() => _discoveryProvider.fetchOrderHistory();
  Future<void> fetchPopularItems() => _discoveryProvider.fetchPopularItems();
  Future<void> fetchTopRatedItems() => _discoveryProvider.fetchTopRatedItems();
  Future<void> fetchRecommendedItems() => _discoveryProvider.fetchRecommendedItems();
}
