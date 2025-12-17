import 'package:flutter/foundation.dart';
import 'package:grab_go_customer/features/groceries/model/grocery_category.dart';
import 'package:grab_go_customer/features/groceries/model/grocery_item.dart';
import 'package:grab_go_customer/features/groceries/model/grocery_store.dart';
import 'package:grab_go_customer/features/groceries/model/store_special.dart';
import 'package:grab_go_customer/features/groceries/repository/grocery_repository.dart';

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
  Future<void> fetchStores() async {
    _isLoadingStores = true;
    notifyListeners();

    try {
      _stores = await _repository.fetchStores();
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error in fetchStores: $e');
      }
      _stores = [];
    } finally {
      _isLoadingStores = false;
      notifyListeners();
    }
  }

  /// Fetch all grocery categories
  Future<void> fetchCategories() async {
    _isLoadingCategories = true;
    notifyListeners();

    try {
      _categories = await _repository.fetchCategories();
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error in fetchCategories: $e');
      }
      _categories = [];
    } finally {
      _isLoadingCategories = false;
      notifyListeners();
    }
  }

  /// Fetch grocery items with optional filters
  Future<void> fetchItems({String? category, String? store, String? minPrice, String? maxPrice, String? tags}) async {
    _isLoadingItems = true;
    notifyListeners();

    try {
      _items = await _repository.fetchItems(
        category: category,
        store: store,
        minPrice: minPrice,
        maxPrice: maxPrice,
        tags: tags,
      );
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error in fetchItems: $e');
      }
      _items = [];
    } finally {
      _isLoadingItems = false;
      notifyListeners();

      // Automatically fetch fresh arrivals and buy again after items are loaded
      if (_items.isNotEmpty) {
        fetchFreshArrivals();
        fetchBuyAgainItems();
        fetchStoreSpecials();
      }
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
  Future<void> fetchDeals() async {
    _isLoadingDeals = true;
    notifyListeners();

    try {
      _deals = await _repository.fetchDeals();
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error in fetchDeals: $e');
      }
      _deals = [];
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
    await Future.wait([fetchStores(), fetchCategories(), fetchItems(), fetchDeals()]);
    // Fetch fresh arrivals, buy again, and store specials after items are loaded
    await Future.wait([fetchFreshArrivals(), fetchBuyAgainItems(), fetchStoreSpecials()]);
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
