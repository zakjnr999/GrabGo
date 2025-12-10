import 'package:flutter/foundation.dart';
import 'package:grab_go_customer/features/order/service/order_service_wrapper.dart';
import 'package:grab_go_customer/shared/services/user_service.dart';
import 'package:grab_go_shared/shared/services/cache_service.dart';

class OrderProvider extends ChangeNotifier {
  List<Map<String, dynamic>> _orders = [];
  bool _isLoading = false;
  String? _error;

  List<Map<String, dynamic>> get orders => _orders;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetchOrders({bool forceRefresh = false}) async {
    // Check authentication first
    final userService = UserService();
    final token = await CacheService.getAuthToken();

    if (!userService.isLoggedIn) {
      _error = 'Please log in to view your orders';
      _isLoading = false;
      notifyListeners();
      return;
    }

    if (token == null || token.isEmpty) {
      _error = 'Authentication required. Please log in again.';
      _isLoading = false;
      notifyListeners();
      return;
    }

    // Don't fetch if already loading or if we have orders (unless force refresh)
    if (!forceRefresh && (_orders.isNotEmpty || _isLoading)) {
      if (kDebugMode) {
        print('⏭️ Skipping fetch: orders=${_orders.isNotEmpty}, loading=$_isLoading');
      }
      return;
    }

    // If force refresh, clear cache first
    if (forceRefresh) {
      try {
        await CacheService.clearOrderHistory();
        _orders = [];
      } catch (e) {
        if (kDebugMode) {
          print('Error clearing cache for force refresh: $e');
        }
      }
    }

    // Load from cache first for instant display (same pattern as other features)
    bool cacheLoaded = false;
    if (!forceRefresh && _orders.isEmpty) {
      if (kDebugMode) {
        print('📦 Attempting to load orders from cache...');
      }
      try {
        _loadOrdersFromCache();
        if (_orders.isNotEmpty) {
          cacheLoaded = true;
          if (kDebugMode) {
            print('✅ Loaded ${_orders.length} orders from cache');
          }
          notifyListeners();
          // Fetch fresh data in background without showing loading state
          _fetchOrdersInBackground();
        }
      } catch (e) {
        if (kDebugMode) {
          print('❌ Error loading from cache: $e');
        }
        _orders = [];
      }
    }

    // If cache loading failed or returned empty, fetch from API
    if (!cacheLoaded && _orders.isEmpty) {
      if (kDebugMode) {
        print('🔄 Fetching orders from API...');
      }
      _isLoading = true;
      _error = null;
      notifyListeners();

      try {
        final orderService = OrderServiceWrapper();
        _orders = await orderService.getUserOrders();

        if (kDebugMode) {
          print('✅ Loaded ${_orders.length} orders from API');
        }

        // Save to cache asynchronously without blocking
        _saveOrdersToCacheAsync();
      } catch (e) {
        String errorMessage = 'Error fetching orders';
        if (e.toString().contains('SocketException') || e.toString().contains('Failed host lookup')) {
          errorMessage = 'Cannot connect to server. Please check your internet connection or try again later.';
        } else if (e.toString().contains('TimeoutException')) {
          errorMessage = 'Request timed out. Please try again.';
        } else if (e.toString().contains('authentication') || e.toString().contains('token')) {
          errorMessage = 'Authentication error. Please log in again.';
        } else {
          errorMessage = 'Error fetching orders: ${e.toString()}';
        }
        _error = errorMessage;
        if (kDebugMode) {
          print('❌ Order fetch error: $e');
        }
        if (_orders.isEmpty) {
          _orders = [];
        }
      } finally {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  /// Fetch orders in background without showing loading state
  Future<void> _fetchOrdersInBackground() async {
    try {
      if (kDebugMode) {
        print('🔄 Fetching fresh orders in background...');
      }
      final orderService = OrderServiceWrapper();
      final freshOrders = await orderService.getUserOrders();

      if (freshOrders.isNotEmpty) {
        _orders = freshOrders;
        if (kDebugMode) {
          print('✅ Updated ${_orders.length} orders from background fetch');
        }
        _saveOrdersToCacheAsync();
        notifyListeners();
      }
    } catch (e) {
      if (kDebugMode) {
        print('Background order fetch error (ignored): $e');
      }
    }
  }

  Future<void> refreshOrders() async {
    // Check authentication first
    final userService = UserService();
    if (!userService.isLoggedIn) {
      if (kDebugMode) {
        print('❌ User not logged in, cannot refresh orders');
      }
      _error = 'Please log in to view your orders';
      notifyListeners();
      return;
    }

    final token = await CacheService.getAuthToken();
    if (token == null || token.isEmpty) {
      if (kDebugMode) {
        print('❌ No authentication token found for refresh');
      }
      _error = 'Authentication required. Please log in again.';
      notifyListeners();
      return;
    }

    _isLoading = true;
    _error = null;
    _orders = [];
    try {
      await CacheService.clearOrderHistory();
    } catch (e) {
      if (kDebugMode) {
        print('Error clearing order cache: $e');
      }
    }
    notifyListeners();

    try {
      if (kDebugMode) {
        print('🔄 Refreshing orders...');
      }
      final orderService = OrderServiceWrapper();
      _orders = await orderService.getUserOrders();

      if (kDebugMode) {
        print('✅ Refreshed ${_orders.length} orders');
      }

      _saveOrdersToCacheAsync();
    } catch (e) {
      String errorMessage = 'Error refreshing orders';
      if (e.toString().contains('SocketException') || e.toString().contains('Failed host lookup')) {
        errorMessage = 'Cannot connect to server. Please check your internet connection or try again later.';
      } else if (e.toString().contains('TimeoutException')) {
        errorMessage = 'Request timed out. Please try again.';
      } else if (e.toString().contains('authentication') || e.toString().contains('token')) {
        errorMessage = 'Authentication error. Please log in again.';
      } else {
        errorMessage = 'Error refreshing orders: ${e.toString()}';
      }
      _error = errorMessage;
      if (kDebugMode) {
        print('Order refresh error: $e');
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _loadOrdersFromCache() {
    try {
      final cachedOrders = CacheService.getOrderHistory();
      if (kDebugMode) {
        print('📦 Cache contains ${cachedOrders.length} orders');
      }
      _orders = cachedOrders;
      if (kDebugMode) {
        print('✅ Successfully loaded ${_orders.length} orders from cache');
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('❌ Error loading orders from cache: $e');
        print('Stack trace: $stackTrace');
      }
      _orders = [];
      rethrow;
    }
  }

  void _saveOrdersToCacheAsync() {
    Future.microtask(() async {
      try {
        await CacheService.saveOrderHistory(_orders);
        if (kDebugMode) {
          print('✅ Saved ${_orders.length} orders to cache');
        }
      } catch (e) {
        if (kDebugMode) {
          print('Error saving orders to cache: $e');
        }
      }
    });
  }

  /// Add new order to history
  void addOrder(Map<String, dynamic> order) {
    _orders.insert(0, order); // Add to beginning (most recent first)
    notifyListeners();

    // Save to cache
    CacheService.addOrderToHistory(order);
  }

  /// Save order history to cache
  Future<void> saveOrderHistory(List<Map<String, dynamic>> orders) async {
    try {
      final success = await CacheService.saveOrderHistory(orders);
      if (success) {
        _orders = orders;
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
      _orders = [];
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('Error clearing order history: $e');
      }
    }
  }

  /// Get orders by status
  List<Map<String, dynamic>> getOrdersByStatus(String status) {
    return _orders.where((order) {
      final orderStatus = (order['status'] as String? ?? '').toLowerCase();
      switch (status.toLowerCase()) {
        case 'pending':
          return orderStatus == 'pending';
        case 'ongoing':
          return ['confirmed', 'preparing', 'ready', 'picked_up', 'on_the_way'].contains(orderStatus);
        case 'completed':
          return orderStatus == 'delivered';
        case 'cancelled':
          return orderStatus == 'cancelled';
        default:
          return true;
      }
    }).toList();
  }

  void clearOrders() {
    _orders = [];
    _error = null;
    notifyListeners();
  }

  /// Get recent orders (last 10)
  List<Map<String, dynamic>> getRecentOrders() {
    final sortedOrders = List<Map<String, dynamic>>.from(_orders);
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
      return _orders.firstWhere((order) => order['id'] == orderId);
    } catch (e) {
      return null;
    }
  }

  /// Update order status
  Future<void> updateOrderStatus(String orderId, String newStatus) async {
    try {
      final orderIndex = _orders.indexWhere((order) => order['id'] == orderId);
      if (orderIndex != -1) {
        _orders[orderIndex]['status'] = newStatus;
        _orders[orderIndex]['updatedAt'] = DateTime.now().toIso8601String();

        await saveOrderHistory(_orders);
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error updating order status: $e');
      }
    }
  }

  /// Get order statistics
  Map<String, dynamic> getOrderStatistics() {
    final totalOrders = _orders.length;
    final completedOrders = _orders.where((order) => order['status'] == 'completed').length;
    final pendingOrders = _orders.where((order) => order['status'] == 'pending').length;
    final cancelledOrders = _orders.where((order) => order['status'] == 'cancelled').length;

    double totalSpent = 0.0;
    for (var order in _orders) {
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
