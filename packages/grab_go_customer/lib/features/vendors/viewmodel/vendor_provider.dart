import 'package:flutter/foundation.dart';
import 'package:chopper/chopper.dart';
import 'package:geolocator/geolocator.dart';
import 'package:grab_go_shared/shared/services/cache_service.dart';
import '../model/vendor_model.dart';
import '../model/vendor_type.dart';
import '../service/vendor_service.dart';

class VendorProvider extends ChangeNotifier {
  final VendorService _vendorService;

  VendorProvider(this._vendorService);

  // State
  List<VendorModel> _vendors = [];
  List<VendorModel> _filteredVendors = [];
  VendorType? _selectedType;
  String? _selectedCategoryId;
  bool _isLoading = false;
  String? _error;
  String _searchQuery = '';

  // Filters
  bool _openNowOnly = false;
  bool _emergencyOnly = false;
  bool _is24HoursOnly = false;
  double? _minRating;
  double? _maxDistance;
  int? _priceRange; // 1: GH₵, 2: GH₵GH₵, 3: GH₵GH₵GH₵
  bool _fastDeliveryOnly = false;
  VendorType? _mapCategoryFilter;

  // Getters
  List<VendorModel> get vendors => _vendors;
  List<VendorModel> get filteredVendors => _filteredVendors;
  VendorType? get selectedType => _selectedType;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get selectedCategoryId => _selectedCategoryId;
  String get searchQuery => _searchQuery;
  bool get openNowOnly => _openNowOnly;
  bool get emergencyOnly => _emergencyOnly;
  bool get is24HoursOnly => _is24HoursOnly;
  double? get minRating => _minRating;
  double? get maxDistance => _maxDistance;
  int? get priceRange => _priceRange;
  bool get fastDeliveryOnly => _fastDeliveryOnly;
  VendorType? get mapCategoryFilter => _mapCategoryFilter;

  List<VendorModel> get exclusiveVendors {
    return _vendors.where((v) => v.isExclusive).toList();
  }

  List<VendorModel> get nearestVendors {
    final list = _vendors.where((v) => v.distance != null).toList();
    list.sort((a, b) => a.distance!.compareTo(b.distance!));
    return list.take(10).toList();
  }

  List<VendorModel> get newVendors {
    final list = List<VendorModel>.from(_vendors);
    // Sort by createdAt descending, if available
    list.sort((a, b) {
      if (a.createdAt == null && b.createdAt == null) return 0;
      if (a.createdAt == null) return 1;
      if (b.createdAt == null) return -1;
      return b.createdAt!.compareTo(a.createdAt!);
    });
    return list.take(10).toList();
  }

  List<VendorModel> get budgetFriendlyVendors {
    final list = _vendors.where((v) => v.minOrder > 0 && v.minOrder <= 20).toList();
    list.sort((a, b) => a.minOrder.compareTo(b.minOrder));
    return list.take(10).toList();
  }

  int get activeFilterCount {
    int count = 0;
    if (_openNowOnly) count++;
    if (_emergencyOnly) count++;
    if (_is24HoursOnly) count++;
    if (_minRating != null) count++;
    if (_maxDistance != null) count++;
    if (_priceRange != null) count++;
    if (_fastDeliveryOnly) count++;
    if (_mapCategoryFilter != null) count++;
    return count;
  }

