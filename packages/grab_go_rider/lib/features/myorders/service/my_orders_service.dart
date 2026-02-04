import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:grab_go_rider/features/orders/service/available_order_dto.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:http/http.dart' as http;

/// Service for fetching rider's own orders (ongoing, completed, cancelled)
class MyOrdersService {
  MyOrdersService({http.Client? client}) : _client = client ?? http.Client();

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
      debugPrint('Error getting auth token: $e');
    }
    return headers;
  }

  /// Fetch ongoing orders (assigned to rider, not yet delivered/cancelled)
  Future<List<AvailableOrderDto>> getOngoingOrders() async {
    return _fetchOrdersByStatus(['confirmed', 'preparing', 'ready', 'picked_up', 'on_the_way']);
  }

  /// Fetch completed (delivered) orders
  Future<List<AvailableOrderDto>> getCompletedOrders() async {
    return _fetchOrdersByStatus(['delivered']);
  }

  /// Fetch cancelled orders
  Future<List<AvailableOrderDto>> getCancelledOrders() async {
    return _fetchOrdersByStatus(['cancelled']);
  }

  /// Fetch orders by status(es)
  Future<List<AvailableOrderDto>> _fetchOrdersByStatus(List<String> statuses) async {
    final uri = Uri.parse('$_baseUrl/orders');
    debugPrint('🔍 Fetching rider orders: $uri');

    try {
      final headers = await _buildHeaders();
      final response = await _client.get(uri, headers: headers);

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        final data = decoded['data'] as List<dynamic>? ?? [];

        // Filter by status and map to DTO
        final orders = data
            .whereType<Map<String, dynamic>>()
            .where((o) => statuses.contains(o['status']))
            .map((o) => _mapOrderToDto(o))
            .toList();

        debugPrint('✅ Fetched ${orders.length} orders with statuses: $statuses');
        return orders;
      } else {
        debugPrint('❌ Failed to fetch orders: ${response.statusCode}');
        return [];
      }
    } catch (e, stack) {
      debugPrint('❌ Error fetching orders: $e');
      debugPrint('Stack: $stack');
      return [];
    }
  }

  /// Map backend order response to AvailableOrderDto
  AvailableOrderDto _mapOrderToDto(Map<String, dynamic> order) {
    final items = order['items'] as List<dynamic>? ?? [];
    final restaurant = order['restaurant'] as Map<String, dynamic>?;
    final groceryStore = order['groceryStore'] as Map<String, dynamic>?;
    final pharmacyStore = order['pharmacyStore'] as Map<String, dynamic>?;
    final customer = order['customer'] as Map<String, dynamic>? ?? {};

    // Extract item names
    final orderItems = items.map((item) {
      final food = item['food'] as Map<String, dynamic>?;
      final groceryItem = item['groceryItem'] as Map<String, dynamic>?;
      final pharmacyItem = item['pharmacyItem'] as Map<String, dynamic>?;
      final quantity = item['quantity'] ?? 1;

      String name = 'Item';
      if (food != null) {
        name = food['foodName'] ?? food['name'] ?? 'Food item';
      } else if (groceryItem != null) {
        name = groceryItem['name'] ?? 'Grocery item';
      } else if (pharmacyItem != null) {
        name = pharmacyItem['name'] ?? 'Pharmacy item';
      }

      return '$name x$quantity';
    }).toList();

    // Get store details (restaurant, grocery, or pharmacy)
    final storeName =
        restaurant?['restaurantName'] ?? groceryStore?['storeName'] ?? pharmacyStore?['storeName'] ?? 'Store';
    final storeAddress =
        restaurant?['address'] ??
        restaurant?['location'] ??
        groceryStore?['address'] ??
        pharmacyStore?['address'] ??
        '';
    final storeLogo = restaurant?['logo'] ?? groceryStore?['logo'] ?? pharmacyStore?['logo'];
    final pickupLat = (restaurant?['latitude'] ?? groceryStore?['latitude'] ?? pharmacyStore?['latitude']) as num?;
    final pickupLon = (restaurant?['longitude'] ?? groceryStore?['longitude'] ?? pharmacyStore?['longitude']) as num?;

    // Build delivery address
    final street = order['deliveryStreet']?.toString() ?? '';
    final city = order['deliveryCity']?.toString() ?? '';
    final state = order['deliveryState']?.toString() ?? '';
    final deliveryAddress = [street, city, state].where((s) => s.isNotEmpty).join(', ');
    final finalAddress = deliveryAddress.isNotEmpty ? deliveryAddress : (order['deliveryAddress']?.toString() ?? '');

    // Get rider earnings from backend (or calculate fallback)
    final totalAmount = (order['totalAmount'] as num?)?.toDouble() ?? 0.0;
    final riderEarnings = (order['riderEarnings'] as num?)?.toDouble() ?? (totalAmount * 0.12) + 2.0;

    return AvailableOrderDto(
      id: order['id']?.toString() ?? '',
      orderNumber: order['orderNumber']?.toString() ?? '',
      customerName: customer['username']?.toString() ?? 'Customer',
      customerId: order['customerId']?.toString() ?? customer['id']?.toString() ?? '',
      riderId: order['riderId']?.toString(),
      customerAddress: finalAddress,
      customerArea: city,
      customerPhone: customer['phone']?.toString() ?? '',
      customerPhoto: customer['profilePicture']?.toString(),
      restaurantName: storeName,
      restaurantAddress: storeAddress,
      restaurantLogo: storeLogo?.toString(),
      totalAmount: totalAmount,
      orderItems: orderItems.cast<String>(),
      itemCount: items.length,
      orderStatus: order['status']?.toString() ?? 'unknown',
      orderType: order['orderType']?.toString(),
      paymentMethod: order['paymentMethod']?.toString() ?? 'cash',
      riderEarnings: riderEarnings,
      distance: (order['distance'] as num?)?.toDouble(),
      createdAt: order['createdAt'] != null ? DateTime.tryParse(order['createdAt'].toString()) : DateTime.now(),
      notes: order['notes']?.toString(),
      pickupLatitude: pickupLat?.toDouble(),
      pickupLongitude: pickupLon?.toDouble(),
      destinationLatitude: (order['deliveryLatitude'] as num?)?.toDouble(),
      destinationLongitude: (order['deliveryLongitude'] as num?)?.toDouble(),
    );
  }
}
