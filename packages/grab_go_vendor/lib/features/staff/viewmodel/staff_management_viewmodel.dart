import 'package:flutter/material.dart';
import 'package:grab_go_vendor/features/staff/model/vendor_staff_models.dart';

class StaffManagementViewModel extends ChangeNotifier {
  StaffManagementViewModel() {
    searchController.addListener(_onSearchChanged);
  }

  final TextEditingController searchController = TextEditingController();
  final List<VendorStaffMember> _members = mockVendorStaff();

  String _query = '';
  VendorStaffStatus? _statusFilter;
  VendorStaffRole _actingRole = VendorStaffRole.owner;

  VendorStaffStatus? get statusFilter => _statusFilter;
  VendorStaffRole get actingRole => _actingRole;
  VendorStaffPermissionMatrix get actingPermissions =>
      permissionMatrixForRole(_actingRole);

  List<VendorStaffMember> get filteredMembers {
    final search = _query.toLowerCase();
    final result = _members.where((member) {
      final matchesStatus =
          _statusFilter == null || member.status == _statusFilter;
      final matchesSearch =
          search.isEmpty ||
          member.fullName.toLowerCase().contains(search) ||
          member.email.toLowerCase().contains(search) ||
          member.phone.toLowerCase().contains(search) ||
          member.role.label.toLowerCase().contains(search);
      return matchesStatus && matchesSearch;
    }).toList();

    result.sort((a, b) {
      final roleDiff = b.role.rank.compareTo(a.role.rank);
      if (roleDiff != 0) return roleDiff;
      return a.fullName.compareTo(b.fullName);
    });
    return result;
  }

  bool get canInviteStaff => actingPermissions.canManageStaff;

  String get inviteDisabledReason {
    if (canInviteStaff) return '';
    return 'Only owner/manager can invite or update staff.';
  }

  bool canEditMember(VendorStaffMember member) {
    if (!actingPermissions.canManageStaff) return false;
    if (_actingRole == VendorStaffRole.owner) return true;
    if (_actingRole == VendorStaffRole.manager) {
      return member.role == VendorStaffRole.operator ||
          member.role == VendorStaffRole.cashier ||
          member.status == VendorStaffStatus.invited;
    }
    return false;
  }

  String editDisabledReason(VendorStaffMember member) {
    if (canEditMember(member)) return '';
    if (!actingPermissions.canManageStaff) {
      return 'Your role does not allow staff management.';
    }
    if (_actingRole == VendorStaffRole.manager &&
        (member.role == VendorStaffRole.owner ||
            member.role == VendorStaffRole.manager)) {
      return 'Managers cannot edit owner/manager accounts.';
    }
    return 'You cannot edit this staff member.';
  }

  void setActingRole(VendorStaffRole role) {
    if (_actingRole == role) return;
    _actingRole = role;
    notifyListeners();
  }

  void setStatusFilter(VendorStaffStatus? status) {
    if (_statusFilter == status) return;
    _statusFilter = status;
    notifyListeners();
  }

  void inviteStaff({
    required String fullName,
    required String email,
    required String phone,
    required VendorStaffRole role,
  }) {
    if (!canInviteStaff) return;
    _members.insert(
      0,
      VendorStaffMember(
        id: 'staff_${DateTime.now().microsecondsSinceEpoch}',
        fullName: fullName.trim(),
        email: email.trim(),
        phone: phone.trim(),
        role: role,
        status: VendorStaffStatus.invited,
        lastActiveLabel: 'Invite pending',
      ),
    );
    notifyListeners();
  }

  void updateStaffRole(String staffId, VendorStaffRole role) {
    final index = _members.indexWhere((member) => member.id == staffId);
    if (index < 0) return;
    final member = _members[index];
    if (!canEditMember(member)) return;
    _members[index] = member.copyWith(role: role);
    notifyListeners();
  }

  void updateStaffStatus(String staffId, VendorStaffStatus status) {
    final index = _members.indexWhere((member) => member.id == staffId);
    if (index < 0) return;
    final member = _members[index];
    if (!canEditMember(member)) return;
    _members[index] = member.copyWith(status: status);
    notifyListeners();
  }

  void _onSearchChanged() {
    final nextValue = searchController.text.trim();
    if (_query == nextValue) return;
    _query = nextValue;
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
