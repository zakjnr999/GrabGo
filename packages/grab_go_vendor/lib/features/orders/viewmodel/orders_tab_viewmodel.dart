import 'package:flutter/material.dart';
import 'package:grab_go_vendor/features/orders/model/vendor_order_summary.dart';

class OrdersTabViewModel extends ChangeNotifier {
  OrdersTabViewModel() {
    searchController.addListener(_onSearchChanged);
  }

  final TextEditingController searchController = TextEditingController();
  final List<VendorOrderSummary> _orders = mockVendorOrders();

  OrderServiceType? _selectedServiceFilter;
  VendorOrderStatus? _selectedStatusFilter;
  bool _atRiskOnly = false;
  String _searchQuery = '';

  List<VendorOrderSummary> get orders {
    return _orders.where((order) {
      final matchesService =
          _selectedServiceFilter == null ||
          order.serviceType == _selectedServiceFilter;
      final matchesStatus =
          _selectedStatusFilter == null ||
          order.status == _selectedStatusFilter;
      final matchesRisk = !_atRiskOnly || order.isAtRisk;
      final search = _searchQuery.toLowerCase();
      final matchesSearch =
          search.isEmpty ||
          order.id.toLowerCase().contains(search) ||
          order.customerName.toLowerCase().contains(search);
      return matchesService && matchesStatus && matchesRisk && matchesSearch;
    }).toList();
  }

  OrderServiceType? get selectedServiceFilter => _selectedServiceFilter;
  VendorOrderStatus? get selectedStatusFilter => _selectedStatusFilter;
  bool get atRiskOnly => _atRiskOnly;

  void setServiceFilter(OrderServiceType? service) {
    if (_selectedServiceFilter == service) return;
    _selectedServiceFilter = service;
    notifyListeners();
  }

  void setStatusFilter(VendorOrderStatus? status) {
    if (_selectedStatusFilter == status) return;
    _selectedStatusFilter = status;
    notifyListeners();
  }

  void toggleAtRiskOnly() {
    _atRiskOnly = !_atRiskOnly;
    notifyListeners();
  }

  void _onSearchChanged() {
    final next = searchController.text.trim();
    if (_searchQuery == next) return;
    _searchQuery = next;
    notifyListeners();
  }

  @override
  void dispose() {
    searchController
      ..removeListener(_onSearchChanged)
      ..dispose();
    super.dispose();
  }
}
