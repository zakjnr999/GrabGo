import 'package:chopper/chopper.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:grab_go_customer/core/api/api_client.dart' as api_client;
import 'package:grab_go_customer/features/vendors/model/vendor_model.dart';
import 'package:grab_go_customer/features/vendors/model/vendor_type.dart';

class ExclusiveVendorService {
  static const int _defaultLimit = 24;

  Future<List<VendorModel>> fetchExclusiveVendors({
    VendorType? vendorType,
    double? latitude,
    double? longitude,
  }) async {
    final types = vendorType == null ? VendorType.values : [vendorType];
    var failureCount = 0;

    final batches = await Future.wait(
      types.map((type) async {
        try {
          return await _fetchExclusiveVendorsForType(
            type,
            latitude: latitude,
            longitude: longitude,
          );
        } catch (error) {
          failureCount += 1;
          debugPrint(
            'ExclusiveVendorService: failed to load ${type.id} exclusives: $error',
          );
          return <VendorModel>[];
        }
      }),
    );

    final vendors = batches
        .expand((batch) => batch)
        .where((vendor) => vendor.isExclusive)
        .toList();
    vendors.sort(_compareExclusiveVendors);

    if (vendors.isEmpty && failureCount == types.length) {
      throw Exception('Failed to load GrabGo exclusive vendors.');
    }

    return vendors;
  }

  Future<List<VendorModel>> _fetchExclusiveVendorsForType(
    VendorType vendorType, {
    double? latitude,
    double? longitude,
  }) async {
    Response<Map<String, dynamic>> response;

    switch (vendorType) {
      case VendorType.food:
        response = await api_client.vendorService.getRestaurants(
          limit: _defaultLimit,
          exclusive: 'true',
        );
        break;
      case VendorType.grocery:
        response = await api_client.vendorService.getGroceryStores(
          limit: _defaultLimit,
          exclusive: 'true',
        );
        break;
      case VendorType.pharmacy:
        response = await api_client.vendorService.getPharmacyStores(
          limit: _defaultLimit,
          exclusive: 'true',
        );
        break;
      case VendorType.grabmart:
        response = await api_client.vendorService.getGrabMartStores(
          limit: _defaultLimit,
          exclusive: 'true',
        );
        break;
    }

    if (!response.isSuccessful || response.body == null) {
      throw Exception('Exclusive vendor request failed for ${vendorType.id}.');
    }

    final payload = response.body!['data'];
    if (payload is! List) {
      return <VendorModel>[];
    }

    return payload
        .map(
          (entry) => VendorModel.fromJson(
            Map<String, dynamic>.from(entry as Map),
          ).copyWith(vendorTypeEnum: vendorType),
        )
        .map(
          (vendor) =>
              _attachDistance(vendor, latitude: latitude, longitude: longitude),
        )
        .toList(growable: false);
  }

  VendorModel _attachDistance(
    VendorModel vendor, {
    double? latitude,
    double? longitude,
  }) {
    if (latitude == null || longitude == null) {
      return vendor;
    }

    if (vendor.latitude == 0 || vendor.longitude == 0) {
      return vendor;
    }

    final distanceInMeters = Geolocator.distanceBetween(
      latitude,
      longitude,
      vendor.latitude,
      vendor.longitude,
    );
    return vendor.copyWith(distance: distanceInMeters / 1000);
  }

  int _compareExclusiveVendors(VendorModel a, VendorModel b) {
    final exclusiveOrder = _compareBoolDesc(a.isExclusive, b.isExclusive);
    if (exclusiveOrder != 0) return exclusiveOrder;

    final availabilityOrder = _compareBoolDesc(
      a.isAvailableForOrders,
      b.isAvailableForOrders,
    );
    if (availabilityOrder != 0) return availabilityOrder;

    final distanceOrder = _compareNullableDoubleAsc(a.distance, b.distance);
    if (distanceOrder != 0) return distanceOrder;

    final ratingOrder = b.rating.compareTo(a.rating);
    if (ratingOrder != 0) return ratingOrder;

    final featuredOrder = _compareBoolDesc(
      a.featured ?? false,
      b.featured ?? false,
    );
    if (featuredOrder != 0) return featuredOrder;

    return a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
  }

  int _compareBoolDesc(bool a, bool b) {
    return (b ? 1 : 0).compareTo(a ? 1 : 0);
  }

  int _compareNullableDoubleAsc(double? a, double? b) {
    if (a == null && b == null) return 0;
    if (a == null) return 1;
    if (b == null) return -1;
    return a.compareTo(b);
  }
}
