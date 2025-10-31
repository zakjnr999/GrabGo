class FoodItem {
  final String name;
  final String image;
  final String description;
  final String sellerName;
  final int sellerId;
  final double price;
  final double rating;
  final int prepTimeMinutes;
  final int calories;
  final List<String> dietaryTags;
  final int deliveryTimeMinutes;
  final bool isAvailable;
  final double discountPercentage;

  FoodItem({
    required this.name,
    required this.image,
    required this.description,
    required this.sellerName,
    required this.sellerId,
    required this.price,
    this.rating = 4.5,
    this.prepTimeMinutes = 15,
    this.calories = 300,
    this.dietaryTags = const [],
    this.deliveryTimeMinutes = 30,
    this.isAvailable = true,
    this.discountPercentage = 0.0,
  });

  factory FoodItem.fromJson(Map<String, dynamic> json) {
    return FoodItem(
      name: json['name'] ?? '',
      image: json['image'] ?? '',
      description: json['description'] ?? '',
      sellerName: json['sellerName'],
      sellerId: json['sellerId'],
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      rating: (json['rating'] as num?)?.toDouble() ?? 4.5,
      prepTimeMinutes: json['prepTimeMinutes'] ?? 15,
      calories: json['calories'] ?? 300,
      dietaryTags: (json['dietaryTags'] as List<dynamic>?)?.cast<String>() ?? [],
      deliveryTimeMinutes: json['deliveryTimeMinutes'] ?? 30,
      isAvailable: json['isAvailable'] ?? true,
      discountPercentage: (json['discountPercentage'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'image': image,
        'description': description,
        'sellerName': sellerName,
        'sellerId': sellerId,
        'price': price,
        'rating': rating,
        'prepTimeMinutes': prepTimeMinutes,
        'calories': calories,
        'dietaryTags': dietaryTags,
        'deliveryTimeMinutes': deliveryTimeMinutes,
        'isAvailable': isAvailable,
        'discountPercentage': discountPercentage,
      };

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    
    return other is FoodItem &&
        other.name == name &&
        other.sellerId == sellerId &&
        other.sellerName == sellerName;
  }

  @override
  int get hashCode {
    return name.hashCode ^ sellerId.hashCode ^ sellerName.hashCode;
  }
}

class FoodCategoryModel {
  final String id;
  final String name;
  final String emoji;
  final List<FoodItem> items;

  FoodCategoryModel({
    required this.id,
    required this.name,
    required this.emoji,
    required this.items,
  });

  factory FoodCategoryModel.fromJson(Map<String, dynamic> json) {
    var itemsList = (json['items'] as List<dynamic>?)
            ?.map((item) => FoodItem.fromJson(item))
            .toList() ??
        [];

    return FoodCategoryModel(
      id: json['id']?.toString() ?? '',
      name: json['categoryName'] ?? json['name'] ?? '',
      emoji: json['emoji'] ?? '',
      items: itemsList,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'emoji': emoji,
        'items': items.map((e) => e.toJson()).toList(),
      };
}

