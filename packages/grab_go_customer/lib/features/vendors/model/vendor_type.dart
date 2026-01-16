/// Enum representing different types of vendors in the app
enum VendorType {
  food('food', 'Restaurant', '🍔', '#FE6132'),
  grocery('grocery', 'Grocery Store', '🛒', '#4CAF50'),
  pharmacy('pharmacy', 'Pharmacy', '💊', '#2196F3'),
  grabmart('grabmart', 'GrabMart', '🏪', '#9C27B0');

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
