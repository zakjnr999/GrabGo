// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'restaurant_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RestaurantResponse _$RestaurantResponseFromJson(Map<String, dynamic> json) =>
    RestaurantResponse(
      success: json['success'] as bool,
      message: json['message'] as String,
      data: (json['data'] as List<dynamic>?)
          ?.map((e) => RestaurantData.fromJson(e as Map<String, dynamic>))
          .toList(),
      error: json['error'] as String?,
    );

Map<String, dynamic> _$RestaurantResponseToJson(RestaurantResponse instance) =>
    <String, dynamic>{
      'success': instance.success,
      'message': instance.message,
      'data': instance.data,
      'error': instance.error,
    };

RestaurantData _$RestaurantDataFromJson(Map<String, dynamic> json) =>
    RestaurantData(
      id: json['_id'] as String,
      restaurantName: json['restaurant_name'] as String,
      email: json['email'] as String,
      phone: json['phone'] as String,
      address: json['address'] as String,
      city: json['city'] as String,
      ownerFullName: json['owner_full_name'] as String,
      ownerContactNumber: json['owner_contact_number'] as String,
      businessIdNumber: json['business_id_number'] as String,
      password: json['password'] as String,
      logo: json['logo'] as String?,
      businessIdPhoto: json['business_id_photo'] as String?,
      ownerPhoto: json['owner_photo'] as String?,
      foodType: json['food_type'] as String?,
      description: json['description'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      averageDeliveryTime: json['average_delivery_time'] as String?,
      deliveryFee: (json['delivery_fee'] as num?)?.toDouble(),
      minOrder: (json['min_order'] as num?)?.toDouble(),
      openingHours: json['opening_hours'] as String?,
      paymentMethods: (json['payment_methods'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      bannerImages: (json['banner_images'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      status: json['status'] as String,
      rating: (json['rating'] as num).toDouble(),
      isOpen: json['is_open'] as bool?,
      totalReviews: (json['total_reviews'] as num?)?.toInt(),
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.parse(json['createdAt'] as String),
      version: (json['__v'] as num?)?.toInt(),
      socials: json['socials'] == null
          ? null
          : Socials.fromJson(json['socials'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$RestaurantDataToJson(RestaurantData instance) =>
    <String, dynamic>{
      '_id': instance.id,
      'restaurant_name': instance.restaurantName,
      'email': instance.email,
      'phone': instance.phone,
      'address': instance.address,
      'city': instance.city,
      'owner_full_name': instance.ownerFullName,
      'owner_contact_number': instance.ownerContactNumber,
      'business_id_number': instance.businessIdNumber,
      'password': instance.password,
      'logo': instance.logo,
      'business_id_photo': instance.businessIdPhoto,
      'owner_photo': instance.ownerPhoto,
      'food_type': instance.foodType,
      'description': instance.description,
      'latitude': instance.latitude,
      'longitude': instance.longitude,
      'average_delivery_time': instance.averageDeliveryTime,
      'delivery_fee': instance.deliveryFee,
      'min_order': instance.minOrder,
      'opening_hours': instance.openingHours,
      'payment_methods': instance.paymentMethods,
      'banner_images': instance.bannerImages,
      'status': instance.status,
      'rating': instance.rating,
      'is_open': instance.isOpen,
      'total_reviews': instance.totalReviews,
      'createdAt': instance.createdAt?.toIso8601String(),
      '__v': instance.version,
      'socials': instance.socials,
    };

Socials _$SocialsFromJson(Map<String, dynamic> json) => Socials(
  facebook: json['facebook'] as String?,
  instagram: json['instagram'] as String?,
);

Map<String, dynamic> _$SocialsToJson(Socials instance) => <String, dynamic>{
  'facebook': instance.facebook,
  'instagram': instance.instagram,
};
