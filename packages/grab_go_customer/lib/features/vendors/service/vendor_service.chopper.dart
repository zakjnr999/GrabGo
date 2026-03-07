// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

part of 'vendor_service.dart';

// **************************************************************************
// ChopperGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: type=lint
final class _$VendorService extends VendorService {
  _$VendorService([ChopperClient? client]) {
    if (client == null) return;
    this.client = client;
  }

  @override
  final Type definitionType = VendorService;

  @override
  Future<Response<Map<String, dynamic>>> getRestaurants({
    String? isOpen,
    double? minRating,
    int? limit,
    String? exclusive,
  }) {
    final Uri $url = Uri.parse('/restaurants');
    final Map<String, dynamic> $params = <String, dynamic>{
      'isOpen': isOpen,
      'minRating': minRating,
      'limit': limit,
      'exclusive': exclusive,
    };
    final Request $request = Request(
      'GET',
      $url,
      client.baseUrl,
      parameters: $params,
    );
    return client.send<Map<String, dynamic>, Map<String, dynamic>>($request);
  }

  @override
  Future<Response<Map<String, dynamic>>> getRestaurantById(String id) {
    final Uri $url = Uri.parse('/restaurants/${id}');
    final Request $request = Request('GET', $url, client.baseUrl);
    return client.send<Map<String, dynamic>, Map<String, dynamic>>($request);
  }

  @override
  Future<Response<Map<String, dynamic>>> searchRestaurants({
    required String query,
  }) {
    final Uri $url = Uri.parse('/restaurants/search');
    final Map<String, dynamic> $params = <String, dynamic>{'q': query};
    final Request $request = Request(
      'GET',
      $url,
      client.baseUrl,
      parameters: $params,
    );
    return client.send<Map<String, dynamic>, Map<String, dynamic>>($request);
  }

  @override
  Future<Response<Map<String, dynamic>>> getNearbyRestaurants({
    required double latitude,
    required double longitude,
    double? radius,
  }) {
    final Uri $url = Uri.parse('/restaurants/nearby');
    final Map<String, dynamic> $params = <String, dynamic>{
      'lat': latitude,
      'lng': longitude,
      'radius': radius,
    };
    final Request $request = Request(
      'GET',
      $url,
      client.baseUrl,
      parameters: $params,
    );
    return client.send<Map<String, dynamic>, Map<String, dynamic>>($request);
  }

  @override
  Future<Response<Map<String, dynamic>>> getGroceryStores({
    String? isOpen,
    double? minRating,
    int? limit,
    String? exclusive,
  }) {
    final Uri $url = Uri.parse('/groceries/stores');
    final Map<String, dynamic> $params = <String, dynamic>{
      'isOpen': isOpen,
      'minRating': minRating,
      'limit': limit,
      'exclusive': exclusive,
    };
    final Request $request = Request(
      'GET',
      $url,
      client.baseUrl,
      parameters: $params,
    );
    return client.send<Map<String, dynamic>, Map<String, dynamic>>($request);
  }

  @override
  Future<Response<Map<String, dynamic>>> getGroceryStoreById(String id) {
    final Uri $url = Uri.parse('/groceries/stores/${id}');
    final Request $request = Request('GET', $url, client.baseUrl);
    return client.send<Map<String, dynamic>, Map<String, dynamic>>($request);
  }

  @override
  Future<Response<Map<String, dynamic>>> searchGroceryStores({
    required String query,
  }) {
    final Uri $url = Uri.parse('/groceries/search');
    final Map<String, dynamic> $params = <String, dynamic>{'q': query};
    final Request $request = Request(
      'GET',
      $url,
      client.baseUrl,
      parameters: $params,
    );
    return client.send<Map<String, dynamic>, Map<String, dynamic>>($request);
  }

  @override
  Future<Response<Map<String, dynamic>>> getNearbyGroceryStores({
    required double latitude,
    required double longitude,
    double? radius,
  }) {
    final Uri $url = Uri.parse('/groceries/nearby');
    final Map<String, dynamic> $params = <String, dynamic>{
      'lat': latitude,
      'lng': longitude,
      'radius': radius,
    };
    final Request $request = Request(
      'GET',
      $url,
      client.baseUrl,
      parameters: $params,
    );
    return client.send<Map<String, dynamic>, Map<String, dynamic>>($request);
  }

  @override
  Future<Response<Map<String, dynamic>>> getPharmacyStores({
    String? isOpen,
    double? minRating,
    int? limit,
    String? exclusive,
  }) {
    final Uri $url = Uri.parse('/pharmacies/stores');
    final Map<String, dynamic> $params = <String, dynamic>{
      'isOpen': isOpen,
      'minRating': minRating,
      'limit': limit,
      'exclusive': exclusive,
    };
    final Request $request = Request(
      'GET',
      $url,
      client.baseUrl,
      parameters: $params,
    );
    return client.send<Map<String, dynamic>, Map<String, dynamic>>($request);
  }

  @override
  Future<Response<Map<String, dynamic>>> getPharmacyStoreById(String id) {
    final Uri $url = Uri.parse('/pharmacies/stores/${id}');
    final Request $request = Request('GET', $url, client.baseUrl);
    return client.send<Map<String, dynamic>, Map<String, dynamic>>($request);
  }

