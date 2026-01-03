/// Abstract base class for all cart items across different services
/// (Food, Grocery, Pharmacy, Laundry, etc.)
abstract class CartItem {
  /// Unique identifier for the item
  String get id;

  /// Display name of the item
  String get name;

  /// Price of the item
  double get price;

  /// Image URL for the item
  String get image;

  /// Type of item (Food, GroceryItem, PharmacyItem, etc.)
  String get itemType;

  /// Provider/Seller name (Restaurant, Store, Pharmacy, etc.)
  String get providerName;

  /// Provider/Seller ID
  String get providerId;

  /// Provider/Seller image
  String get providerImage;

  /// Rating of the item
  double get rating;

  /// Description of the item
  String get description;

  /// Whether the item is currently available
  bool get isAvailable;

  /// Convert to JSON for storage/API
  Map<String, dynamic> toJson();

  /// Create from JSON
  /// Note: Subclasses should implement their own fromJson factory

  @override
  bool operator ==(Object other);

  @override
  int get hashCode;
}
