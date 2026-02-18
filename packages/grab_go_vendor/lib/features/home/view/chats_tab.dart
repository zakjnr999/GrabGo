import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:grab_go_vendor/features/auth/model/vendor_service_option.dart';
import 'package:grab_go_vendor/features/chats/model/vendor_chat_models.dart';
import 'package:grab_go_vendor/features/chats/view/chat_thread_page.dart';
import 'package:grab_go_vendor/features/chats/viewmodel/chats_tab_viewmodel.dart';
import 'package:grab_go_vendor/features/orders/model/vendor_order_summary.dart';
import 'package:grab_go_vendor/features/orders/view/order_detail_page.dart';
import 'package:grab_go_vendor/features/store_context/viewmodel/store_context_viewmodel.dart';
import 'package:grab_go_vendor/shared/viewmodel/vendor_preview_session_viewmodel.dart';
import 'package:grab_go_vendor/shared/widgets/vendor_store_context_chip.dart';
import 'package:provider/provider.dart';

class ChatsTab extends StatelessWidget {
  const ChatsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ChatsTabViewModel(),
      child: const _ChatsTabView(),
    );
  }
}

class _ChatsTabView extends StatelessWidget {
  const _ChatsTabView();

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Consumer3<
      ChatsTabViewModel,
      VendorStoreContextViewModel,
      VendorPreviewSessionViewModel
    >(
      builder: (context, viewModel, storeContext, previewSession, _) {
        final visibleVendorServices = _visibleVendorServices(storeContext);
        final visibleOrderServices = visibleVendorServices
            .map(previewSession.mapToOrderService)
            .toSet();
        final threads = viewModel.filteredThreads
            .where(
              (thread) => visibleOrderServices.contains(thread.serviceType),
            )
            .toList();

        return SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 14.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Chats',
                      style: TextStyle(
                        fontSize: 28.sp,
                        fontWeight: FontWeight.w900,
                        color: colors.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    const VendorStoreContextChip(),
                  ],
                ),
                SizedBox(height: 6.h),
                Text(
                  visibleVendorServices.isEmpty
                      ? 'No services are active for this profile and store context.'
                      : 'Showing ${previewSession.servicesLabel(visibleVendorServices)} conversations.',
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w500,
                    color: colors.textSecondary,
                  ),
                ),
                SizedBox(height: 12.h),
                TextField(
                  controller: viewModel.searchController,
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search by order, name, message',
                    hintStyle: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w500,
                      color: colors.textSecondary,
                    ),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      size: 18.sp,
                      color: colors.textSecondary,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.r),
                      borderSide: BorderSide(color: colors.inputBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.r),
                      borderSide: BorderSide(color: colors.vendorPrimaryBlue),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.r),
                      borderSide: BorderSide(color: colors.inputBorder),
                    ),
                    filled: true,
                    fillColor: colors.backgroundPrimary,
                  ),
                ),
                SizedBox(height: 10.h),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _FilterChip(
                        label: 'All',
                        selected: viewModel.counterpartFilter == null,
                        color: colors.vendorPrimaryBlue,
                        onTap: () => viewModel.setCounterpartFilter(null),
                      ),
                      _FilterChip(
                        label: 'Customers',
                        selected:
                            viewModel.counterpartFilter ==
                            VendorChatCounterpartType.customer,
                        color: colors.serviceFood,
                        onTap: () => viewModel.setCounterpartFilter(
                          VendorChatCounterpartType.customer,
                        ),
                      ),
                      _FilterChip(
                        label: 'Riders',
                        selected:
                            viewModel.counterpartFilter ==
                            VendorChatCounterpartType.rider,
                        color: colors.serviceGrabMart,
                        onTap: () => viewModel.setCounterpartFilter(
                          VendorChatCounterpartType.rider,
                        ),
                      ),
                      _FilterChip(
                        label: 'Unread',
                        selected: viewModel.showUnreadOnly,
                        color: colors.warning,
                        onTap: viewModel.toggleUnreadOnly,
                      ),
                      _FilterChip(
                        label: 'At Risk',
                        selected: viewModel.showAtRiskOnly,
                        color: colors.error,
                        onTap: viewModel.toggleAtRiskOnly,
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 12.h),
                if (visibleOrderServices.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(18.r),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14.r),
                      border: Border.all(color: colors.border),
                      color: colors.backgroundPrimary,
                    ),
                    child: Text(
                      'No services are active for this vendor profile on the selected branch.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w600,
                        color: colors.textSecondary,
                      ),
                    ),
                  )
                else if (threads.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(18.r),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14.r),
                      border: Border.all(color: colors.border),
                      color: colors.backgroundPrimary,
                    ),
                    child: Text(
                      'No conversations match current filters.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w600,
                        color: colors.textSecondary,
                      ),
                    ),
                  )
                else
                  ...threads.map(
                    (thread) => _ChatThreadTile(
                      thread: thread,
                      onTap: () => _openThread(context, viewModel, thread.id),
                      onOpenOrder: () =>
                          _openOrder(context, viewModel, thread.orderId),
                      timeLabel: viewModel.relativeTimeLabel(
                        thread.lastMessageAt,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openThread(
    BuildContext context,
    ChatsTabViewModel viewModel,
    String threadId,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ChatThreadPage(threadId: threadId, parentViewModel: viewModel),
      ),
    );
  }

  void _openOrder(
    BuildContext context,
    ChatsTabViewModel viewModel,
    String orderId,
  ) {
    final order = viewModel.linkedOrder(orderId);
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
}

Set<VendorServiceType> _visibleVendorServices(
  VendorStoreContextViewModel storeContext,
) {
  final scope = storeContext.serviceScope;
  if (scope != null) return {scope};
  return storeContext.availableServicesForSelectedBranch.toSet();
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999.r),
      child: Container(
        margin: EdgeInsets.only(right: 8.w),
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 7.h),
        decoration: BoxDecoration(
          color: selected ? color : color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999.r),
          border: Border.all(color: selected ? color : colors.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.sp,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : colors.textPrimary,
          ),
        ),
      ),
    );
  }
}

