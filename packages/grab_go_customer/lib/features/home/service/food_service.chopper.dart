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
  Future<Response<dynamic>> getCategories() {
    final Uri $url = Uri.parse('/categories');
    final Request $request = Request('GET', $url, client.baseUrl);
    return client.send<dynamic, dynamic>($request);
  }

  @override
  Future<Response<dynamic>> getFoods({
    String? restaurant,
    String? category,
    String? isAvailable,
  }) {
    final Uri $url = Uri.parse('/foods');
    final Map<String, dynamic> $params = <String, dynamic>{};
    if (restaurant != null) {
      $params['restaurant'] = restaurant;
    }
    if (category != null) {
      $params['category'] = category;
    }
    if (isAvailable != null) {
      $params['isAvailable'] = isAvailable;
    }
    final Uri $urlWithParams = $url.replace(queryParameters: $params);
    final Request $request = Request('GET', $urlWithParams, client.baseUrl);
    return client.send<dynamic, dynamic>($request);
  }
}
