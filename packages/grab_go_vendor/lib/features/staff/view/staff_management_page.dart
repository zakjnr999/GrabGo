import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:grab_go_vendor/features/staff/model/vendor_staff_models.dart';
import 'package:grab_go_vendor/features/staff/viewmodel/staff_management_viewmodel.dart';
import 'package:provider/provider.dart';

class StaffManagementPage extends StatelessWidget {
  const StaffManagementPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => StaffManagementViewModel(),
      child: const _StaffManagementView(),
    );
  }
}

class _StaffManagementView extends StatelessWidget {
  const _StaffManagementView();

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Consumer<StaffManagementViewModel>(
      builder: (context, viewModel, _) {
        final members = viewModel.filteredMembers;

        return Scaffold(
          backgroundColor: colors.backgroundPrimary,
          appBar: AppBar(
            backgroundColor: colors.backgroundPrimary,
            elevation: 0,
            title: Text(
              'Staff Management',
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.w800,
                color: colors.textPrimary,
              ),
            ),
            actions: [
              TextButton.icon(
                onPressed: viewModel.canInviteStaff
                    ? () => _showInviteSheet(context)
                    : () => _showInfo(context, viewModel.inviteDisabledReason),
                icon: Icon(
                  viewModel.canInviteStaff
                      ? Icons.person_add_alt_1_rounded
                      : Icons.lock_outline_rounded,
                  size: 16.sp,
                  color: viewModel.canInviteStaff
                      ? colors.vendorPrimaryBlue
                      : colors.textSecondary,
                ),
                label: Text(
                  'Invite',
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w700,
                    color: viewModel.canInviteStaff
                        ? colors.vendorPrimaryBlue
                        : colors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            backgroundColor: viewModel.canInviteStaff
                ? colors.vendorPrimaryBlue
                : colors.backgroundSecondary,
            foregroundColor: viewModel.canInviteStaff
                ? Colors.white
                : colors.textSecondary,
            onPressed: viewModel.canInviteStaff
                ? () => _showInviteSheet(context)
                : () => _showInfo(context, viewModel.inviteDisabledReason),
            icon: Icon(
              viewModel.canInviteStaff
                  ? Icons.person_add_alt_1_rounded
                  : Icons.lock_outline_rounded,
            ),
            label: const Text('Invite Staff'),
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 90.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Invite and manage owner, manager, operator, and cashier roles.',
                    style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w500,
                      color: colors.textSecondary,
                    ),
                  ),
                  SizedBox(height: 12.h),
                  _SectionCard(
                    title: 'Role Context',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'UI role preview (for permission gating).',
                          style: TextStyle(
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w600,
                            color: colors.textSecondary,
                          ),
                        ),
                        SizedBox(height: 8.h),
                        Wrap(
                          spacing: 8.w,
                          runSpacing: 8.h,
                          children: VendorStaffRole.values.map((role) {
                            final selected = viewModel.actingRole == role;
                            return _FilterChip(
                              label: role.label,
                              selected: selected,
                              color: _roleColor(colors, role),
                              onTap: () => viewModel.setActingRole(role),
                            );
                          }).toList(),
                        ),
                        if (!viewModel.canInviteStaff) ...[
                          SizedBox(height: 8.h),
                          Text(
                            viewModel.inviteDisabledReason,
                            style: TextStyle(
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w700,
                              color: colors.error,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  SizedBox(height: 12.h),
                  _SectionCard(
                    title: 'Permission Matrix',
                    child: _PermissionMatrixGrid(
                      actingRole: viewModel.actingRole,
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
                      hintText: 'Search by name, email, phone, role',
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
                          selected: viewModel.statusFilter == null,
                          color: colors.vendorPrimaryBlue,
                          onTap: () => viewModel.setStatusFilter(null),
                        ),
                        _FilterChip(
                          label: 'Active',
                          selected:
                              viewModel.statusFilter ==
                              VendorStaffStatus.active,
                          color: colors.success,
                          onTap: () => viewModel.setStatusFilter(
                            VendorStaffStatus.active,
                          ),
                        ),
                        _FilterChip(
                          label: 'Invited',
                          selected:
                              viewModel.statusFilter ==
                              VendorStaffStatus.invited,
                          color: colors.warning,
                          onTap: () => viewModel.setStatusFilter(
                            VendorStaffStatus.invited,
                          ),
                        ),
                        _FilterChip(
                          label: 'Suspended',
                          selected:
                              viewModel.statusFilter ==
                              VendorStaffStatus.suspended,
                          color: colors.error,
                          onTap: () => viewModel.setStatusFilter(
                            VendorStaffStatus.suspended,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 12.h),
                  if (members.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(16.r),
                      decoration: BoxDecoration(
                        color: colors.backgroundPrimary,
                        borderRadius: BorderRadius.circular(14.r),
                        border: Border.all(color: colors.border),
                      ),
                      child: Text(
                        'No staff members match current filters.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w600,
                          color: colors.textSecondary,
                        ),
                      ),
                    )
                  else
                    ...members.map((member) {
                      final canEdit = viewModel.canEditMember(member);
                      return _StaffCard(
                        member: member,
                        canEdit: canEdit,
                        disabledReason: viewModel.editDisabledReason(member),
                        onEdit: () => _showEditSheet(context, member),
                        onBlockedEdit: () => _showInfo(
                          context,
                          viewModel.editDisabledReason(member),
                        ),
                      );
                    }),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showInviteSheet(BuildContext context) async {
    final colors = context.appColors;
    final viewModel = context.read<StaffManagementViewModel>();
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final phoneController = TextEditingController();
    var selectedRole = VendorStaffRole.operator;
    String? nameError;
    String? emailError;
    String? phoneError;

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
            builder: (sheetContext, setSheetState) {
              return Padding(
                padding: EdgeInsets.fromLTRB(
                  16.w,
                  12.h,
                  16.w,
                  20.h + MediaQuery.viewInsetsOf(sheetContext).bottom,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Invite Staff',
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w800,
                          color: colors.textPrimary,
                        ),
                      ),
                      SizedBox(height: 10.h),
                      TextField(
                        controller: nameController,
                        onChanged: (_) => setSheetState(() => nameError = null),
                        decoration: InputDecoration(
                          labelText: 'Full name',
                          errorText: nameError,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                        ),
                      ),
                      SizedBox(height: 10.h),
                      TextField(
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        onChanged: (_) =>
                            setSheetState(() => emailError = null),
                        decoration: InputDecoration(
                          labelText: 'Email',
                          errorText: emailError,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                        ),
                      ),
                      SizedBox(height: 10.h),
                      TextField(
                        controller: phoneController,
                        keyboardType: TextInputType.phone,
                        onChanged: (_) =>
                            setSheetState(() => phoneError = null),
                        decoration: InputDecoration(
                          labelText: 'Phone',
                          errorText: phoneError,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                        ),
                      ),
                      SizedBox(height: 10.h),
                      DropdownButtonFormField<VendorStaffRole>(
                        key: ValueKey<VendorStaffRole>(selectedRole),
                        initialValue: selectedRole,
                        decoration: InputDecoration(
                          labelText: 'Role',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                        ),
                        items: VendorStaffRole.values.map((role) {
                          return DropdownMenuItem<VendorStaffRole>(
                            value: role,
                            child: Text(role.label),
                          );
                        }).toList(),
                        onChanged: (role) {
                          if (role == null) return;
                          setSheetState(() => selectedRole = role);
                        },
                      ),
                      SizedBox(height: 14.h),
                      SizedBox(
                        width: double.infinity,
                        child: AppButton(
                          buttonText: 'Send Invite',
                          onPressed: () {
                            final name = nameController.text.trim();
                            final email = emailController.text.trim();
                            final phone = phoneController.text.trim();
                            var hasError = false;
                            if (name.isEmpty) {
                              nameError = 'Enter full name';
                              hasError = true;
                            }
                            if (email.isEmpty || !email.contains('@')) {
                              emailError = 'Enter valid email';
                              hasError = true;
                            }
                            if (phone.isEmpty) {
                              phoneError = 'Enter phone';
                              hasError = true;
                            }
                            if (hasError) {
                              setSheetState(() {});
                              return;
                            }
                            viewModel.inviteStaff(
                              fullName: name,
                              email: email,
                              phone: phone,
                              role: selectedRole,
                            );
                            Navigator.pop(sheetContext);
                          },
                          backgroundColor: colors.vendorPrimaryBlue,
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
                ),
              );
            },
          );
        },
      );
    } finally {
      nameController.dispose();
      emailController.dispose();
      phoneController.dispose();
    }
  }

  Future<void> _showEditSheet(
    BuildContext context,
    VendorStaffMember member,
  ) async {
    final colors = context.appColors;
    final viewModel = context.read<StaffManagementViewModel>();
    var selectedRole = member.role;
    var selectedStatus = member.status;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.backgroundPrimary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18.r)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
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
                    'Edit Staff',
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w800,
                      color: colors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    member.fullName,
                    style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w700,
                      color: colors.textSecondary,
                    ),
                  ),
                  SizedBox(height: 10.h),
                  DropdownButtonFormField<VendorStaffRole>(
                    key: ValueKey<VendorStaffRole>(selectedRole),
                    initialValue: selectedRole,
                    decoration: InputDecoration(
                      labelText: 'Role',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                    ),
                    items: VendorStaffRole.values.map((role) {
                      return DropdownMenuItem<VendorStaffRole>(
                        value: role,
                        child: Text(role.label),
                      );
                    }).toList(),
                    onChanged: (role) {
                      if (role == null) return;
                      setSheetState(() => selectedRole = role);
                    },
                  ),
                  SizedBox(height: 10.h),
                  Text(
                    'Status',
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
                    children: VendorStaffStatus.values.map((status) {
                      final selected = selectedStatus == status;
                      final chipColor = _statusColor(colors, status);
                      return _FilterChip(
                        label: status.label,
                        selected: selected,
                        color: chipColor,
                        onTap: () =>
                            setSheetState(() => selectedStatus = status),
                      );
                    }).toList(),
                  ),
                  SizedBox(height: 14.h),
                  SizedBox(
                    width: double.infinity,
                    child: AppButton(
                      buttonText: 'Save Changes',
                      onPressed: () {
                        viewModel.updateStaffRole(member.id, selectedRole);
                        viewModel.updateStaffStatus(member.id, selectedStatus);
                        Navigator.pop(sheetContext);
                      },
                      backgroundColor: colors.vendorPrimaryBlue,
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
  }

  void _showInfo(BuildContext context, String message) {
    if (message.trim().isEmpty) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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

class _PermissionMatrixGrid extends StatelessWidget {
  final VendorStaffRole actingRole;

  const _PermissionMatrixGrid({required this.actingRole});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final matrix = permissionMatrixForRole(actingRole);
    return Column(
      children: [
        _PermissionRow(
          label: 'Manage Staff',
          enabled: matrix.canManageStaff,
          color: colors.vendorPrimaryBlue,
        ),
        _PermissionRow(
          label: 'Manage Store Operations',
          enabled: matrix.canManageStore,
          color: colors.serviceFood,
        ),
        _PermissionRow(
          label: 'Process Orders',
          enabled: matrix.canProcessOrders,
          color: colors.warning,
        ),
        _PermissionRow(
          label: 'Manage Catalog',
          enabled: matrix.canManageCatalog,
          color: colors.serviceGrocery,
        ),
        _PermissionRow(
          label: 'View Analytics',
          enabled: matrix.canViewAnalytics,
          color: colors.servicePharmacy,
        ),
      ],
    );
  }
}

class _PermissionRow extends StatelessWidget {
  final String label;
  final bool enabled;
  final Color color;

  const _PermissionRow({
    required this.label,
    required this.enabled,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: Row(
        children: [
          Icon(
            enabled ? Icons.task_alt_rounded : Icons.block_rounded,
            size: 18.sp,
            color: enabled ? color : colors.textSecondary,
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              ),
            ),
          ),
          Text(
            enabled ? 'Allowed' : 'Restricted',
            style: TextStyle(
              fontSize: 11.sp,
              fontWeight: FontWeight.w700,
              color: enabled ? color : colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
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

class _StaffCard extends StatelessWidget {
  final VendorStaffMember member;
  final bool canEdit;
  final String disabledReason;
  final VoidCallback onEdit;
  final VoidCallback onBlockedEdit;

  const _StaffCard({
    required this.member,
    required this.canEdit,
    required this.disabledReason,
    required this.onEdit,
    required this.onBlockedEdit,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final roleColor = _roleColor(colors, member.role);
    final statusColor = _statusColor(colors, member.status);
    final initials = member.fullName
        .split(' ')
        .where((entry) => entry.trim().isNotEmpty)
        .map((entry) => entry.trim()[0])
        .take(2)
        .join()
        .toUpperCase();

    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: 10.h),
      padding: EdgeInsets.all(12.r),
      decoration: BoxDecoration(
        color: colors.backgroundPrimary,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18.r,
                backgroundColor: roleColor.withValues(alpha: 0.16),
                child: Text(
                  initials,
                  style: TextStyle(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w800,
                    color: roleColor,
                  ),
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      member.fullName,
                      style: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w800,
                        color: colors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      member.email,
                      style: TextStyle(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w500,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 10.h),
          Row(
            children: [
              _Tag(label: member.role.label, color: roleColor),
              SizedBox(width: 8.w),
              _Tag(label: member.status.label, color: statusColor),
              const Spacer(),
              Text(
                member.lastActiveLabel,
                style: TextStyle(
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w700,
                  color: colors.textSecondary,
                ),
              ),
            ],
          ),
          SizedBox(height: 10.h),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: canEdit ? onEdit : onBlockedEdit,
                  icon: Icon(
                    canEdit ? Icons.edit_outlined : Icons.lock_outline_rounded,
                    size: 16.sp,
                  ),
                  label: Text(
                    canEdit ? 'Edit Role/Status' : 'Restricted',
                    style: TextStyle(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: canEdit
                        ? colors.vendorPrimaryBlue
                        : colors.textSecondary,
                    side: BorderSide(
                      color: canEdit
                          ? colors.vendorPrimaryBlue
                          : colors.inputBorder,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (!canEdit && disabledReason.trim().isNotEmpty) ...[
            SizedBox(height: 6.h),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                disabledReason,
                style: TextStyle(
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w600,
                  color: colors.error,
                ),
              ),
            ),
          ],
        ],
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

Color _roleColor(AppColorsExtension colors, VendorStaffRole role) {
  return switch (role) {
    VendorStaffRole.owner => colors.vendorPrimaryBlue,
    VendorStaffRole.manager => colors.info,
    VendorStaffRole.operator => colors.serviceGrocery,
    VendorStaffRole.cashier => colors.warning,
  };
}

Color _statusColor(AppColorsExtension colors, VendorStaffStatus status) {
  return switch (status) {
    VendorStaffStatus.active => colors.success,
    VendorStaffStatus.suspended => colors.error,
    VendorStaffStatus.invited => colors.warning,
  };
}
