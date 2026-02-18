import 'package:grab_go_vendor/features/auth/model/vendor_service_option.dart';

class VendorStoreBranch {
  final String id;
  final String name;
  final String address;
  final bool isOpen;
  final int pendingOrders;
  final List<VendorServiceType> serviceTypes;

  const VendorStoreBranch({
    required this.id,
    required this.name,
    required this.address,
    required this.isOpen,
    required this.pendingOrders,
    required this.serviceTypes,
  });
}

List<VendorStoreBranch> mockVendorStoreBranches() {
  return const [
    VendorStoreBranch(
      id: 'branch_001',
      name: 'Downtown Branch',
      address: '14 Ring Road West, Accra',
      isOpen: true,
      pendingOrders: 7,
      serviceTypes: [
        VendorServiceType.food,
        VendorServiceType.grocery,
        VendorServiceType.grabMart,
      ],
    ),
    VendorStoreBranch(
      id: 'branch_002',
      name: 'Airport Branch',
      address: 'Airport Residential, Accra',
      isOpen: true,
      pendingOrders: 4,
      serviceTypes: [VendorServiceType.food, VendorServiceType.pharmacy],
    ),
    VendorStoreBranch(
      id: 'branch_003',
      name: 'Spintex Branch',
      address: 'Spintex Road, Accra',
      isOpen: false,
      pendingOrders: 0,
      serviceTypes: [VendorServiceType.grocery, VendorServiceType.grabMart],
    ),
  ];
}
