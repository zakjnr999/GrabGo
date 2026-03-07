// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

part of 'order_service_chopper.dart';

// **************************************************************************
// ChopperGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: type=lint
final class _$OrderServiceChopper extends OrderServiceChopper {
  _$OrderServiceChopper([ChopperClient? client]) {
    if (client == null) return;
    this.client = client;
  }

  @override
  final Type definitionType = OrderServiceChopper;

  @override
  Future<Response<Map<String, dynamic>>> createOrder(
    CreateOrderRequest request,
  ) {
    final Uri $url = Uri.parse('/orders');
    final $body = request;
    final Request $request = Request('POST', $url, client.baseUrl, body: $body);
    return client.send<Map<String, dynamic>, Map<String, dynamic>>($request);
  }

  @override
  Future<Response<Map<String, dynamic>>> resendDeliveryCode(
    String orderId,
    Map<String, dynamic> body,
  ) {
    final Uri $url = Uri.parse('/orders/${orderId}/delivery-code/resend');
    final $body = body;
    final Request $request = Request('POST', $url, client.baseUrl, body: $body);
    return client.send<Map<String, dynamic>, Map<String, dynamic>>($request);
  }

  @override
  Future<Response<Map<String, dynamic>>> confirmPayment(
    String orderId,
    Map<String, dynamic> body,
  ) {
    final Uri $url = Uri.parse('/orders/${orderId}/confirm-payment');
    final $body = body;
    final Request $request = Request('POST', $url, client.baseUrl, body: $body);
    return client.send<Map<String, dynamic>, Map<String, dynamic>>($request);
  }

  @override
  Future<Response<Map<String, dynamic>>> releaseCreditHold(String orderId) {
    final Uri $url = Uri.parse('/orders/${orderId}/release-credit-hold');
    final Request $request = Request('POST', $url, client.baseUrl);
    return client.send<Map<String, dynamic>, Map<String, dynamic>>($request);
  }

  @override
  Future<Response<Map<String, dynamic>>> initializePaystack(String orderId) {
    final Uri $url = Uri.parse('/orders/${orderId}/paystack/initialize');
    final Request $request = Request('POST', $url, client.baseUrl);
    return client.send<Map<String, dynamic>, Map<String, dynamic>>($request);
  }

  @override
  Future<Response<Map<String, dynamic>>> createCheckoutSession(
    Map<String, dynamic> body,
  ) {
    final Uri $url = Uri.parse('/checkout-sessions');
    final $body = body;
    final Request $request = Request('POST', $url, client.baseUrl, body: $body);
    return client.send<Map<String, dynamic>, Map<String, dynamic>>($request);
  }

  @override
  Future<Response<Map<String, dynamic>>> initializeCheckoutSessionPaystack(
    String sessionId,
  ) {
    final Uri $url = Uri.parse(
      '/checkout-sessions/${sessionId}/paystack/initialize',
    );
    final Request $request = Request('POST', $url, client.baseUrl);
    return client.send<Map<String, dynamic>, Map<String, dynamic>>($request);
  }

  @override
  Future<Response<Map<String, dynamic>>> confirmCheckoutSessionPayment(
    String sessionId,
    Map<String, dynamic> body,
  ) {
    final Uri $url = Uri.parse(
      '/checkout-sessions/${sessionId}/confirm-payment',
    );
    final $body = body;
    final Request $request = Request('POST', $url, client.baseUrl, body: $body);
    return client.send<Map<String, dynamic>, Map<String, dynamic>>($request);
  }

  @override
  Future<Response<Map<String, dynamic>>> releaseCheckoutSessionCreditHold(
    String sessionId,
  ) {
    final Uri $url = Uri.parse(
      '/checkout-sessions/${sessionId}/release-credit-hold',
    );
    final Request $request = Request('POST', $url, client.baseUrl);
    return client.send<Map<String, dynamic>, Map<String, dynamic>>($request);
  }

  @override
  Future<Response<Map<String, dynamic>>> getOrder(String orderId) {
    final Uri $url = Uri.parse('/orders/${orderId}');
    final Request $request = Request('GET', $url, client.baseUrl);
    return client.send<Map<String, dynamic>, Map<String, dynamic>>($request);
  }

  @override
  Future<Response<Map<String, dynamic>>> getUserOrders() {
    final Uri $url = Uri.parse('/orders');
    final Request $request = Request('GET', $url, client.baseUrl);
    return client.send<Map<String, dynamic>, Map<String, dynamic>>($request);
  }

  @override
  Future<Response<Map<String, dynamic>>> getCodEligibility() {
    final Uri $url = Uri.parse('/orders/cod/eligibility');
    final Request $request = Request('GET', $url, client.baseUrl);
    return client.send<Map<String, dynamic>, Map<String, dynamic>>($request);
  }

  @override
  Future<Response<Map<String, dynamic>>> submitVendorRating(
    String orderId,
    Map<String, dynamic> body,
  ) {
    final Uri $url = Uri.parse('/orders/${orderId}/vendor-rating');
    final $body = body;
    final Request $request = Request('POST', $url, client.baseUrl, body: $body);
    return client.send<Map<String, dynamic>, Map<String, dynamic>>($request);
  }

  @override
  Future<Response<Map<String, dynamic>>> submitItemReviews(
    String orderId,
    Map<String, dynamic> body,
  ) {
    final Uri $url = Uri.parse('/orders/${orderId}/item-reviews');
    final $body = body;
    final Request $request = Request('POST', $url, client.baseUrl, body: $body);
    return client.send<Map<String, dynamic>, Map<String, dynamic>>($request);
  }
}
