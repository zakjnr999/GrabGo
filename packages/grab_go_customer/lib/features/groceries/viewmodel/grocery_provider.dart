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

  // Top rated items
  List<GroceryItem> _topRatedItems = [];
  List<GroceryItem> get topRatedItems => _topRatedItems;

  bool _isLoadingTopRated = false;
  bool get isLoadingTopRated => _isLoadingTopRated;

  /// Fetch all grocery stores
  Future<void> fetchStores({bool forceRefresh = false}) async {
    // Load from cache if not already loaded and not forcing refresh
    if (!forceRefresh && _stores.isEmpty) {
      final cached = CacheService.getGroceryStores();
      if (cached.isNotEmpty) {
        _stores = cached.map((json) => GroceryStore.fromJson(json)).toList();
        notifyListeners();
      }
    }

    _isLoadingStores = true;
    notifyListeners();

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
    if (!forceRefresh && _categories.isEmpty) {
      final cached = CacheService.getGroceryCategories();
      if (cached.isNotEmpty) {
        _categories = cached.map((json) => GroceryCategory.fromJson(json)).toList();
        notifyListeners();
      }
    }

    _isLoadingCategories = true;
    notifyListeners();

    try {
      final freshCategories = await _repository.fetchCategories();
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

    if (!forceRefresh && isBaseFetch && _items.isEmpty) {
      final cached = CacheService.getGroceryItems();
      if (cached.isNotEmpty) {
        _items = cached.map((json) => GroceryItem.fromJson(json)).toList();
        notifyListeners();
        // Load sub-sections from memory-cached items
        fetchFreshArrivals();
      }
    }

    _isLoadingItems = true;
    notifyListeners();

    try {
      final freshItems = await _repository.fetchItems(
        category: category,
        store: store,
        minPrice: minPrice,
        maxPrice: maxPrice,
        tags: tags,
      );
      _items = freshItems;

      if (isBaseFetch) {
        await CacheService.saveGroceryItems(freshItems.map((i) => i.toJson()).toList());
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error in fetchItems: $e');
      }
    } finally {
      _isLoadingItems = false;
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
    if (!forceRefresh && _deals.isEmpty) {
      final cached = CacheService.getGroceryDeals();
      if (cached.isNotEmpty) {
        _deals = cached.map((json) => GroceryItem.fromJson(json)).toList();
        notifyListeners();
      }
    }

    _isLoadingDeals = true;
    notifyListeners();

    try {
      final freshDeals = await _repository.fetchDeals();
      _deals = freshDeals;
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
  Future<void> fetchBuyAgainItems() async {
    _isLoadingBuyAgain = true;
    notifyListeners();

    try {
      _buyAgainItems = await _repository.fetchOrderHistory();
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error in fetchBuyAgainItems: $e');
      }
      _buyAgainItems = [];
    } finally {
      _isLoadingBuyAgain = false;
      notifyListeners();
    }
  }

  /// Refresh all grocery data
  Future<void> refreshAll() async {
    // Pre-set all loading states to true so UI shows loading skeletons immediately
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

    await Future.wait([
      fetchStores(forceRefresh: true),
      fetchCategories(forceRefresh: true),
      fetchItems(forceRefresh: true),
      fetchDeals(forceRefresh: true),
    ]);
    // Fetch fresh arrivals, buy again, store specials, popular, and top-rated after items are loaded
    await Future.wait([
      fetchFreshArrivals(),
      fetchBuyAgainItems(),
      fetchStoreSpecials(),
      fetchPopularItems(),
      fetchTopRatedItems(),
    ]);
  }

  /// Clear all data
  void clearAll() {
    _stores = [];
    _categories = [];
    _items = [];
    _deals = [];
    notifyListeners();
  }

  /// Fetch store specials (items with active discounts grouped by store)
  Future<void> fetchStoreSpecials() async {
    _isLoadingStoreSpecials = true;
    notifyListeners();

    try {
      _storeSpecials = await _repository.fetchStoreSpecials();
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error fetching store specials: $e');
      }
      _storeSpecials = [];
    } finally {
      _isLoadingStoreSpecials = false;
      notifyListeners();
    }
  }

  /// Fetch popular grocery items sorted by order count
  Future<void> fetchPopularItems() async {
    _isLoadingPopular = true;
    notifyListeners();

    try {
      _popularItems = await _repository.fetchPopularItems(limit: 10);
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error fetching popular items: $e');
      }
      _popularItems = [];
    } finally {
      _isLoadingPopular = false;
      notifyListeners();
    }
  }

  /// Fetch top-rated grocery items sorted by rating
  Future<void> fetchTopRatedItems() async {
    _isLoadingTopRated = true;
    notifyListeners();

    try {
      _topRatedItems = await _repository.fetchTopRatedItems(limit: 10, minRating: 4.5);
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error fetching top rated items: $e');
      }
      _topRatedItems = [];
    } finally {
      _isLoadingTopRated = false;
      notifyListeners();
    }
  }
}
