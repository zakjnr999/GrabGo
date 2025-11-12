class FoodItem {
  final String id;
  final String name;
  final String image;
  final String restaurantImage;
  final String description;
  final String sellerName;
  final int sellerId;
  final String restaurantId;
  final double price;
  final double rating;
  final int prepTimeMinutes;
  final int calories;
  final List<String> dietaryTags;
  final int deliveryTimeMinutes;
  final bool isAvailable;
  final double discountPercentage;

  FoodItem({
    required this.id,
    required this.name,
    required this.image,
    required this.description,
    required this.sellerName,
    required this.sellerId,
    required this.restaurantId,
    required this.price,
    this.rating = 4.5,
    this.prepTimeMinutes = 15,
    this.calories = 300,
    this.dietaryTags = const [],
    this.deliveryTimeMinutes = 30,
    this.isAvailable = true,
    this.discountPercentage = 0.0,
    required this.restaurantImage,
  });

  factory FoodItem.fromJson(Map<String, dynamic> json) {
    final id = json['_id']?.toString() ?? json['id']?.toString() ?? '';
    final restaurant = json['restaurant'];

    String restaurantId = '';

    String restaurantName = '';
    if (restaurant != null && restaurant is Map<String, dynamic>) {
      restaurantName = restaurant['restaurant_name']?.toString() ?? '';
    }
    if (restaurantName.isEmpty) {
      restaurantName = json['sellerName']?.toString() ?? '';
    }

    if (restaurant != null && restaurant is Map<String, dynamic>) {
      restaurantId = restaurant['_id']?.toString() ?? '';
    }
    if (restaurantId.isEmpty) {
      restaurantId = json['restaurantId']?.toString() ?? '';
    }
    if (restaurantId.isEmpty) {
      restaurantId = json['sellerId']?.toString() ?? '';
    }
    String restaurantImage = '';
    if (restaurant != null && restaurant is Map<String, dynamic>) {
      restaurantImage = restaurant['logo']?.toString() ?? '';
    }
    if (restaurantImage.isEmpty) {
      restaurantImage = json['restaurantImage']?.toString() ?? '';
    }

    int sellerIdInt = 0;
    if (restaurantId.isNotEmpty) {
      try {
        sellerIdInt = int.tryParse(restaurantId.substring(restaurantId.length > 6 ? restaurantId.length - 6 : 0)) ?? 0;
      } catch (e) {
        sellerIdInt = restaurantId.hashCode % 1000000;
      }
    }

    // Ensure all String fields are never null
    final nameStr = json['name']?.toString() ?? '';
    final name = nameStr.isEmpty ? 'Unknown Food' : nameStr;

    final imageStr = json['food_image']?.toString() ?? json['image']?.toString() ?? '';
    final image = imageStr.isEmpty ? '' : imageStr;

    final description = json['description']?.toString() ?? '';
    final safeSellerName = restaurantName.isEmpty ? 'Unknown Restaurant' : restaurantName;
    final safeRestaurantImage = restaurantImage.isEmpty ? '' : restaurantImage;

    return FoodItem(
      id: id,
      name: name,
      image: image,
      description: description,
      sellerName: safeSellerName,
      sellerId: sellerIdInt,
      restaurantId: restaurantId,
      restaurantImage: safeRestaurantImage,
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      prepTimeMinutes: (json['prepTimeMinutes'] as num?)?.toInt() ?? 15,
      calories: (json['calories'] as num?)?.toInt() ?? 300,
      dietaryTags:
          (json['dietaryTags'] as List<dynamic>?)
              ?.map((e) => e?.toString() ?? '')
              .where((e) => e.isNotEmpty)
              .toList() ??
          [],
      deliveryTimeMinutes: (json['deliveryTimeMinutes'] as num?)?.toInt() ?? 30,
      isAvailable: json['isAvailable'] is bool
          ? json['isAvailable'] as bool
          : (json['isAvailable']?.toString().toLowerCase() == 'true'),
      discountPercentage: (json['discountPercentage'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'image': image,
    'description': description,
    'sellerName': sellerName,
    'sellerId': sellerId,
    'restaurantId': restaurantId,
    'restaurantImage': restaurantImage,
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
    if (other is! FoodItem) return false;

    if (id.isNotEmpty && other.id.isNotEmpty) {
      return other.id == id;
    }

    return other.name == name && other.sellerId == sellerId && other.sellerName == sellerName;
  }

  @override
  int get hashCode {
    if (id.isNotEmpty) {
      return id.hashCode;
    }
    return name.hashCode ^ sellerId.hashCode ^ sellerName.hashCode;
  }
}

class FoodCategoryModel {
  final String id;
  final String name;
  final String description;
  final String emoji;
  final bool isActive;
  final List<FoodItem> items;

  FoodCategoryModel({
    required this.id,
    required this.name,
    required this.description,
    required this.emoji,
    required this.isActive,
    required this.items,
  });

  factory FoodCategoryModel.fromJson(Map<String, dynamic> json) {
    var itemsList = (json['items'] as List<dynamic>?)?.map((item) => FoodItem.fromJson(item)).toList() ?? [];

    return FoodCategoryModel(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      name: json['categoryName'] ?? json['name'] ?? '',
      description: json['description'] ?? '',
      emoji: json['emoji'] ?? '',
      isActive: json['isActive'] ?? true,
      items: itemsList,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'emoji': emoji,
    'isActive': isActive,
    'items': items.map((e) => e.toJson()).toList(),
  };
}
