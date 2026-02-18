import 'package:grab_go_vendor/features/auth/model/vendor_service_option.dart';

enum VendorCapacityStatus { available, nearCapacity, full, paused }

class VendorScheduledOrder {
  final String id;
  final String customerName;
  final VendorServiceType serviceType;
  final String fulfillmentLabel;
  final String slotLabel;
  final int itemCount;
  final bool atRisk;

  const VendorScheduledOrder({
    required this.id,
    required this.customerName,
    required this.serviceType,
    required this.fulfillmentLabel,
    required this.slotLabel,
    required this.itemCount,
    required this.atRisk,
  });
}

class VendorTimeSlotCapacity {
  final String id;
  final String slotLabel;
  final int capacity;
  final int booked;
  final VendorCapacityStatus status;

  const VendorTimeSlotCapacity({
    required this.id,
    required this.slotLabel,
    required this.capacity,
    required this.booked,
    required this.status,
  });

  VendorTimeSlotCapacity copyWith({
    int? capacity,
    int? booked,
    VendorCapacityStatus? status,
  }) {
    return VendorTimeSlotCapacity(
      id: id,
      slotLabel: slotLabel,
      capacity: capacity ?? this.capacity,
      booked: booked ?? this.booked,
      status: status ?? this.status,
    );
  }
}

class VendorCutoffRule {
  final String id;
  final VendorServiceType serviceType;
  final int cutoffMinutes;
  final bool sameDayEnabled;

  const VendorCutoffRule({
    required this.id,
    required this.serviceType,
    required this.cutoffMinutes,
    required this.sameDayEnabled,
  });

  VendorCutoffRule copyWith({int? cutoffMinutes, bool? sameDayEnabled}) {
    return VendorCutoffRule(
      id: id,
      serviceType: serviceType,
      cutoffMinutes: cutoffMinutes ?? this.cutoffMinutes,
      sameDayEnabled: sameDayEnabled ?? this.sameDayEnabled,
    );
  }
}

extension VendorCapacityStatusX on VendorCapacityStatus {
  String get label {
    return switch (this) {
      VendorCapacityStatus.available => 'Available',
      VendorCapacityStatus.nearCapacity => 'Near Capacity',
      VendorCapacityStatus.full => 'Full',
      VendorCapacityStatus.paused => 'Paused',
    };
  }
}

List<VendorScheduledOrder> mockScheduledOrders() {
  return const [
    VendorScheduledOrder(
      id: 'GG-91201',
      customerName: 'Kwame T.',
      serviceType: VendorServiceType.food,
      fulfillmentLabel: 'Delivery',
      slotLabel: 'Today 1:00 PM - 1:30 PM',
      itemCount: 4,
      atRisk: false,
    ),
    VendorScheduledOrder(
      id: 'GG-91204',
      customerName: 'Akosua M.',
      serviceType: VendorServiceType.grocery,
      fulfillmentLabel: 'Pickup',
      slotLabel: 'Today 2:00 PM - 2:30 PM',
      itemCount: 7,
      atRisk: true,
    ),
    VendorScheduledOrder(
      id: 'GG-91208',
      customerName: 'Kofi D.',
      serviceType: VendorServiceType.pharmacy,
      fulfillmentLabel: 'Delivery',
      slotLabel: 'Today 4:00 PM - 4:30 PM',
      itemCount: 2,
      atRisk: false,
    ),
    VendorScheduledOrder(
      id: 'GG-91215',
      customerName: 'Nana Y.',
      serviceType: VendorServiceType.grabMart,
      fulfillmentLabel: 'Delivery',
      slotLabel: 'Tomorrow 9:00 AM - 9:30 AM',
      itemCount: 5,
      atRisk: false,
    ),
  ];
}

List<VendorTimeSlotCapacity> mockTimeSlotCapacities() {
  return const [
    VendorTimeSlotCapacity(
      id: 'slot_001',
      slotLabel: '11:00 - 11:30',
      capacity: 14,
      booked: 8,
      status: VendorCapacityStatus.available,
    ),
    VendorTimeSlotCapacity(
      id: 'slot_002',
      slotLabel: '12:00 - 12:30',
      capacity: 18,
      booked: 16,
      status: VendorCapacityStatus.nearCapacity,
    ),
    VendorTimeSlotCapacity(
      id: 'slot_003',
      slotLabel: '1:00 - 1:30',
      capacity: 20,
      booked: 20,
      status: VendorCapacityStatus.full,
    ),
    VendorTimeSlotCapacity(
      id: 'slot_004',
      slotLabel: '2:00 - 2:30',
      capacity: 12,
      booked: 0,
      status: VendorCapacityStatus.paused,
    ),
  ];
}

List<VendorCutoffRule> mockCutoffRules() {
  return const [
    VendorCutoffRule(
      id: 'cutoff_food',
      serviceType: VendorServiceType.food,
      cutoffMinutes: 25,
      sameDayEnabled: true,
    ),
    VendorCutoffRule(
      id: 'cutoff_grocery',
      serviceType: VendorServiceType.grocery,
      cutoffMinutes: 45,
      sameDayEnabled: true,
    ),
    VendorCutoffRule(
      id: 'cutoff_pharmacy',
      serviceType: VendorServiceType.pharmacy,
      cutoffMinutes: 60,
      sameDayEnabled: false,
    ),
    VendorCutoffRule(
      id: 'cutoff_grabmart',
      serviceType: VendorServiceType.grabMart,
      cutoffMinutes: 35,
      sameDayEnabled: true,
    ),
  ];
}
