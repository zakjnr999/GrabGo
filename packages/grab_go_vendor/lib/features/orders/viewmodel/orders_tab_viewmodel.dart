import 'package:flutter/material.dart';
import 'package:grab_go_vendor/features/orders/model/vendor_order_summary.dart';

enum VendorOrderPreviewPrimaryAction {
  accept,
  markReady,
  verifyPickupCode,
  waitingForRider,
  openDetails,
}

extension VendorOrderPreviewPrimaryActionX on VendorOrderPreviewPrimaryAction {
  String get label {
    return switch (this) {
      VendorOrderPreviewPrimaryAction.accept => 'Accept Order',
      VendorOrderPreviewPrimaryAction.markReady => 'Mark Ready',
      VendorOrderPreviewPrimaryAction.verifyPickupCode => 'Verify Pickup Code',
      VendorOrderPreviewPrimaryAction.waitingForRider => 'Waiting for Rider',
      VendorOrderPreviewPrimaryAction.openDetails => 'Open Full Details',
    };
  }

  bool get isActionable {
    return switch (this) {
      VendorOrderPreviewPrimaryAction.accept ||
      VendorOrderPreviewPrimaryAction.markReady ||
      VendorOrderPreviewPrimaryAction.verifyPickupCode => true,
      VendorOrderPreviewPrimaryAction.waitingForRider ||
      VendorOrderPreviewPrimaryAction.openDetails => false,
    };
  }
}

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

  VendorOrderPreviewPrimaryAction primaryActionFor(VendorOrderSummary order) {
    if (order.status == VendorOrderStatus.newOrder) {
      return VendorOrderPreviewPrimaryAction.accept;
    }
    if (order.status == VendorOrderStatus.accepted ||
        order.status == VendorOrderStatus.preparing) {
      return VendorOrderPreviewPrimaryAction.markReady;
    }
    if (order.isPickupOrder && order.status == VendorOrderStatus.ready) {
      return VendorOrderPreviewPrimaryAction.verifyPickupCode;
    }
    if (!order.isPickupOrder && order.status == VendorOrderStatus.ready) {
      return VendorOrderPreviewPrimaryAction.waitingForRider;
    }
    return VendorOrderPreviewPrimaryAction.openDetails;
  }

  bool runPrimaryAction(
    String orderId,
    VendorOrderPreviewPrimaryAction action,
  ) {
    return switch (action) {
      VendorOrderPreviewPrimaryAction.accept => _setOrderStatus(
        orderId,
        fromStatus: VendorOrderStatus.newOrder,
        toStatus: VendorOrderStatus.preparing,
        action: 'Accept',
        details: 'Order confirmed and moved to preparing from order preview.',
      ),
      VendorOrderPreviewPrimaryAction.markReady => _setOrderStatus(
        orderId,
        fromStatus: null,
        toStatus: VendorOrderStatus.ready,
        action: 'Mark ready',
        details: 'Order moved to ready queue from order preview.',
      ),
      VendorOrderPreviewPrimaryAction.verifyPickupCode => false,
      VendorOrderPreviewPrimaryAction.waitingForRider => false,
      VendorOrderPreviewPrimaryAction.openDetails => false,
    };
  }

  bool _setOrderStatus(
    String orderId, {
    required VendorOrderStatus? fromStatus,
    required VendorOrderStatus toStatus,
    required String action,
    required String details,
  }) {
    final index = _orders.indexWhere((order) => order.id == orderId);
    if (index < 0) return false;
    final order = _orders[index];
    if (fromStatus != null) {
      if (order.status != fromStatus) return false;
    } else {
      final canMarkReady =
          order.status == VendorOrderStatus.accepted ||
          order.status == VendorOrderStatus.preparing;
      if (!canMarkReady) return false;
    }

    _orders[index] = order.copyWith(
      status: toStatus,
      isAtRisk: false,
      auditEntries: [
        VendorOrderAuditEntry(
          action: action,
          actor: 'Vendor Team',
          timeLabel: 'Now',
          details: details,
        ),
        ...order.auditEntries,
      ],
    );
    notifyListeners();
    return true;
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