class _ChatThreadTile extends StatelessWidget {
  final VendorChatThread thread;
  final VoidCallback onTap;
  final VoidCallback onOpenOrder;
  final String timeLabel;

  const _ChatThreadTile({
    required this.thread,
    required this.onTap,
    required this.onOpenOrder,
    required this.timeLabel,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final serviceColor = _serviceColor(colors, thread.serviceType);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14.r),
      child: Container(
        margin: EdgeInsets.only(bottom: 10.h),
        padding: EdgeInsets.all(12.r),
        decoration: BoxDecoration(
          color: colors.backgroundPrimary,
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(
            color: thread.isAtRisk
                ? colors.error.withValues(alpha: 0.35)
                : colors.border,
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 44.w,
                  height: 44.w,
                  decoration: BoxDecoration(
                    color: serviceColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Icon(
                    thread.counterpartType == VendorChatCounterpartType.customer
                        ? Icons.person_outline_rounded
                        : Icons.delivery_dining_rounded,
                    color: serviceColor,
                    size: 20.sp,
                  ),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              '${thread.orderId} • ${thread.counterpartType.label}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13.sp,
                                fontWeight: FontWeight.w800,
                                color: colors.textPrimary,
                              ),
                            ),
                          ),
                          if (thread.unreadCount > 0) ...[
                            SizedBox(width: 6.w),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 6.w,
                                vertical: 2.h,
                              ),
                              decoration: BoxDecoration(
                                color: colors.vendorPrimaryBlue,
                                borderRadius: BorderRadius.circular(999.r),
                              ),
                              child: Text(
                                thread.unreadCount > 9
                                    ? '9+'
                                    : '${thread.unreadCount}',
                                style: TextStyle(
                                  fontSize: 10.sp,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        thread.counterpartName,
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w600,
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 6.w),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      timeLabel,
                      style: TextStyle(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w700,
                        color: colors.textSecondary,
                      ),
                    ),
                    SizedBox(height: 6.h),
                    IconButton(
                      onPressed: onOpenOrder,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints.tightFor(
                        width: 28,
                        height: 28,
                      ),
                      icon: Icon(
                        Icons.open_in_new_rounded,
                        size: 18.sp,
                        color: colors.vendorPrimaryBlue,
                      ),
                      tooltip: 'Open linked order',
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(height: 10.h),
            Row(
              children: [
                Expanded(
                  child: Text(
                    thread.lastMessage,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w500,
                      color: colors.textSecondary,
                    ),
                  ),
                ),
                SizedBox(width: 8.w),
                _Tag(label: thread.serviceType.label, color: serviceColor),
                if (thread.isAtRisk) ...[
                  SizedBox(width: 6.w),
                  _Tag(label: 'At Risk', color: colors.error),
                ],
                if (thread.hasOpenIssue) ...[
                  SizedBox(width: 6.w),
                  _Tag(label: 'Issue', color: colors.warning),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String label;
  final Color color;

  const _Tag({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 3.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999.r),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10.sp,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
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
