import 'package:flutter/material.dart';
import 'package:grab_go_vendor/features/chats/model/vendor_chat_models.dart';
import 'package:grab_go_vendor/features/orders/model/vendor_order_summary.dart';

class ChatsTabViewModel extends ChangeNotifier {
  ChatsTabViewModel() {
    searchController.addListener(_onSearchChanged);
  }

  final TextEditingController searchController = TextEditingController();

  final List<VendorChatThread> _threads = mockVendorThreads();
  String _query = '';
  bool _showUnreadOnly = false;
  bool _showAtRiskOnly = false;
  VendorChatCounterpartType? _counterpartFilter;

  bool get showUnreadOnly => _showUnreadOnly;
  bool get showAtRiskOnly => _showAtRiskOnly;
  VendorChatCounterpartType? get counterpartFilter => _counterpartFilter;

  List<VendorChatThread> get filteredThreads {
    final lowerQuery = _query.toLowerCase();
    final result = _threads.where((thread) {
      final matchesUnread = !_showUnreadOnly || thread.unreadCount > 0;
      final matchesAtRisk = !_showAtRiskOnly || thread.isAtRisk;
      final matchesCounterpart =
          _counterpartFilter == null ||
          thread.counterpartType == _counterpartFilter;
      final matchesQuery =
          lowerQuery.isEmpty ||
          thread.orderId.toLowerCase().contains(lowerQuery) ||
          thread.counterpartName.toLowerCase().contains(lowerQuery) ||
          thread.lastMessage.toLowerCase().contains(lowerQuery);
      return matchesUnread &&
          matchesAtRisk &&
          matchesCounterpart &&
          matchesQuery;
    }).toList();

    result.sort((a, b) => b.lastMessageAt.compareTo(a.lastMessageAt));
    return result;
  }

  VendorChatThread? threadById(String threadId) {
    final index = _threads.indexWhere((thread) => thread.id == threadId);
    if (index < 0) return null;
    return _threads[index];
  }

  VendorOrderSummary? linkedOrder(String orderId) {
    return mockVendorOrders().cast<VendorOrderSummary?>().firstWhere(
      (order) => order?.id == orderId,
      orElse: () => null,
    );
  }

  void markThreadRead(String threadId) {
    final index = _threads.indexWhere((thread) => thread.id == threadId);
    if (index < 0) return;
    final thread = _threads[index];
    if (thread.unreadCount == 0) return;
    _threads[index] = thread.copyWith(unreadCount: 0);
    notifyListeners();
  }

  void sendMessage(String threadId, String text, {bool isAttachment = false}) {
    final index = _threads.indexWhere((thread) => thread.id == threadId);
    if (index < 0) return;

    final trimmedText = text.trim();
    if (trimmedText.isEmpty) return;

    final thread = _threads[index];
    final now = DateTime.now();
    final nextMessages = List<VendorChatMessage>.from(thread.messages)
      ..add(
        VendorChatMessage(
          id: 'msg_${now.microsecondsSinceEpoch}',
          sender: VendorMessageSenderType.vendor,
          text: trimmedText,
          sentAt: now,
          isAttachment: isAttachment,
        ),
      );

    _threads[index] = thread.copyWith(
      lastMessage: trimmedText,
      lastMessageAt: now,
      messages: nextMessages,
      unreadCount: 0,
    );
    notifyListeners();
  }

  void toggleIssueFlag(String threadId) {
    final index = _threads.indexWhere((thread) => thread.id == threadId);
    if (index < 0) return;
    final thread = _threads[index];
    _threads[index] = thread.copyWith(hasOpenIssue: !thread.hasOpenIssue);
    notifyListeners();
  }

  void setCounterpartFilter(VendorChatCounterpartType? type) {
    if (_counterpartFilter == type) return;
    _counterpartFilter = type;
    notifyListeners();
  }

  void toggleUnreadOnly() {
    _showUnreadOnly = !_showUnreadOnly;
    notifyListeners();
  }

  void toggleAtRiskOnly() {
    _showAtRiskOnly = !_showAtRiskOnly;
    notifyListeners();
  }

  String relativeTimeLabel(DateTime value) {
    final diff = DateTime.now().difference(value);
    if (diff.inMinutes < 1) return 'Now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }

  void _onSearchChanged() {
    final nextQuery = searchController.text.trim();
    if (_query == nextQuery) return;
    _query = nextQuery;
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
