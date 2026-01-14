import 'package:flutter/foundation.dart';
import 'package:grab_go_customer/features/home/model/food_category.dart';
import 'package:grab_go_customer/features/home/repository/food_repository.dart';
import 'package:grab_go_customer/shared/viewmodels/base_provider.dart';
import 'package:grab_go_shared/shared/services/cache_service.dart';

/// State for food deals
class FoodDealsState {
  final List<FoodItem> deals;
  final bool isLoading;
  final String? error;

  const FoodDealsState({this.deals = const [], this.isLoading = false, this.error});

  FoodDealsState copyWith({List<FoodItem>? deals, bool? isLoading, String? error}) {
    return FoodDealsState(deals: deals ?? this.deals, isLoading: isLoading ?? this.isLoading, error: error);
  }
}

/// Provider for managing food deals
class FoodDealsProvider extends ChangeNotifier with CacheMixin {
  FoodDealsState _state = const FoodDealsState();
  FoodDealsState get state => _state;

  final FoodRepository _repository = FoodRepository();

  // Convenience getters for backward compatibility
  List<FoodItem> get dealItems => _state.deals;
  bool get isLoadingDeals => _state.isLoading;

  /// Fetch food deals with caching
  Future<void> fetchDeals({bool forceRefresh = false}) async {
    // Skip if already loading
    if (_state.isLoading) return;

    // Try loading from cache ONLY if we have no data yet and not force refreshing
    if (!forceRefresh && _state.deals.isEmpty) {
      if (CacheService.isFoodDealsCacheValid()) {
        await _loadFromCache();
        if (_state.deals.isNotEmpty) {
          return; // Cache hit, we're done
        }
      }
    }

    _updateState(_state.copyWith(isLoading: true));

    try {
      final deals = await _repository.fetchDeals();
      _updateState(_state.copyWith(deals: deals, isLoading: false, error: null));
      await _saveToCache();
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching deals: $e');
      }

      // If we have existing data, keep it. Otherwise try cache
      if (_state.deals.isEmpty) {
        await _loadFromCache();
      }

      _updateState(_state.copyWith(isLoading: false, error: 'Failed to load deals: ${e.toString()}'));
    }
  }

  /// Force refresh deals (for pull-to-refresh)
  Future<void> refreshDeals() async {
    await fetchDeals(forceRefresh: true);
  }

  /// Private: Load from cache
  Future<void> _loadFromCache() async {
    try {
      final cached = CacheService.getFoodDeals();
      if (cached.isNotEmpty) {
        final deals = cached.map((json) => FoodItem.fromJson(json)).toList();
        _updateState(_state.copyWith(deals: deals));
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading deals from cache: $e');
      }
    }
  }

  /// Private: Save to cache
  Future<void> _saveToCache() async {
    try {
      final dealsJson = _state.deals.map((deal) => deal.toJson()).toList();
      CacheService.saveFoodDeals(dealsJson);
    } catch (e) {
      if (kDebugMode) {
        print('Error saving deals to cache: $e');
      }
    }
  }

  /// Private: Update state and notify listeners
  void _updateState(FoodDealsState newState) {
    _state = newState;
    notifyListeners();
  }
}
