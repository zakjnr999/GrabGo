enum OrderServiceType { food, grocery, pharmacy, grabmart }

enum VendorOrderStatus {
  newOrder,
  accepted,
  preparing,
  ready,
  pickedUp,
  cancelled,
}

enum VendorOrderActionType {
  accept,
  reject,
  startPreparing,
  markReady,
  verifyPickupCode,
}

class VendorOrderItem {
  final String name;
  final int quantity;
  final double unitPrice;
  final String? note;
  final bool canBeReplaced;

  const VendorOrderItem({
    required this.name,
    required this.quantity,
    required this.unitPrice,
    this.note,
    this.canBeReplaced = true,
  });
}

class VendorOrderTimelineEntry {
  final String title;
  final String subtitle;
  final String timeLabel;
  final bool isWarning;

  const VendorOrderTimelineEntry({
    required this.title,
    required this.subtitle,
    required this.timeLabel,
    this.isWarning = false,
  });
}

class VendorOrderAuditEntry {
  final String action;
  final String actor;
  final String timeLabel;
  final String details;

  const VendorOrderAuditEntry({
    required this.action,
    required this.actor,
    required this.timeLabel,
    required this.details,
  });
}

class VendorIssueEntry {
  final String title;
  final String status;
  final String timeLabel;
  final String details;

  const VendorIssueEntry({
    required this.title,
    required this.status,
    required this.timeLabel,
    required this.details,
  });
}

class VendorOrderSummary {
  final String id;
  final String customerName;
  final String customerPhone;
  final String? customerNote;
  final String riderName;
  final String riderEtaLabel;
  final int itemCount;
  final String elapsedLabel;
  final OrderServiceType serviceType;
  final VendorOrderStatus status;
  final bool isAtRisk;
  final bool requiresPrescription;
  final bool isPickupOrder;
  final double subtotal;
  final double deliveryFee;
  final List<VendorOrderItem> items;
  final List<VendorOrderTimelineEntry> timelineEntries;
  final List<VendorOrderAuditEntry> auditEntries;
  final List<VendorIssueEntry> issueEntries;

  const VendorOrderSummary({
    required this.id,
    required this.customerName,
    required this.customerPhone,
    this.customerNote,
    required this.riderName,
    required this.riderEtaLabel,
    required this.itemCount,
    required this.elapsedLabel,
    required this.serviceType,
    required this.status,
    required this.isAtRisk,
    required this.requiresPrescription,
    required this.isPickupOrder,
    required this.subtotal,
    required this.deliveryFee,
    required this.items,
    required this.timelineEntries,
    required this.auditEntries,
    required this.issueEntries,
  });

  double get total => subtotal + deliveryFee;

  VendorOrderSummary copyWith({
    VendorOrderStatus? status,
    bool? isAtRisk,
    String? customerNote,
    List<VendorOrderAuditEntry>? auditEntries,
    List<VendorIssueEntry>? issueEntries,
  }) {
    return VendorOrderSummary(
      id: id,
      customerName: customerName,
      customerPhone: customerPhone,
      customerNote: customerNote ?? this.customerNote,
      riderName: riderName,
      riderEtaLabel: riderEtaLabel,
      itemCount: itemCount,
      elapsedLabel: elapsedLabel,
      serviceType: serviceType,
      status: status ?? this.status,
      isAtRisk: isAtRisk ?? this.isAtRisk,
      requiresPrescription: requiresPrescription,
      isPickupOrder: isPickupOrder,
      subtotal: subtotal,
      deliveryFee: deliveryFee,
      items: items,
      timelineEntries: timelineEntries,
      auditEntries: auditEntries ?? this.auditEntries,
      issueEntries: issueEntries ?? this.issueEntries,
    );
  }
}

extension OrderServiceTypeX on OrderServiceType {
  String get label {
    return switch (this) {
      OrderServiceType.food => 'Food',
      OrderServiceType.grocery => 'Grocery',
      OrderServiceType.pharmacy => 'Pharmacy',
      OrderServiceType.grabmart => 'GrabMart',
    };
  }
}

extension VendorOrderStatusX on VendorOrderStatus {
  String get label {
    return switch (this) {
      VendorOrderStatus.newOrder => 'New',
      VendorOrderStatus.accepted => 'Confirmed',
      VendorOrderStatus.preparing => 'Preparing',
      VendorOrderStatus.ready => 'Ready',
      VendorOrderStatus.pickedUp => 'Picked Up',
      VendorOrderStatus.cancelled => 'Cancelled',
    };
  }
}

extension VendorOrderActionTypeX on VendorOrderActionType {
  String get label {
    return switch (this) {
      VendorOrderActionType.accept => 'Accept Order',
      VendorOrderActionType.reject => 'Cancel Order',
      VendorOrderActionType.startPreparing => 'Start Preparing',
      VendorOrderActionType.markReady => 'Mark Ready',
      VendorOrderActionType.verifyPickupCode => 'Verify Pickup Code',
    };
  }
}

