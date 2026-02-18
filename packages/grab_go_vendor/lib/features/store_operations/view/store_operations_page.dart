import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:grab_go_vendor/features/auth/model/vendor_service_option.dart';
import 'package:grab_go_vendor/features/store_context/viewmodel/store_context_viewmodel.dart';
import 'package:grab_go_vendor/features/store_operations/viewmodel/store_operations_viewmodel.dart';
import 'package:grab_go_vendor/shared/viewmodel/vendor_preview_session_viewmodel.dart';
import 'package:provider/provider.dart';

class StoreOperationsPage extends StatelessWidget {
  const StoreOperationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Scaffold(
      backgroundColor: colors.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: colors.backgroundPrimary,
        elevation: 0,
        title: Text(
          'Store Operations',
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.w800,
            color: colors.textPrimary,
          ),
        ),
      ),
      body: SafeArea(
        child:
            Consumer3<
              VendorStoreOperationsViewModel,
              VendorStoreContextViewModel,
              VendorPreviewSessionViewModel
            >(
              builder: (context, viewModel, storeContext, previewSession, _) {
                final visibleServices = _visibleVendorServices(
                  storeContext,
                ).toList()..sort((a, b) => a.index.compareTo(b.index));

                return SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: 20.w,
                    vertical: 12.h,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        visibleServices.isEmpty
                            ? 'No services are active for this profile and store context.'
                            : 'Preview: ${previewSession.activeProfile.title}',
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w600,
                          color: colors.textSecondary,
                        ),
                      ),
                      SizedBox(height: 10.h),
                      _OutageStatusCard(viewModel: viewModel),
                      SizedBox(height: 12.h),
                      _SectionCard(
                        title: 'Store State',
                        child: Column(
                          children: [
                            _SwitchRow(
                              title: 'Store Open',
                              subtitle:
                                  'Allow branch to receive operations traffic',
                              value: viewModel.isStoreOpen,
                              activeColor: colors.success,
                              onChanged: (value) async {
                                if (!value) {
                                  final allowed = await _confirmAction(
                                    context,
                                    title: 'Close Store?',
                                    message:
                                        'This blocks incoming operations until reopened.',
                                  );
                                  if (!allowed) return;
                                }
                                viewModel.setStoreOpen(value);
                              },
                            ),
                            _SwitchRow(
                              title: 'Accepting Orders',
                              subtitle:
                                  'Queue new customer orders for this branch',
                              value: viewModel.acceptsOrders,
                              activeColor: colors.vendorPrimaryBlue,
                              onChanged: (value) async {
                                if (!value) {
                                  final allowed = await _confirmAction(
                                    context,
                                    title: 'Pause New Orders?',
                                    message:
                                        'New orders will stop until re-enabled.',
                                  );
                                  if (!allowed) return;
                                }
                                viewModel.setAcceptsOrders(value);
                              },
                            ),
                            Row(
                              children: [
                                Expanded(
                                  child: AppButton(
                                    buttonText: viewModel.isPaused
                                        ? 'Resume Store'
                                        : 'Pause Store',
                                    onPressed: viewModel.isPaused
                                        ? viewModel.resumeStore
                                        : () => _showPauseSheet(context),
                                    backgroundColor: viewModel.isPaused
                                        ? colors.success
                                        : colors.warning,
                                    borderRadius: KBorderSize.borderRadius12,
                                    textStyle: TextStyle(
                                      color: Colors.white,
                                      fontSize: 13.sp,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 12.h),
                      _SectionCard(
                        title: 'Service Toggles',
                        child: visibleServices.isEmpty
                            ? Text(
                                'No service toggles available for the selected scope.',
                                style: TextStyle(
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w600,
                                  color: colors.textSecondary,
                                ),
                              )
                            : Column(
                                children: visibleServices.map((service) {
                                  return _ServiceToggleRow(
                                    serviceType: service,
                                    isEnabled: viewModel.isServiceEnabled(
                                      service,
                                    ),
                                    onChanged: (value) => viewModel
                                        .setServiceEnabled(service, value),
                                  );
                                }).toList(),
                              ),
                      ),
                      SizedBox(height: 12.h),
                      _SectionCard(
                        title: 'Prep & Fulfillment',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Prep time target: ${viewModel.prepTimeMinutes} mins',
                              style: TextStyle(
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w700,
                                color: colors.textPrimary,
                              ),
                            ),
                            Slider(
                              value: viewModel.prepTimeMinutes.toDouble(),
                              min: 10,
                              max: 90,
                              divisions: 16,
                              activeColor: colors.vendorPrimaryBlue,
                              label: '${viewModel.prepTimeMinutes} mins',
                              onChanged: (value) =>
                                  viewModel.setPrepTimeMinutes(value.round()),
                            ),
                            _SwitchRow(
                              title: 'Pickup Enabled',
                              subtitle: 'Allow pickup fulfillment orders',
                              value: viewModel.pickupEnabled,
                              activeColor: colors.vendorPrimaryBlue,
                              onChanged: viewModel.setPickupEnabled,
                            ),
                            _SwitchRow(
                              title: 'Delivery Enabled',
                              subtitle: 'Allow rider delivery fulfillment',
                              value: viewModel.deliveryEnabled,
                              activeColor: colors.vendorPrimaryBlue,
                              onChanged: viewModel.setDeliveryEnabled,
                            ),
                            _SwitchRow(
                              title: 'Auto Accept Orders',
                              subtitle:
                                  'Auto move new orders to accepted queue',
                              value: viewModel.autoAcceptOrders,
                              activeColor: colors.vendorPrimaryBlue,
                              onChanged: viewModel.setAutoAcceptOrders,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
      ),
    );
  }

  Future<void> _showPauseSheet(BuildContext context) async {
    final colors = context.appColors;
    final viewModel = context.read<VendorStoreOperationsViewModel>();
    final noteController = TextEditingController();
    String? selectedReason;
    Duration? selectedDuration;
    String? reasonError;

    const presetReasons = [
      'Kitchen overload',
      'Inventory outage',
      'Power interruption',
      'Staff shortage',
      'System maintenance',
    ];

    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: colors.backgroundPrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(18.r)),
        ),
        builder: (sheetContext) {
          return StatefulBuilder(
            builder: (sheetContext, setState) {
              final customReason = noteController.text.trim();
              final reason = (selectedReason ?? '').trim().isNotEmpty
                  ? selectedReason!.trim()
                  : customReason;

              return Padding(
                padding: EdgeInsets.fromLTRB(
                  16.w,
                  12.h,
                  16.w,
                  20.h + MediaQuery.viewInsetsOf(sheetContext).bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pause Store',
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w800,
                        color: colors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      'Reason is required. You can also set an optional auto-resume timer.',
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w500,
                        color: colors.textSecondary,
                      ),
                    ),
                    SizedBox(height: 12.h),
                    Wrap(
                      spacing: 8.w,
                      runSpacing: 8.h,
                      children: presetReasons.map((entry) {
                        final selected = selectedReason == entry;
                        return InkWell(
                          onTap: () {
                            setState(() {
                              selectedReason = entry;
                              reasonError = null;
                            });
                          },
                          borderRadius: BorderRadius.circular(999.r),
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 10.w,
                              vertical: 6.h,
                            ),
                            decoration: BoxDecoration(
                              color: selected
                                  ? colors.warning
                                  : colors.warning.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(999.r),
                              border: Border.all(
                                color: selected
                                    ? colors.warning
                                    : colors.border,
                              ),
                            ),
                            child: Text(
                              entry,
                              style: TextStyle(
                                fontSize: 11.sp,
                                fontWeight: FontWeight.w700,
                                color: selected
                                    ? Colors.white
                                    : colors.textPrimary,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    SizedBox(height: 12.h),
                    TextField(
                      controller: noteController,
                      onChanged: (_) => setState(() => reasonError = null),
                      decoration: InputDecoration(
                        labelText: 'Or enter custom reason',
                        hintText: 'Type pause reason',
                        errorText: reasonError,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                      ),
                    ),
                    SizedBox(height: 12.h),
                    Text(
                      'Auto-resume',
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Wrap(
                      spacing: 8.w,
                      runSpacing: 8.h,
                      children: [
                        _DurationChip(
                          label: 'None',
                          selected: selectedDuration == null,
                          onTap: () => setState(() => selectedDuration = null),
                        ),
                        _DurationChip(
                          label: '30m',
                          selected:
                              selectedDuration == const Duration(minutes: 30),
                          onTap: () => setState(
                            () =>
                                selectedDuration = const Duration(minutes: 30),
                          ),
                        ),
                        _DurationChip(
                          label: '1h',
                          selected:
                              selectedDuration == const Duration(hours: 1),
                          onTap: () => setState(
                            () => selectedDuration = const Duration(hours: 1),
                          ),
                        ),
                        _DurationChip(
                          label: '2h',
                          selected:
                              selectedDuration == const Duration(hours: 2),
                          onTap: () => setState(
                            () => selectedDuration = const Duration(hours: 2),
                          ),
                        ),
                        _DurationChip(
                          label: '4h',
                          selected:
                              selectedDuration == const Duration(hours: 4),
                          onTap: () => setState(
                            () => selectedDuration = const Duration(hours: 4),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 14.h),
                    SizedBox(
                      width: double.infinity,
                      child: AppButton(
                        buttonText: 'Confirm Pause',
                        onPressed: () {
                          final finalReason = reason.trim();
                          if (finalReason.isEmpty) {
                            setState(
                              () => reasonError = 'Pause reason is required',
                            );
                            return;
                          }
                          viewModel.pauseStore(
                            reason: finalReason,
                            autoResumeAfter: selectedDuration,
                          );
                          Navigator.pop(sheetContext);
                        },
                        backgroundColor: colors.warning,
                        borderRadius: KBorderSize.borderRadius12,
                        textStyle: TextStyle(
                          color: Colors.white,
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      );
    } finally {
      noteController.dispose();
    }
  }

  Future<bool> _confirmAction(
    BuildContext context, {
    required String title,
    required String message,
  }) async {
    final colors = context.appColors;
    final shouldProceed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: colors.backgroundPrimary,
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text('Continue', style: TextStyle(color: colors.error)),
            ),
          ],
        );
      },
    );
    return shouldProceed ?? false;
  }
}

class _OutageStatusCard extends StatelessWidget {
  final VendorStoreOperationsViewModel viewModel;

  const _OutageStatusCard({required this.viewModel});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final hasOutage = viewModel.hasOutage;
    final color = hasOutage ? colors.error : colors.success;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(12.r),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                hasOutage
                    ? Icons.warning_amber_rounded
                    : Icons.check_circle_outline_rounded,
                size: 18.sp,
                color: color,
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(
                  hasOutage
                      ? viewModel.outageHeadline
                      : 'Store is operating normally',
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 6.h),
          Text(
            hasOutage
                ? viewModel.outageDetail
                : 'All critical services are active and accepting orders.',
            style: TextStyle(
              fontSize: 12.sp,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
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

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(14.r),
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
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w800,
              color: colors.textPrimary,
            ),
          ),
          SizedBox(height: 10.h),
          child,
        ],
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final Color activeColor;
  final ValueChanged<bool> onChanged;

  const _SwitchRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.activeColor,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Padding(
      padding: EdgeInsets.only(bottom: 10.h),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w500,
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeTrackColor: activeColor,
          ),
        ],
      ),
    );
  }
}

class _ServiceToggleRow extends StatelessWidget {
  final VendorServiceType serviceType;
  final bool isEnabled;
  final ValueChanged<bool> onChanged;

  const _ServiceToggleRow({
    required this.serviceType,
    required this.isEnabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final color = switch (serviceType) {
      VendorServiceType.food => colors.serviceFood,
      VendorServiceType.grocery => colors.serviceGrocery,
      VendorServiceType.pharmacy => colors.servicePharmacy,
      VendorServiceType.grabMart => colors.serviceGrabMart,
    };
    final icon = switch (serviceType) {
      VendorServiceType.food => Icons.restaurant_rounded,
      VendorServiceType.grocery => Icons.local_grocery_store_rounded,
      VendorServiceType.pharmacy => Icons.local_pharmacy_outlined,
      VendorServiceType.grabMart => Icons.shopping_bag_outlined,
    };
    final label = switch (serviceType) {
      VendorServiceType.food => 'Food',
      VendorServiceType.grocery => 'Grocery',
      VendorServiceType.pharmacy => 'Pharmacy',
      VendorServiceType.grabMart => 'GrabMart',
    };

    return Padding(
      padding: EdgeInsets.only(bottom: 10.h),
      child: Row(
        children: [
          Container(
            width: 36.w,
            height: 36.w,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: Icon(icon, color: color, size: 18.sp),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13.sp,
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
              ),
            ),
          ),
          Switch.adaptive(
            value: isEnabled,
            onChanged: onChanged,
            activeTrackColor: color,
          ),
        ],
      ),
    );
  }
}

class _DurationChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _DurationChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999.r),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
        decoration: BoxDecoration(
          color: selected
              ? colors.vendorPrimaryBlue
              : colors.vendorPrimaryBlue.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999.r),
          border: Border.all(
            color: selected ? colors.vendorPrimaryBlue : colors.border,
          ),
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
