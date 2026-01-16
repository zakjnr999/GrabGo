import 'package:grab_go_customer/features/cart/model/cart_item_interface.dart';

class PharmacyItem implements CartItem {
  final String id;
  final String name;
  final String description;
  final String image;
  final double price;
  final String unit;
  final String categoryId;
  final String? categoryName;
  final String? categoryEmoji;
  final String storeId;
  final String? storeName;
  final String? storeLogo;
  final String brand;
  final int stock;
  final bool isAvailable;
  final bool requiresPrescription;
  final double discountPercentage;
  final DateTime? discountEndDate;
  final DateTime? expiryDate;
  final List<String> tags;
  final double rating;
  final int reviewCount;
  final int orderCount;
  final DateTime createdAt;

  // CartItem interface implementations
  @override
  String get itemType => 'PharmacyItem';

  @override
  String get providerName => storeName ?? 'Pharmacy';

  @override
  String get providerId => storeId;

  @override
  String get providerImage => storeLogo ?? '';

  PharmacyItem({
    required this.id,
    required this.name,
    required this.description,
    required this.image,
    required this.price,
    required this.unit,
    required this.categoryId,
    this.categoryName,
    this.categoryEmoji,
    required this.storeId,
    this.storeName,
    this.storeLogo,
    required this.brand,
    required this.stock,
    required this.isAvailable,
    required this.requiresPrescription,
    required this.discountPercentage,
    this.discountEndDate,
    this.expiryDate,
    required this.tags,
    required this.rating,
    required this.reviewCount,
    required this.orderCount,
    required this.createdAt,
  });

  factory PharmacyItem.fromJson(Map<String, dynamic> json) {
    return PharmacyItem(
      id: json['_id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      image: json['image'] ?? '',
      price: (json['price'] ?? 0).toDouble(),
      unit: json['unit'] ?? 'piece',
      categoryId: json['category'] is Map ? json['category']['_id'] ?? '' : json['category'] ?? '',
      categoryName: json['category'] is Map ? json['category']['name'] : null,
      categoryEmoji: json['category'] is Map ? json['category']['emoji'] : null,
      storeId: json['store'] is Map ? json['store']['_id'] ?? '' : json['store'] ?? '',
      storeName: json['store'] is Map ? json['store']['store_name'] : null,
      storeLogo: json['store'] is Map ? json['store']['logo'] : null,
      brand: json['brand'] ?? '',
      stock: json['stock'] ?? 0,
      isAvailable: json['isAvailable'] ?? true,
      requiresPrescription: json['requiresPrescription'] ?? false,
      discountPercentage: (json['discountPercentage'] ?? 0).toDouble(),
      discountEndDate: json['discountEndDate'] != null ? DateTime.parse(json['discountEndDate']) : null,
      expiryDate: json['expiryDate'] != null ? DateTime.parse(json['expiryDate']) : null,
      tags: json['tags'] != null ? List<String>.from(json['tags']) : [],
      rating: (json['rating'] ?? 0).toDouble(),
      reviewCount: json['reviewCount'] ?? 0,
      orderCount: json['orderCount'] ?? 0,
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'name': name,
      'description': description,
      'image': image,
      'price': price,
      'unit': unit,
      'category': categoryId,
      'store': storeId,
      'brand': brand,
      'stock': stock,
      'isAvailable': isAvailable,
      'requiresPrescription': requiresPrescription,
      'discountPercentage': discountPercentage,
      'discountEndDate': discountEndDate?.toIso8601String(),
      'expiryDate': expiryDate?.toIso8601String(),
      'tags': tags,
      'rating': rating,
      'reviewCount': reviewCount,
      'orderCount': orderCount,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  double get discountedPrice {
    if (discountPercentage > 0) {
      return price * (1 - discountPercentage / 100);
    }
    return price;
  }

  bool get hasDiscount => discountPercentage > 0 && (discountEndDate == null || discountEndDate!.isAfter(DateTime.now()));
}