List<VendorOrderSummary> mockVendorOrders() {
  return [
    VendorOrderSummary(
      id: '#GG-829301',
      customerName: 'Mabel Asare',
      customerPhone: '+233 54 239 1021',
      customerNote: 'Please call when rider is 2 minutes away.',
      riderName: 'Kwesi Rider',
      riderEtaLabel: '4 min away',
      itemCount: 5,
      elapsedLabel: '2m',
      serviceType: OrderServiceType.food,
      status: VendorOrderStatus.newOrder,
      isAtRisk: false,
      requiresPrescription: false,
      isPickupOrder: false,
      subtotal: 96.00,
      deliveryFee: 12.00,
      items: const [
        VendorOrderItem(
          name: 'Jollof + Chicken',
          quantity: 2,
          unitPrice: 28.0,
          note: 'No onions',
        ),
        VendorOrderItem(name: 'Plantain', quantity: 1, unitPrice: 14.0),
        VendorOrderItem(name: 'Fruit Juice', quantity: 2, unitPrice: 13.0),
      ],
      timelineEntries: const [
        VendorOrderTimelineEntry(
          title: 'Order placed',
          subtitle: 'Customer completed checkout',
          timeLabel: '12:34 PM',
        ),
        VendorOrderTimelineEntry(
          title: 'Awaiting vendor acceptance',
          subtitle: 'Action required in under 5 minutes',
          timeLabel: '12:35 PM',
          isWarning: true,
        ),
      ],
      auditEntries: const [
        VendorOrderAuditEntry(
          action: 'Order created',
          actor: 'System',
          timeLabel: '12:34 PM',
          details: 'Payment authorized and order queued.',
        ),
      ],
      issueEntries: const [],
    ),
    VendorOrderSummary(
      id: '#GG-829300',
      customerName: 'Kwame Boateng',
      customerPhone: '+233 20 101 2203',
      customerNote: 'Pickup on behalf of mother. Confirm dosage at handover.',
      riderName: 'Abena Rider',
      riderEtaLabel: '8 min away',
      itemCount: 2,
      elapsedLabel: '11m',
      serviceType: OrderServiceType.pharmacy,
      status: VendorOrderStatus.preparing,
      isAtRisk: true,
      requiresPrescription: true,
      isPickupOrder: true,
      subtotal: 64.00,
      deliveryFee: 0.00,
      items: const [
        VendorOrderItem(name: 'Vitamin C 1000mg', quantity: 1, unitPrice: 18.0),
        VendorOrderItem(
          name: 'Antibiotic Syrup',
          quantity: 1,
          unitPrice: 46.0,
          canBeReplaced: false,
        ),
      ],
      timelineEntries: const [
        VendorOrderTimelineEntry(
          title: 'Order accepted',
          subtitle: 'Accepted by Ama (Operator)',
          timeLabel: '12:22 PM',
        ),
        VendorOrderTimelineEntry(
          title: 'Prescription reviewed',
          subtitle: 'Approved manually by store pharmacist',
          timeLabel: '12:25 PM',
        ),
        VendorOrderTimelineEntry(
          title: 'Preparing order',
          subtitle: 'Items being packaged',
          timeLabel: '12:30 PM',
        ),
      ],
      auditEntries: const [
        VendorOrderAuditEntry(
          action: 'Accept',
          actor: 'Ama (Operator)',
          timeLabel: '12:22 PM',
          details: 'Order accepted from queue.',
        ),
        VendorOrderAuditEntry(
          action: 'Prescription approved',
          actor: 'Dr. Mensah',
          timeLabel: '12:25 PM',
          details: 'Prescription image validated.',
        ),
      ],
      issueEntries: const [
        VendorIssueEntry(
          title: 'Customer unreachable',
          status: 'Resolved',
          timeLabel: '12:28 PM',
          details: 'Customer called back and confirmed dosage.',
        ),
      ],
    ),
    VendorOrderSummary(
      id: '#GG-829298',
      customerName: 'Esi A.',
      customerPhone: '+233 24 555 8120',
      customerNote: 'Leave at reception if customer is not reachable.',
      riderName: 'Jojo Rider',
      riderEtaLabel: 'Arrived',
      itemCount: 8,
      elapsedLabel: '19m',
      serviceType: OrderServiceType.grabmart,
      status: VendorOrderStatus.ready,
      isAtRisk: false,
      requiresPrescription: false,
      isPickupOrder: false,
      subtotal: 132.50,
      deliveryFee: 15.00,
      items: const [
        VendorOrderItem(name: 'Rice 5kg', quantity: 1, unitPrice: 92.0),
        VendorOrderItem(name: 'Tomato Paste', quantity: 3, unitPrice: 8.5),
        VendorOrderItem(name: 'Cooking Oil 1L', quantity: 1, unitPrice: 15.0),
      ],
      timelineEntries: const [
        VendorOrderTimelineEntry(
          title: 'Ready for rider pickup',
          subtitle: 'Rider notified for pickup',
          timeLabel: '12:20 PM',
        ),
      ],
      auditEntries: const [
        VendorOrderAuditEntry(
          action: 'Mark ready',
          actor: 'Nana (Manager)',
          timeLabel: '12:20 PM',
          details: 'Order moved to ready queue.',
        ),
      ],
      issueEntries: const [],
    ),
  ];
}
