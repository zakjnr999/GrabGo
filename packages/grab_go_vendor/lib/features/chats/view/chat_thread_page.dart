import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:grab_go_vendor/features/chats/view/chat_attachment_preview_page.dart';
import 'package:grab_go_vendor/features/chats/model/vendor_chat_models.dart';
import 'package:grab_go_vendor/features/chats/viewmodel/chat_thread_viewmodel.dart';
import 'package:grab_go_vendor/features/chats/viewmodel/chats_tab_viewmodel.dart';
import 'package:grab_go_vendor/features/orders/model/vendor_order_summary.dart';
import 'package:grab_go_vendor/features/orders/view/order_detail_page.dart';
import 'package:provider/provider.dart';

class ChatThreadPage extends StatelessWidget {
  final String threadId;
  final ChatsTabViewModel parentViewModel;

  const ChatThreadPage({
    super.key,
    required this.threadId,
    required this.parentViewModel,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ChatThreadViewModel(
        parentViewModel: parentViewModel,
        threadId: threadId,
      ),
      child: const _ChatThreadView(),
    );
  }
}

class _ChatThreadView extends StatelessWidget {
  const _ChatThreadView();

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Consumer<ChatThreadViewModel>(
      builder: (context, viewModel, _) {
        final thread = viewModel.thread;
        if (thread == null) {
          return Scaffold(
            backgroundColor: colors.backgroundPrimary,
            appBar: AppBar(
              backgroundColor: colors.backgroundPrimary,
              elevation: 0,
            ),
            body: Center(
              child: Text(
                'Chat not found',
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w700,
                  color: colors.textSecondary,
                ),
              ),
            ),
          );
        }

        final serviceColor = _serviceColor(colors, thread.serviceType);

        return Scaffold(
          backgroundColor: colors.backgroundPrimary,
          appBar: AppBar(
            backgroundColor: colors.backgroundPrimary,
            elevation: 0,
            centerTitle: false,
            titleSpacing: 8.w,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${thread.orderId} • ${thread.counterpartType.label}',
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w800,
                    color: colors.textPrimary,
                  ),
                ),
                SizedBox(height: 2.h),
                Row(
                  children: [
                    Text(
                      thread.counterpartName,
                      style: TextStyle(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w600,
                        color: colors.textSecondary,
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 6.w,
                        vertical: 2.h,
                      ),
                      decoration: BoxDecoration(
                        color: serviceColor.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(999.r),
                      ),
                      child: Text(
                        thread.serviceType.label,
                        style: TextStyle(
                          fontSize: 9.sp,
                          fontWeight: FontWeight.w700,
                          color: serviceColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          body: SafeArea(
            child: Column(
              children: [
                if (thread.hasOpenIssue)
                  Container(
                    width: double.infinity,
                    margin: EdgeInsets.fromLTRB(14.w, 0, 14.w, 8.h),
                    padding: EdgeInsets.all(10.r),
                    decoration: BoxDecoration(
                      color: colors.warning.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.report_problem_outlined,
                          color: colors.warning,
                          size: 16.sp,
                        ),
                        SizedBox(width: 6.w),
                        Expanded(
                          child: Text(
                            'Issue is flagged on this thread. Follow up before closing order.',
                            style: TextStyle(
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w600,
                              color: colors.warning,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                _ThreadShortcutRow(
                  onOpenOrder: () =>
                      _openLinkedOrder(context, viewModel, thread.orderId),
                  onCall: () => _showCallHint(context, thread.counterpartName),
                  onToggleIssue: viewModel.toggleIssueFlag,
                  issueActive: thread.hasOpenIssue,
                ),
                SizedBox(height: 8.h),
                Expanded(
                  child: ListView.separated(
                    padding: EdgeInsets.symmetric(
                      horizontal: 14.w,
                      vertical: 8.h,
                    ),
                    itemCount: viewModel.messages.length,
                    separatorBuilder: (_, _) => SizedBox(height: 8.h),
                    itemBuilder: (context, index) {
                      final message = viewModel.messages[index];
                      return _MessageBubble(
                        message: message,
                        timeLabel: viewModel.relativeTime(message.sentAt),
                        onOpenAttachment: message.isAttachment
                            ? () => _openAttachmentPreview(
                                context,
                                message,
                                viewModel.relativeTime(message.sentAt),
                              )
                            : null,
                      );
                    },
                  ),
                ),
                _QuickReplyRow(
                  quickReplies: viewModel.quickReplies,
                  onReplyTap: viewModel.sendQuickReply,
                ),
                _Composer(
                  controller: viewModel.messageController,
                  onAttach: () => _showAttachmentSheet(context, viewModel),
                  onSend: viewModel.sendCurrentMessage,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openLinkedOrder(
    BuildContext context,
    ChatThreadViewModel viewModel,
    String orderId,
  ) {
    final order = viewModel.parentViewModel.linkedOrder(orderId);
    if (order == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Linked order details are unavailable')),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => OrderDetailPage(order: order)),
    );
  }

  void _showCallHint(BuildContext context, String name) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Call action placeholder for $name')),
    );
  }

  void _openAttachmentPreview(
    BuildContext context,
    VendorChatMessage message,
    String sentAtLabel,
  ) {
    final fileLabel = message.text.replaceFirst('Attachment:', '').trim();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatAttachmentPreviewPage(
          title: 'Attachment Preview',
          fileLabel: fileLabel.isEmpty ? 'Attachment file' : fileLabel,
          sentAtLabel: sentAtLabel,
        ),
      ),
    );
  }

  Future<void> _showAttachmentSheet(
    BuildContext context,
    ChatThreadViewModel viewModel,
  ) async {
    final colors = context.appColors;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: colors.backgroundPrimary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(14.w, 12.h, 14.w, 14.h),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Add attachment',
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w800,
                    color: colors.textPrimary,
                  ),
                ),
                SizedBox(height: 8.h),
                _AttachmentAction(
                  icon: Icons.camera_alt_outlined,
                  label: 'Take Photo',
                  onTap: () {
                    viewModel.sendAttachmentPlaceholder('Camera photo.jpg');
                    Navigator.pop(sheetContext);
                  },
                ),
                _AttachmentAction(
                  icon: Icons.photo_library_outlined,
                  label: 'Choose from Gallery',
                  onTap: () {
                    viewModel.sendAttachmentPlaceholder('Gallery image.png');
                    Navigator.pop(sheetContext);
                  },
                ),
                _AttachmentAction(
                  icon: Icons.attach_file_rounded,
                  label: 'Attach Document',
                  onTap: () {
                    viewModel.sendAttachmentPlaceholder('order-note.pdf');
                    Navigator.pop(sheetContext);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ThreadShortcutRow extends StatelessWidget {
  final VoidCallback onOpenOrder;
  final VoidCallback onCall;
  final VoidCallback onToggleIssue;
  final bool issueActive;

  const _ThreadShortcutRow({
    required this.onOpenOrder,
    required this.onCall,
    required this.onToggleIssue,
    required this.issueActive,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 14.w),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: onOpenOrder,
              icon: Icon(Icons.receipt_long_outlined, size: 16.sp),
              label: const Text('Open Order'),
              style: OutlinedButton.styleFrom(
                foregroundColor: colors.textPrimary,
                side: BorderSide(color: colors.inputBorder),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10.r),
                ),
              ),
            ),
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: onCall,
              icon: Icon(Icons.phone_outlined, size: 16.sp),
              label: const Text('Call'),
              style: OutlinedButton.styleFrom(
                foregroundColor: colors.textPrimary,
                side: BorderSide(color: colors.inputBorder),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10.r),
                ),
              ),
            ),
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: onToggleIssue,
              icon: Icon(
                issueActive
                    ? Icons.task_alt_rounded
                    : Icons.report_problem_outlined,
                size: 16.sp,
              ),
              label: Text(issueActive ? 'Resolve' : 'Issue'),
              style: OutlinedButton.styleFrom(
                foregroundColor: issueActive ? colors.success : colors.error,
                side: BorderSide(
                  color: (issueActive ? colors.success : colors.error)
                      .withValues(alpha: 0.4),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10.r),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final VendorChatMessage message;
  final String timeLabel;
  final VoidCallback? onOpenAttachment;

  const _MessageBubble({
    required this.message,
    required this.timeLabel,
    this.onOpenAttachment,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isVendor = message.sender == VendorMessageSenderType.vendor;
    final isSystem = message.sender == VendorMessageSenderType.system;

    if (isSystem) {
      return Container(
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 7.h),
        decoration: BoxDecoration(
          color: colors.backgroundSecondary,
          borderRadius: BorderRadius.circular(999.r),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.info_outline_rounded,
              size: 14.sp,
              color: colors.textSecondary,
            ),
            SizedBox(width: 5.w),
            Flexible(
              child: Text(
                message.text,
                style: TextStyle(
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w600,
                  color: colors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final bubble = Container(
      padding: EdgeInsets.all(10.r),
      decoration: BoxDecoration(
        color: isVendor ? colors.vendorPrimaryBlue : colors.backgroundSecondary,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (message.isAttachment)
            Padding(
              padding: EdgeInsets.only(bottom: 4.h),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.attach_file_rounded,
                    size: 13.sp,
                    color: isVendor ? Colors.white70 : colors.textSecondary,
                  ),
                  SizedBox(width: 4.w),
                  Text(
                    'Attachment',
                    style: TextStyle(
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w700,
                      color: isVendor ? Colors.white70 : colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          Text(
            message.text,
            style: TextStyle(
              fontSize: 12.sp,
              fontWeight: FontWeight.w600,
              color: isVendor ? Colors.white : colors.textPrimary,
            ),
          ),
          SizedBox(height: 4.h),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              timeLabel,
              style: TextStyle(
                fontSize: 10.sp,
                fontWeight: FontWeight.w600,
                color: isVendor
                    ? Colors.white.withValues(alpha: 0.75)
                    : colors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );

    return Align(
      alignment: isVendor ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 260.w),
        child: message.isAttachment && onOpenAttachment != null
            ? InkWell(
                onTap: onOpenAttachment,
                borderRadius: BorderRadius.circular(12.r),
                child: bubble,
              )
            : bubble,
      ),
    );
  }
}

class _QuickReplyRow extends StatelessWidget {
  final List<String> quickReplies;
  final ValueChanged<String> onReplyTap;

  const _QuickReplyRow({required this.quickReplies, required this.onReplyTap});

  @override
  Widget build(BuildContext context) {
    if (quickReplies.isEmpty) return const SizedBox.shrink();
    final colors = context.appColors;
    return SizedBox(
      height: 44.h,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 14.w),
        itemCount: quickReplies.length,
        separatorBuilder: (_, _) => SizedBox(width: 8.w),
        itemBuilder: (context, index) {
          final reply = quickReplies[index];
          return ActionChip(
            label: Text(
              reply,
              style: TextStyle(
                fontSize: 11.sp,
                fontWeight: FontWeight.w700,
                color: colors.vendorPrimaryBlue,
              ),
            ),
            onPressed: () => onReplyTap(reply),
            backgroundColor: colors.vendorPrimaryBlue.withValues(alpha: 0.1),
            side: BorderSide(
              color: colors.vendorPrimaryBlue.withValues(alpha: 0.25),
            ),
          );
        },
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onAttach;
  final VoidCallback onSend;

  const _Composer({
    required this.controller,
    required this.onAttach,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      padding: EdgeInsets.fromLTRB(
        12.w,
        8.h,
        12.w,
        8.h + MediaQuery.viewInsetsOf(context).bottom,
      ),
      decoration: BoxDecoration(
        color: colors.backgroundPrimary,
        border: Border(top: BorderSide(color: colors.divider)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: onAttach,
            icon: Icon(Icons.attach_file_rounded, color: colors.textSecondary),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSend(),
              decoration: InputDecoration(
                hintText: 'Type a message',
                hintStyle: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w500,
                  color: colors.textSecondary,
                ),
                filled: true,
                fillColor: colors.backgroundSecondary,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(999.r),
                  borderSide: BorderSide.none,
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12.w,
                  vertical: 8.h,
                ),
              ),
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              ),
            ),
          ),
          SizedBox(width: 8.w),
          CircleAvatar(
            radius: 18.r,
            backgroundColor: colors.vendorPrimaryBlue,
            child: IconButton(
              onPressed: onSend,
              icon: Icon(Icons.send_rounded, color: Colors.white, size: 16.sp),
            ),
          ),
        ],
      ),
    );
  }
}

class _AttachmentAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _AttachmentAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 34.w,
        height: 34.w,
        decoration: BoxDecoration(
          color: colors.vendorPrimaryBlue.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10.r),
        ),
        child: Icon(icon, color: colors.vendorPrimaryBlue, size: 18.sp),
      ),
      title: Text(
        label,
        style: TextStyle(
          fontSize: 13.sp,
          fontWeight: FontWeight.w700,
          color: colors.textPrimary,
        ),
      ),
      onTap: onTap,
    );
  }
}

Color _serviceColor(AppColorsExtension colors, OrderServiceType serviceType) {
  return switch (serviceType) {
    OrderServiceType.food => colors.serviceFood,
    OrderServiceType.grocery => colors.serviceGrocery,
    OrderServiceType.pharmacy => colors.servicePharmacy,
    OrderServiceType.grabmart => colors.serviceGrabMart,
  };
}
