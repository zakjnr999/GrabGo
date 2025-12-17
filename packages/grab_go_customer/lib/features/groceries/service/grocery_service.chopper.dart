// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

part of 'grocery_service.dart';

// **************************************************************************
// ChopperGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: type=lint
final class _$GroceryService extends GroceryService {
  _$GroceryService([ChopperClient? client]) {
    if (client == null) return;
    this.client = client;
  }

  @override
  final Type definitionType = GroceryService;

  @override
  Future<Response<dynamic>> getStores() {
    final Uri $url = Uri.parse('/groceries/stores');
    final Request $request = Request('GET', $url, client.baseUrl);
    return client.send<dynamic, dynamic>($request);
  }

  @override
  Future<Response<dynamic>> getStoreById(String id) {
    final Uri $url = Uri.parse('/groceries/stores/${id}');
    final Request $request = Request('GET', $url, client.baseUrl);
    return client.send<dynamic, dynamic>($request);
  }

  @override
  Future<Response<dynamic>> getCategories() {
    final Uri $url = Uri.parse('/groceries/categories');
    final Request $request = Request('GET', $url, client.baseUrl);
    return client.send<dynamic, dynamic>($request);
  }

  @override
  Future<Response<dynamic>> getItems({
    String? category,
    String? store,
    String? minPrice,
    String? maxPrice,
    String? tags,
  }) {
    final Uri $url = Uri.parse('/groceries/items');
    final Map<String, dynamic> $params = <String, dynamic>{
      'category': category,
      'store': store,
      'minPrice': minPrice,
      'maxPrice': maxPrice,
      'tags': tags,
    };
    final Request $request = Request(
      'GET',
      $url,
      client.baseUrl,
      parameters: $params,
    );
    return client.send<dynamic, dynamic>($request);
  }

  @override
  Future<Response<dynamic>> getItemById(String id) {
    final Uri $url = Uri.parse('/groceries/items/${id}');
    final Request $request = Request('GET', $url, client.baseUrl);
    return client.send<dynamic, dynamic>($request);
  }

  @override
  Future<Response<dynamic>> searchItems(String query) {
    final Uri $url = Uri.parse('/groceries/search');
    final Map<String, dynamic> $params = <String, dynamic>{'q': query};
    final Request $request = Request(
      'GET',
      $url,
      client.baseUrl,
      parameters: $params,
    );
    return client.send<dynamic, dynamic>($request);
  }

  @override
  Future<Response<dynamic>> getDeals() {
    final Uri $url = Uri.parse('/groceries/deals');
    final Request $request = Request('GET', $url, client.baseUrl);
    return client.send<dynamic, dynamic>($request);
  }

  @override
  Future<Response<dynamic>> getStoreItems(String storeId) {
    final Uri $url = Uri.parse('/groceries/stores/${storeId}/items');
    final Request $request = Request('GET', $url, client.baseUrl);
    return client.send<dynamic, dynamic>($request);
  }

  @override
  Future<Response<dynamic>> getOrderHistory() {
    final Uri $url = Uri.parse('/groceries/order-history');
    final Request $request = Request('GET', $url, client.baseUrl);
    return client.send<dynamic, dynamic>($request);
  }

  @override
  Future<Response<dynamic>> getStoreSpecials() {
    final Uri $url = Uri.parse('/groceries/store-specials');
    final Request $request = Request('GET', $url, client.baseUrl);
    return client.send<dynamic, dynamic>($request);
  }

  @override
  Future<Response<dynamic>> getPopularItems(int? limit) {
    final Uri $url = Uri.parse('/groceries/popular');
    final Map<String, dynamic> $params = <String, dynamic>{'limit': limit};
    final Request $request = Request(
      'GET',
      $url,
      client.baseUrl,
      parameters: $params,
    );
    return client.send<dynamic, dynamic>($request);
  }

  @override
  Future<Response<dynamic>> getTopRatedItems(int? limit, double? minRating) {
    final Uri $url = Uri.parse('/groceries/top-rated');
    final Map<String, dynamic> $params = <String, dynamic>{
      'limit': limit,
      'minRating': minRating,
    };
    final Request $request = Request(
      'GET',
      $url,
      client.baseUrl,
      parameters: $params,
    );
    return client.send<dynamic, dynamic>($request);
  }
}
