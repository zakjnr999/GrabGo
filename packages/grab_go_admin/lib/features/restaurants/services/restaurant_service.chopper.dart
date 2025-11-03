// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

part of 'restaurant_service.dart';

// **************************************************************************
// ChopperGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: type=lint
final class _$RestaurantService extends RestaurantService {
  _$RestaurantService([ChopperClient? client]) {
    if (client == null) return;
    this.client = client;
  }

  @override
  final Type definitionType = RestaurantService;

  @override
  Future<Response<List<RestaurantData>>> getRestaurants() {
    final Uri $url = Uri.parse('/restaurants');
    final Request $request = Request('GET', $url, client.baseUrl);
    return client.send<List<RestaurantData>, RestaurantData>($request);
  }

  @override
  Future<Response<RestaurantData>> updateRestaurantStatus(
    String restaurantId,
    Map<String, dynamic> data,
  ) {
    final Uri $url = Uri.parse('/restaurants/${restaurantId}');
    final $body = data;
    final Request $request = Request('PUT', $url, client.baseUrl, body: $body);
    return client.send<RestaurantData, RestaurantData>($request);
  }
}
