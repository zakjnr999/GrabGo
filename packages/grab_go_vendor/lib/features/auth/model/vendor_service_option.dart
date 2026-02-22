import 'package:grab_go_shared/gen/assets.gen.dart';

enum VendorServiceType { food, grocery, pharmacy, grabMart }

class VendorServiceOption {
  final VendorServiceType type;
  final String label;
  final String icon;

  const VendorServiceOption({required this.type, required this.label, required this.icon});
}

List<VendorServiceOption> vendorServiceOptions = [
  VendorServiceOption(type: VendorServiceType.food, label: 'Food', icon: Assets.icons.utensilsCrossed),
  VendorServiceOption(type: VendorServiceType.grocery, label: 'Grocery', icon: Assets.icons.cart),
  VendorServiceOption(type: VendorServiceType.pharmacy, label: 'Pharmacy', icon: Assets.icons.pharmacyCrossCircle),
  VendorServiceOption(type: VendorServiceType.grabMart, label: 'GrabMart', icon: Assets.icons.cart),
];
