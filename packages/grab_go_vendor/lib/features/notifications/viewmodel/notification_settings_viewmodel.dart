import 'package:flutter/material.dart';
import 'package:grab_go_vendor/features/notifications/model/vendor_notification_models.dart';

class NotificationSettingsViewModel extends ChangeNotifier {
  NotificationSettingsViewModel() {
    _channelSettings = List<VendorNotificationChannelSetting>.from(
      defaultNotificationChannels(),
    );
    _history = List<VendorNotificationHistoryItem>.from(
      mockNotificationHistory(),
    );
  }

  late List<VendorNotificationChannelSetting> _channelSettings;
  late List<VendorNotificationHistoryItem> _history;

  bool _pushEnabled = true;
  bool _inAppEnabled = true;
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;
  bool _showMessagePreview = true;

  bool _quietHoursEnabled = false;
  TimeOfDay _quietStart = const TimeOfDay(hour: 22, minute: 0);
  TimeOfDay _quietEnd = const TimeOfDay(hour: 7, minute: 0);

  bool _escalateAtRiskOrders = true;
  bool _escalateUnacceptedOrders = true;
  bool _escalateOfflineEvents = true;

  List<VendorNotificationChannelSetting> get channelSettings =>
      List.unmodifiable(_channelSettings);
  List<VendorNotificationHistoryItem> get history =>
      List.unmodifiable(_history);

  bool get pushEnabled => _pushEnabled;
  bool get inAppEnabled => _inAppEnabled;
  bool get soundEnabled => _soundEnabled;
  bool get vibrationEnabled => _vibrationEnabled;
  bool get showMessagePreview => _showMessagePreview;
  bool get quietHoursEnabled => _quietHoursEnabled;
  TimeOfDay get quietStart => _quietStart;
  TimeOfDay get quietEnd => _quietEnd;
  bool get escalateAtRiskOrders => _escalateAtRiskOrders;
  bool get escalateUnacceptedOrders => _escalateUnacceptedOrders;
  bool get escalateOfflineEvents => _escalateOfflineEvents;
  int get unreadCount => _history.where((entry) => !entry.isRead).length;

  void setPushEnabled(bool value) {
    if (_pushEnabled == value) return;
    _pushEnabled = value;
    notifyListeners();
  }

  void setInAppEnabled(bool value) {
    if (_inAppEnabled == value) return;
    _inAppEnabled = value;
    notifyListeners();
  }

  void setSoundEnabled(bool value) {
    if (_soundEnabled == value) return;
    _soundEnabled = value;
    notifyListeners();
  }

  void setVibrationEnabled(bool value) {
    if (_vibrationEnabled == value) return;
    _vibrationEnabled = value;
    notifyListeners();
  }

  void setShowMessagePreview(bool value) {
    if (_showMessagePreview == value) return;
    _showMessagePreview = value;
    notifyListeners();
  }

  void setQuietHoursEnabled(bool value) {
    if (_quietHoursEnabled == value) return;
    _quietHoursEnabled = value;
    notifyListeners();
  }

  void setQuietStart(TimeOfDay value) {
    _quietStart = value;
    notifyListeners();
  }

  void setQuietEnd(TimeOfDay value) {
    _quietEnd = value;
    notifyListeners();
  }

  void setEscalateAtRiskOrders(bool value) {
    if (_escalateAtRiskOrders == value) return;
    _escalateAtRiskOrders = value;
    notifyListeners();
  }

  void setEscalateUnacceptedOrders(bool value) {
    if (_escalateUnacceptedOrders == value) return;
    _escalateUnacceptedOrders = value;
    notifyListeners();
  }

  void setEscalateOfflineEvents(bool value) {
    if (_escalateOfflineEvents == value) return;
    _escalateOfflineEvents = value;
    notifyListeners();
  }

  void setChannelEnabled(VendorNotificationChannelType type, bool enabled) {
    final index = _channelSettings.indexWhere((entry) => entry.channel == type);
    if (index < 0) return;
    final channel = _channelSettings[index];
    if (channel.isCritical && !enabled) return;
    _channelSettings[index] = channel.copyWith(enabled: enabled);
    notifyListeners();
  }

  void markAllHistoryRead() {
    var changed = false;
    final next = <VendorNotificationHistoryItem>[];
    for (final entry in _history) {
      if (!entry.isRead) {
        next.add(entry.copyWith(isRead: true));
        changed = true;
      } else {
        next.add(entry);
      }
    }
    if (!changed) return;
    _history = next;
    notifyListeners();
  }

  void markHistoryRead(String id) {
    final index = _history.indexWhere((entry) => entry.id == id);
    if (index < 0) return;
    final current = _history[index];
    if (current.isRead) return;
    _history[index] = current.copyWith(isRead: true);
    notifyListeners();
  }

  void addTestAlert(VendorNotificationSeverity severity) {
    final now = DateTime.now().microsecondsSinceEpoch;
    final (title, body) = switch (severity) {
      VendorNotificationSeverity.info => (
        'Test: New Order',
        'This is a simulated new-order alert.',
      ),
      VendorNotificationSeverity.warning => (
        'Test: Inventory Warning',
        'This is a simulated low-stock warning.',
      ),
      VendorNotificationSeverity.critical => (
        'Test: SLA Critical',
        'This is a simulated critical SLA alert.',
      ),
    };

    _history.insert(
      0,
      VendorNotificationHistoryItem(
        id: 'notif_$now',
        title: title,
        body: body,
        timeLabel: 'Now',
        severity: severity,
        isRead: false,
      ),
    );
    notifyListeners();
  }

  String formatTime(TimeOfDay value) {
    final hour = value.hour == 0
        ? 12
        : value.hour > 12
        ? value.hour - 12
        : value.hour;
    final minute = value.minute.toString().padLeft(2, '0');
    final period = value.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }
}
