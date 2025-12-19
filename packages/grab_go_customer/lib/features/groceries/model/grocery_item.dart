import 'package:grab_go_customer/features/home/model/food_category.dart';

class NutritionInfo {
  final double calories;
  final double protein;
  final double carbs;
  final double fat;

  NutritionInfo({required this.calories, required this.protein, required this.carbs, required this.fat});

  factory NutritionInfo.fromJson(Map<String, dynamic> json) {
    return NutritionInfo(
      calories: (json['calories'] ?? 0).toDouble(),
      protein: (json['protein'] ?? 0).toDouble(),
      carbs: (json['carbs'] ?? 0).toDouble(),
      fat: (json['fat'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {'calories': calories, 'protein': protein, 'carbs': carbs, 'fat': fat};
  }
}

class GroceryItem {
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
  final double discountPercentage;
  final DateTime? discountEndDate;
  final NutritionInfo? nutritionInfo;
  final List<String> tags;
  final double rating;
  final int reviewCount;
  final int orderCount; // Number of times ordered (for popularity)
  final DateTime createdAt;

  GroceryItem({
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
    required this.discountPercentage,
    this.discountEndDate,
    this.nutritionInfo,
    required this.tags,
    required this.rating,
    required this.reviewCount,
    this.orderCount = 0, // Default to 0 if not provided
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  // Calculate discounted price
  double get discountedPrice {
    if (discountPercentage > 0) {
      return price * (1 - discountPercentage / 100);
    }
    return price;
  }

  // Check if item has active discount
  bool get hasDiscount {
    if (discountPercentage <= 0) return false;
    if (discountEndDate == null) return true;
    return discountEndDate!.isAfter(DateTime.now());
  }

  // Check if item is new (added in last 7 days)
  bool get isNew {
    final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
    return createdAt.isAfter(sevenDaysAgo);
  }

  // Days since item was created
  int get daysSinceCreation {
    return DateTime.now().difference(createdAt).inDays;
  }

  factory GroceryItem.fromJson(Map<String, dynamic> json) {
    // Handle category (can be populated or just ID)
    String categoryId = '';
    String? categoryName;
    String? categoryEmoji;

    if (json['category'] is Map) {
      categoryId = json['category']['_id'] ?? '';
      categoryName = json['category']['name'];
      categoryEmoji = json['category']['emoji'];
    } else if (json['category'] is String) {
      categoryId = json['category'];
    }

    // Handle store (can be populated or just ID)
    String storeId = '';
    String? storeName;
    String? storeLogo;

    if (json['store'] is Map) {
      storeId = json['store']['_id'] ?? '';
      storeName = json['store']['store_name'];
      storeLogo = json['store']['logo'];
    } else if (json['store'] is String) {
      storeId = json['store'];
    }

    return GroceryItem(
      id: json['_id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      image: json['image'] ?? '',
      price: (json['price'] ?? 0).toDouble(),
      unit: json['unit'] ?? 'piece',
      categoryId: categoryId,
      categoryName: categoryName,
      categoryEmoji: categoryEmoji,
      storeId: storeId,
      storeName: storeName,
      storeLogo: storeLogo,
      brand: json['brand'] ?? '',
      stock: json['stock'] ?? 0,
      isAvailable: json['isAvailable'] ?? true,
      discountPercentage: (json['discountPercentage'] ?? 0).toDouble(),
      discountEndDate: json['discountEndDate'] != null ? DateTime.parse(json['discountEndDate']) : null,
      nutritionInfo: json['nutritionInfo'] != null ? NutritionInfo.fromJson(json['nutritionInfo']) : null,
      tags: (json['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      rating: (json['rating'] ?? 0).toDouble(),
      reviewCount: json['reviewCount'] ?? 0,
      orderCount: json['orderCount'] ?? 0, // Parse orderCount from backend
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
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
      'discountPercentage': discountPercentage,
      'discountEndDate': discountEndDate?.toIso8601String(),
      'nutritionInfo': nutritionInfo?.toJson(),
      'tags': tags,
      'rating': rating,
      'reviewCount': reviewCount,
      'orderCount': orderCount, // Include orderCount in JSON
      'createdAt': createdAt.toIso8601String(),
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is GroceryItem && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  // Convert GroceryItem to FoodItem for UI compatibility
  FoodItem toFoodItem() {
    return FoodItem(
      id: id,
      name: name,
      image: image,
      description: description,
      sellerName: storeName ?? 'Grocery Store',
      sellerId: storeId.hashCode, // Use hash or parse strict int if available
      restaurantId: storeId,
      restaurantImage: storeLogo ?? '',
      price: price,
      rating: rating,
      prepTimeMinutes: 0, // Not applicable for groceries usually
      calories: nutritionInfo?.calories.round() ?? 0,
      dietaryTags: tags,
      deliveryTimeMinutes: 45, // Default for groceries
      isAvailable: isAvailable,
      discountPercentage: discountPercentage,
      discountEndDate: discountEndDate,
      orderCount: orderCount, // Pass through the order count from backend
    );
  }
}
