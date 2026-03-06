import 'dart:convert';

import 'package:grab_go_customer/shared/models/promo_models.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:grab_go_shared/shared/services/secure_storage_service.dart';
import 'package:http/http.dart' as http;

class PromoService {
  PromoService._();
  static final PromoService _instance = PromoService._();
  factory PromoService() => _instance;

  String get _baseUrl => '${AppConfig.apiBaseUrl}/promo';

  Future<Map<String, String>> _buildHeaders() async {
    final token = await SecureStorageService.getAuthToken();
    return {
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  dynamic _decodeResponse(http.Response response) {
    if (response.body.isEmpty) return null;
    return jsonDecode(response.body);
  }

  Future<PromoCodesBucketResponse> getMyCodes() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/my-codes'),
      headers: await _buildHeaders(),
    );
    final body = _decodeResponse(response) as Map<String, dynamic>?;

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        (body?['message'] ?? body?['error'] ?? 'Unable to load promo codes')
            .toString(),
      );
    }

    final data = body?['data'];
    if (data is! Map) {
      return const PromoCodesBucketResponse(
        available: [],
        used: [],
        expired: [],
        fetchedAt: null,
      );
    }
    return PromoCodesBucketResponse.fromJson(Map<String, dynamic>.from(data));
  }

  Future<PromoValidationResult> validateCode({
    required String code,
    required double orderAmount,
    required String orderType,
  }) async {
    final normalizedCode = code.trim().toUpperCase();
    final normalizedOrderType = orderType.trim().toLowerCase();
    if (normalizedCode.isEmpty) {
      return const PromoValidationResult(
        valid: false,
        code: '',
        description: null,
        type: null,
        discount: 0,
        message: 'Promo code is required.',
      );
    }

    final response = await http.post(
      Uri.parse('$_baseUrl/validate'),
      headers: await _buildHeaders(),
      body: jsonEncode({
        'code': normalizedCode,
        'orderAmount': orderAmount,
        'orderType': normalizedOrderType,
      }),
    );

    final body = _decodeResponse(response) as Map<String, dynamic>?;
    if (response.statusCode >= 200 &&
        response.statusCode < 300 &&
        body?['valid'] == true) {
      return PromoValidationResult(
        valid: true,
        code: (body?['code'] ?? normalizedCode).toString().toUpperCase(),
        description: body?['description']?.toString(),
        type: body?['type']?.toString(),
        discount: (body?['discount'] as num?)?.toDouble() ?? 0.0,
        message: (body?['message'] ?? 'Promo code applied successfully.')
            .toString(),
      );
    }

    final errorMessage =
        (body?['error'] ?? body?['message'] ?? 'Invalid promo code').toString();
    return PromoValidationResult(
      valid: false,
      code: normalizedCode,
      description: null,
      type: null,
      discount: 0.0,
      message: errorMessage,
    );
  }
}
