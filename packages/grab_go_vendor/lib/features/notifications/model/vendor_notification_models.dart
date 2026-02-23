enum VendorNotificationSeverity { info, warning, critical }

enum VendorNotificationChannelType {
  newOrders,
  orderSlaRisk,
  inventoryLowStock,
  payoutUpdates,
  accountSecurity,
}

class VendorNotificationChannelSetting {
  final VendorNotificationChannelType channel;
  final bool enabled;
  final bool isCritical;

  const VendorNotificationChannelSetting({
    required this.channel,
    required this.enabled,
    required this.isCritical,
  });

  VendorNotificationChannelSetting copyWith({bool? enabled}) {
    return VendorNotificationChannelSetting(
      channel: channel,
      enabled: enabled ?? this.enabled,
      isCritical: isCritical,
    );
  }
}

class VendorNotificationHistoryItem {
  final String id;
  final String title;
  final String body;
  final String timeLabel;
  final VendorNotificationSeverity severity;
  final bool isRead;

  const VendorNotificationHistoryItem({
    required this.id,
    required this.title,
    required this.body,
    required this.timeLabel,
    required this.severity,
    required this.isRead,
  });

  VendorNotificationHistoryItem copyWith({bool? isRead}) {
    return VendorNotificationHistoryItem(
      id: id,
      title: title,
      body: body,
      timeLabel: timeLabel,
      severity: severity,
      isRead: isRead ?? this.isRead,
    );
  }
}

extension VendorNotificationChannelTypeX on VendorNotificationChannelType {
  String get label {
    return switch (this) {
      VendorNotificationChannelType.newOrders => 'New Orders',
      VendorNotificationChannelType.orderSlaRisk => 'SLA Risk Alerts',
      VendorNotificationChannelType.inventoryLowStock => 'Low Stock Alerts',
      VendorNotificationChannelType.payoutUpdates => 'Payout Updates',
      VendorNotificationChannelType.accountSecurity => 'Security Alerts',
    };
  }

  String get subtitle {
    return switch (this) {
      VendorNotificationChannelType.newOrders =>
        'Immediate alert when a new order enters queue',
      VendorNotificationChannelType.orderSlaRisk =>
        'Warn when active orders are close to SLA breach',
      VendorNotificationChannelType.inventoryLowStock =>
        'Alert when key items reach low stock threshold',
      VendorNotificationChannelType.payoutUpdates =>
        'Updates on settlement and payout status',
      VendorNotificationChannelType.accountSecurity =>
        'Password, login, and account protection events',
    };
  }
}

List<VendorNotificationChannelSetting> defaultNotificationChannels() {
  return const [
    VendorNotificationChannelSetting(
      channel: VendorNotificationChannelType.newOrders,
      enabled: true,
      isCritical: true,
    ),
    VendorNotificationChannelSetting(
      channel: VendorNotificationChannelType.orderSlaRisk,
      enabled: true,
      isCritical: true,
    ),
    VendorNotificationChannelSetting(
      channel: VendorNotificationChannelType.inventoryLowStock,
      enabled: true,
      isCritical: false,
    ),
    VendorNotificationChannelSetting(
      channel: VendorNotificationChannelType.payoutUpdates,
      enabled: true,
      isCritical: false,
    ),
    VendorNotificationChannelSetting(
      channel: VendorNotificationChannelType.accountSecurity,
      enabled: true,
      isCritical: true,
    ),
  ];
}

List<VendorNotificationHistoryItem> mockNotificationHistory() {
  return const [
    VendorNotificationHistoryItem(
      id: 'notif_001',
      title: 'Order #GG-829318 At Risk',
      body: 'Prep time is above target. Action recommended now.',
      timeLabel: 'Now',
      severity: VendorNotificationSeverity.critical,
      isRead: false,
    ),
    VendorNotificationHistoryItem(
      id: 'notif_002',
      title: 'New Order Received',
      body: 'Food order #GG-829321 is waiting for acceptance.',
      timeLabel: '3m ago',
      severity: VendorNotificationSeverity.info,
      isRead: false,
    ),
    VendorNotificationHistoryItem(
      id: 'notif_003',
      title: 'Low Stock Alert',
      body: 'Vitamin C 1000mg has reached low stock threshold.',
      timeLabel: '11m ago',
      severity: VendorNotificationSeverity.warning,
      isRead: true,
    ),
    VendorNotificationHistoryItem(
      id: 'notif_004',
      title: 'Security Notice',
      body: 'A login was detected on another device.',
      timeLabel: '1h ago',
      severity: VendorNotificationSeverity.critical,
      isRead: true,
    ),
  ];
}
