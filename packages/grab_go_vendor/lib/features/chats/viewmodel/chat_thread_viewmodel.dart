import 'package:flutter/material.dart';
import 'package:grab_go_vendor/features/chats/model/vendor_chat_models.dart';
import 'package:grab_go_vendor/features/chats/viewmodel/chats_tab_viewmodel.dart';

class ChatThreadViewModel extends ChangeNotifier {
  ChatThreadViewModel({required this.parentViewModel, required this.threadId}) {
    parentViewModel.addListener(_onParentChanged);
    parentViewModel.markThreadRead(threadId);
  }

  final ChatsTabViewModel parentViewModel;
  final String threadId;
  final TextEditingController messageController = TextEditingController();

  VendorChatThread? get thread => parentViewModel.threadById(threadId);

  List<VendorChatMessage> get messages => thread == null
      ? const []
      : List<VendorChatMessage>.from(thread!.messages);

  List<String> get quickReplies {
    final current = thread;
    if (current == null) return const [];
    return switch (current.counterpartType) {
      VendorChatCounterpartType.customer => [
        'Noted, updating now.',
        'Your order is in preparation.',
        'We sent a replacement option.',
      ],
      VendorChatCounterpartType.rider => [
        'Pickup at counter 2.',
        'Order will be ready in 3 minutes.',
        'Please confirm handover code on arrival.',
      ],
    };
  }

  void sendCurrentMessage() {
    final text = messageController.text.trim();
    if (text.isEmpty) return;
    parentViewModel.sendMessage(threadId, text);
    messageController.clear();
  }

  void sendQuickReply(String text) {
    parentViewModel.sendMessage(threadId, text);
  }

  void sendAttachmentPlaceholder(String fileLabel) {
    parentViewModel.sendMessage(
      threadId,
      'Attachment: $fileLabel',
      isAttachment: true,
    );
  }

  void toggleIssueFlag() {
    parentViewModel.toggleIssueFlag(threadId);
  }

  String relativeTime(DateTime value) =>
      parentViewModel.relativeTimeLabel(value);

  void _onParentChanged() {
    notifyListeners();
  }

  @override
  void dispose() {
    parentViewModel.removeListener(_onParentChanged);
    messageController.dispose();
    super.dispose();
  }
}
