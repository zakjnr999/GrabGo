import 'package:flutter/material.dart';

enum VendorServiceType { food, grocery, pharmacy, grabMart }

class VendorServiceOption {
  final VendorServiceType type;
  final String label;
  final IconData icon;

  const VendorServiceOption({
    required this.type,
    required this.label,
    required this.icon,
  });
}

const List<VendorServiceOption> vendorServiceOptions = [
  VendorServiceOption(
    type: VendorServiceType.food,
    label: 'Food',
    icon: Icons.restaurant_rounded,
  ),
  VendorServiceOption(
    type: VendorServiceType.grocery,
    label: 'Grocery',
    icon: Icons.local_grocery_store_rounded,
  ),
  VendorServiceOption(
    type: VendorServiceType.pharmacy,
    label: 'Pharmacy',
    icon: Icons.local_pharmacy_outlined,
  ),
  VendorServiceOption(
    type: VendorServiceType.grabMart,
    label: 'GrabMart',
    icon: Icons.shopping_bag_outlined,
  ),
];
