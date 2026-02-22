import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:grab_go_shared/shared/widgets/custom_slider.dart';
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
      body: SafeArea(
        child: Consumer3<VendorStoreOperationsViewModel, VendorStoreContextViewModel, VendorPreviewSessionViewModel>(
          builder: (context, viewModel, storeContext, previewSession, _) {
            final visibleServices = _visibleVendorServices(storeContext).toList()
              ..sort((a, b) => a.index.compareTo(b.index));
            final hasMultipleServices = visibleServices.length > 1;

            return SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 6.h),
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
                    'Store Operations',
                    style: TextStyle(
                      fontSize: 24.sp,
                      fontWeight: FontWeight.w900,
                      color: colors.textPrimary,
                      height: 1.15,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    visibleServices.isEmpty
                        ? 'No services are active for this profile and store context.'
                        : hasMultipleServices
                        ? 'Manage store state, service toggles, and fulfillment settings for ${previewSession.activeProfile.title}.'
                        : 'Manage store state and fulfillment settings for ${previewSession.activeProfile.title}.',
                    style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w500,
                      color: colors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                  SizedBox(height: 12.h),
                  _OutageStatusCard(viewModel: viewModel),
                  SizedBox(height: 12.h),
                  _SectionCard(
                    title: 'Store State',
                    child: Column(
                      children: [
                        _SwitchRow(
                          title: 'Store Open',
                          subtitle: 'Allow branch to receive operations traffic',
                          value: viewModel.isStoreOpen,
                          onChanged: (value) async {
                            if (!value) {
                              final allowed = await _confirmAction(
                                context,
                                title: 'Close Store?',
                                message: 'This blocks incoming operations until reopened.',
                              );
                              if (!allowed) return;
                            }
                            viewModel.setStoreOpen(value);
                          },
                        ),
                        _SwitchRow(
                          title: 'Accepting Orders',
                          subtitle: 'Queue new customer orders for this branch',
                          value: viewModel.acceptsOrders,
                          onChanged: (value) async {
                            if (!value) {
                              final allowed = await _confirmAction(
                                context,
                                title: 'Pause New Orders?',
                                message: 'New orders will stop until re-enabled.',
                              );
                              if (!allowed) return;
                            }
                            viewModel.setAcceptsOrders(value);
                          },
                        ),
                        SizedBox(height: 8.h),
                        Row(
                          children: [
                            Expanded(
                              child: AppButton(
                                buttonText: viewModel.isPaused ? 'Resume Store' : 'Pause Store',
                                onPressed: viewModel.isPaused ? viewModel.resumeStore : () => _showPauseSheet(context),
                                backgroundColor: viewModel.isPaused ? colors.success : colors.vendorPrimaryBlue,
                                borderRadius: KBorderSize.border,
                                textStyle: TextStyle(color: Colors.white, fontSize: 13.sp, fontWeight: FontWeight.w700),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 12.h),
                  if (hasMultipleServices) ...[
                    _SectionCard(
                      title: 'Service Toggles',
                      child: Column(
                        children: visibleServices.map((service) {
                          return _ServiceToggleRow(
                            serviceType: service,
                            isEnabled: viewModel.isServiceEnabled(service),
                            onChanged: (value) => viewModel.setServiceEnabled(service, value),
                          );
                        }).toList(),
                      ),
                    ),
                    SizedBox(height: 12.h),
                  ],
                  _SectionCard(
                    title: 'Prep & Fulfillment',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Prep time target: ${viewModel.prepTimeMinutes} mins',
                          style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w700, color: colors.textPrimary),
                        ),
                        SliderTheme(
                          data: SliderThemeData(
                            trackHeight: 8.h,
                            activeTrackColor: colors.vendorPrimaryBlue,
                            inactiveTrackColor: colors.vendorPrimaryBlue.withValues(alpha: 0.16),
                            thumbColor: Colors.white,
                            overlayColor: colors.vendorPrimaryBlue.withValues(alpha: 0.16),
                            thumbShape: CustomSliderThumbShape(
                              enabledThumbRadius: 14.r,
                              thumbColor: colors.vendorPrimaryBlue,
                            ),
                            trackShape: const CustomSliderTrackShape(),
                            overlayShape: RoundSliderOverlayShape(overlayRadius: 22.r),
                            valueIndicatorColor: colors.vendorPrimaryBlue,
                            valueIndicatorTextStyle: TextStyle(
                              color: Colors.white,
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w700,
                            ),
                            tickMarkShape: const RoundSliderTickMarkShape(tickMarkRadius: 2),
                            activeTickMarkColor: Colors.white.withValues(alpha: 0.55),
                            inactiveTickMarkColor: colors.vendorPrimaryBlue.withValues(alpha: 0.3),
                          ),
                          child: Slider(
                            value: viewModel.prepTimeMinutes.toDouble(),
                            min: 10,
                            max: 90,
                            divisions: 16,
                            label: '${viewModel.prepTimeMinutes} mins',
                            onChanged: (value) => viewModel.setPrepTimeMinutes(value.round()),
                          ),
                        ),
                        _SwitchRow(
                          title: 'Pickup Enabled',
                          subtitle: 'Allow pickup fulfillment orders',
                          value: viewModel.pickupEnabled,
                          onChanged: viewModel.setPickupEnabled,
                        ),
                        _SwitchRow(
                          title: 'Delivery Enabled',
                          subtitle: 'Allow rider delivery fulfillment',
                          value: viewModel.deliveryEnabled,
                          onChanged: viewModel.setDeliveryEnabled,
                        ),
                        _SwitchRow(
                          title: 'Auto Accept Orders',
                          subtitle: 'Auto move new orders to accepted queue',
                          value: viewModel.autoAcceptOrders,
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
    var showCustomReason = false;
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
          borderRadius: BorderRadius.vertical(top: Radius.circular(KBorderSize.borderRadius20)),
        ),
        builder: (sheetContext) {
          return StatefulBuilder(
            builder: (sheetContext, setState) {
              final customReason = noteController.text.trim();
              final reason = (selectedReason ?? '').trim().isNotEmpty
                  ? selectedReason!.trim()
                  : (showCustomReason ? customReason : '');

              return SafeArea(
                top: false,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
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
                        'Pause Store',
                        style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w800, color: colors.textPrimary),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        'Reason is required. You can also set an optional auto-resume timer.',
                        style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w500, color: colors.textSecondary),
                      ),
                      SizedBox(height: 16.h),
                      Wrap(
                        spacing: 8.w,
                        runSpacing: 8.h,
                        children: [
                          ...presetReasons.map((entry) {
                            final isSelected = selectedReason == entry;
                            return _buildInstructionChip(
                              label: entry,
                              isSelected: isSelected,
                              colors: colors,
                              onTap: () {
                                setState(() {
                                  selectedReason = isSelected ? null : entry;
                                  showCustomReason = false;
                                  reasonError = null;
                                });
                              },
                            );
                          }),
                          _buildCustomInstructionChip(
                            colors: colors,
                            isExpanded: showCustomReason,
                            onTap: () {
                              setState(() {
                                showCustomReason = !showCustomReason;
                                reasonError = null;
                                if (showCustomReason) {
                                  selectedReason = null;
                                } else {
                                  noteController.clear();
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
                        child: showCustomReason
                            ? Padding(
                                key: const ValueKey('custom_reason_input'),
                                padding: EdgeInsets.only(top: 12.h),
                                child: AppTextInput(
                                  controller: noteController,
                                  onChanged: (_) => setState(() => reasonError = null),
                                  label: 'Custom reason',
                                  hintText: 'Type pause reason...',
                                  errorText: reasonError,
                                  fillColor: colors.backgroundSecondary,
                                  borderColor: colors.inputBorder,
                                  borderActiveColor: colors.vendorPrimaryBlue,
                                  borderRadius: KBorderSize.border,
                                  cursorColor: colors.vendorPrimaryBlue,
                                ),
                              )
                            : const SizedBox.shrink(key: ValueKey('custom_reason_empty')),
                      ),
                      SizedBox(height: 12.h),
                      Text(
                        'Auto-resume',
                        style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w700, color: colors.textPrimary),
                      ),
                      SizedBox(height: 8.h),
                      Wrap(
                        spacing: 8.w,
                        runSpacing: 8.h,
                        children: [
                          _buildInstructionChip(
                            label: 'None',
                            isSelected: selectedDuration == null,
                            colors: colors,
                            onTap: () => setState(() => selectedDuration = null),
                          ),
                          _buildInstructionChip(
                            label: '30m',
                            isSelected: selectedDuration == const Duration(minutes: 30),
                            colors: colors,
                            onTap: () => setState(() => selectedDuration = const Duration(minutes: 30)),
                          ),
                          _buildInstructionChip(
                            label: '1h',
                            isSelected: selectedDuration == const Duration(hours: 1),
                            colors: colors,
                            onTap: () => setState(() => selectedDuration = const Duration(hours: 1)),
                          ),
                          _buildInstructionChip(
                            label: '2h',
                            isSelected: selectedDuration == const Duration(hours: 2),
                            colors: colors,
                            onTap: () => setState(() => selectedDuration = const Duration(hours: 2)),
                          ),
                          _buildInstructionChip(
                            label: '4h',
                            isSelected: selectedDuration == const Duration(hours: 4),
                            colors: colors,
                            onTap: () => setState(() => selectedDuration = const Duration(hours: 4)),
                          ),
                        ],
                      ),
                      SizedBox(height: 18.h),
                      SizedBox(
                        width: double.infinity,
                        child: AppButton(
                          buttonText: 'Confirm Pause',
                          onPressed: () {
                            final finalReason = reason.trim();
                            if (finalReason.isEmpty) {
                              setState(() => reasonError = 'Pause reason is required');
                              return;
                            }
                            viewModel.pauseStore(reason: finalReason, autoResumeAfter: selectedDuration);
                            Navigator.pop(sheetContext);
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
      noteController.dispose();
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

  Future<bool> _confirmAction(BuildContext context, {required String title, required String message}) async {
    final colors = context.appColors;
    final shouldProceed = await AppDialog.show(
      context: context,
      title: title,
      message: message,
      type: AppDialogType.question,
      primaryButtonColor: colors.error,
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
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14.r)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SvgPicture.asset(
                hasOutage ? Assets.icons.circleAlert : Assets.icons.checkCircleSolid,
                package: 'grab_go_shared',
                width: 18.w,
                height: 18.w,
                colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
              ),

              SizedBox(width: 8.w),
              Expanded(
                child: Text(
                  hasOutage ? viewModel.outageHeadline : 'Store is operating normally',
                  style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w800, color: color),
                ),
              ),
            ],
          ),
          SizedBox(height: 6.h),
          Text(
            hasOutage ? viewModel.outageDetail : 'All critical services are active and accepting orders.',
            style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }
}

Set<VendorServiceType> _visibleVendorServices(VendorStoreContextViewModel storeContext) {
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
            style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w800, color: colors.textSecondary),
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
  final ValueChanged<bool> onChanged;

  const _SwitchRow({required this.title, required this.subtitle, required this.value, required this.onChanged});

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
                  style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700, color: colors.textPrimary),
                ),
                SizedBox(height: 2.h),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w500, color: colors.textSecondary),
                ),
              ],
            ),
          ),
          CustomSwitch(
            value: value,
            onChanged: onChanged,
            activeColor: colors.vendorPrimaryBlue,
            inactiveColor: colors.inputBorder,
            thumbColor: colors.backgroundPrimary,
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

  const _ServiceToggleRow({required this.serviceType, required this.isEnabled, required this.onChanged});

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
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10.r)),
            child: Icon(icon, color: color, size: 18.sp),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700, color: colors.textPrimary),
            ),
          ),
          CustomSwitch(
            value: isEnabled,
            onChanged: onChanged,
            activeColor: colors.vendorPrimaryBlue,
            inactiveColor: colors.inputBorder,
            thumbColor: colors.backgroundPrimary,
          ),
        ],
      ),
    );
  }
}
