import 'package:dotted_line/dotted_line.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:grab_go_vendor/features/auth/model/vendor_service_option.dart';
import 'package:grab_go_vendor/features/orders/model/vendor_order_summary.dart';
import 'package:grab_go_vendor/features/orders/view/order_audit_timeline_page.dart';
import 'package:grab_go_vendor/features/orders/view/order_issue_timeline_page.dart';
import 'package:grab_go_vendor/features/orders/viewmodel/order_detail_viewmodel.dart';
import 'package:grab_go_vendor/features/store_context/viewmodel/store_context_viewmodel.dart';
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

class _OrderDetailView extends StatefulWidget {
  const _OrderDetailView();

  @override
  State<_OrderDetailView> createState() => _OrderDetailViewState();
}

class _OrderDetailViewState extends State<_OrderDetailView> {
  final ScrollController _contentScrollController = ScrollController();
  bool _showTopDivider = false;

  @override
  void initState() {
    super.initState();
    _contentScrollController.addListener(_handleScroll);
  }

  void _handleScroll() {
    if (!_contentScrollController.hasClients) return;
    final shouldShow = _contentScrollController.offset > 0.5;
    if (shouldShow == _showTopDivider) return;
    setState(() => _showTopDivider = shouldShow);
  }

  @override
  void dispose() {
    _contentScrollController.removeListener(_handleScroll);
    _contentScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Consumer<OrderDetailViewModel>(
      builder: (context, viewModel, _) {
        final order = viewModel.order;
        var showServiceChip = true;
        try {
          final storeContext = context.watch<VendorStoreContextViewModel>();
          showServiceChip = _visibleVendorServices(storeContext).length > 1;
        } on ProviderNotFoundException {
          showServiceChip = true;
        }

        return Scaffold(
          backgroundColor: colors.backgroundPrimary,
          body: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(20.w, 6.h, 20.w, 8.h),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextButton.icon(
                        onPressed: () => Navigator.of(context).maybePop(),
                        style: TextButton.styleFrom(padding: EdgeInsets.zero, foregroundColor: colors.textSecondary),
                        icon: SvgPicture.asset(
                          Assets.icons.navArrowLeft,
                          package: 'grab_go_shared',
                          width: 18.w,
                          height: 18.w,
                          colorFilter: ColorFilter.mode(colors.textSecondary, BlendMode.srcIn),
                        ),
                        label: Text(
                          'Back',
                          style: TextStyle(color: colors.textSecondary, fontSize: 14.sp, fontWeight: FontWeight.w500),
                        ),
                      ),
                      SizedBox(height: 6.h),
                      Text(
                        'Order details',
                        style: TextStyle(
                          fontSize: 24.sp,
                          fontWeight: FontWeight.w900,
                          color: colors.textPrimary,
                          height: 1.15,
                        ),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              order.id,
                              style: TextStyle(
                                fontSize: 13.sp,
                                fontWeight: FontWeight.w500,
                                color: colors.textSecondary,
                                height: 1.4,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () => Navigator.push(
                              context,
                              CupertinoPageRoute(
                                builder: (_) =>
                                    OrderAuditTimelinePage(orderId: order.id, entries: viewModel.auditEntries),
                              ),
                            ),
                            child: Text(
                              'Audit',
                              style: TextStyle(
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w700,
                                color: colors.vendorPrimaryBlue,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  height: _showTopDivider ? 1.h : 0,
                  color: colors.backgroundSecondary,
                ),
                Expanded(
                  child: SingleChildScrollView(
                    controller: _contentScrollController,
                    padding: EdgeInsets.fromLTRB(20.w, 6.h, 20.w, 20.h),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _HeaderCard(
                          serviceType: order.serviceType,
                          status: viewModel.currentStatus,
                          elapsedLabel: order.elapsedLabel,
                          isAtRisk: order.isAtRisk,
                          showServiceChip: showServiceChip,
                        ),
                        SizedBox(height: 10.h),
                        _ContactCard(
                          customerName: order.customerName,
                          customerPhone: order.customerPhone,
                          status: viewModel.currentStatus,
                          isPickupOrder: order.isPickupOrder,
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
                              message: 'Pickup order. Verify customer pickup OTP before completion.',
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
                                      decoration: BoxDecoration(
                                        color: colors.backgroundSecondary,
                                        shape: BoxShape.circle,
                                      ),
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
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _PriceRow(label: 'Items Subtotal', value: order.subtotal),
                              SizedBox(height: 8.h),
                              DottedLine(
                                dashLength: 6,
                                dashGapLength: 4,
                                lineThickness: 1,
                                dashColor: colors.textSecondary.withAlpha(50),
                              ),
                              SizedBox(height: 12.h),
                              _PriceRow(label: 'Total', value: order.total, emphasized: true),
                              if (!order.isPickupOrder && order.deliveryFee > 0) ...[
                                SizedBox(height: 8.h),
                                Text(
                                  'Delivery fee is included in total.',
                                  style: TextStyle(
                                    fontSize: 11.sp,
                                    fontWeight: FontWeight.w500,
                                    color: colors.textSecondary,
                                  ),
                                ),
                              ],
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
                              if (order.isPickupOrder && viewModel.currentStatus == VendorOrderStatus.ready)
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
                                  CupertinoPageRoute(
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
              ],
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
            padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 20.h),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Align(
                  alignment: Alignment.center,
                  child: Container(
                    width: 40.w,
                    height: 4.h,
                    margin: EdgeInsets.only(bottom: 12.h),
                    decoration: BoxDecoration(
                      color: colors.border,
                      borderRadius: BorderRadius.circular(KBorderSize.border),
                    ),
                  ),
                ),
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
                      trailing: SvgPicture.asset(
                        Assets.icons.navArrowRight,
                        package: 'grab_go_shared',
                        width: 18.w,
                        height: 18.w,
                        colorFilter: ColorFilter.mode(
                          enabled ? colors.vendorPrimaryBlue : colors.textSecondary,
                          BlendMode.srcIn,
                        ),
                      ),
                      onTap: !enabled
                          ? null
                          : () {
                              if (action == VendorOrderActionType.verifyPickupCode) {
                                Navigator.pop(context);
                                _showPickupOtpSheet(context, viewModel);
                                return;
                              }
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
      builder: (sheetContext) {
        return ChangeNotifierProvider.value(
          value: viewModel,
          child: Padding(
            padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 20.h + MediaQuery.viewInsetsOf(sheetContext).bottom),
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
                        buttonText: 'Verify Pickup Code',
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          if (!model.validatePickupCode()) return;
                          final updated = model.applyAction(VendorOrderActionType.verifyPickupCode);
                          if (!updated) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Order is not ready for pickup verification.')),
                            );
                            return;
                          }
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
      builder: (sheetContext) {
        final replaceableItems = viewModel.order.items.where((e) => e.canBeReplaced).toList();
        return Padding(
          padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 20.h + MediaQuery.viewInsetsOf(sheetContext).bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Align(
                alignment: Alignment.center,
                child: Container(
                  width: 40.w,
                  height: 4.h,
                  margin: EdgeInsets.only(bottom: 12.h),
                  decoration: BoxDecoration(
                    color: colors.border,
                    borderRadius: BorderRadius.circular(KBorderSize.border),
                  ),
                ),
              ),
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
                fillColor: colors.backgroundSecondary,
                borderColor: colors.inputBorder,
                borderActiveColor: colors.vendorPrimaryBlue,
                borderRadius: KBorderSize.border,
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
                    Navigator.pop(sheetContext);
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(const SnackBar(content: Text('Item change proposal submitted (UI mock).')));
                  },
                  backgroundColor: colors.vendorPrimaryBlue,
                  borderRadius: KBorderSize.border,
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
    final customIssueTypeController = TextEditingController();
    var selectedIssueType = viewModel.selectedIssueType;
    var showCustomIssueType = false;
    String? issueTypeError;

    const issueTypes = ['Item Unavailable', 'Customer Unreachable', 'Rider Delay', 'Payment Problem'];

    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: colors.backgroundPrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(KBorderSize.borderRadius20)),
        ),
        builder: (sheetContext) {
          return StatefulBuilder(
            builder: (sheetContext, setState) {
              final customIssueType = customIssueTypeController.text.trim();
              final resolvedIssueType = (selectedIssueType ?? '').trim().isNotEmpty
                  ? selectedIssueType!.trim()
                  : (showCustomIssueType ? customIssueType : '');

              return SafeArea(
                top: false,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 20.h + MediaQuery.viewInsetsOf(sheetContext).bottom),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Align(
                        alignment: Alignment.center,
                        child: Container(
                          width: 40.w,
                          height: 4.h,
                          margin: EdgeInsets.only(bottom: 12.h),
                          decoration: BoxDecoration(
                            color: colors.border,
                            borderRadius: BorderRadius.circular(KBorderSize.border),
                          ),
                        ),
                      ),
                      Text(
                        'Report Issue',
                        style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w800, color: colors.textPrimary),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        'Issue type is required. Add optional details for tracking.',
                        style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w500, color: colors.textSecondary),
                      ),
                      SizedBox(height: 16.h),
                      Wrap(
                        spacing: 8.w,
                        runSpacing: 8.h,
                        children: [
                          ...issueTypes.map((entry) {
                            final isSelected = selectedIssueType == entry;
                            return _buildInstructionChip(
                              label: entry,
                              isSelected: isSelected,
                              colors: colors,
                              onTap: () {
                                setState(() {
                                  selectedIssueType = isSelected ? null : entry;
                                  showCustomIssueType = false;
                                  issueTypeError = null;
                                });
                              },
                            );
                          }),
                          _buildCustomInstructionChip(
                            colors: colors,
                            isExpanded: showCustomIssueType,
                            onTap: () {
                              setState(() {
                                showCustomIssueType = !showCustomIssueType;
                                issueTypeError = null;
                                if (showCustomIssueType) {
                                  selectedIssueType = null;
                                } else {
                                  customIssueTypeController.clear();
                                }
                              });
                            },
                          ),
                        ],
                      ),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 260),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        transitionBuilder: (child, animation) {
                          final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
                          return FadeTransition(
                            opacity: curved,
                            child: SizeTransition(sizeFactor: curved, axisAlignment: -1, child: child),
                          );
                        },
                        child: showCustomIssueType
                            ? Padding(
                                key: const ValueKey('custom_issue_type_input'),
                                padding: EdgeInsets.only(top: 12.h),
                                child: AppTextInput(
                                  controller: customIssueTypeController,
                                  onChanged: (_) => setState(() => issueTypeError = null),
                                  label: 'Custom issue type',
                                  hintText: 'Type issue type...',
                                  errorText: issueTypeError,
                                  fillColor: colors.backgroundSecondary,
                                  borderColor: colors.inputBorder,
                                  borderActiveColor: colors.vendorPrimaryBlue,
                                  borderRadius: KBorderSize.border,
                                  cursorColor: colors.vendorPrimaryBlue,
                                ),
                              )
                            : const SizedBox.shrink(key: ValueKey('custom_issue_type_empty')),
                      ),
                      SizedBox(height: 12.h),
                      AppTextInput(
                        controller: viewModel.issueNoteController,
                        label: 'Issue details (optional)',
                        hintText: 'Describe what happened',
                        fillColor: colors.backgroundSecondary,
                        borderColor: colors.inputBorder,
                        borderActiveColor: colors.vendorPrimaryBlue,
                        borderRadius: KBorderSize.border,
                        cursorColor: colors.vendorPrimaryBlue,
                      ),
                      SizedBox(height: 18.h),
                      SizedBox(
                        width: double.infinity,
                        child: AppButton(
                          buttonText: 'Submit Issue',
                          onPressed: () {
                            final finalIssueType = resolvedIssueType.trim();
                            if (finalIssueType.isEmpty) {
                              setState(() => issueTypeError = 'Issue type is required');
                              return;
                            }
                            viewModel.selectIssueType(finalIssueType);
                            final submitted = viewModel.submitIssue();
                            if (!submitted) return;
                            Navigator.pop(sheetContext);
                            ScaffoldMessenger.of(
                              context,
                            ).showSnackBar(const SnackBar(content: Text('Issue submitted (UI mock).')));
                          },
                          backgroundColor: colors.vendorPrimaryBlue,
                          borderRadius: KBorderSize.border,
                          textStyle: TextStyle(color: Colors.white, fontSize: 14.sp, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      );
    } finally {
      customIssueTypeController.dispose();
    }
  }

  Widget _buildInstructionChip({
    required String label,
    required bool isSelected,
    required AppColorsExtension colors,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
        decoration: BoxDecoration(
          color: isSelected ? colors.vendorPrimaryBlue : colors.backgroundSecondary,
          borderRadius: BorderRadius.circular(20.r),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : colors.textPrimary,
            fontSize: 13.sp,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildCustomInstructionChip({
    required AppColorsExtension colors,
    required bool isExpanded,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
        decoration: BoxDecoration(
          color: isExpanded ? colors.vendorPrimaryBlue : colors.backgroundSecondary,
          borderRadius: BorderRadius.circular(20.r),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Custom',
              style: TextStyle(
                color: isExpanded ? Colors.white : colors.textPrimary,
                fontSize: 13.sp,
                fontWeight: isExpanded ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
            SizedBox(width: 4.w),
            SvgPicture.asset(
              isExpanded ? Assets.icons.navArrowUp : Assets.icons.navArrowDown,
              package: 'grab_go_shared',
              height: 16.h,
              width: 16.w,
              colorFilter: ColorFilter.mode(isExpanded ? Colors.white : colors.textPrimary, BlendMode.srcIn),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final OrderServiceType serviceType;
  final VendorOrderStatus status;
  final String elapsedLabel;
  final bool isAtRisk;
  final bool showServiceChip;

  const _HeaderCard({
    required this.serviceType,
    required this.status,
    required this.elapsedLabel,
    required this.isAtRisk,
    required this.showServiceChip,
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
          if (showServiceChip) ...[
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
          ],
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
  final VendorOrderStatus status;
  final bool isPickupOrder;
  final String riderName;
  final String riderEtaLabel;

  const _ContactCard({
    required this.customerName,
    required this.customerPhone,
    required this.status,
    required this.isPickupOrder,
    required this.riderName,
    required this.riderEtaLabel,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final showAssignedRider =
        !isPickupOrder && (status == VendorOrderStatus.ready || status == VendorOrderStatus.pickedUp);
    final showRiderPending =
        !isPickupOrder && (status == VendorOrderStatus.accepted || status == VendorOrderStatus.preparing);
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
          if (isPickupOrder) ...[
            Text(
              'Fulfillment',
              style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w700, color: colors.textSecondary),
            ),
            SizedBox(height: 2.h),
            Text(
              'Customer pickup order',
              style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700, color: colors.textPrimary),
            ),
          ] else if (showAssignedRider) ...[
            Text(
              'Rider',
              style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w700, color: colors.textSecondary),
            ),
            SizedBox(height: 2.h),
            Text(
              '$riderName • $riderEtaLabel',
              style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700, color: colors.textPrimary),
            ),
          ] else if (showRiderPending) ...[
            Text(
              'Rider',
              style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w700, color: colors.textSecondary),
            ),
            SizedBox(height: 2.h),
            Text(
              'Rider assignment pending',
              style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700, color: colors.textPrimary),
            ),
          ],
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
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
        decoration: BoxDecoration(
          color: enabled ? colors.vendorPrimaryBlue.withValues(alpha: 0.1) : colors.backgroundSecondary,
          borderRadius: BorderRadius.circular(100.r),
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

Set<VendorServiceType> _visibleVendorServices(VendorStoreContextViewModel storeContext) {
  final scope = storeContext.serviceScope;
  if (scope != null) return {scope};
  return storeContext.availableServicesForSelectedBranch.toSet();
}

Color _statusColor(AppColorsExtension colors, VendorOrderStatus status) {
  return switch (status) {
    VendorOrderStatus.newOrder => colors.vendorPrimaryBlue,
    VendorOrderStatus.accepted => colors.info,
    VendorOrderStatus.preparing => colors.warning,
    VendorOrderStatus.ready => colors.success,
    VendorOrderStatus.pickedUp => colors.accentGreen,
    VendorOrderStatus.cancelled => colors.error,
  };
}
