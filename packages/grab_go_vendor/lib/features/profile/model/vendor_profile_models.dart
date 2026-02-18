class VendorSessionDevice {
  final String id;
  final String deviceName;
  final String location;
  final String lastActiveLabel;
  final bool isCurrent;

  const VendorSessionDevice({
    required this.id,
    required this.deviceName,
    required this.location,
    required this.lastActiveLabel,
    required this.isCurrent,
  });

  VendorSessionDevice copyWith({
    String? deviceName,
    String? location,
    String? lastActiveLabel,
    bool? isCurrent,
  }) {
    return VendorSessionDevice(
      id: id,
      deviceName: deviceName ?? this.deviceName,
      location: location ?? this.location,
      lastActiveLabel: lastActiveLabel ?? this.lastActiveLabel,
      isCurrent: isCurrent ?? this.isCurrent,
    );
  }
}

List<VendorSessionDevice> mockSessionDevices() {
  return const [
    VendorSessionDevice(
      id: 'session_001',
      deviceName: 'Pixel 8 Pro • Android',
      location: 'Accra, Ghana',
      lastActiveLabel: 'Now',
      isCurrent: true,
    ),
    VendorSessionDevice(
      id: 'session_002',
      deviceName: 'iPhone 15 • iOS',
      location: 'Kumasi, Ghana',
      lastActiveLabel: '2h ago',
      isCurrent: false,
    ),
    VendorSessionDevice(
      id: 'session_003',
      deviceName: 'Chrome • Windows',
      location: 'Tema, Ghana',
      lastActiveLabel: 'Yesterday',
      isCurrent: false,
    ),
  ];
}
