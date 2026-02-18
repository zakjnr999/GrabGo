import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:grab_go_vendor/features/orders/model/vendor_order_summary.dart';
import 'package:grab_go_vendor/features/orders/view/order_audit_timeline_page.dart';
import 'package:grab_go_vendor/features/orders/view/order_issue_timeline_page.dart';
import 'package:grab_go_vendor/features/orders/viewmodel/order_detail_viewmodel.dart';
import 'package:provider/provider.dart';

class OrderDetailPage extends StatelessWidget {
  final VendorOrderSummary order;

  const OrderDetailPage({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => OrderDetailViewModel(order: order),
      child: const _OrderDetailView(),
    );
  }
}

class _OrderDetailView extends StatelessWidget {
  const _OrderDetailView();

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Consumer<OrderDetailViewModel>(
      builder: (context, viewModel, _) {
        final order = viewModel.order;

        return Scaffold(
          backgroundColor: colors.backgroundPrimary,
          appBar: AppBar(
            backgroundColor: colors.backgroundPrimary,
            elevation: 0,
            centerTitle: false,
            title: Text(
              'Order ${order.id}',
              style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w800, color: colors.textPrimary),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => OrderAuditTimelinePage(orderId: order.id, entries: viewModel.auditEntries),
                  ),
                ),
                child: Text(
                  'Audit',
                  style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w700, color: colors.vendorPrimaryBlue),
                ),
              ),
            ],
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _HeaderCard(
                    serviceType: order.serviceType,
                    status: viewModel.currentStatus,
                    elapsedLabel: order.elapsedLabel,
                    isAtRisk: order.isAtRisk,
                  ),
                  SizedBox(height: 10.h),
                  _ContactCard(
                    customerName: order.customerName,
                    customerPhone: order.customerPhone,
                    riderName: order.riderName,
                    riderEtaLabel: order.riderEtaLabel,
                  ),
                  SizedBox(height: 10.h),
                  if (order.requiresPrescription)
                    _InfoBanner(
                      icon: Icons.local_pharmacy_outlined,
                      color: colors.servicePharmacy,
                      message: 'Prescription-required order. Complete manual review before final dispatch.',
                    ),
                  if (order.isPickupOrder)
                    Padding(
                      padding: EdgeInsets.only(top: 8.h),
                      child: _InfoBanner(
                        icon: Icons.pin_outlined,
                        color: colors.vendorPrimaryBlue,
                        message: 'Pickup order. Verify customer pickup OTP before handover.',
                      ),
                    ),
                  SizedBox(height: 10.h),
                  _SectionCard(
                    title: 'Items',
                    child: Column(
                      children: order.items.map((item) {
                        return Padding(
                          padding: EdgeInsets.only(bottom: 10.h),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 24.w,
                                height: 24.w,
                                decoration: BoxDecoration(color: colors.backgroundSecondary, shape: BoxShape.circle),
                                child: Center(
                                  child: Text(
                                    '${item.quantity}',
                                    style: TextStyle(
                                      fontSize: 11.sp,
                                      fontWeight: FontWeight.w700,
                                      color: colors.textPrimary,
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(width: 8.w),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.name,
                                      style: TextStyle(
                                        fontSize: 13.sp,
                                        fontWeight: FontWeight.w700,
                                        color: colors.textPrimary,
                                      ),
                                    ),
                                    if (item.note != null)
                                      Padding(
                                        padding: EdgeInsets.only(top: 2.h),
                                        child: Text(
                                          'Note: ${item.note}',
                                          style: TextStyle(
                                            fontSize: 11.sp,
                                            fontWeight: FontWeight.w600,
                                            color: colors.textSecondary,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              Text(
                                'GHS ${(item.unitPrice * item.quantity).toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w700,
                                  color: colors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  SizedBox(height: 10.h),
                  _SectionCard(
                    title: 'Order Totals',
                    child: Column(
                      children: [
                        _PriceRow(label: 'Subtotal', value: order.subtotal),
                        SizedBox(height: 6.h),
                        _PriceRow(label: 'Delivery Fee', value: order.deliveryFee),
                        Divider(height: 18.h, color: colors.divider),
                        _PriceRow(label: 'Total', value: order.total, emphasized: true),
                      ],
                    ),
                  ),
                  SizedBox(height: 10.h),
                  _SectionCard(
                    title: 'Timeline',
                    child: Column(
                      children: order.timelineEntries.map((entry) {
                        return Padding(
                          padding: EdgeInsets.only(bottom: 10.h),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 10.w,
                                height: 10.w,
                                margin: EdgeInsets.only(top: 4.h),
                                decoration: BoxDecoration(
                                  color: entry.isWarning ? colors.warning : colors.success,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              SizedBox(width: 8.w),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      entry.title,
                                      style: TextStyle(
                                        fontSize: 12.sp,
                                        fontWeight: FontWeight.w700,
                                        color: colors.textPrimary,
                                      ),
                                    ),
                                    SizedBox(height: 2.h),
                                    Text(
                                      entry.subtitle,
                                      style: TextStyle(
                                        fontSize: 11.sp,
                                        fontWeight: FontWeight.w500,
                                        color: colors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                entry.timeLabel,
                                style: TextStyle(
                                  fontSize: 11.sp,
                                  fontWeight: FontWeight.w600,
                                  color: colors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  SizedBox(height: 10.h),
                  _SectionCard(
                    title: 'Actions',
                    child: Wrap(
                      spacing: 8.w,
                      runSpacing: 8.h,
                      children: [
                        _ActionChip(
                          label: 'Status Actions',
                          icon: Icons.playlist_add_check_rounded,
                          onTap: () => _showOrderActionsSheet(context, viewModel),
                        ),
                        _ActionChip(
                          label: 'Pickup OTP',
                          icon: Icons.pin_outlined,
                          onTap: () => _showPickupOtpSheet(context, viewModel),
                        ),
                        _ActionChip(
                          label: 'Prescription',
                          icon: Icons.local_pharmacy_outlined,
                          onTap: order.requiresPrescription
                              ? () => _showPrescriptionReviewSheet(context, viewModel)
                              : null,
                        ),
                        _ActionChip(
                          label: 'Item Change',
                          icon: Icons.swap_horiz_rounded,
                          onTap: () => _showSubstitutionSheet(context, viewModel),
                        ),
                        _ActionChip(
                          label: 'Report Issue',
                          icon: Icons.flag_outlined,
                          onTap: () => _showIssueReportSheet(context, viewModel),
                        ),
                        _ActionChip(
                          label: 'Issue Timeline',
                          icon: Icons.timeline_outlined,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  OrderIssueTimelinePage(orderId: order.id, entries: viewModel.issueEntries),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showOrderActionsSheet(BuildContext context, OrderDetailViewModel viewModel) async {
    final colors = context.appColors;
    final actions = VendorOrderActionType.values;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.backgroundPrimary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18.r))),
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 20.h),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Order Actions',
                  style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w800, color: colors.textPrimary),
                ),
                SizedBox(height: 10.h),
                ...actions.map((action) {
                  final reason = viewModel.reasonActionUnavailable(action);
                  final enabled = reason == null;
                  return Container(
                    margin: EdgeInsets.only(bottom: 8.h),
                    decoration: BoxDecoration(
                      border: Border.all(color: colors.border),
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: ListTile(
                      title: Text(
                        action.label,
                        style: TextStyle(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w700,
                          color: enabled ? colors.textPrimary : colors.textSecondary,
                        ),
                      ),
                      subtitle: reason == null
                          ? null
                          : Text(
                              reason,
                              style: TextStyle(
                                fontSize: 11.sp,
                                fontWeight: FontWeight.w500,
                                color: colors.textSecondary,
                              ),
                            ),
                      trailing: Icon(
                        Icons.chevron_right_rounded,
                        color: enabled ? colors.vendorPrimaryBlue : colors.textSecondary,
                      ),
                      onTap: !enabled
                          ? null
                          : () {
                              final updated = viewModel.applyAction(action);
                              Navigator.pop(context);
                              if (!updated) return;
                              ScaffoldMessenger.of(
                                context,
                              ).showSnackBar(SnackBar(content: Text('${action.label} saved (UI mock).')));
                            },
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showPickupOtpSheet(BuildContext context, OrderDetailViewModel viewModel) async {
    final colors = context.appColors;
    viewModel.clearPickupCodeError();
    viewModel.pickupCodeController.clear();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.backgroundPrimary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18.r))),
      builder: (_) {
        return Padding(
          padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 20.h + MediaQuery.viewInsetsOf(context).bottom),
          child: Consumer<OrderDetailViewModel>(
            builder: (context, model, child) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pickup Code Verification',
                    style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w800, color: colors.textPrimary),
                  ),
                  SizedBox(height: 10.h),
                  AppTextInput(
                    controller: model.pickupCodeController,
                    label: 'Pickup Code',
                    hintText: 'Enter 6-digit code',
                    keyboardType: TextInputType.number,
                    errorText: model.pickupCodeError,
                    fillColor: colors.backgroundPrimary,
                    borderColor: colors.inputBorder,
                    borderActiveColor: colors.vendorPrimaryBlue,
                    borderRadius: KBorderSize.borderRadius12,
                    cursorColor: colors.vendorPrimaryBlue,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
                  ),
                  SizedBox(height: 10.h),
                  SizedBox(
                    width: double.infinity,
                    child: AppButton(
                      buttonText: 'Verify Code',
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        if (!model.validatePickupCode()) return;
                        model.addAuditEntry(
                          action: 'Pickup code verified',
                          details: 'Customer handover completed with OTP.',
                        );
                        Navigator.pop(context);
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(const SnackBar(content: Text('Pickup code verified (UI mock).')));
                      },
                      backgroundColor: colors.vendorPrimaryBlue,
                      borderRadius: KBorderSize.borderRadius12,
                      textStyle: TextStyle(color: Colors.white, fontSize: 14.sp, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _showPrescriptionReviewSheet(BuildContext context, OrderDetailViewModel viewModel) async {
    final colors = context.appColors;
    viewModel.prescriptionDecisionNoteController.clear();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.backgroundPrimary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18.r))),
      builder: (_) {
        return Padding(
          padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 20.h + MediaQuery.viewInsetsOf(context).bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Prescription Review',
                style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w800, color: colors.textPrimary),
              ),
              SizedBox(height: 10.h),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 90.h,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12.r),
                        border: Border.all(color: colors.border),
                        color: colors.backgroundSecondary,
                      ),
                      child: Center(
                        child: Text(
                          'Prescription Image 1',
                          style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w600, color: colors.textSecondary),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Container(
                      height: 90.h,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12.r),
                        border: Border.all(color: colors.border),
                        color: colors.backgroundSecondary,
                      ),
                      child: Center(
                        child: Text(
                          'Prescription Image 2',
                          style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w600, color: colors.textSecondary),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 10.h),
              AppTextInput(
                controller: viewModel.prescriptionDecisionNoteController,
                label: 'Review Note (Optional)',
                hintText: 'Add review details',
                fillColor: colors.backgroundPrimary,
                borderColor: colors.inputBorder,
                borderActiveColor: colors.vendorPrimaryBlue,
                borderRadius: KBorderSize.borderRadius12,
                cursorColor: colors.vendorPrimaryBlue,
              ),
              SizedBox(height: 10.h),
              Row(
                children: [
                  Expanded(
                    child: AppButton(
                      buttonText: 'Reject',
                      onPressed: () {
                        viewModel.addAuditEntry(
                          action: 'Prescription rejected',
                          details: viewModel.prescriptionDecisionNoteController.text.trim().isEmpty
                              ? 'Rejected without additional note.'
                              : viewModel.prescriptionDecisionNoteController.text.trim(),
                        );
                        Navigator.pop(context);
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(const SnackBar(content: Text('Prescription rejected (UI mock).')));
                      },
                      backgroundColor: colors.error,
                      borderRadius: KBorderSize.borderRadius12,
                      textStyle: TextStyle(color: Colors.white, fontSize: 14.sp, fontWeight: FontWeight.w700),
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: AppButton(
                      buttonText: 'Approve',
                      onPressed: () {
                        viewModel.addAuditEntry(
                          action: 'Prescription approved',
                          details: viewModel.prescriptionDecisionNoteController.text.trim().isEmpty
                              ? 'Approved by vendor staff.'
                              : viewModel.prescriptionDecisionNoteController.text.trim(),
                        );
                        Navigator.pop(context);
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(const SnackBar(content: Text('Prescription approved (UI mock).')));
                      },
                      backgroundColor: colors.success,
                      borderRadius: KBorderSize.borderRadius12,
                      textStyle: TextStyle(color: Colors.white, fontSize: 14.sp, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showSubstitutionSheet(BuildContext context, OrderDetailViewModel viewModel) async {
    final colors = context.appColors;
    viewModel.substitutionNoteController.clear();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.backgroundPrimary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18.r))),
      builder: (_) {
        final replaceableItems = viewModel.order.items.where((e) => e.canBeReplaced).toList();
        return Padding(
          padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 20.h + MediaQuery.viewInsetsOf(context).bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Item Change Proposal',
                style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w800, color: colors.textPrimary),
              ),
              SizedBox(height: 10.h),
              if (replaceableItems.isEmpty)
                Text(
                  'No replaceable items in this order.',
                  style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w600, color: colors.textSecondary),
                )
              else
                ...replaceableItems.map((item) {
                  return Container(
                    margin: EdgeInsets.only(bottom: 8.h),
                    padding: EdgeInsets.all(10.r),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(color: colors.border),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.name,
                            style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w700, color: colors.textPrimary),
                          ),
                        ),
                        Text(
                          'x${item.quantity}',
                          style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w700, color: colors.textSecondary),
                        ),
                      ],
                    ),
                  );
                }),
              AppTextInput(
                controller: viewModel.substitutionNoteController,
                label: 'Proposal Note',
                hintText: 'Example: Replace unavailable item with similar product',
                fillColor: colors.backgroundPrimary,
                borderColor: colors.inputBorder,
                borderActiveColor: colors.vendorPrimaryBlue,
                borderRadius: KBorderSize.borderRadius12,
                cursorColor: colors.vendorPrimaryBlue,
              ),
              SizedBox(height: 10.h),
              SizedBox(
                width: double.infinity,
                child: AppButton(
                  buttonText: 'Submit Proposal',
                  onPressed: () {
                    final note = viewModel.substitutionNoteController.text.trim();
                    viewModel.addAuditEntry(
                      action: 'Item change proposed',
                      details: note.isEmpty ? 'Replacement proposal sent to customer.' : note,
                    );
                    Navigator.pop(context);
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(const SnackBar(content: Text('Item change proposal submitted (UI mock).')));
                  },
                  backgroundColor: colors.vendorPrimaryBlue,
                  borderRadius: KBorderSize.borderRadius12,
                  textStyle: TextStyle(color: Colors.white, fontSize: 14.sp, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showIssueReportSheet(BuildContext context, OrderDetailViewModel viewModel) async {
    final colors = context.appColors;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.backgroundPrimary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18.r))),
      builder: (_) {
        const issueTypes = ['Item Unavailable', 'Customer Unreachable', 'Rider Delay', 'Payment Problem', 'Other'];
        return Padding(
          padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 20.h + MediaQuery.viewInsetsOf(context).bottom),
          child: Consumer<OrderDetailViewModel>(
            builder: (context, model, child) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Report Issue',
                    style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w800, color: colors.textPrimary),
                  ),
                  SizedBox(height: 10.h),
                  Wrap(
                    spacing: 8.w,
                    runSpacing: 8.h,
                    children: issueTypes.map((type) {
                      final selected = model.selectedIssueType == type;
                      return InkWell(
                        onTap: () => model.selectIssueType(type),
                        borderRadius: BorderRadius.circular(999.r),
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                          decoration: BoxDecoration(
                            color: selected
                                ? colors.vendorPrimaryBlue.withValues(alpha: 0.16)
                                : colors.backgroundSecondary,
                            borderRadius: BorderRadius.circular(999.r),
                            border: Border.all(color: selected ? colors.vendorPrimaryBlue : colors.border),
                          ),
                          child: Text(
                            type,
                            style: TextStyle(
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w700,
                              color: selected ? colors.vendorPrimaryBlue : colors.textSecondary,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  SizedBox(height: 10.h),
                  AppTextInput(
                    controller: model.issueNoteController,
                    label: 'Issue Details',
                    hintText: 'Describe what happened',
                    fillColor: colors.backgroundPrimary,
                    borderColor: colors.inputBorder,
                    borderActiveColor: colors.vendorPrimaryBlue,
                    borderRadius: KBorderSize.borderRadius12,
                    cursorColor: colors.vendorPrimaryBlue,
                  ),
                  SizedBox(height: 10.h),
                  SizedBox(
                    width: double.infinity,
                    child: AppButton(
                      buttonText: 'Submit Issue',
                      onPressed: () {
                        final submitted = model.submitIssue();
                        if (!submitted) {
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(const SnackBar(content: Text('Select an issue type to continue.')));
                          return;
                        }
                        Navigator.pop(context);
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(const SnackBar(content: Text('Issue submitted (UI mock).')));
                      },
                      backgroundColor: colors.vendorPrimaryBlue,
                      borderRadius: KBorderSize.borderRadius12,
                      textStyle: TextStyle(color: Colors.white, fontSize: 14.sp, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final OrderServiceType serviceType;
  final VendorOrderStatus status;
  final String elapsedLabel;
  final bool isAtRisk;

  const _HeaderCard({
    required this.serviceType,
    required this.status,
    required this.elapsedLabel,
    required this.isAtRisk,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final serviceColor = _serviceColor(colors, serviceType);
    final statusColor = _statusColor(colors, status);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(12.r),
      decoration: BoxDecoration(
        color: colors.backgroundPrimary,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 5.h),
            decoration: BoxDecoration(
              color: serviceColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(999.r),
            ),
            child: Text(
              serviceType.label,
              style: TextStyle(fontSize: 10.sp, fontWeight: FontWeight.w700, color: serviceColor),
            ),
          ),
          SizedBox(width: 8.w),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 5.h),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(999.r),
            ),
            child: Text(
              status.label,
              style: TextStyle(fontSize: 10.sp, fontWeight: FontWeight.w700, color: statusColor),
            ),
          ),
          const Spacer(),
          Text(
            elapsedLabel,
            style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w700, color: colors.textSecondary),
          ),
          if (isAtRisk)
            Padding(
              padding: EdgeInsets.only(left: 8.w),
              child: Icon(Icons.warning_amber_rounded, size: 16.sp, color: colors.warning),
            ),
        ],
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  final String customerName;
  final String customerPhone;
  final String riderName;
  final String riderEtaLabel;

  const _ContactCard({
    required this.customerName,
    required this.customerPhone,
    required this.riderName,
    required this.riderEtaLabel,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(12.r),
      decoration: BoxDecoration(
        color: colors.backgroundPrimary,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Customer',
            style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w700, color: colors.textSecondary),
          ),
          SizedBox(height: 2.h),
          Text(
            '$customerName • $customerPhone',
            style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700, color: colors.textPrimary),
          ),
          SizedBox(height: 8.h),
          Divider(height: 1, color: colors.divider),
          SizedBox(height: 8.h),
          Text(
            'Rider',
            style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w700, color: colors.textSecondary),
          ),
          SizedBox(height: 2.h),
          Text(
            '$riderName • $riderEtaLabel',
            style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700, color: colors.textPrimary),
          ),
        ],
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String message;

  const _InfoBanner({required this.icon, required this.color, required this.message});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 10.h),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12.r)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16.sp, color: color),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(
              message,
              style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w600, color: colors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(12.r),
      decoration: BoxDecoration(
        color: colors.backgroundPrimary,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w800, color: colors.textPrimary),
          ),
          SizedBox(height: 10.h),
          child,
        ],
      ),
    );
  }
}

class _PriceRow extends StatelessWidget {
  final String label;
  final double value;
  final bool emphasized;

  const _PriceRow({required this.label, required this.value, this.emphasized = false});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12.sp,
            fontWeight: emphasized ? FontWeight.w800 : FontWeight.w600,
            color: colors.textPrimary,
          ),
        ),
        const Spacer(),
        Text(
          'GHS ${value.toStringAsFixed(2)}',
          style: TextStyle(
            fontSize: emphasized ? 13.sp : 12.sp,
            fontWeight: emphasized ? FontWeight.w900 : FontWeight.w700,
            color: colors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _ActionChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  const _ActionChip({required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final enabled = onTap != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(100.r),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 7.h),
        decoration: BoxDecoration(
          color: enabled ? colors.vendorPrimaryBlue.withValues(alpha: 0.1) : colors.backgroundSecondary,
          borderRadius: BorderRadius.circular(100.r),
          border: Border.all(color: enabled ? colors.vendorPrimaryBlue.withValues(alpha: 0.4) : colors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15.sp, color: enabled ? colors.vendorPrimaryBlue : colors.textSecondary),
            SizedBox(width: 6.w),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.sp,
                fontWeight: FontWeight.w700,
                color: enabled ? colors.vendorPrimaryBlue : colors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Color _serviceColor(AppColorsExtension colors, OrderServiceType type) {
  return switch (type) {
    OrderServiceType.food => colors.serviceFood,
    OrderServiceType.grocery => colors.serviceGrocery,
    OrderServiceType.pharmacy => colors.servicePharmacy,
    OrderServiceType.grabmart => colors.serviceGrabMart,
  };
}

Color _statusColor(AppColorsExtension colors, VendorOrderStatus status) {
  return switch (status) {
    VendorOrderStatus.newOrder => colors.vendorPrimaryBlue,
    VendorOrderStatus.accepted => colors.info,
    VendorOrderStatus.preparing => colors.warning,
    VendorOrderStatus.ready => colors.success,
    VendorOrderStatus.handover => colors.accentGreen,
    VendorOrderStatus.cancelled => colors.error,
  };
}
