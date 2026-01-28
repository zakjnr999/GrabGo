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
  final String customerArea; // For card display
  final String customerPhone;
  final String restaurantName;
  final String restaurantAddress;
  final double totalAmount;
  final List<String> orderItems;
  final String? notes;
  final String orderStatus; // confirmed, preparing, ready
  final String paymentMethod; // cash, card, mobile_money
  final String? orderType; // food, grocery, pharmacy
  final int itemCount;
  final DateTime? createdAt;
  final double? distance; // Distance in km
  final double? riderEarnings; // What the rider will earn

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
    required this.customerArea,
    required this.customerPhone,
    required this.restaurantName,
    required this.restaurantAddress,
    required this.totalAmount,
    required this.orderItems,
    required this.notes,
    required this.orderStatus,
    required this.paymentMethod,
    this.orderType,
    required this.itemCount,
    this.createdAt,
    this.distance,
    this.riderEarnings,
    this.destinationLatitude,
    this.destinationLongitude,
    this.pickupLatitude,
    this.pickupLongitude,
  });

  factory AvailableOrderDto.fromJson(Map<String, dynamic> json) {
    final customer = json['customer'] as Map<String, dynamic>?;
    final restaurant = json['restaurant'] as Map<String, dynamic>?;
    final groceryStore = json['groceryStore'] as Map<String, dynamic>?;
    final pharmacyStore = json['pharmacyStore'] as Map<String, dynamic>?;

    // Parse delivery address from top-level fields (not nested)
    final street = json['deliveryStreet']?.toString();
    final city = json['deliveryCity']?.toString();
    final state = json['deliveryState']?.toString();

    final addressParts = <String>[
      if (street != null && street.isNotEmpty) street,
      if (city != null && city.isNotEmpty) city,
      if (state != null && state.isNotEmpty) state,
    ];

    final customerAddress = addressParts.isNotEmpty ? addressParts.join(', ') : '';

    // Extract coordinates from delivery address
    final destinationLat = (json['deliveryLatitude'] as num?)?.toDouble();
    final destinationLng = (json['deliveryLongitude'] as num?)?.toDouble();

    // Extract pickup coordinates (restaurant, grocery, or pharmacy)
    double? pickupLat;
    double? pickupLng;

    if (restaurant != null) {
      pickupLat = (restaurant['latitude'] as num?)?.toDouble();
      pickupLng = (restaurant['longitude'] as num?)?.toDouble();
    } else if (groceryStore != null) {
      pickupLat = (groceryStore['latitude'] as num?)?.toDouble();
      pickupLng = (groceryStore['longitude'] as num?)?.toDouble();
    } else if (pharmacyStore != null) {
      pickupLat = (pharmacyStore['latitude'] as num?)?.toDouble();
      pickupLng = (pharmacyStore['longitude'] as num?)?.toDouble();
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

    // Extract customer area (use street for specific location, fallback to city)
    final customerArea = street?.isNotEmpty == true ? street! : (city ?? state ?? 'Unknown Area');

    // Parse createdAt
    DateTime? createdAt;
    if (json['createdAt'] != null) {
      try {
        createdAt = DateTime.parse(json['createdAt'].toString());
      } catch (e) {
        debugPrint('Failed to parse createdAt: $e');
      }
    }

    // Extract store name based on order type
    String storeName = 'Store';
    if (restaurant != null) {
      storeName = restaurant['restaurantName']?.toString() ?? 'Restaurant';
    } else if (groceryStore != null) {
      storeName = groceryStore['storeName']?.toString() ?? 'Grocery Store';
    } else if (pharmacyStore != null) {
      storeName = pharmacyStore['storeName']?.toString() ?? 'Pharmacy';
    }

    return AvailableOrderDto(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      orderNumber: json['orderNumber']?.toString() ?? '',
      customerName: customer != null ? (customer['username']?.toString() ?? 'Customer') : 'Customer',
      customerId: customer != null ? (customer['id']?.toString() ?? customer['_id']?.toString() ?? '') : '',
      customerAddress: customerAddress,
      customerArea: customerArea,
      customerPhone: customer != null ? (customer['phone']?.toString() ?? '') : '',
      restaurantName: storeName,
      restaurantAddress: restaurant?['address']?.toString() ?? 
                        groceryStore?['address']?.toString() ?? 
                        pharmacyStore?['address']?.toString() ?? '',
      totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0.0,
      orderItems: items,
      itemCount: items.length,
      notes: json['notes']?.toString(),
      orderStatus: json['status']?.toString() ?? 'confirmed',
      paymentMethod: json['paymentMethod']?.toString() ?? 'cash',
      orderType: json['orderType']?.toString() ?? json['type']?.toString(),
      createdAt: createdAt,
      distance: (json['distance'] as num?)?.toDouble(),
      riderEarnings: (json['riderEarnings'] as num?)?.toDouble(),
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

  String get _baseUrl => AppConfig.apiBaseUrl;

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
          final orders = data.whereType<Map<String, dynamic>>().map((e) {
            final order = AvailableOrderDto.fromJson(e);
            debugPrint('📦 Parsed order ${order.orderNumber}:');
            debugPrint('   Distance: ${order.distance} km');
            debugPrint('   Rider Earnings: GHS ${order.riderEarnings}');
            debugPrint('   Raw JSON distance: ${e['distance']}');
            debugPrint('   Raw JSON riderEarnings: ${e['riderEarnings']}');
            return order;
          }).toList();
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
