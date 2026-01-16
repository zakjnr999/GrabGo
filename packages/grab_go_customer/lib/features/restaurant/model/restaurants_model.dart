class RestaurantModel {
  final int id;
  final String backendId;
  final String name;
  final String city;
  final String foodType;
  final String imageUrl;
  final List<String> bannerImages;
  final double distance;
  final double rating;
  final int totalReviews;
  final String averageDeliveryTime;
  final double deliveryFee;
  final double minOrder;
  final String description;
  final String phone;
  final String email;
  final String address;
  final double latitude;
  final double longitude;
  final String openingHours;
  final bool isOpen;
  final List<String> paymentMethods;
  final Socials socials;
  final List<Food> foods;

  RestaurantModel({
    required this.id,
    required this.backendId,
    required this.name,
    required this.city,
    required this.foodType,
    required this.imageUrl,
    required this.bannerImages,
    required this.distance,
    required this.rating,
    required this.totalReviews,
    required this.averageDeliveryTime,
    required this.deliveryFee,
    required this.minOrder,
    required this.description,
    required this.phone,
    required this.email,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.openingHours,
    required this.isOpen,
    required this.paymentMethods,
    required this.socials,
    required this.foods,
  });

  factory RestaurantModel.fromJson(Map<String, dynamic> json) {
    final backendId = json['_id']?.toString() ?? json['backendId']?.toString() ?? '';
    final dynamic rawId = json['id'];

    int restaurantId = 0;
    if (rawId is num) {
      restaurantId = rawId.toInt();
    } else if (rawId is String && rawId.isNotEmpty) {
      restaurantId = int.tryParse(rawId) ?? rawId.hashCode % 1000000;
    } else if (backendId.isNotEmpty) {
      final tail = backendId.length > 6 ? backendId.substring(backendId.length - 6) : backendId;
      restaurantId = int.tryParse(tail) ?? backendId.hashCode % 1000000;
    }

    final location = json['location'] as Map<String, dynamic>?;
    final List<dynamic>? coordinates = location?['coordinates'] as List<dynamic>?;

    return RestaurantModel(
      id: restaurantId,
      backendId: backendId,
      name: json['restaurantName']?.toString() ?? json['restaurant_name']?.toString() ?? json['name']?.toString() ?? '',
      city: location?['city']?.toString() ?? json['city']?.toString() ?? '',
      foodType: json['foodType']?.toString() ?? json['food_type']?.toString() ?? '',
      imageUrl: json['logo']?.toString() ?? json['imageUrl']?.toString() ?? json['image_url']?.toString() ?? '',
      bannerImages:
          (json['bannerImages'] as List<dynamic>? ?? json['banner_images'] as List<dynamic>?)
              ?.map((e) => e?.toString() ?? '')
              .where((e) => e.isNotEmpty)
              .toList() ??
          [],
      distance: (json['distance'] as num?)?.toDouble() ?? 0.0,
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      totalReviews: (json['totalReviews'] as num? ?? json['total_reviews'] as num?)?.toInt() ?? 0,
      averageDeliveryTime: json['averageDeliveryTime']?.toString() ?? json['average_delivery_time']?.toString() ?? '',
      deliveryFee: (json['deliveryFee'] as num? ?? json['delivery_fee'] as num?)?.toDouble() ?? 0.0,
      minOrder: (json['minOrder'] as num? ?? json['min_order'] as num?)?.toDouble() ?? 0.0,
      description: json['description']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      address: location?['address']?.toString() ?? json['address']?.toString() ?? '',
      latitude: coordinates != null && coordinates.length >= 2
          ? (coordinates[1] as num).toDouble()
          : (location?['lat'] as num? ?? json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: coordinates != null && coordinates.length >= 2
          ? (coordinates[0] as num).toDouble()
          : (location?['lng'] as num? ?? json['longitude'] as num?)?.toDouble() ?? 0.0,
      openingHours: json['openingHours']?.toString() ?? json['opening_hours']?.toString() ?? '',
      isOpen: (json['isOpen'] ?? json['is_open']) is bool
          ? (json['isOpen'] ?? json['is_open']) as bool
          : (json['isOpen'] ?? json['is_open'])?.toString().toLowerCase() == 'true',
      paymentMethods:
          (json['paymentMethods'] as List<dynamic>? ?? json['payment_methods'] as List<dynamic>?)
              ?.map((e) => e?.toString() ?? '')
              .where((e) => e.isNotEmpty)
              .toList() ??
          [],
      socials: Socials.fromJson(json['socials'] is Map ? (json['socials'] as Map<String, dynamic>) : {}),
      foods:
          (json['foods'] as List<dynamic>?)
              ?.map((foodJson) => Food.fromJson(foodJson as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class Socials {
  final String instagram;
  final String facebook;

  Socials({required this.instagram, required this.facebook});

  factory Socials.fromJson(Map<String, dynamic> json) {
    return Socials(instagram: json['instagram']?.toString() ?? '', facebook: json['facebook']?.toString() ?? '');
  }
}

class Food {
  final String backendId;
  final int id;
  final String name;
  final double price;
  final String imageUrl;
  final String category;
  final String description;
  final int sellerId;
  final String sellerName;
  final String restaurantId;

  Food({
    required this.backendId,
    required this.id,
    required this.name,
    required this.price,
    required this.imageUrl,
    required this.category,
    required this.description,
    required this.sellerId,
    required this.sellerName,
    required this.restaurantId,
  });

  factory Food.fromJson(Map<String, dynamic> json) {
    final backendId = json['_id']?.toString() ?? json['backendId']?.toString() ?? json['id']?.toString() ?? '';

    int foodId = 0;
    if (json['id'] != null) {
      if (json['id'] is num) {
        foodId = (json['id'] as num).toInt();
      } else {
        foodId = json['id'].toString().hashCode;
      }
    } else if (backendId.isNotEmpty) {
      foodId = backendId.hashCode;
    }

    String restaurantId = '';
    final restaurantField = json['restaurant'];
    if (restaurantField is Map<String, dynamic>) {
      restaurantId =
          restaurantField['_id']?.toString() ??
          restaurantField['backendId']?.toString() ??
          restaurantField['id']?.toString() ??
          '';
    } else if (restaurantField != null) {
      restaurantId = restaurantField.toString();
    }
    if (restaurantId.isEmpty) {
      restaurantId = json['restaurantId']?.toString() ?? json['restaurant_id']?.toString() ?? '';
    }

    return Food(
      backendId: backendId,
      id: foodId,
      name: json['name']?.toString() ?? json['food_name']?.toString() ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      imageUrl: json['foodImage']?.toString() ?? json['imageUrl']?.toString() ?? json['image_url']?.toString() ?? json['image']?.toString() ?? '',
      category: json['category']?.toString() ?? json['category_name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      sellerId:
          (json['sellerId'] as num?)?.toInt() ??
          (json['seller_id'] as num?)?.toInt() ??
          (json['restaurant'] as num?)?.toInt() ??
          0,
      sellerName:
          json['sellerName']?.toString() ??
          json['seller_name']?.toString() ??
          json['restaurant_name']?.toString() ??
          '',
      restaurantId: restaurantId,
    );
  }
}