  /// Fetch vendors by type
  Future<void> fetchVendors(VendorType type, {double? lat, double? lng, bool forceRefresh = false}) async {
    final typeName = type.toString().split('.').last;

    // If type changed, clear current vendors immediately to avoid showing wrong data
    if (_selectedType != type) {
      _vendors = [];
      _filteredVendors = [];
    }

    _selectedType = type;

    // Load from cache first for immediate UI update
    if (!forceRefresh) {
      final cachedJson = CacheService.getVendorsByType(typeName);
      if (cachedJson.isNotEmpty) {
        _vendors = cachedJson.map((json) {
          final vendor = VendorModel.fromJson(Map<String, dynamic>.from(json)).copyWith(vendorTypeEnum: type);
          if (lat != null && lng != null) {
            final distanceInMeters = Geolocator.distanceBetween(lat, lng, vendor.latitude, vendor.longitude);
            return vendor.copyWith(distance: distanceInMeters / 1000);
          }
          return vendor;
        }).toList();
        _applyFilters();
        notifyListeners();
      }
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      Response<Map<String, dynamic>> response;

      switch (type) {
        case VendorType.food:
          response = await _vendorService.getRestaurants(
            isOpen: _openNowOnly ? 'true' : null,
            minRating: _minRating,
            limit: 50,
          );
          break;
        case VendorType.grocery:
          response = await _vendorService.getGroceryStores(
            isOpen: _openNowOnly ? 'true' : null,
            minRating: _minRating,
            limit: 50,
          );
          break;
        case VendorType.pharmacy:
          response = await _vendorService.getPharmacyStores(
            isOpen: _openNowOnly ? 'true' : null,
            minRating: _minRating,
            limit: 50,
          );
          break;
        case VendorType.grabmart:
          response = await _vendorService.getGrabMartStores(
            isOpen: _openNowOnly ? 'true' : null,
            is24Hours: _is24HoursOnly ? 'true' : null,
            minRating: _minRating,
            limit: 50,
          );
          break;
      }

      if (response.isSuccessful && response.body != null) {
        final data = response.body!['data'] as List;

        final List<Map<String, dynamic>> vendorsList = data.map((e) => Map<String, dynamic>.from(e as Map)).toList();

        // Save to cache
        await CacheService.saveVendorsByType(typeName, vendorsList);

        _vendors = vendorsList.map((json) {
          final vendor = VendorModel.fromJson(json).copyWith(vendorTypeEnum: type);
          if (lat != null && lng != null) {
            final distanceInMeters = Geolocator.distanceBetween(lat, lng, vendor.latitude, vendor.longitude);
            return vendor.copyWith(distance: distanceInMeters / 1000);
          }
          return vendor;
        }).toList();
        _applyFilters();
      } else {
        // Only set error if we don't have cached data
        if (_vendors.isEmpty) {
          _error = 'Failed to fetch vendors';
        }
      }
    } catch (e) {
      debugPrint('Error fetching vendors: $e');
      // Only set error if we don't have cached data
      if (_vendors.isEmpty) {
        _error = e.toString();
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Search vendors
  Future<void> searchVendors(String query) async {
    if (_selectedType == null) return;

    _searchQuery = query;
    if (query.isEmpty) {
      _applyFilters();
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      Response<Map<String, dynamic>> response;

      switch (_selectedType!) {
        case VendorType.food:
          response = await _vendorService.searchRestaurants(query: query);
          break;
        case VendorType.grocery:
          response = await _vendorService.searchGroceryStores(query: query);
          break;
        case VendorType.pharmacy:
          response = await _vendorService.searchPharmacies(
            query: query,
            emergencyService: _emergencyOnly ? 'true' : null,
          );
          break;
        case VendorType.grabmart:
          response = await _vendorService.searchGrabMarts(query: query);
          break;
      }

      if (response.isSuccessful && response.body != null) {
        final data = response.body!['data'] as List;
        _filteredVendors = data.map((json) {
          final vendor = VendorModel.fromJson(
            Map<String, dynamic>.from(json as Map),
          ).copyWith(vendorTypeEnum: _selectedType!);
          // Search results from backend might not include coordinates in search results in some APIs
          // but if they do, we can calculate distance
          return vendor;
        }).toList();
      } else {
        _error = 'Search failed';
      }
    } catch (e) {
      _error = e.toString();
      debugPrint('Error searching vendors: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Get nearby vendors
  Future<void> getNearbyVendors(double lat, double lng, {double radius = 5}) async {
    if (_selectedType == null) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      Response<Map<String, dynamic>> response;

      switch (_selectedType!) {
        case VendorType.food:
          response = await _vendorService.getNearbyRestaurants(latitude: lat, longitude: lng, radius: radius);
          break;
        case VendorType.grocery:
          response = await _vendorService.getNearbyGroceryStores(latitude: lat, longitude: lng, radius: radius);
          break;
        case VendorType.pharmacy:
          response = await _vendorService.getNearbyPharmacies(latitude: lat, longitude: lng, radius: radius);
          break;
        case VendorType.grabmart:
          response = await _vendorService.getNearbyGrabMarts(latitude: lat, longitude: lng, radius: radius);
          break;
      }

      if (response.isSuccessful && response.body != null) {
        final data = response.body!['data'] as List;
        _vendors = data.map((json) {
          final vendor = VendorModel.fromJson(
            Map<String, dynamic>.from(json as Map),
          ).copyWith(vendorTypeEnum: _selectedType!);
          final distanceInMeters = Geolocator.distanceBetween(lat, lng, vendor.latitude, vendor.longitude);
          return vendor.copyWith(distance: distanceInMeters / 1000);
        }).toList();
        _applyFilters();
      } else {
        _error = 'Failed to fetch nearby vendors';
      }
    } catch (e) {
      _error = e.toString();
      debugPrint('Error fetching nearby vendors: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Get all nearby vendors regardless of type
  Future<void> getAllNearbyVendors(double lat, double lng, {double radius = 5}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Execute all 4 calls in parallel
      final results = await Future.wait([
        _vendorService.getNearbyRestaurants(latitude: lat, longitude: lng, radius: radius),
        _vendorService.getNearbyGroceryStores(latitude: lat, longitude: lng, radius: radius),
        _vendorService.getNearbyPharmacies(latitude: lat, longitude: lng, radius: radius),
        _vendorService.getNearbyGrabMarts(latitude: lat, longitude: lng, radius: radius),
      ]);

      final List<VendorModel> allVendors = [];

      for (int i = 0; i < results.length; i++) {
        final response = results[i];
        final type = VendorType.values[i];

        if (response.isSuccessful && response.body != null) {
          final data = response.body!['data'] as List;
          final typeVendors = data.map((json) {
            final vendor = VendorModel.fromJson(
              Map<String, dynamic>.from(json as Map),
            ).copyWith(vendorTypeEnum: type);
            final distanceInMeters = Geolocator.distanceBetween(lat, lng, vendor.latitude, vendor.longitude);
            return vendor.copyWith(distance: distanceInMeters / 1000);
          }).toList();
          allVendors.addAll(typeVendors);
        }
      }

      _vendors = allVendors;
      _applyFilters();
    } catch (e) {
      _error = e.toString();
      debugPrint('Error fetching all nearby vendors: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Get emergency pharmacies
  Future<void> getEmergencyPharmacies() async {
    _selectedType = VendorType.pharmacy;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _vendorService.getEmergencyPharmacies();

      if (response.isSuccessful && response.body != null) {
        final data = response.body!['data'] as List;
        _vendors = data
            .map(
              (json) => VendorModel.fromJson(
                Map<String, dynamic>.from(json as Map),
              ).copyWith(vendorTypeEnum: VendorType.pharmacy),
            )
            .toList();
        _filteredVendors = _vendors;
      } else {
        _error = 'Failed to fetch emergency pharmacies';
      }
    } catch (e) {
      _error = e.toString();
      debugPrint('Error fetching emergency pharmacies: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Get 24-hour vendors
  Future<void> get24HourVendors() async {
    if (_selectedType == null) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      Response<Map<String, dynamic>> response;

      switch (_selectedType!) {
        case VendorType.pharmacy:
          response = await _vendorService.get24HourPharmacies();
          break;
        case VendorType.grabmart:
          response = await _vendorService.get24HourGrabMarts();
          break;
        default:
          _error = '24-hour filter not supported for this vendor type';
          _isLoading = false;
          notifyListeners();
          return;
      }

      if (response.isSuccessful && response.body != null) {
        final data = response.body!['data'] as List;
        _vendors = data
            .map(
              (json) =>
                  VendorModel.fromJson(Map<String, dynamic>.from(json as Map)).copyWith(vendorTypeEnum: _selectedType!),
            )
            .toList();
        _filteredVendors = _vendors;
      } else {
        _error = 'Failed to fetch 24-hour vendors';
      }
    } catch (e) {
      _error = e.toString();
      debugPrint('Error fetching 24-hour vendors: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Apply local filters
  void _applyFilters() {
    _filteredVendors = _vendors.where((vendor) {
      if (_openNowOnly && !vendor.isOpen) return false;
      if (_emergencyOnly && vendor.emergencyService != true) return false;
      if (_is24HoursOnly && vendor.is24Hours != true) return false;
      if (_minRating != null && vendor.rating < _minRating!) return false;
      if (_maxDistance != null && vendor.distance != null && vendor.distance! > _maxDistance!) {
        return false;
      }
      if (_mapCategoryFilter != null && vendor.vendorTypeEnum != _mapCategoryFilter) {
        return false;
      }
      if (_fastDeliveryOnly && (vendor.averageDeliveryTime ?? 60) > 30) {
        return false;
      }
      if (_priceRange != null) {
        // GH₵: Low budget (< 30 GHS), GH₵GH₵: Mid budget (< 80 GHS)
        if (_priceRange == 1 && vendor.minOrder > 30) return false;
        if (_priceRange == 2 && vendor.minOrder > 80) return false;
      }
      if (_selectedCategoryId != null) {
        final matchesCategory = vendor.categories?.contains(_selectedCategoryId) ?? false;
        final matchesService = vendor.services?.contains(_selectedCategoryId) ?? false;
        final matchesProductType = vendor.productTypes?.contains(_selectedCategoryId) ?? false;

        if (!matchesCategory && !matchesService && !matchesProductType) return false;
      }
      return true;
    }).toList();
  }

  /// Set filters
  void setOpenNowFilter(bool value) {
    _openNowOnly = value;
    _applyFilters();
    notifyListeners();
  }

  void setEmergencyFilter(bool value) {
    _emergencyOnly = value;
    _applyFilters();
    notifyListeners();
  }

  void set24HoursFilter(bool value) {
    _is24HoursOnly = value;
    _applyFilters();
    notifyListeners();
  }

  void setMinRating(double? value) {
    _minRating = value;
    _applyFilters();
    notifyListeners();
  }

  void setMaxDistance(double? value) {
    _maxDistance = value;
    _applyFilters();
    notifyListeners();
  }

  void setCategoryFilter(String? categoryId) {
    _selectedCategoryId = categoryId;
    _applyFilters();
    notifyListeners();
  }

  void setMapCategoryFilter(VendorType? type) {
    _mapCategoryFilter = type;
    _applyFilters();
    notifyListeners();
  }

  void setPriceRange(int? range) {
    _priceRange = range;
    _applyFilters();
    notifyListeners();
  }

  void setFastDelivery(bool value) {
    _fastDeliveryOnly = value;
    _applyFilters();
    notifyListeners();
  }

  /// Clear all filters
  void clearFilters() {
    _openNowOnly = false;
    _emergencyOnly = false;
    _is24HoursOnly = false;
    _minRating = null;
    _maxDistance = null;
    _selectedCategoryId = null;
    _priceRange = null;
    _fastDeliveryOnly = false;
    _mapCategoryFilter = null;
    _searchQuery = '';
    _applyFilters();
    notifyListeners();
  }

  /// Refresh vendors
  Future<void> refreshVendors() async {
    if (_selectedType != null) {
      await fetchVendors(_selectedType!, forceRefresh: true);
    }
  }
}