  @override
  Future<Response<Map<String, dynamic>>> searchPharmacies({
    required String query,
    String? emergencyService,
    String? prescriptionService,
  }) {
    final Uri $url = Uri.parse('/pharmacies/search');
    final Map<String, dynamic> $params = <String, dynamic>{
      'q': query,
      'emergencyService': emergencyService,
      'prescriptionService': prescriptionService,
    };
    final Request $request = Request(
      'GET',
      $url,
      client.baseUrl,
      parameters: $params,
    );
    return client.send<Map<String, dynamic>, Map<String, dynamic>>($request);
  }

  @override
  Future<Response<Map<String, dynamic>>> getEmergencyPharmacies() {
    final Uri $url = Uri.parse('/pharmacies/emergency');
    final Request $request = Request('GET', $url, client.baseUrl);
    return client.send<Map<String, dynamic>, Map<String, dynamic>>($request);
  }

  @override
  Future<Response<Map<String, dynamic>>> get24HourPharmacies() {
    final Uri $url = Uri.parse('/pharmacies/24-hours');
    final Request $request = Request('GET', $url, client.baseUrl);
    return client.send<Map<String, dynamic>, Map<String, dynamic>>($request);
  }

  @override
  Future<Response<Map<String, dynamic>>> getNearbyPharmacies({
    required double latitude,
    required double longitude,
    double? radius,
  }) {
    final Uri $url = Uri.parse('/pharmacies/nearby');
    final Map<String, dynamic> $params = <String, dynamic>{
      'lat': latitude,
      'lng': longitude,
      'radius': radius,
    };
    final Request $request = Request(
      'GET',
      $url,
      client.baseUrl,
      parameters: $params,
    );
    return client.send<Map<String, dynamic>, Map<String, dynamic>>($request);
  }

  @override
  Future<Response<Map<String, dynamic>>> getGrabMartStores({
    String? isOpen,
    String? is24Hours,
    double? minRating,
    int? limit,
    String? exclusive,
  }) {
    final Uri $url = Uri.parse('/grabmart/stores');
    final Map<String, dynamic> $params = <String, dynamic>{
      'isOpen': isOpen,
      'is24Hours': is24Hours,
      'minRating': minRating,
      'limit': limit,
      'exclusive': exclusive,
    };
    final Request $request = Request(
      'GET',
      $url,
      client.baseUrl,
      parameters: $params,
    );
    return client.send<Map<String, dynamic>, Map<String, dynamic>>($request);
  }

  @override
  Future<Response<Map<String, dynamic>>> getGrabMartStoreById(String id) {
    final Uri $url = Uri.parse('/grabmart/stores/${id}');
    final Request $request = Request('GET', $url, client.baseUrl);
    return client.send<Map<String, dynamic>, Map<String, dynamic>>($request);
  }

  @override
  Future<Response<Map<String, dynamic>>> searchGrabMarts({
    required String query,
    String? services,
    String? productTypes,
  }) {
    final Uri $url = Uri.parse('/grabmart/search');
    final Map<String, dynamic> $params = <String, dynamic>{
      'q': query,
      'services': services,
      'productTypes': productTypes,
    };
    final Request $request = Request(
      'GET',
      $url,
      client.baseUrl,
      parameters: $params,
    );
    return client.send<Map<String, dynamic>, Map<String, dynamic>>($request);
  }

  @override
  Future<Response<Map<String, dynamic>>> get24HourGrabMarts() {
    final Uri $url = Uri.parse('/grabmart/24-hours');
    final Request $request = Request('GET', $url, client.baseUrl);
    return client.send<Map<String, dynamic>, Map<String, dynamic>>($request);
  }

  @override
  Future<Response<Map<String, dynamic>>> getGrabMartsWithServices({
    required String services,
  }) {
    final Uri $url = Uri.parse('/grabmart/with-services');
    final Map<String, dynamic> $params = <String, dynamic>{
      'services': services,
    };
    final Request $request = Request(
      'GET',
      $url,
      client.baseUrl,
      parameters: $params,
    );
    return client.send<Map<String, dynamic>, Map<String, dynamic>>($request);
  }

  @override
  Future<Response<Map<String, dynamic>>> getNearbyGrabMarts({
    required double latitude,
    required double longitude,
    double? radius,
  }) {
    final Uri $url = Uri.parse('/grabmart/nearby');
    final Map<String, dynamic> $params = <String, dynamic>{
      'lat': latitude,
      'lng': longitude,
      'radius': radius,
    };
    final Request $request = Request(
      'GET',
      $url,
      client.baseUrl,
      parameters: $params,
    );
    return client.send<Map<String, dynamic>, Map<String, dynamic>>($request);
  }

  @override
  Future<Response<Map<String, dynamic>>> getGrabMartsByPaymentMethods({
    String? cash,
    String? card,
    String? mobileMoney,
  }) {
    final Uri $url = Uri.parse('/grabmart/payment-methods');
    final Map<String, dynamic> $params = <String, dynamic>{
      'cash': cash,
      'card': card,
      'mobileMoney': mobileMoney,
    };
    final Request $request = Request(
      'GET',
      $url,
      client.baseUrl,
      parameters: $params,
    );
    return client.send<Map<String, dynamic>, Map<String, dynamic>>($request);
  }
}
