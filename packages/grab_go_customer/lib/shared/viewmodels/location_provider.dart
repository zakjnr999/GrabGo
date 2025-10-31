import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:grab_go_customer/shared/services/cache_service.dart';
import 'package:grab_go_customer/shared/services/location_service.dart';

class LocationProvider with ChangeNotifier {
  String _address = "";
  double? _latitude;
  double? _longitude;
  
  String get address => _address;
  double? get latitude => _latitude;
  double? get longitude => _longitude;

  bool _isFetching = false;
  bool get isFetching => _isFetching;

  LocationProvider() {
    // Load location data asynchronously without blocking
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCachedLocation();
    });
  }

  /// Load cached location data
  Future<void> _loadCachedLocation() async {
    try {
      final locationData = CacheService.getUserLocation();
      if (locationData != null && CacheService.isLocationCacheValid()) {
        _address = locationData['address'] ?? '';
        _latitude = locationData['latitude']?.toDouble();
        _longitude = locationData['longitude']?.toDouble();
        notifyListeners();
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading cached location: $e');
      }
    }
  }

  Future<void> fetchAddress() async {
    if (_isFetching) return;

    // Try to use cached location if valid
    if (CacheService.isLocationCacheValid()) {
      await _loadCachedLocation();
      if (_address.isNotEmpty) {
        return;
      }
    }

    _isFetching = true;
    notifyListeners();

    try {
      _address = await LocationService.getCurrentAddress();
      
      // Get coordinates if available
      final position = await LocationService.getCurrentPosition();
      if (position != null) {
        _latitude = position.latitude;
        _longitude = position.longitude;
        
        // Save to cache
        await CacheService.saveUserLocation(
          latitude: _latitude!,
          longitude: _longitude!,
          address: _address,
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching address: $e');
      }
    } finally {
      _isFetching = false;
      notifyListeners();
    }
  }

  /// Update location manually
  Future<void> updateLocation({
    required double latitude,
    required double longitude,
    required String address,
  }) async {
    _latitude = latitude;
    _longitude = longitude;
    _address = address;
    
    // Save to cache
    await CacheService.saveUserLocation(
      latitude: latitude,
      longitude: longitude,
      address: address,
    );
    
    notifyListeners();
  }

  void clearAddress() {
    _address = "";
    _latitude = null;
    _longitude = null;
    notifyListeners();
    LocationService.clearCache();
  }
}

