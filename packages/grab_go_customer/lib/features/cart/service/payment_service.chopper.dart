// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

part of 'payment_service.dart';

// **************************************************************************
// ChopperGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: type=lint
final class _$PaymentService extends PaymentService {
  _$PaymentService([ChopperClient? client]) {
    if (client == null) return;
    this.client = client;
  }

  @override
  final Type definitionType = PaymentService;

  @override
  Future<Response<Map<String, dynamic>>> initiateMtnMomoPayment(
    MtnMomoInitiateRequest request,
  ) {
    final Uri $url = Uri.parse('/payments/mtn-momo/initiate');
    final $body = request;
    final Request $request = Request('POST', $url, client.baseUrl, body: $body);
    return client.send<Map<String, dynamic>, Map<String, dynamic>>($request);
  }

  @override
  Future<Response<Map<String, dynamic>>> checkPaymentStatus(String paymentId) {
    final Uri $url = Uri.parse('/payments/mtn-momo/status/${paymentId}');
    final Request $request = Request('GET', $url, client.baseUrl);
    return client.send<Map<String, dynamic>, Map<String, dynamic>>($request);
  }

  @override
  Future<Response<Map<String, dynamic>>> cancelPayment(String paymentId) {
    final Uri $url = Uri.parse('/payments/${paymentId}/cancel');
    final Request $request = Request('PUT', $url, client.baseUrl);
    return client.send<Map<String, dynamic>, Map<String, dynamic>>($request);
  }

  @override
  Future<Response<Map<String, dynamic>>> getUserPayments(int page, int limit) {
    final Uri $url = Uri.parse('/payments/my-payments');
    final Map<String, dynamic> $params = <String, dynamic>{
      'page': page,
      'limit': limit,
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
