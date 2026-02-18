import 'package:grab_go_vendor/features/orders/model/vendor_order_summary.dart';

enum VendorChatCounterpartType { customer, rider }

enum VendorMessageSenderType { vendor, counterpart, system }

class VendorChatMessage {
  final String id;
  final VendorMessageSenderType sender;
  final String text;
  final DateTime sentAt;
  final bool isAttachment;

  const VendorChatMessage({
    required this.id,
    required this.sender,
    required this.text,
    required this.sentAt,
    this.isAttachment = false,
  });

  VendorChatMessage copyWith({
    VendorMessageSenderType? sender,
    String? text,
    DateTime? sentAt,
    bool? isAttachment,
  }) {
    return VendorChatMessage(
      id: id,
      sender: sender ?? this.sender,
      text: text ?? this.text,
      sentAt: sentAt ?? this.sentAt,
      isAttachment: isAttachment ?? this.isAttachment,
    );
  }
}

class VendorChatThread {
  final String id;
  final String orderId;
  final OrderServiceType serviceType;
  final VendorChatCounterpartType counterpartType;
  final String counterpartName;
  final String lastMessage;
  final DateTime lastMessageAt;
  final int unreadCount;
  final bool isAtRisk;
  final bool hasOpenIssue;
  final List<VendorChatMessage> messages;

  const VendorChatThread({
    required this.id,
    required this.orderId,
    required this.serviceType,
    required this.counterpartType,
    required this.counterpartName,
    required this.lastMessage,
    required this.lastMessageAt,
    required this.unreadCount,
    required this.isAtRisk,
    required this.hasOpenIssue,
    required this.messages,
  });

  VendorChatThread copyWith({
    String? lastMessage,
    DateTime? lastMessageAt,
    int? unreadCount,
    bool? isAtRisk,
    bool? hasOpenIssue,
    List<VendorChatMessage>? messages,
  }) {
    return VendorChatThread(
      id: id,
      orderId: orderId,
      serviceType: serviceType,
      counterpartType: counterpartType,
      counterpartName: counterpartName,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      unreadCount: unreadCount ?? this.unreadCount,
      isAtRisk: isAtRisk ?? this.isAtRisk,
      hasOpenIssue: hasOpenIssue ?? this.hasOpenIssue,
      messages: messages ?? this.messages,
    );
  }
}

extension VendorChatCounterpartTypeX on VendorChatCounterpartType {
  String get label {
    return switch (this) {
      VendorChatCounterpartType.customer => 'Customer',
      VendorChatCounterpartType.rider => 'Rider',
    };
  }
}

List<VendorChatThread> mockVendorThreads() {
  final now = DateTime.now();
  return [
    VendorChatThread(
      id: 'thread_001',
      orderId: '#GG-829301',
      serviceType: OrderServiceType.food,
      counterpartType: VendorChatCounterpartType.customer,
      counterpartName: 'Mabel Asare',
      lastMessage: 'Please remove onions from item 2.',
      lastMessageAt: now.subtract(const Duration(minutes: 1)),
      unreadCount: 2,
      isAtRisk: false,
      hasOpenIssue: false,
      messages: [
        VendorChatMessage(
          id: 'msg_001_1',
          sender: VendorMessageSenderType.counterpart,
          text: 'Hi, can you remove onions from item 2 please?',
          sentAt: now.subtract(const Duration(minutes: 3)),
        ),
        VendorChatMessage(
          id: 'msg_001_2',
          sender: VendorMessageSenderType.vendor,
          text: 'Noted. We are updating it now.',
          sentAt: now.subtract(const Duration(minutes: 2)),
        ),
        VendorChatMessage(
          id: 'msg_001_3',
          sender: VendorMessageSenderType.counterpart,
          text: 'Please remove onions from item 2.',
          sentAt: now.subtract(const Duration(minutes: 1)),
        ),
      ],
    ),
    VendorChatThread(
      id: 'thread_002',
      orderId: '#GG-829300',
      serviceType: OrderServiceType.pharmacy,
      counterpartType: VendorChatCounterpartType.customer,
      counterpartName: 'Kwame Boateng',
      lastMessage: 'I just uploaded the prescription image.',
      lastMessageAt: now.subtract(const Duration(minutes: 4)),
      unreadCount: 1,
      isAtRisk: true,
      hasOpenIssue: true,
      messages: [
        VendorChatMessage(
          id: 'msg_002_1',
          sender: VendorMessageSenderType.system,
          text: 'Prescription review is required before dispatch.',
          sentAt: now.subtract(const Duration(minutes: 10)),
        ),
        VendorChatMessage(
          id: 'msg_002_2',
          sender: VendorMessageSenderType.counterpart,
          text: 'I just uploaded the prescription image.',
          sentAt: now.subtract(const Duration(minutes: 4)),
        ),
      ],
    ),
    VendorChatThread(
      id: 'thread_003',
      orderId: '#GG-829298',
      serviceType: OrderServiceType.grabmart,
      counterpartType: VendorChatCounterpartType.rider,
      counterpartName: 'Jojo Rider',
      lastMessage: 'Arrived at pickup point.',
      lastMessageAt: now.subtract(const Duration(minutes: 6)),
      unreadCount: 0,
      isAtRisk: false,
      hasOpenIssue: false,
      messages: [
        VendorChatMessage(
          id: 'msg_003_1',
          sender: VendorMessageSenderType.vendor,
          text: 'Order is packed. Come to counter 2.',
          sentAt: now.subtract(const Duration(minutes: 8)),
        ),
        VendorChatMessage(
          id: 'msg_003_2',
          sender: VendorMessageSenderType.counterpart,
          text: 'Arrived at pickup point.',
          sentAt: now.subtract(const Duration(minutes: 6)),
        ),
      ],
    ),
  ];
}
