// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'order_service.dart';

// **************************************************************************
// ChopperGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: type=lint
final class _$OrderService extends OrderService {
  _$OrderService([ChopperClient? client]) {
    if (client == null) return;
    this.client = client;
  }

  @override
  final Type definitionType = OrderService;

  @override
  Future<Response<OrderResponse>> getOrders() {
    final Uri $url = Uri.parse('/orders');
    final Request $request = Request(
      'GET',
      $url,
      client.baseUrl,
    );
    return client.send<OrderResponse, OrderResponse>($request);
  }

  @override
  Future<Response<Map<String, dynamic>>> getOrderById(String orderId) {
    final Uri $url = Uri.parse('/orders/${orderId}');
    final Request $request = Request(
      'GET',
      $url,
      client.baseUrl,
    );
    return client.send<Map<String, dynamic>, Map<String, dynamic>>($request);
  }

  @override
  Future<Response<Map<String, dynamic>>> updateOrderStatus(
    String orderId,
    Map<String, dynamic> body,
  ) {
    final Uri $url = Uri.parse('/orders/${orderId}/status');
    final Request $request = Request(
      'PUT',
      $url,
      client.baseUrl,
      body: body,
    );
    return client.send<Map<String, dynamic>, Map<String, dynamic>>($request);
  }

  @override
  Future<Response<Map<String, dynamic>>> assignRider(
    String orderId,
    Map<String, dynamic> body,
  ) {
    final Uri $url = Uri.parse('/orders/${orderId}/assign-rider');
    final Request $request = Request(
      'PUT',
      $url,
      client.baseUrl,
      body: body,
    );
    return client.send<Map<String, dynamic>, Map<String, dynamic>>($request);
  }
}