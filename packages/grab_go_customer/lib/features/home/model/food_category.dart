import 'package:grab_go_customer/features/cart/model/cart_item_interface.dart';

class FoodItem implements CartItem {
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
  final List<String> ingredients;
  final int deliveryTimeMinutes;
  final bool isAvailable;
  final double discountPercentage;
  final DateTime? discountEndDate;
  final int orderCount;
  final DateTime? lastOrderedAt;
  final bool isRestaurantOpen;
  final String estimatedDeliveryTime;

  // CartItem interface implementations
  @override
  String get itemType => 'Food';

  @override
  String get providerName => sellerName;

  @override
  String get providerId => restaurantId;

  @override
  String get providerImage => restaurantImage;

  // Getter for original price before discount
  double get originalPrice {
    if (discountPercentage > 0) {
      return price / (1 - discountPercentage / 100);
    }
    return price;
  }

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
    this.ingredients = const [],
    this.deliveryTimeMinutes = 30,
    this.isAvailable = true,
    this.discountPercentage = 0.0,
    this.discountEndDate,
    required this.restaurantImage,
    this.orderCount = 0,
    this.lastOrderedAt,
    this.isRestaurantOpen = true,
    this.estimatedDeliveryTime = '25-30 min',
  });

  factory FoodItem.fromJson(Map<String, dynamic> json) {
    final id = json['_id']?.toString() ?? json['id']?.toString() ?? '';
    final restaurant = json['restaurant'];
    bool parseBool(dynamic value, {bool defaultValue = true}) {
      if (value is bool) return value;
      if (value is num) return value != 0;
      if (value is String) return value.toLowerCase() == 'true';
      return defaultValue;
    }

    String restaurantId = '';
    String restaurantName = '';
    String restaurantImage = '';

    // Handle different restaurant field formats
    if (restaurant != null) {
      if (restaurant is Map<String, dynamic>) {
        // Case 1: Restaurant is a populated object with full details
        restaurantName =
            restaurant['restaurant_name']?.toString() ??
            restaurant['restaurantName']?.toString() ??
            restaurant['name']?.toString() ??
            '';
        restaurantId = restaurant['_id']?.toString() ?? '';
        restaurantImage = restaurant['logo']?.toString() ?? restaurant['image']?.toString() ?? '';
      } else {
        // Case 2: Restaurant is a string ID (your server format)
        restaurantId = restaurant.toString();
        restaurantName = ''; // Will be fetched later
        restaurantImage = '';
      }
    }

    // Fallback for missing restaurant data
    if (restaurantId.isEmpty) {
      restaurantId = json['restaurantId']?.toString() ?? json['sellerId']?.toString() ?? '';
    }
    if (restaurantName.isEmpty) {
      restaurantName = json['sellerName']?.toString() ?? json['restaurant_name']?.toString() ?? '';
    }
    if (restaurantImage.isEmpty) {
      restaurantImage = json['restaurantImage']?.toString() ?? json['restaurant_logo']?.toString() ?? '';
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

    final imageStr = json['food_image']?.toString() ?? json['foodImage']?.toString() ?? json['image']?.toString() ?? '';
    final image = imageStr.isEmpty ? '' : imageStr;

    final description = json['description']?.toString() ?? '';
    // Mark items that need restaurant details to be fetched
    final safeSellerName = restaurantName.isEmpty && restaurantId.isNotEmpty
        ? 'Loading Restaurant...'
        : (restaurantName.isEmpty ? 'Unknown Restaurant' : restaurantName);
    final safeRestaurantImage = restaurantImage.isEmpty ? '' : restaurantImage;

    final dynamic rawOpen = () {
      if (json.containsKey('isRestaurantOpen')) return json['isRestaurantOpen'];
      if (restaurant is Map) {
        if (restaurant.containsKey('isRestaurantOpen')) return restaurant['isRestaurantOpen'];
        if (restaurant.containsKey('isOpen')) return restaurant['isOpen'];
        if (restaurant.containsKey('is_open')) return restaurant['is_open'];
      }
      if (json.containsKey('isOpen')) return json['isOpen'];
      if (json.containsKey('is_open')) return json['is_open'];
      return null;
    }();

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
      ingredients: () {
        try {
          final ingredientsList = json['ingredients'];
          print('🔍 DEBUG - Ingredients raw data: $ingredientsList');
          print('🔍 DEBUG - Ingredients type: ${ingredientsList.runtimeType}');

          if (ingredientsList == null) {
            print('⚠️ WARNING - Ingredients is null for item: ${json['name']}');
            return <String>[];
          }
          if (ingredientsList is! List) {
            print(
              '⚠️ WARNING - Ingredients is not a List for item: ${json['name']}, type: ${ingredientsList.runtimeType}',
            );
            return <String>[];
          }

          final parsed = (ingredientsList as List<dynamic>)
              .map((e) => e?.toString() ?? '')
              .where((e) => e.isNotEmpty)
              .toList();
          print('✅ SUCCESS - Parsed ${parsed.length} ingredients for ${json['name']}: $parsed');
          return parsed;
        } catch (e) {
          print('❌ ERROR - Failed to parse ingredients for ${json['name']}: $e');
          return <String>[];
        }
      }(),
      deliveryTimeMinutes: (json['deliveryTimeMinutes'] as num?)?.toInt() ?? 30,
      isAvailable: json['isAvailable'] is bool
          ? json['isAvailable'] as bool
          : (json['isAvailable']?.toString().toLowerCase() == 'true'),
      discountPercentage: (json['discountPercentage'] as num?)?.toDouble() ?? 0.0,
      discountEndDate: json['discountEndDate'] != null ? DateTime.tryParse(json['discountEndDate'].toString()) : null,
      orderCount: (json['orderCount'] as num?)?.toInt() ?? 0, // Parse from backend
      lastOrderedAt: json['lastOrderedAt'] != null ? DateTime.tryParse(json['lastOrderedAt'].toString()) : null,
      isRestaurantOpen: parseBool(rawOpen, defaultValue: true),
      estimatedDeliveryTime: json['estimatedDeliveryTime']?.toString() ?? '25-30 min',
    );
  }

  @override
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
    'ingredients': ingredients,
    'deliveryTimeMinutes': deliveryTimeMinutes,
    'isAvailable': isAvailable,
    'isRestaurantOpen': isRestaurantOpen,
    'discountPercentage': discountPercentage,
    'orderCount': orderCount,
    'lastOrderedAt': lastOrderedAt?.toIso8601String(),
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
