import 'package:flutter/foundation.dart';
import 'package:grab_go_admin/features/orders/model/order_response.dart';
import 'package:grab_go_admin/features/orders/services/order_service.dart';
import 'package:grab_go_admin/core/api/api_client.dart';

class OrderProvider extends ChangeNotifier {
  final OrderService _orderService = orderService;
  
  List<OrderData> _allOrders = [];
  bool _isLoading = false;
  String? _error;

  List<OrderData> get allOrders => _allOrders;
  bool get isLoading => _isLoading;
  String? get error => _error;

  List<OrderData> get pendingOrders => _allOrders.where((order) => order.status == 'pending').toList();
  List<OrderData> get confirmedOrders => _allOrders.where((order) => order.status == 'confirmed').toList();
  List<OrderData> get preparingOrders => _allOrders.where((order) => order.status == 'preparing').toList();
  List<OrderData> get readyOrders => _allOrders.where((order) => order.status == 'ready').toList();
  List<OrderData> get pickedUpOrders => _allOrders.where((order) => order.status == 'picked_up').toList();
  List<OrderData> get onTheWayOrders => _allOrders.where((order) => order.status == 'on_the_way').toList();
  List<OrderData> get deliveredOrders => _allOrders.where((order) => order.status == 'delivered').toList();
  List<OrderData> get cancelledOrders => _allOrders.where((order) => order.status == 'cancelled').toList();

  Future<void> fetchOrders() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _orderService.getOrders();
      
      if (response.isSuccessful && response.body != null) {
        _allOrders = response.body!.data;
        _error = null;
      } else {
        _error = 'Failed to fetch orders: ${response.error}';
      }
    } catch (e) {
      _error = 'Error fetching orders: $e';
      print('Error fetching orders: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateOrderStatus(String orderId, String newStatus, {String? cancellationReason}) async {
    try {
      final body = <String, dynamic>{
        'status': newStatus,
      };
      
      if (cancellationReason != null) {
        body['cancellationReason'] = cancellationReason;
      }

      final response = await _orderService.updateOrderStatus(orderId, body);
      
      if (response.isSuccessful) {
        // Update the local order list
        final orderIndex = _allOrders.indexWhere((order) => order.id == orderId);
        if (orderIndex != -1) {
          // Refresh orders to get updated data
          await fetchOrders();
        }
        return true;
      } else {
        _error = 'Failed to update order status: ${response.error}';
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = 'Error updating order status: $e';
      print('Error updating order status: $e');
      notifyListeners();
      return false;
    }
  }

  Future<bool> assignRider(String orderId, String riderId) async {
    try {
      final response = await _orderService.assignRider(orderId, {'riderId': riderId});
      
      if (response.isSuccessful) {
        // Refresh orders to get updated data
        await fetchOrders();
        return true;
      } else {
        _error = 'Failed to assign rider: ${response.error}';
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = 'Error assigning rider: $e';
      print('Error assigning rider: $e');
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}