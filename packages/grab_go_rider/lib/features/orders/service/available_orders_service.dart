import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:http/http.dart' as http;

class AvailableOrderDto {
  final String id;
  final String orderNumber;
  final String customerName;
  final String customerId;
  final String customerAddress;
  final String customerPhone;
  final String restaurantName;
  final String restaurantAddress;
  final double totalAmount;
  final List<String> orderItems;
  final String? notes;

  // Coordinates for tracking initialization
  final double? destinationLatitude;
  final double? destinationLongitude;
  final double? pickupLatitude;
  final double? pickupLongitude;

  AvailableOrderDto({
    required this.id,
    required this.orderNumber,
    required this.customerName,
    required this.customerId,
    required this.customerAddress,
    required this.customerPhone,
    required this.restaurantName,
    required this.restaurantAddress,
    required this.totalAmount,
    required this.orderItems,
    required this.notes,
    this.destinationLatitude,
    this.destinationLongitude,
    this.pickupLatitude,
    this.pickupLongitude,
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

    // Extract coordinates from delivery address
    final destinationLat = delivery != null ? (delivery['latitude'] as num?)?.toDouble() : null;
    final destinationLng = delivery != null ? (delivery['longitude'] as num?)?.toDouble() : null;

    // Extract restaurant/pickup coordinates
    final restaurantLocation = restaurant?['location'] as Map<String, dynamic>?;
    double? pickupLat;
    double? pickupLng;

    debugPrint('🍕 Parsing restaurant coordinates:');
    debugPrint('   restaurant: $restaurant');
    debugPrint('   restaurantLocation: $restaurantLocation');

    if (restaurantLocation != null) {
      // GeoJSON format: coordinates [longitude, latitude]
      final coords = restaurantLocation['coordinates'] as List<dynamic>?;
      debugPrint('   coords: $coords');
      if (coords != null && coords.length >= 2) {
        pickupLng = (coords[0] as num?)?.toDouble();
        pickupLat = (coords[1] as num?)?.toDouble();
        debugPrint('   ✅ Parsed: lat=$pickupLat, lng=$pickupLng');
      }
    } else if (restaurant != null) {
      // Try direct latitude/longitude fields
      pickupLat = (restaurant['latitude'] as num?)?.toDouble();
      pickupLng = (restaurant['longitude'] as num?)?.toDouble();
      debugPrint('   📍 Direct fields: lat=$pickupLat, lng=$pickupLng');
    }

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
      customerId: customer != null ? (customer['_id']?.toString() ?? '') : '',
      customerAddress: customerAddress,
      customerPhone: customer != null ? (customer['phone']?.toString() ?? '') : '',
      // Handle both restaurant_name and restaurantName
      restaurantName: restaurant != null
          ? (restaurant['restaurantName']?.toString() ?? restaurant['restaurant_name']?.toString() ?? 'Restaurant')
          : 'Restaurant',
      restaurantAddress: restaurant != null ? (restaurant['address']?.toString() ?? '') : '',
      totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0.0,
      orderItems: items,
      notes: json['notes']?.toString(),
      destinationLatitude: destinationLat,
      destinationLongitude: destinationLng,
      pickupLatitude: pickupLat,
      pickupLongitude: pickupLng,
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
    debugPrint('🔍 Fetching available orders from: $uri');
    try {
      final headers = await _buildHeaders();
      debugPrint('🔍 Headers: ${headers.keys.toList()}');

      final response = await _client.get(uri, headers: headers);
      debugPrint('🔍 Response status: ${response.statusCode}');
      debugPrint(
        '🔍 Response body: ${response.body.substring(0, response.body.length > 500 ? 500 : response.body.length)}',
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        final data = decoded['data'];
        debugPrint('🔍 Data type: ${data.runtimeType}, length: ${data is List ? data.length : 'N/A'}');
        if (data is List) {
          final orders = data.whereType<Map<String, dynamic>>().map((e) => AvailableOrderDto.fromJson(e)).toList();
          debugPrint('✅ Parsed ${orders.length} orders');
          return orders;
        }
        return [];
      } else {
        debugPrint('❌ AvailableOrdersService.getAvailableOrders failed: ${response.statusCode} ${response.body}');
        return [];
      }
    } catch (e, stack) {
      debugPrint('❌ AvailableOrdersService.getAvailableOrders error: $e');
      debugPrint('Stack: $stack');
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
