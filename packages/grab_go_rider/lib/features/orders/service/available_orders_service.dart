import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:http/http.dart' as http;

class AvailableOrderDto {
  final String id;
  final String orderNumber;
  final String customerName;
  final String customerAddress;
  final String customerPhone;
  final String restaurantName;
  final String restaurantAddress;
  final double totalAmount;
  final List<String> orderItems;
  final String? notes;

  AvailableOrderDto({
    required this.id,
    required this.orderNumber,
    required this.customerName,
    required this.customerAddress,
    required this.customerPhone,
    required this.restaurantName,
    required this.restaurantAddress,
    required this.totalAmount,
    required this.orderItems,
    required this.notes,
  });

  factory AvailableOrderDto.fromJson(Map<String, dynamic> json) {
    final customer = json['customer'] as Map<String, dynamic>?;
    final restaurant = json['restaurant'] as Map<String, dynamic>?;
    final delivery = json['deliveryAddress'] as Map<String, dynamic>?;

    final street = delivery != null ? delivery['street'] as String? : null;
    final city = delivery != null ? delivery['city'] as String? : null;
    final state = delivery != null ? delivery['state'] as String? : null;
    final addressParts = <String>[
      if (street != null && street.isNotEmpty) street,
      if (city != null && city.isNotEmpty) city,
      if (state != null && state.isNotEmpty) state,
    ];

    final customerAddress = addressParts.isNotEmpty ? addressParts.join(', ') : '';

    final items = (json['items'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map((item) {
          final name = item['name']?.toString() ?? '';
          final quantity = (item['quantity'] as num?)?.toInt() ?? 0;
          if (name.isEmpty) return null;
          return quantity > 0 ? '$name x$quantity' : name;
        })
        .whereType<String>()
        .toList();

    return AvailableOrderDto(
      id: json['_id']?.toString() ?? '',
      orderNumber: json['orderNumber']?.toString() ?? '',
      customerName: customer != null ? (customer['username']?.toString() ?? 'Customer') : 'Customer',
      customerAddress: customerAddress,
      customerPhone: customer != null ? (customer['phone']?.toString() ?? '') : '',
      restaurantName: restaurant != null ? (restaurant['restaurant_name']?.toString() ?? 'Restaurant') : 'Restaurant',
      restaurantAddress: restaurant != null ? (restaurant['address']?.toString() ?? '') : '',
      totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0.0,
      orderItems: items,
      notes: json['notes']?.toString(),
    );
  }
}

class AvailableOrdersService {
  AvailableOrdersService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  String get _baseUrl => AppConfig.apiBaseUrl; // e.g. https://.../api

  Future<Map<String, String>> _buildHeaders() async {
    final headers = <String, String>{'Content-Type': 'application/json'};
    try {
      final token = await CacheService.getAuthToken();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    } catch (e) {
      debugPrint('Error getting auth token for available orders requests: $e');
    }
    return headers;
  }

  Future<List<AvailableOrderDto>> getAvailableOrders() async {
    final uri = Uri.parse('$_baseUrl/riders/available-orders');
    try {
      final response = await _client.get(uri, headers: await _buildHeaders());
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        final data = decoded['data'];
        if (data is List) {
          return data.whereType<Map<String, dynamic>>().map((e) => AvailableOrderDto.fromJson(e)).toList();
        }
        return [];
      } else {
        debugPrint('AvailableOrdersService.getAvailableOrders failed: ${response.statusCode} ${response.body}');
        return [];
      }
    } catch (e) {
      debugPrint('AvailableOrdersService.getAvailableOrders error: $e');
      return [];
    }
  }

  Future<AvailableOrderDto?> acceptOrder(String orderId) async {
    final uri = Uri.parse('$_baseUrl/riders/accept-order/$orderId');
    try {
      final response = await _client.post(uri, headers: await _buildHeaders());
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        final data = decoded['data'];
        if (data is Map<String, dynamic>) {
          return AvailableOrderDto.fromJson(data);
        }
        return null;
      } else {
        debugPrint('AvailableOrdersService.acceptOrder failed: ${response.statusCode} ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('AvailableOrdersService.acceptOrder error: $e');
      return null;
    }
  }
}
