// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

part of 'cart_api_service.dart';

// **************************************************************************
// ChopperGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: type=lint
final class _$CartApiService extends CartApiService {
  _$CartApiService([ChopperClient? client]) {
    if (client == null) return;
    this.client = client;
  }

  @override
  final Type definitionType = CartApiService;

  @override
  Future<Response<Map<String, dynamic>>> getCartGroups({
    String? fulfillmentMode,
    double? lat,
    double? lng,
    bool? useCredits,
    String? promoCode,
  }) {
    final Uri $url = Uri.parse('/cart/groups');
    final Map<String, dynamic> $params = <String, dynamic>{
      'fulfillmentMode': fulfillmentMode,
      'lat': lat,
      'lng': lng,
      'useCredits': useCredits,
      'promoCode': promoCode,
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
  Future<Response<Map<String, dynamic>>> getCart({
    String? type,
    String? fulfillmentMode,
    double? lat,
    double? lng,
    bool? useCredits,
    String? promoCode,
  }) {
    final Uri $url = Uri.parse('/cart');
    final Map<String, dynamic> $params = <String, dynamic>{
      'type': type,
      'fulfillmentMode': fulfillmentMode,
      'lat': lat,
      'lng': lng,
      'useCredits': useCredits,
      'promoCode': promoCode,
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
  Future<Response<Map<String, dynamic>>> addToCart(
    Map<String, dynamic> body, {
    String? fulfillmentMode,
    double? lat,
    double? lng,
    bool? useCredits,
    String? promoCode,
  }) {
    final Uri $url = Uri.parse('/cart/add');
    final Map<String, dynamic> $params = <String, dynamic>{
      'fulfillmentMode': fulfillmentMode,
      'lat': lat,
      'lng': lng,
      'useCredits': useCredits,
      'promoCode': promoCode,
    };
    final $body = body;
    final Request $request = Request(
      'POST',
      $url,
      client.baseUrl,
      body: $body,
      parameters: $params,
    );
    return client.send<Map<String, dynamic>, Map<String, dynamic>>($request);
  }

  @override
  Future<Response<Map<String, dynamic>>> updateCartItem(
    String itemId,
    Map<String, dynamic> body, {
    String? fulfillmentMode,
    double? lat,
    double? lng,
    bool? useCredits,
    String? promoCode,
  }) {
    final Uri $url = Uri.parse('/cart/update/${itemId}');
    final Map<String, dynamic> $params = <String, dynamic>{
      'fulfillmentMode': fulfillmentMode,
      'lat': lat,
      'lng': lng,
      'useCredits': useCredits,
      'promoCode': promoCode,
    };
    final $body = body;
    final Request $request = Request(
      'PATCH',
      $url,
      client.baseUrl,
      body: $body,
      parameters: $params,
    );
    return client.send<Map<String, dynamic>, Map<String, dynamic>>($request);
  }

  @override
  Future<Response<Map<String, dynamic>>> removeFromCart(
    String itemId, {
    String? fulfillmentMode,
    double? lat,
    double? lng,
    bool? useCredits,
    String? promoCode,
  }) {
    final Uri $url = Uri.parse('/cart/remove/${itemId}');
    final Map<String, dynamic> $params = <String, dynamic>{
      'fulfillmentMode': fulfillmentMode,
      'lat': lat,
      'lng': lng,
      'useCredits': useCredits,
      'promoCode': promoCode,
    };
    final Request $request = Request(
      'DELETE',
      $url,
      client.baseUrl,
      parameters: $params,
    );
    return client.send<Map<String, dynamic>, Map<String, dynamic>>($request);
  }

  @override
  Future<Response<Map<String, dynamic>>> clearCart({
    String? fulfillmentMode,
    double? lat,
    double? lng,
    bool? useCredits,
    String? promoCode,
  }) {
    final Uri $url = Uri.parse('/cart/clear');
    final Map<String, dynamic> $params = <String, dynamic>{
      'fulfillmentMode': fulfillmentMode,
      'lat': lat,
      'lng': lng,
      'useCredits': useCredits,
      'promoCode': promoCode,
    };
    final Request $request = Request(
      'DELETE',
      $url,
      client.baseUrl,
      parameters: $params,
    );
    return client.send<Map<String, dynamic>, Map<String, dynamic>>($request);
  }
}
