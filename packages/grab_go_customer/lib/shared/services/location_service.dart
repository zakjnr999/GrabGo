import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:grab_go_customer/shared/services/storage_service.dart';

class LocationService {
  static Position? _cachedPosition;
  static String? _cachedAddress;

  static Future<Position?> getCurrentPosition() async {
    if (_cachedPosition != null) return _cachedPosition;

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;

    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      final hasShownLocationScreen = StorageService.hasLocationPermissionScreenShown();
      if (!hasShownLocationScreen) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return null;
      } else {
        return null;
      }
    }

    if (permission == LocationPermission.deniedForever) return null;

    _cachedPosition = await Geolocator.getCurrentPosition(
      locationSettings: AndroidSettings(accuracy: LocationAccuracy.high),
    );
    return _cachedPosition;
  }

  static Future<String> getCurrentAddress() async {
    if (_cachedAddress != null) return _cachedAddress!;

    try {
      Position? position = await getCurrentPosition();
      if (position == null) return "Location not available";

      List<Placemark> placeMarks = await placemarkFromCoordinates(position.latitude, position.longitude);

      if (placeMarks.isNotEmpty) {
        Placemark place = placeMarks[0];
        _cachedAddress = _formatAddress(place);
        return _cachedAddress!;
      } else {
        return "Address not found";
      }
    } catch (e) {
      if (kDebugMode) {
        print('Location error: $e');
      }
      return "Unable to get location";
    }
  }

  /// Get address from specific coordinates
  static Future<String> getAddressFromCoordinates(double latitude, double longitude) async {
    try {
      List<Placemark> placeMarks = await placemarkFromCoordinates(latitude, longitude);

      if (placeMarks.isNotEmpty) {
        Placemark place = placeMarks[0];
        return _formatAddress(place);
      } else {
        return "Address not found";
      }
    } catch (e) {
      if (kDebugMode) {
        print('Reverse geocoding error: $e');
      }
      return "Unable to get address";
    }
  }

  static String _formatAddress(Placemark place) {
    final parts = <String>[];

    // Try to get a specific location name or street
    if (place.name?.isNotEmpty == true && place.name != place.locality) {
      parts.add(place.name!);
    } else if (place.street?.isNotEmpty == true && place.street != place.locality) {
      parts.add(place.street!);
    }

    if (place.subLocality?.isNotEmpty == true) parts.add(place.subLocality!);
    if (place.locality?.isNotEmpty == true) parts.add(place.locality!);
    if (place.administrativeArea?.isNotEmpty == true) parts.add(place.administrativeArea!);

    return parts.isNotEmpty ? parts.join(', ') : "Address not available";
  }

  static void clearCache() {
    _cachedPosition = null;
    _cachedAddress = null;
  }

  static Future<bool> isServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  static Future<LocationPermission> checkPermissionStatus() async {
    return await Geolocator.checkPermission();
  }

  static Future<LocationPermission> requestPermission() async {
    return await Geolocator.requestPermission();
  }

  static Future<bool> hasPermission() async {
    final permission = await checkPermissionStatus();
    return permission == LocationPermission.whileInUse || permission == LocationPermission.always;
  }

  static Future<bool> isPermissionDeniedForever() async {
    final permission = await checkPermissionStatus();
    return permission == LocationPermission.deniedForever;
  }

  static Future<bool> isPermissionDenied() async {
    final permission = await checkPermissionStatus();
    return permission == LocationPermission.denied;
  }

  static Future<bool?> requestPermissionAndCheck() async {
    final permission = await requestPermission();
    if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
      return true;
    } else if (permission == LocationPermission.deniedForever) {
      return null;
    } else {
      return false;
    }
  }

  static Future<bool> openAppSettings() async {
    return await Geolocator.openAppSettings();
  }

  static Future<bool> openLocationSettings() async {
    return await Geolocator.openLocationSettings();
  }
}
