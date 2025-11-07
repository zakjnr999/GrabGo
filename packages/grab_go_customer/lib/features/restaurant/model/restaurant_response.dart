import 'package:json_annotation/json_annotation.dart';

part 'restaurant_response.g.dart';

@JsonSerializable()
class RestaurantResponse {
  final bool success;
  final String message;
  final List<RestaurantData>? data;
  final String? error;

  const RestaurantResponse({required this.success, required this.message, this.data, this.error});

  factory RestaurantResponse.fromJson(Map<String, dynamic> json) => _$RestaurantResponseFromJson(json);

  Map<String, dynamic> toJson() => _$RestaurantResponseToJson(this);
}

@JsonSerializable()
class RestaurantData {
  @JsonKey(name: '_id')
  final String id;

  @JsonKey(name: 'restaurant_name')
  final String restaurantName;

  final String email;
  final String phone;
  final String address;
  final String city;

  @JsonKey(name: 'owner_full_name')
  final String ownerFullName;

  @JsonKey(name: 'owner_contact_number')
  final String ownerContactNumber;

  @JsonKey(name: 'business_id_number')
  final String businessIdNumber;

  final String password;
  final String? logo;
  @JsonKey(name: 'business_id_photo')
  final String? businessIdPhoto;
  @JsonKey(name: 'owner_photo')
  final String? ownerPhoto;

  @JsonKey(name: 'food_type')
  final String? foodType;

  final String? description;
  final double? latitude;
  final double? longitude;

  @JsonKey(name: 'average_delivery_time')
  final String? averageDeliveryTime;

  @JsonKey(name: 'delivery_fee')
  final double? deliveryFee;

  @JsonKey(name: 'min_order')
  final double? minOrder;

  @JsonKey(name: 'opening_hours')
  final String? openingHours;

  @JsonKey(name: 'payment_methods')
  final List<String>? paymentMethods;

  @JsonKey(name: 'banner_images')
  final List<String>? bannerImages;

  final String status;
  final double rating;

  @JsonKey(name: 'is_open')
  final bool isOpen;

  @JsonKey(name: 'total_reviews')
  final int totalReviews;

  @JsonKey(name: 'created_at')
  final DateTime createdAt;

  @JsonKey(name: '__v')
  final int version;

  final Socials? socials;

  const RestaurantData({
    required this.id,
    required this.restaurantName,
    required this.email,
    required this.phone,
    required this.address,
    required this.city,
    required this.ownerFullName,
    required this.ownerContactNumber,
    required this.businessIdNumber,
    required this.password,
    this.logo,
    this.businessIdPhoto,
    this.ownerPhoto,
    this.foodType,
    this.description,
    this.latitude,
    this.longitude,
    this.averageDeliveryTime,
    this.deliveryFee,
    this.minOrder,
    this.openingHours,
    this.paymentMethods,
    this.bannerImages,
    required this.status,
    required this.rating,
    required this.isOpen,
    required this.totalReviews,
    required this.createdAt,
    required this.version,
    this.socials,
  });

  factory RestaurantData.fromJson(Map<String, dynamic> json) => _$RestaurantDataFromJson(json);

  Map<String, dynamic> toJson() => _$RestaurantDataToJson(this);
}

@JsonSerializable()
class Socials {
  final String? facebook;
  final String? instagram;

  const Socials({this.facebook, this.instagram});

  factory Socials.fromJson(Map<String, dynamic> json) => _$SocialsFromJson(json);

  Map<String, dynamic> toJson() => _$SocialsToJson(this);
}
