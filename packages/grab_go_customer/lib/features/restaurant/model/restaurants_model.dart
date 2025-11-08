class RestaurantModel {
  final int id;
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
    final idStr = json['_id']?.toString() ?? '';
    int restaurantId = 0;
    if (idStr.isNotEmpty) {
      try {
        restaurantId = int.tryParse(idStr.length > 6 ? idStr.substring(idStr.length - 6) : idStr) ?? 0;
      } catch (e) {
        restaurantId = idStr.hashCode % 1000000;
      }
    }

    return RestaurantModel(
      id: restaurantId,
      name: json['restaurant_name']?.toString() ?? json['name']?.toString() ?? '',
      city: json['city']?.toString() ?? '',
      foodType: json['food_type']?.toString() ?? '',
      imageUrl: json['logo']?.toString() ?? json['image_url']?.toString() ?? '',
      bannerImages:
          (json['banner_images'] as List<dynamic>?)
              ?.map((e) => e?.toString() ?? '')
              .where((e) => e.isNotEmpty)
              .toList() ??
          [],
      distance: (json['distance'] as num?)?.toDouble() ?? 0.0,
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      totalReviews: (json['total_reviews'] as num?)?.toInt() ?? 0,
      averageDeliveryTime: json['average_delivery_time']?.toString() ?? '',
      deliveryFee: (json['delivery_fee'] as num?)?.toDouble() ?? 0.0,
      minOrder: (json['min_order'] as num?)?.toDouble() ?? 0.0,
      description: json['description']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      openingHours: json['opening_hours']?.toString() ?? '',
      isOpen: json['is_open'] is bool ? json['is_open'] as bool : (json['is_open']?.toString().toLowerCase() == 'true'),
      paymentMethods:
          (json['payment_methods'] as List<dynamic>?)
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
  final int id;
  final String name;
  final double price;
  final String imageUrl;
  final String category;
  final String description;
  final int sellerId;
  final String sellerName;

  Food({
    required this.id,
    required this.name,
    required this.price,
    required this.imageUrl,
    required this.category,
    required this.description,
    required this.sellerId,
    required this.sellerName,
  });

  factory Food.fromJson(Map<String, dynamic> json) {
    int foodId = 0;
    if (json['id'] != null) {
      if (json['id'] is num) {
        foodId = (json['id'] as num).toInt();
      } else {
        foodId = json['id'].toString().hashCode;
      }
    } else if (json['_id'] != null) {
      foodId = json['_id'].toString().hashCode;
    }

    return Food(
      id: foodId,
      name: json['name']?.toString() ?? json['food_name']?.toString() ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      imageUrl: json['imageUrl']?.toString() ?? json['image_url']?.toString() ?? json['image']?.toString() ?? '',
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
    );
  }
}
