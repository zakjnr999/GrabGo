// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

part of 'food_service.dart';

// **************************************************************************
// ChopperGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: type=lint
final class _$FoodService extends FoodService {
  _$FoodService([ChopperClient? client]) {
    if (client == null) return;
    this.client = client;
  }

  @override
  final Type definitionType = FoodService;

  @override
  Future<Response<dynamic>> getCategories({double? userLat, double? userLng}) {
    final Uri $url = Uri.parse('/categories');
    final Map<String, dynamic> $params = <String, dynamic>{
      'userLat': userLat,
      'userLng': userLng,
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
  Future<Response<dynamic>> getFoods({
    String? restaurant,
    String? category,
    String? isAvailable,
    double? userLat,
    double? userLng,
  }) {
    final Uri $url = Uri.parse('/foods');
    final Map<String, dynamic> $params = <String, dynamic>{
      'restaurant': restaurant,
      'category': category,
      'isAvailable': isAvailable,
      'userLat': userLat,
      'userLng': userLng,
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
  Future<Response<dynamic>> getDeals() {
    final Uri $url = Uri.parse('/foods/deals');
    final Request $request = Request('GET', $url, client.baseUrl);
    return client.send<dynamic, dynamic>($request);
  }

  @override
  Future<Response<dynamic>> getPromotionalBanners() {
    final Uri $url = Uri.parse('/promotions/banners');
    final Request $request = Request('GET', $url, client.baseUrl);
    return client.send<dynamic, dynamic>($request);
  }

  @override
  Future<Response<dynamic>> getHomeFeed({double? userLat, double? userLng}) {
    final Uri $url = Uri.parse('/home/food-feed');
    final Map<String, dynamic> $params = <String, dynamic>{
      'userLat': userLat,
      'userLng': userLng,
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
  Future<Response<dynamic>> getOrderHistory() {
    final Uri $url = Uri.parse('/foods/order-history');
    final Request $request = Request('GET', $url, client.baseUrl);
    return client.send<dynamic, dynamic>($request);
  }

  @override
  Future<Response<dynamic>> getPopularItems(
    int? limit,
    double? userLat,
    double? userLng,
  ) {
    final Uri $url = Uri.parse('/foods/popular');
    final Map<String, dynamic> $params = <String, dynamic>{
      'limit': limit,
      'userLat': userLat,
      'userLng': userLng,
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
  Future<Response<dynamic>> getTopRatedItems(
    int? limit,
    double? minRating,
    double? userLat,
    double? userLng,
  ) {
    final Uri $url = Uri.parse('/foods/top-rated');
    final Map<String, dynamic> $params = <String, dynamic>{
      'limit': limit,
      'minRating': minRating,
      'userLat': userLat,
      'userLng': userLng,
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
  Future<Response<dynamic>> getRecommendedItems(
    int? limit,
    int? page,
    double? userLat,
    double? userLng,
  ) {
    final Uri $url = Uri.parse('/foods/recommended');
    final Map<String, dynamic> $params = <String, dynamic>{
      'limit': limit,
      'page': page,
      'userLat': userLat,
      'userLng': userLng,
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
