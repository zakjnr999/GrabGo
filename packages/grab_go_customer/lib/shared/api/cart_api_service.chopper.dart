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
  Future<Response<Map<String, dynamic>>> getCart() {
    final Uri $url = Uri.parse('/cart');
    final Request $request = Request('GET', $url, client.baseUrl);
    return client.send<Map<String, dynamic>, Map<String, dynamic>>($request);
  }

  @override
  Future<Response<Map<String, dynamic>>> addToCart(Map<String, dynamic> body) {
    final Uri $url = Uri.parse('/cart/add');
    final $body = body;
    final Request $request = Request('POST', $url, client.baseUrl, body: $body);
    return client.send<Map<String, dynamic>, Map<String, dynamic>>($request);
  }

  @override
  Future<Response<Map<String, dynamic>>> updateCartItem(
    String itemId,
    Map<String, dynamic> body,
  ) {
    final Uri $url = Uri.parse('/cart/update/${itemId}');
    final $body = body;
    final Request $request = Request(
      'PATCH',
      $url,
      client.baseUrl,
      body: $body,
    );
    return client.send<Map<String, dynamic>, Map<String, dynamic>>($request);
  }

  @override
  Future<Response<Map<String, dynamic>>> removeFromCart(String itemId) {
    final Uri $url = Uri.parse('/cart/remove/${itemId}');
    final Request $request = Request('DELETE', $url, client.baseUrl);
    return client.send<Map<String, dynamic>, Map<String, dynamic>>($request);
  }

  @override
  Future<Response<Map<String, dynamic>>> clearCart() {
    final Uri $url = Uri.parse('/cart/clear');
    final Request $request = Request('DELETE', $url, client.baseUrl);
    return client.send<Map<String, dynamic>, Map<String, dynamic>>($request);
  }
}
