import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:grab_go_vendor/features/auth/model/vendor_service_option.dart';
import 'package:grab_go_vendor/features/store_context/model/vendor_store_context_models.dart';
import 'package:grab_go_vendor/features/store_context/viewmodel/store_context_viewmodel.dart';
import 'package:provider/provider.dart';

class StoreContextSwitcherPage extends StatelessWidget {
  const StoreContextSwitcherPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Scaffold(
      backgroundColor: colors.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: colors.backgroundPrimary,
        elevation: 0,
        title: Text(
          'Store Context',
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.w800,
            color: colors.textPrimary,
          ),
        ),
      ),
      body: SafeArea(
        child: Consumer<VendorStoreContextViewModel>(
          builder: (context, viewModel, _) {
            final currentBranch = viewModel.selectedBranch;
            final branches = viewModel.filteredBranches;
            final scopedServices = viewModel.allowedServices.toList()
              ..sort((a, b) => a.index.compareTo(b.index));

            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20.w, 10.h, 20.w, 24.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Switch branch and active service context for this session.',
                    style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w500,
                      color: colors.textSecondary,
                    ),
                  ),
                  SizedBox(height: 12.h),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(12.r),
                    decoration: BoxDecoration(
                      color: colors.vendorPrimaryBlue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Current Branch',
                          style: TextStyle(
                            fontSize: 10.sp,
                            fontWeight: FontWeight.w700,
                            color: colors.vendorPrimaryBlue,
                          ),
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          currentBranch.name,
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w800,
                            color: colors.textPrimary,
                          ),
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          '${currentBranch.address} • ${viewModel.serviceScopeLabel()}',
                          style: TextStyle(
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w600,
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
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
                      hintText: 'Search branches',
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
                  SizedBox(height: 12.h),
                  Text(
                    'Service Scope',
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _ScopeChip(
                          label: 'All Services',
                          selected: viewModel.serviceScope == null,
                          color: colors.vendorPrimaryBlue,
                          onTap: () => viewModel.setServiceScope(null),
                        ),
                        ...scopedServices.map((service) {
                          final isAvailable = viewModel
                              .availableServicesForSelectedBranch
                              .contains(service);
                          final color = _serviceColor(colors, service);
                          return _ScopeChip(
                            label: _serviceLabel(service),
                            selected: viewModel.serviceScope == service,
                            color: color,
                            enabled: isAvailable,
                            onTap: () {
                              if (!isAvailable) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      '${_serviceLabel(service)} is not available for ${currentBranch.name}.',
                                    ),
                                  ),
                                );
                                return;
                              }
                              viewModel.setServiceScope(service);
                            },
                          );
                        }),
                      ],
                    ),
                  ),
                  SizedBox(height: 12.h),
                  Text(
                    'Branches',
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  if (branches.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(16.r),
                      decoration: BoxDecoration(
                        color: colors.backgroundPrimary,
                        borderRadius: BorderRadius.circular(12.r),
                        border: Border.all(color: colors.border),
                      ),
                      child: Text(
                        'No branches found.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w600,
                          color: colors.textSecondary,
                        ),
                      ),
                    )
                  else
                    ...branches.map((branch) {
                      return _BranchCard(
                        branch: branch,
                        selected: branch.id == currentBranch.id,
                        onTap: () {
                          viewModel.setBranch(branch.id);
                          Navigator.pop(context);
                        },
                      );
                    }),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _BranchCard extends StatelessWidget {
  final VendorStoreBranch branch;
  final bool selected;
  final VoidCallback onTap;

  const _BranchCard({
    required this.branch,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12.r),
      child: Container(
        width: double.infinity,
        margin: EdgeInsets.only(bottom: 10.h),
        padding: EdgeInsets.all(12.r),
        decoration: BoxDecoration(
          color: colors.backgroundPrimary,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color: selected ? colors.vendorPrimaryBlue : colors.border,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    branch.name,
                    style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w800,
                      color: colors.textPrimary,
                    ),
                  ),
                ),
                if (selected)
                  Icon(
                    Icons.check_circle_rounded,
                    size: 18.sp,
                    color: colors.vendorPrimaryBlue,
                  ),
              ],
            ),
            SizedBox(height: 2.h),
            Text(
              branch.address,
              style: TextStyle(
                fontSize: 11.sp,
                fontWeight: FontWeight.w500,
                color: colors.textSecondary,
              ),
            ),
            SizedBox(height: 8.h),
            Row(
              children: [
                _MetaTag(
                  label: branch.isOpen ? 'Open' : 'Closed',
                  color: branch.isOpen ? colors.success : colors.error,
                ),
                SizedBox(width: 8.w),
                _MetaTag(
                  label: 'Pending: ${branch.pendingOrders}',
                  color: colors.warning,
                ),
              ],
            ),
            SizedBox(height: 8.h),
            Wrap(
              spacing: 6.w,
              runSpacing: 6.h,
              children: branch.serviceTypes.map((service) {
                final color = _serviceColor(colors, service);
                return _MetaTag(label: _serviceLabel(service), color: color);
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScopeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final bool enabled;
  final VoidCallback onTap;

  const _ScopeChip({
    required this.label,
    required this.selected,
    required this.color,
    this.enabled = true,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999.r),
      child: Opacity(
        opacity: enabled ? 1 : 0.45,
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
      ),
    );
  }
}

class _MetaTag extends StatelessWidget {
  final String label;
  final Color color;

  const _MetaTag({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
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

Color _serviceColor(AppColorsExtension colors, VendorServiceType serviceType) {
  return switch (serviceType) {
    VendorServiceType.food => colors.serviceFood,
    VendorServiceType.grocery => colors.serviceGrocery,
    VendorServiceType.pharmacy => colors.servicePharmacy,
    VendorServiceType.grabMart => colors.serviceGrabMart,
  };
}

String _serviceLabel(VendorServiceType serviceType) {
  return switch (serviceType) {
    VendorServiceType.food => 'Food',
    VendorServiceType.grocery => 'Grocery',
    VendorServiceType.pharmacy => 'Pharmacy',
    VendorServiceType.grabMart => 'GrabMart',
  };
}
