import 'package:flutter/material.dart';
import 'package:grab_go_vendor/features/auth/model/vendor_service_option.dart';

class VendorStoreOperationsViewModel extends ChangeNotifier {
  bool _isStoreOpen = true;
  bool _acceptsOrders = true;
  bool _isPaused = false;
  String? _pauseReason;
  DateTime? _autoResumeAt;

  int _prepTimeMinutes = 20;
  bool _pickupEnabled = true;
  bool _deliveryEnabled = true;
  bool _autoAcceptOrders = false;

  final Map<VendorServiceType, bool> _serviceEnabled = {
    VendorServiceType.food: true,
    VendorServiceType.grocery: true,
    VendorServiceType.pharmacy: true,
    VendorServiceType.grabMart: true,
  };

  bool get isStoreOpen => _isStoreOpen;
  bool get acceptsOrders => _acceptsOrders;
  bool get isPaused => _isPaused;
  String? get pauseReason => _pauseReason;
  DateTime? get autoResumeAt => _autoResumeAt;
  int get prepTimeMinutes => _prepTimeMinutes;
  bool get pickupEnabled => _pickupEnabled;
  bool get deliveryEnabled => _deliveryEnabled;
  bool get autoAcceptOrders => _autoAcceptOrders;

  bool isServiceEnabled(VendorServiceType serviceType) {
    return _serviceEnabled[serviceType] ?? false;
  }

  bool get hasOutage {
    return _isPaused ||
        !_isStoreOpen ||
        !_acceptsOrders ||
        _serviceEnabled.values.every((enabled) => !enabled);
  }

  String get outageHeadline {
    if (_isPaused) return 'Store is temporarily paused';
    if (!_isStoreOpen) return 'Store is currently closed';
    if (!_acceptsOrders) return 'New orders are paused';
    if (_serviceEnabled.values.every((enabled) => !enabled)) {
      return 'All services are currently disabled';
    }
    return 'Outage control active';
  }

  String get outageDetail {
    if (_isPaused) {
      final reason = (_pauseReason ?? '').trim().isEmpty
          ? 'No reason provided'
          : _pauseReason!;
      final resume = _autoResumeAt == null
          ? 'Manual resume required'
          : 'Auto-resume: ${_formatDateTime(_autoResumeAt!)}';
      return '$reason • $resume';
    }
    if (!_isStoreOpen) {
      return 'Store must be reopened before operations continue.';
    }
    if (!_acceptsOrders) {
      return 'Orders are blocked until accepting orders is enabled.';
    }
    return 'Enable at least one service to accept new orders.';
  }

  void setStoreOpen(bool value) {
    if (_isStoreOpen == value) return;
    _isStoreOpen = value;
    if (!value) {
      _acceptsOrders = false;
    }
    notifyListeners();
  }

  void setAcceptsOrders(bool value) {
    if (_acceptsOrders == value) return;
    _acceptsOrders = value;
    if (value && !_isStoreOpen) {
      _isStoreOpen = true;
    }
    notifyListeners();
  }

  void setServiceEnabled(VendorServiceType serviceType, bool value) {
    if ((_serviceEnabled[serviceType] ?? false) == value) return;
    _serviceEnabled[serviceType] = value;
    notifyListeners();
  }

  void setPrepTimeMinutes(int value) {
    final sanitized = value.clamp(10, 90);
    if (_prepTimeMinutes == sanitized) return;
    _prepTimeMinutes = sanitized;
    notifyListeners();
  }

  void setPickupEnabled(bool value) {
    if (_pickupEnabled == value) return;
    _pickupEnabled = value;
    notifyListeners();
  }

  void setDeliveryEnabled(bool value) {
    if (_deliveryEnabled == value) return;
    _deliveryEnabled = value;
    notifyListeners();
  }

  void setAutoAcceptOrders(bool value) {
    if (_autoAcceptOrders == value) return;
    _autoAcceptOrders = value;
    notifyListeners();
  }

  void pauseStore({required String reason, Duration? autoResumeAfter}) {
    final trimmedReason = reason.trim();
    if (trimmedReason.isEmpty) return;
    _isPaused = true;
    _pauseReason = trimmedReason;
    _autoResumeAt = autoResumeAfter == null
        ? null
        : DateTime.now().add(autoResumeAfter);
    _acceptsOrders = false;
    notifyListeners();
  }

  void resumeStore() {
    if (!_isPaused) return;
    _isPaused = false;
    _pauseReason = null;
    _autoResumeAt = null;
    _acceptsOrders = true;
    notifyListeners();
  }

  String autoResumeLabel() {
    final value = _autoResumeAt;
    if (value == null) return 'No auto-resume';
    return _formatDateTime(value);
  }

  String _formatDateTime(DateTime value) {
    final hour = value.hour == 0
        ? 12
        : value.hour > 12
        ? value.hour - 12
        : value.hour;
    final minute = value.minute.toString().padLeft(2, '0');
    final period = value.hour >= 12 ? 'PM' : 'AM';
    return '${value.month}/${value.day} $hour:$minute $period';
  }
}
