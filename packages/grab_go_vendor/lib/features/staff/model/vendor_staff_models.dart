enum VendorStaffRole { owner, manager, operator, cashier }

enum VendorStaffStatus { active, suspended, invited }

class VendorStaffPermissionMatrix {
  final bool canManageStaff;
  final bool canManageStore;
  final bool canProcessOrders;
  final bool canManageCatalog;
  final bool canViewAnalytics;

  const VendorStaffPermissionMatrix({
    required this.canManageStaff,
    required this.canManageStore,
    required this.canProcessOrders,
    required this.canManageCatalog,
    required this.canViewAnalytics,
  });
}

class VendorStaffMember {
  final String id;
  final String fullName;
  final String email;
  final String phone;
  final VendorStaffRole role;
  final VendorStaffStatus status;
  final String lastActiveLabel;

  const VendorStaffMember({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.role,
    required this.status,
    required this.lastActiveLabel,
  });

  VendorStaffMember copyWith({
    String? fullName,
    String? email,
    String? phone,
    VendorStaffRole? role,
    VendorStaffStatus? status,
    String? lastActiveLabel,
  }) {
    return VendorStaffMember(
      id: id,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      status: status ?? this.status,
      lastActiveLabel: lastActiveLabel ?? this.lastActiveLabel,
    );
  }
}

extension VendorStaffRoleX on VendorStaffRole {
  String get label {
    return switch (this) {
      VendorStaffRole.owner => 'Owner',
      VendorStaffRole.manager => 'Manager',
      VendorStaffRole.operator => 'Operator',
      VendorStaffRole.cashier => 'Cashier',
    };
  }

  int get rank {
    return switch (this) {
      VendorStaffRole.owner => 4,
      VendorStaffRole.manager => 3,
      VendorStaffRole.operator => 2,
      VendorStaffRole.cashier => 1,
    };
  }
}

extension VendorStaffStatusX on VendorStaffStatus {
  String get label {
    return switch (this) {
      VendorStaffStatus.active => 'Active',
      VendorStaffStatus.suspended => 'Suspended',
      VendorStaffStatus.invited => 'Invited',
    };
  }
}

List<VendorStaffMember> mockVendorStaff() {
  return const [
    VendorStaffMember(
      id: 'staff_001',
      fullName: 'Ama Mensah',
      email: 'ama.mensah@vendorhub.app',
      phone: '+233 24 120 3319',
      role: VendorStaffRole.owner,
      status: VendorStaffStatus.active,
      lastActiveLabel: 'Now',
    ),
    VendorStaffMember(
      id: 'staff_002',
      fullName: 'Nana Asamoah',
      email: 'nana.asamoah@vendorhub.app',
      phone: '+233 20 880 1295',
      role: VendorStaffRole.manager,
      status: VendorStaffStatus.active,
      lastActiveLabel: '12m ago',
    ),
    VendorStaffMember(
      id: 'staff_003',
      fullName: 'Kojo Annan',
      email: 'kojo.annan@vendorhub.app',
      phone: '+233 54 202 8201',
      role: VendorStaffRole.operator,
      status: VendorStaffStatus.active,
      lastActiveLabel: '25m ago',
    ),
    VendorStaffMember(
      id: 'staff_004',
      fullName: 'Esi Frimpong',
      email: 'esi.frimpong@vendorhub.app',
      phone: '+233 50 128 5092',
      role: VendorStaffRole.cashier,
      status: VendorStaffStatus.suspended,
      lastActiveLabel: 'Yesterday',
    ),
    VendorStaffMember(
      id: 'staff_005',
      fullName: 'Yaw Ofori',
      email: 'yaw.ofori@vendorhub.app',
      phone: '+233 27 901 1170',
      role: VendorStaffRole.operator,
      status: VendorStaffStatus.invited,
      lastActiveLabel: 'Invite pending',
    ),
  ];
}

VendorStaffPermissionMatrix permissionMatrixForRole(VendorStaffRole role) {
  return switch (role) {
    VendorStaffRole.owner => const VendorStaffPermissionMatrix(
      canManageStaff: true,
      canManageStore: true,
      canProcessOrders: true,
      canManageCatalog: true,
      canViewAnalytics: true,
    ),
    VendorStaffRole.manager => const VendorStaffPermissionMatrix(
      canManageStaff: true,
      canManageStore: true,
      canProcessOrders: true,
      canManageCatalog: true,
      canViewAnalytics: true,
    ),
    VendorStaffRole.operator => const VendorStaffPermissionMatrix(
      canManageStaff: false,
      canManageStore: false,
      canProcessOrders: true,
      canManageCatalog: true,
      canViewAnalytics: true,
    ),
    VendorStaffRole.cashier => const VendorStaffPermissionMatrix(
      canManageStaff: false,
      canManageStore: false,
      canProcessOrders: true,
      canManageCatalog: false,
      canViewAnalytics: false,
    ),
  };
}
