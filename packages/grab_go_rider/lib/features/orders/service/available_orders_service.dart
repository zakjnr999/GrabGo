import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:grab_go_rider/features/orders/service/available_order_dto.dart';
import 'package:grab_go_rider/features/orders/service/order_statistics_service.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:http/http.dart' as http;

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

  Future<Map<String, dynamic>> getAvailableOrders({double? lat, double? lon, double? radius}) async {
    final queryParams = <String, String>{};
    if (lat != null) queryParams['lat'] = lat.toString();
    if (lon != null) queryParams['lon'] = lon.toString();
    if (radius != null) queryParams['radius'] = radius.toString();

    final uri = Uri.parse('$_baseUrl/riders/available-orders').replace(queryParameters: queryParams);
    debugPrint('🔍 Fetching available orders from: $uri');

    try {
      final headers = await _buildHeaders();
      debugPrint('🔍 Headers: ${headers.keys.toList()}');

      final response = await _client.get(uri, headers: headers);
      debugPrint('🔍 Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        final data = decoded['data'];

        if (data is Map<String, dynamic>) {
          final ordersList = data['orders'] as List<dynamic>? ?? [];
          final statsJson = data['statistics'] as Map<String, dynamic>?;

          final orders = ordersList.whereType<Map<String, dynamic>>().map((e) {
            final order = AvailableOrderDto.fromJson(e);
            debugPrint('📦 Parsed order ${order.orderNumber}: ${order.distance} km, GHS ${order.riderEarnings}');
            return order;
          }).toList();

          final statistics = statsJson != null ? OrderStatistics.fromJson(statsJson) : OrderStatistics.empty();

          debugPrint('✅ Parsed ${orders.length} orders');
          debugPrint('📊 Statistics: ${statistics.totalOrders} orders, GHS ${statistics.totalEarnings} total');

          return {'orders': orders, 'statistics': statistics};
        }

        if (data is List) {
          final orders = data.whereType<Map<String, dynamic>>().map((e) => AvailableOrderDto.fromJson(e)).toList();
          return {'orders': orders, 'statistics': OrderStatistics.empty()};
        }

        return {'orders': <AvailableOrderDto>[], 'statistics': OrderStatistics.empty()};
      } else {
        debugPrint('❌ AvailableOrdersService.getAvailableOrders failed: ${response.statusCode} ${response.body}');
        return {'orders': <AvailableOrderDto>[], 'statistics': OrderStatistics.empty()};
      }
    } catch (e, stack) {
      debugPrint('❌ AvailableOrdersService.getAvailableOrders error: $e');
      debugPrint('Stack: $stack');
      return {'orders': <AvailableOrderDto>[], 'statistics': OrderStatistics.empty()};
    }
  }

  /// Result class for accept order operation
  Future<AcceptOrderResult> acceptOrder(String orderId) async {
    final uri = Uri.parse('$_baseUrl/riders/accept-order/$orderId');
    try {
      debugPrint('🎯 Accepting order: $orderId');
      final response = await _client.post(uri, headers: await _buildHeaders());
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200) {
        final data = decoded['data'];
        debugPrint('🎯 Accept Order Response Data: $data');
        if (data is Map<String, dynamic>) {
          final dto = AvailableOrderDto.fromJson(data);
          return AcceptOrderResult.success(dto);
        }
        return AcceptOrderResult.error('Invalid response from server');
      } else if (response.statusCode == 409) {
        // Order is reserved by another rider
        final message = decoded['message']?.toString() ?? 'Order is reserved by another rider';
        debugPrint('⚠️ Order reserved: $message');
        return AcceptOrderResult.reserved(message);
      } else if (response.statusCode == 400) {
        // Order already assigned or not available
        final message = decoded['message']?.toString() ?? 'Order is no longer available';
        debugPrint('⚠️ Order unavailable: $message');
        return AcceptOrderResult.error(message);
      } else {
        debugPrint('❌ AvailableOrdersService.acceptOrder failed: ${response.statusCode} ${response.body}');
        return AcceptOrderResult.error(decoded['message']?.toString() ?? 'Failed to accept order');
      }
    } catch (e) {
      debugPrint('❌ AvailableOrdersService.acceptOrder error: $e');
      return AcceptOrderResult.error('Network error: $e');
    }
  }

  Future<bool> cancelOrder(String orderId, {String? reason, String? notes}) async {
    final uri = Uri.parse('$_baseUrl/riders/cancel-order/$orderId');
    try {
      debugPrint('🚫 Cancelling order: $orderId');
      final response = await _client.post(
        uri,
        headers: await _buildHeaders(),
        body: jsonEncode({'reason': reason, 'notes': notes}),
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        debugPrint('✅ Order cancelled successfully: ${decoded['message']}');
        return decoded['success'] == true;
      } else {
        debugPrint('❌ AvailableOrdersService.cancelOrder failed: ${response.statusCode} ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ AvailableOrdersService.cancelOrder error: $e');
      return false;
    }
  }
}

/// Result of an accept order operation
class AcceptOrderResult {
  final bool isSuccess;
  final bool isReserved;
  final String? errorMessage;
  final AvailableOrderDto? order;

  AcceptOrderResult._({required this.isSuccess, required this.isReserved, this.errorMessage, this.order});

  factory AcceptOrderResult.success(AvailableOrderDto order) {
    return AcceptOrderResult._(isSuccess: true, isReserved: false, order: order);
  }

  factory AcceptOrderResult.reserved(String message) {
    return AcceptOrderResult._(isSuccess: false, isReserved: true, errorMessage: message);
  }

  factory AcceptOrderResult.error(String message) {
    return AcceptOrderResult._(isSuccess: false, isReserved: false, errorMessage: message);
  }
}
