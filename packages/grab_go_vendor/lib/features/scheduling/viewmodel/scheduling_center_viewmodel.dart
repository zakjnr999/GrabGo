import 'package:flutter/material.dart';
import 'package:grab_go_vendor/features/auth/model/vendor_service_option.dart';
import 'package:grab_go_vendor/features/scheduling/model/vendor_scheduling_models.dart';

class SchedulingCenterViewModel extends ChangeNotifier {
  SchedulingCenterViewModel() {
    searchController.addListener(_handleSearchChanged);
  }

  final TextEditingController searchController = TextEditingController();

  final List<VendorScheduledOrder> _scheduledOrders = mockScheduledOrders();
  final List<VendorTimeSlotCapacity> _slotCapacities = mockTimeSlotCapacities();
  final List<VendorCutoffRule> _cutoffRules = mockCutoffRules();

  VendorServiceType? _serviceFilter;
  bool _tomorrowOnly = false;

  VendorServiceType? get serviceFilter => _serviceFilter;
  bool get tomorrowOnly => _tomorrowOnly;
  List<VendorTimeSlotCapacity> get slotCapacities =>
      List.unmodifiable(_slotCapacities);

  List<VendorCutoffRule> cutoffRules(Set<VendorServiceType> visibleServices) {
    return _cutoffRules
        .where((rule) => visibleServices.contains(rule.serviceType))
        .toList();
  }

  List<VendorScheduledOrder> filteredOrders(
    Set<VendorServiceType> visibleServices,
  ) {
    final query = searchController.text.trim().toLowerCase();
    return _scheduledOrders.where((order) {
      if (!visibleServices.contains(order.serviceType)) {
        return false;
      }
      if (_serviceFilter != null && order.serviceType != _serviceFilter) {
        return false;
      }
      if (_tomorrowOnly &&
          !order.slotLabel.toLowerCase().contains('tomorrow')) {
        return false;
      }
      if (query.isNotEmpty) {
        final haystack = '${order.id} ${order.customerName} ${order.slotLabel}'
            .toLowerCase();
        if (!haystack.contains(query)) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  void setServiceFilter(VendorServiceType? serviceType) {
    if (_serviceFilter == serviceType) {
      return;
    }
    _serviceFilter = serviceType;
    notifyListeners();
  }

  void toggleTomorrowOnly() {
    _tomorrowOnly = !_tomorrowOnly;
    notifyListeners();
  }

  void updateSlotCapacity(String slotId, int nextCapacity) {
    final index = _slotCapacities.indexWhere((slot) => slot.id == slotId);
    if (index < 0) {
      return;
    }
    final current = _slotCapacities[index];
    final safeCapacity = nextCapacity.clamp(1, 60);
    final safeBooked = current.booked > safeCapacity
        ? safeCapacity
        : current.booked;
    _slotCapacities[index] = current.copyWith(
      capacity: safeCapacity,
      booked: safeBooked,
      status: _deriveStatus(safeBooked, safeCapacity, current.status),
    );
    notifyListeners();
  }

  void toggleSlotPause(String slotId) {
    final index = _slotCapacities.indexWhere((slot) => slot.id == slotId);
    if (index < 0) {
      return;
    }
    final current = _slotCapacities[index];
    final nextStatus = current.status == VendorCapacityStatus.paused
        ? _deriveStatus(current.booked, current.capacity, current.status)
        : VendorCapacityStatus.paused;
    _slotCapacities[index] = current.copyWith(status: nextStatus);
    notifyListeners();
  }

  void setCutoffMinutes(String ruleId, int minutes) {
    final index = _cutoffRules.indexWhere((rule) => rule.id == ruleId);
    if (index < 0) {
      return;
    }
    _cutoffRules[index] = _cutoffRules[index].copyWith(
      cutoffMinutes: minutes.clamp(10, 180),
    );
    notifyListeners();
  }

  void setSameDayEnabled(String ruleId, bool enabled) {
    final index = _cutoffRules.indexWhere((rule) => rule.id == ruleId);
    if (index < 0) {
      return;
    }
    _cutoffRules[index] = _cutoffRules[index].copyWith(sameDayEnabled: enabled);
    notifyListeners();
  }

  VendorCapacityStatus _deriveStatus(
    int booked,
    int capacity,
    VendorCapacityStatus current,
  ) {
    if (current == VendorCapacityStatus.paused) {
      return VendorCapacityStatus.available;
    }
    if (booked >= capacity) {
      return VendorCapacityStatus.full;
    }
    if (capacity == 0) {
      return VendorCapacityStatus.available;
    }
    final ratio = booked / capacity;
    if (ratio >= 0.8) {
      return VendorCapacityStatus.nearCapacity;
    }
    return VendorCapacityStatus.available;
  }

  void _handleSearchChanged() => notifyListeners();

  @override
  void dispose() {
    searchController.removeListener(_handleSearchChanged);
    searchController.dispose();
    super.dispose();
  }
}
