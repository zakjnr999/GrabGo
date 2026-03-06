import 'dart:convert';

import 'package:grab_go_customer/shared/models/subscription_models.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:grab_go_shared/shared/services/secure_storage_service.dart';
import 'package:http/http.dart' as http;

class SubscriptionService {
  SubscriptionService._();
  static final SubscriptionService _instance = SubscriptionService._();
  factory SubscriptionService() => _instance;

  String get _baseUrl => '${AppConfig.apiBaseUrl}/subscriptions';

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

  Future<List<SubscriptionPlan>> getPlans() async {
    final response = await http.get(Uri.parse('$_baseUrl/plans'), headers: await _buildHeaders());

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Unable to load subscription plans');
    }

    final body = _decodeResponse(response) as Map<String, dynamic>?;
    final rawList = body?['data'] as List? ?? const [];
    return rawList.whereType<Map>().map((e) => SubscriptionPlan.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  Future<UserSubscription?> getMySubscription() async {
    final response = await http.get(Uri.parse('$_baseUrl/me'), headers: await _buildHeaders());

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Unable to load subscription');
    }

    final body = _decodeResponse(response) as Map<String, dynamic>?;
    final data = body?['data'];
    if (data is! Map) return null;

    return UserSubscription.fromJson(Map<String, dynamic>.from(data));
  }

  Future<SubscriptionStartResponse> subscribe(String tier) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/subscribe'),
      headers: await _buildHeaders(),
      body: jsonEncode({'tier': tier}),
    );

    final body = _decodeResponse(response) as Map<String, dynamic>?;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception((body?['message'] ?? 'Unable to subscribe').toString());
    }

    final data = body?['data'];
    if (data is! Map) {
      throw Exception('Invalid subscription response');
    }

    return SubscriptionStartResponse.fromJson(Map<String, dynamic>.from(data));
  }

  Future<void> cancel({String? reason}) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/cancel'),
      headers: await _buildHeaders(),
      body: jsonEncode({if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim()}),
    );

    final body = _decodeResponse(response) as Map<String, dynamic>?;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception((body?['message'] ?? 'Unable to cancel subscription').toString());
    }
  }

  Future<SubscriptionPaymentConfirmation> confirmPayment(String reference) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/confirm-payment'),
      headers: await _buildHeaders(),
      body: jsonEncode({'reference': reference}),
    );

    final body = _decodeResponse(response) as Map<String, dynamic>?;
    final data = body?['data'];
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception((body?['message'] ?? 'Unable to confirm subscription payment').toString());
    }

    if (data is! Map) {
      throw Exception('Invalid payment confirmation response');
    }

    return SubscriptionPaymentConfirmation.fromJson(Map<String, dynamic>.from(data));
  }
}
