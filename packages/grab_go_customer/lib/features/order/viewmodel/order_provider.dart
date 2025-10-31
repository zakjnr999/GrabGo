import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:grab_go_customer/shared/services/cache_service.dart';

class OrderProvider extends ChangeNotifier {
  List<Map<String, dynamic>> _orderHistory = [];
  bool _isLoading = false;
  String? _error;

  List<Map<String, dynamic>> get orderHistory => _orderHistory;
  bool get isLoading => _isLoading;
  String? get error => _error;

  OrderProvider() {
    // Load order history asynchronously without blocking
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadOrderHistory();
    });
  }

  /// Load order history from cache
  Future<void> _loadOrderHistory() async {
    try {
      _orderHistory = CacheService.getOrderHistory();
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('Error loading order history from cache: $e');
      }
    }
  }

  /// Add new order to history
  Future<void> addOrder(Map<String, dynamic> order) async {
    try {
      final success = await CacheService.addOrderToHistory(order);
      if (success) {
        await _loadOrderHistory(); // Reload from cache
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error adding order to history: $e');
      }
    }
  }

  /// Save order history to cache
  Future<void> saveOrderHistory(List<Map<String, dynamic>> orders) async {
    try {
      final success = await CacheService.saveOrderHistory(orders);
      if (success) {
        _orderHistory = orders;
        notifyListeners();
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error saving order history: $e');
      }
    }
  }

  /// Clear order history
  Future<void> clearOrderHistory() async {
    try {
      await CacheService.clearOrderHistory();
      _orderHistory = [];
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('Error clearing order history: $e');
      }
    }
  }

  /// Get orders by status
  List<Map<String, dynamic>> getOrdersByStatus(String status) {
    return _orderHistory.where((order) => order['status'] == status).toList();
  }

  /// Get recent orders (last 10)
  List<Map<String, dynamic>> getRecentOrders() {
    final sortedOrders = List<Map<String, dynamic>>.from(_orderHistory);
    sortedOrders.sort((a, b) {
      final dateA = DateTime.tryParse(a['createdAt'] ?? '') ?? DateTime(1970);
      final dateB = DateTime.tryParse(b['createdAt'] ?? '') ?? DateTime(1970);
      return dateB.compareTo(dateA);
    });
    return sortedOrders.take(10).toList();
  }

  /// Get order by ID
  Map<String, dynamic>? getOrderById(String orderId) {
    try {
      return _orderHistory.firstWhere((order) => order['id'] == orderId);
    } catch (e) {
      return null;
    }
  }

  /// Update order status
  Future<void> updateOrderStatus(String orderId, String newStatus) async {
    try {
      final orderIndex = _orderHistory.indexWhere((order) => order['id'] == orderId);
      if (orderIndex != -1) {
        _orderHistory[orderIndex]['status'] = newStatus;
        _orderHistory[orderIndex]['updatedAt'] = DateTime.now().toIso8601String();
        
        await saveOrderHistory(_orderHistory);
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error updating order status: $e');
      }
    }
  }

  /// Get order statistics
  Map<String, dynamic> getOrderStatistics() {
    final totalOrders = _orderHistory.length;
    final completedOrders = _orderHistory.where((order) => order['status'] == 'completed').length;
    final pendingOrders = _orderHistory.where((order) => order['status'] == 'pending').length;
    final cancelledOrders = _orderHistory.where((order) => order['status'] == 'cancelled').length;
    
    double totalSpent = 0.0;
    for (var order in _orderHistory) {
      if (order['status'] == 'completed') {
        totalSpent += (order['total'] ?? 0.0).toDouble();
      }
    }

    return {
      'totalOrders': totalOrders,
      'completedOrders': completedOrders,
      'pendingOrders': pendingOrders,
      'cancelledOrders': cancelledOrders,
      'totalSpent': totalSpent,
      'averageOrderValue': totalOrders > 0 ? totalSpent / totalOrders : 0.0,
    };
  }
}

