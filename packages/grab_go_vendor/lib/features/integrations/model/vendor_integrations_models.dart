enum VendorIntegrationStatus { disconnected, connecting, connected, error }

class VendorPrinterDevice {
  final String id;
  final String name;
  final String locationLabel;
  final String paperLabel;
  final VendorIntegrationStatus status;
  final String lastTestLabel;

  const VendorPrinterDevice({
    required this.id,
    required this.name,
    required this.locationLabel,
    required this.paperLabel,
    required this.status,
    required this.lastTestLabel,
  });

  VendorPrinterDevice copyWith({
    VendorIntegrationStatus? status,
    String? lastTestLabel,
  }) {
    return VendorPrinterDevice(
      id: id,
      name: name,
      locationLabel: locationLabel,
      paperLabel: paperLabel,
      status: status ?? this.status,
      lastTestLabel: lastTestLabel ?? this.lastTestLabel,
    );
  }
}

class VendorKdsStation {
  final String id;
  final String name;
  final String screenLabel;
  final int autoBumpSeconds;
  final VendorIntegrationStatus status;

  const VendorKdsStation({
    required this.id,
    required this.name,
    required this.screenLabel,
    required this.autoBumpSeconds,
    required this.status,
  });

  VendorKdsStation copyWith({
    int? autoBumpSeconds,
    VendorIntegrationStatus? status,
  }) {
    return VendorKdsStation(
      id: id,
      name: name,
      screenLabel: screenLabel,
      autoBumpSeconds: autoBumpSeconds ?? this.autoBumpSeconds,
      status: status ?? this.status,
    );
  }
}

class VendorPrintLog {
  final String id;
  final String title;
  final String timestampLabel;
  final bool success;

  const VendorPrintLog({
    required this.id,
    required this.title,
    required this.timestampLabel,
    required this.success,
  });
}

extension VendorIntegrationStatusX on VendorIntegrationStatus {
  String get label {
    return switch (this) {
      VendorIntegrationStatus.disconnected => 'Disconnected',
      VendorIntegrationStatus.connecting => 'Connecting',
      VendorIntegrationStatus.connected => 'Connected',
      VendorIntegrationStatus.error => 'Error',
    };
  }
}

List<VendorPrinterDevice> mockPrinters() {
  return const [
    VendorPrinterDevice(
      id: 'prn_001',
      name: 'Kitchen Printer A',
      locationLabel: 'Main Kitchen',
      paperLabel: '80mm',
      status: VendorIntegrationStatus.connected,
      lastTestLabel: 'Today 11:40 AM',
    ),
    VendorPrinterDevice(
      id: 'prn_002',
      name: 'Pack Station Printer',
      locationLabel: 'Packing Desk',
      paperLabel: '58mm',
      status: VendorIntegrationStatus.disconnected,
      lastTestLabel: 'Never',
    ),
  ];
}

List<VendorKdsStation> mockKdsStations() {
  return const [
    VendorKdsStation(
      id: 'kds_001',
      name: 'Hot Kitchen Screen',
      screenLabel: 'Tablet 10"',
      autoBumpSeconds: 90,
      status: VendorIntegrationStatus.connected,
    ),
    VendorKdsStation(
      id: 'kds_002',
      name: 'Packing Screen',
      screenLabel: 'Display 15"',
      autoBumpSeconds: 120,
      status: VendorIntegrationStatus.connecting,
    ),
  ];
}

List<VendorPrintLog> mockPrintLogs() {
  return const [
    VendorPrintLog(
      id: 'log_001',
      title: 'Order GG-91201 Kitchen Ticket',
      timestampLabel: 'Today 12:10 PM',
      success: true,
    ),
    VendorPrintLog(
      id: 'log_002',
      title: 'Order GG-91204 Packing Slip',
      timestampLabel: 'Today 12:05 PM',
      success: false,
    ),
  ];
}
