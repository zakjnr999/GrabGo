import 'package:grab_go_shared/grub_go_shared.dart';

/// Enum representing different types of vendors in the app
enum VendorType {
  food('food', 'Restaurant', '🍔', AppColors.serviceFoodHex),
  grocery('grocery', 'Grocery Store', '🛒', AppColors.serviceGroceryHex),
  pharmacy('pharmacy', 'Pharmacy', '💊', AppColors.servicePharmacyHex),
  grabmart('grabmart', 'GrabMart', '🏪', AppColors.serviceGrabMartHex);

  final String id;
  final String displayName;
  final String emoji;
  final String colorHex;

  const VendorType(this.id, this.displayName, this.emoji, this.colorHex);

  /// Get VendorType from string id
  static VendorType fromId(String id) {
    return VendorType.values.firstWhere(
      (type) => type.id == id,
      orElse: () => VendorType.food,
    );
  }

  /// Get color from hex string
  int get color {
    final hexColor = colorHex.replaceAll('#', '');
    return int.parse('FF$hexColor', radix: 16);
  }
}
