import 'package:flutter/foundation.dart';
import 'package:grab_go_customer/features/home/model/promo_banner.dart';
import 'package:grab_go_customer/features/home/repository/food_repository.dart';
import 'package:grab_go_customer/shared/viewmodels/base_provider.dart';
import 'package:grab_go_shared/shared/services/cache_service.dart';

/// State for promotional banners
class FoodBannerState {
  final List<PromoBanner> banners;
  final bool isLoading;
  final String? error;

  const FoodBannerState({this.banners = const [], this.isLoading = false, this.error});

  FoodBannerState copyWith({List<PromoBanner>? banners, bool? isLoading, String? error}) {
    return FoodBannerState(banners: banners ?? this.banners, isLoading: isLoading ?? this.isLoading, error: error);
  }
}

/// Provider for managing promotional banners from backend
class FoodBannerProvider extends ChangeNotifier with CacheMixin {
  FoodBannerState _state = const FoodBannerState();
  FoodBannerState get state => _state;

  final FoodRepository _repository = FoodRepository();

  // Convenience getters
  List<PromoBanner> get promotionalBanners => _state.banners;
  bool get isLoadingBanners => _state.isLoading;

  /// Fetch promotional banners with caching
  Future<void> fetchPromotionalBanners({bool forceRefresh = false}) async {
    if (_state.isLoading) return;

    // Try loading from cache first
    if (!forceRefresh && _state.banners.isEmpty) {
      if (CacheService.isPromotionalBannersCacheValid()) {
        await _loadFromCache();
        if (_state.banners.isNotEmpty) {
          if (kDebugMode) {
            print('✅ Loaded ${_state.banners.length} banners from cache');
          }
          return;
        }
      }
    }

    _updateState(_state.copyWith(isLoading: true));

    try {
      if (kDebugMode) {
        print('🔄 Fetching promotional banners from backend...');
      }
      final banners = await _repository.fetchPromoBanners();
      if (kDebugMode) {
        print('✅ Fetched ${banners.length} promotional banners from backend');
      }
      _updateState(_state.copyWith(banners: banners, isLoading: false, error: null));
      await _saveToCache();
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error fetching promotional banners: $e');
      }
      if (_state.banners.isEmpty) {
        await _loadFromCache();
      }
      _updateState(_state.copyWith(isLoading: false, error: 'Failed to load banners: ${e.toString()}'));
    }
  }

  /// Force refresh banners
  Future<void> refreshBanners() async {
    await fetchPromotionalBanners(forceRefresh: true);
  }

  /// Load from cache
  Future<void> _loadFromCache() async {
    try {
      final cached = CacheService.getPromotionalBanners();
      if (cached.isNotEmpty) {
        final banners = cached.map((json) => PromoBanner.fromJson(json)).toList();
        _updateState(_state.copyWith(banners: banners));
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading banners from cache: $e');
      }
    }
  }

  /// Save to cache
  Future<void> _saveToCache() async {
    try {
      final bannersJson = _state.banners.map((banner) => banner.toJson()).toList();
      CacheService.savePromotionalBanners(bannersJson);
    } catch (e) {
      if (kDebugMode) {
        print('Error saving banners to cache: $e');
      }
    }
  }

  /// Update state
  void _updateState(FoodBannerState newState) {
    _state = newState;
    notifyListeners();
  }
}
