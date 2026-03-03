import 'dart:convert';

import 'package:chopper/chopper.dart';
import 'package:grab_go_customer/core/api/api_client.dart';
import 'package:grab_go_shared/grub_go_shared.dart';

class ParcelApiException implements Exception {
  final String message;
  final String? code;
  final int? statusCode;
  final List<Map<String, dynamic>> details;

  const ParcelApiException({
    required this.message,
    this.code,
    this.statusCode,
    this.details = const [],
  });

  @override
  String toString() {
    final codeText = code == null ? '' : ' [$code]';
    final statusText = statusCode == null ? '' : ' ($statusCode)';
    return 'ParcelApiException$statusText$codeText: $message';
  }
}

class ParcelApiClient {
  final ChopperClient _client;

  ParcelApiClient({ChopperClient? client}) : _client = client ?? chopperClient;

  Future<ParcelConfigModel> fetchConfig() async {
    final response = await _client.get(Uri(path: '/parcel/config'));
    final data = _extractSuccessData(
      response,
      fallbackMessage: 'Failed to fetch parcel config',
    );
    return ParcelConfigModel.fromJson(data);
  }

  Future<ParcelQuoteResponseModel> createQuote(
    ParcelQuoteRequest request,
  ) async {
    final response = await _client.post(
      Uri(path: '/parcel/quote'),
      body: request.toJson(),
    );
    final data = _extractSuccessData(
      response,
      fallbackMessage: 'Failed to generate parcel quote',
    );
    return ParcelQuoteResponseModel.fromJson(data);
  }

  Future<ParcelOrderSummary> createOrder(
    ParcelCreateOrderRequest request,
  ) async {
    final response = await _client.post(
      Uri(path: '/parcel/orders'),
      body: request.toJson(),
    );
    final data = _extractSuccessData(
      response,
      fallbackMessage: 'Failed to create parcel order',
    );
    return ParcelOrderSummary.fromJson(data);
  }

  Future<List<ParcelOrderSummary>> listOrders({
    int limit = 30,
    String? cursor,
  }) async {
    final response = await _client.get(
      Uri(
        path: '/parcel/orders',
        queryParameters: {
          'limit': '$limit',
          if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
        },
      ),
    );
    final data = _extractSuccessData(
      response,
      fallbackMessage: 'Failed to list parcel orders',
    );
    return _asList(
      data,
    ).map((e) => ParcelOrderSummary.fromJson(_asMap(e))).toList();
  }

  Future<ParcelOrderDetailModel> getOrder(String parcelId) async {
    final response = await _client.get(Uri(path: '/parcel/orders/$parcelId'));
    final data = _extractSuccessData(
      response,
      fallbackMessage: 'Failed to fetch parcel order',
    );
    return ParcelOrderDetailModel.fromJson(data);
  }

  Future<ParcelPaymentInitialization> initializePaystack(
    String parcelId,
  ) async {
    final response = await _client.post(
      Uri(path: '/parcel/orders/$parcelId/paystack/initialize'),
    );
    final data = _extractSuccessData(
      response,
      fallbackMessage: 'Failed to initialize parcel payment',
    );
    return ParcelPaymentInitialization.fromJson(data);
  }

  Future<ParcelPaymentConfirmation> confirmPayment(
    String parcelId, {
    String? reference,
    String provider = 'paystack',
  }) async {
    final response = await _client.post(
      Uri(path: '/parcel/orders/$parcelId/confirm-payment'),
      body: {
        if (reference != null && reference.isNotEmpty) 'reference': reference,
        'provider': provider,
      },
    );
    final data = _extractSuccessData(
      response,
      fallbackMessage: 'Failed to confirm parcel payment',
    );
    return ParcelPaymentConfirmation.fromJson(data);
  }

  Future<ParcelOrderSummary> cancelOrder(
    String parcelId, {
    String? reason,
  }) async {
    final response = await _client.post(
      Uri(path: '/parcel/orders/$parcelId/cancel'),
      body: {if (reason != null && reason.isNotEmpty) 'reason': reason},
    );
    final data = _extractSuccessData(
      response,
      fallbackMessage: 'Failed to cancel parcel order',
    );
    return ParcelOrderSummary.fromJson(data);
  }

  Map<String, dynamic> _extractSuccessData(
    Response response, {
    required String fallbackMessage,
  }) {
    final body = _decodeBody(response);
    final success = body['success'] == true;
    if (response.isSuccessful && success && body['data'] is Map) {
      return _asMap(body['data']);
    }
    if (response.isSuccessful && success && body['data'] is List) {
      return {'items': body['data']};
    }

    throw ParcelApiException(
      message: _asString(body['message'], fallbackMessage),
      code: _asString(body['code']).isEmpty ? null : _asString(body['code']),
      statusCode: response.statusCode,
      details: _asErrorDetails(body['errors']),
    );
  }

  Map<String, dynamic> _decodeBody(Response response) {
    if (response.body is Map<String, dynamic>) {
      return response.body as Map<String, dynamic>;
    }
    if (response.body is Map) {
      return Map<String, dynamic>.from(response.body as Map);
    }
    if (response.bodyString.isNotEmpty) {
      try {
        final decoded = jsonDecode(response.bodyString);
        if (decoded is Map<String, dynamic>) return decoded;
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {
        // ignore and fall through to empty map
      }
    }
    return const {};
  }

  List<dynamic> _asList(dynamic value) {
    if (value is List) return value;
    if (value is Map && value['items'] is List) return value['items'] as List;
    return const [];
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return const {};
  }

  String _asString(dynamic value, [String fallback = '']) {
    final text = value?.toString();
    if (text == null || text.trim().isEmpty) return fallback;
    return text.trim();
  }

  List<Map<String, dynamic>> _asErrorDetails(dynamic value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((entry) => Map<String, dynamic>.from(entry))
        .toList();
  }
}
