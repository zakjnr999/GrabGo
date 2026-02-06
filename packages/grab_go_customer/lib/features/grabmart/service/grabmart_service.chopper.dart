// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

part of 'grabmart_service.dart';

// **************************************************************************
// ChopperGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: type=lint
final class _$GrabMartService extends GrabMartService {
  _$GrabMartService([ChopperClient? client]) {
    if (client == null) return;
    this.client = client;
  }

  @override
  final Type definitionType = GrabMartService;

  @override
  Future<Response<dynamic>> getCategories() {
    final Uri $url = Uri.parse('/grabmart/categories');
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
    double? userLat,
    double? userLng,
  }) {
    final Uri $url = Uri.parse('/grabmart/items');
    final Map<String, dynamic> $params = <String, dynamic>{
      'category': category,
      'store': store,
      'minPrice': minPrice,
      'maxPrice': maxPrice,
      'tags': tags,
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
