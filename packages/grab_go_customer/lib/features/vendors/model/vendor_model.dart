import 'package:json_annotation/json_annotation.dart';
import 'vendor_type.dart';

part 'vendor_model.g.dart';

@JsonSerializable()
class DaySchedule {
  final String open;
  final String close;
  final bool isClosed;

  DaySchedule({
    this.open = '09:00',
    this.close = '21:00',
    this.isClosed = false,
  });

  factory DaySchedule.fromJson(Map<String, dynamic> json) => _$DayScheduleFromJson(json);
  Map<String, dynamic> toJson() => _$DayScheduleToJson(this);
}

@JsonSerializable()
class OpeningHours {
  final DaySchedule? monday;
  final DaySchedule? tuesday;
  final DaySchedule? wednesday;
  final DaySchedule? thursday;
  final DaySchedule? friday;
  final DaySchedule? saturday;
  final DaySchedule? sunday;

  OpeningHours({
    this.monday,
    this.tuesday,
    this.wednesday,
    this.thursday,
    this.friday,
    this.saturday,
    this.sunday,
  });

  factory OpeningHours.fromJson(Map<String, dynamic> json) => _$OpeningHoursFromJson(json);
  Map<String, dynamic> toJson() => _$OpeningHoursToJson(this);
}

@JsonSerializable()
class VendorLocation {
  final double lat;
  final double lng;
  final String address;
  final String city;
  final String? area;

  VendorLocation({
    required this.lat,
    required this.lng,
    required this.address,
    required this.city,
    this.area,
  });

  factory VendorLocation.fromJson(Map<String, dynamic> json) {
    if (json['coordinates'] != null) {
      final coords = json['coordinates'] as List;
      return VendorLocation(
        lng: (coords[0] as num).toDouble(),
        lat: (coords[1] as num).toDouble(),
        address: (json['address'] ?? '').toString(),
        city: (json['city'] ?? '').toString(),
        area: json['area']?.toString(),
      );
    }
    return VendorLocation(
      lat: (json['lat'] ?? 0.0).toDouble(),
      lng: (json['lng'] ?? 0.0).toDouble(),
      address: (json['address'] ?? '').toString(),
      city: (json['city'] ?? '').toString(),
      area: json['area']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => _$VendorLocationToJson(this);
}

@JsonSerializable()
class VendorModel {
  @JsonKey(name: '_id')
  final String id;

  final String? storeName;
  final String? restaurantName;
  final String? name;

  // Computed name
  String get displayName => storeName ?? restaurantName ?? name ?? 'Unknown Vendor';

  final String? logo;
  final String? description;
  final String phone;
  final String email;
  final bool isOpen;
  final bool isAcceptingOrders;
  final double deliveryFee;
  final double minOrder;
  final double rating;
  final int totalReviews;
  final List<String>? categories;
  final String? foodType;
  final VendorLocation? location;
  final OpeningHours? openingHours;
  final String? deliveryTime;
  final int? averageDeliveryTime;
  final int? averagePreparationTime;
  final double? deliveryRadius;
  final List<String>? features;
  final List<String>? tags;
  final bool? featured;
  final DateTime? featuredUntil;
  final bool? isVerified;
  final DateTime? verifiedAt;
  final String? whatsappNumber;
  final List<String>? paymentMethods;
  final List<String>? bannerImages;
  final bool? isGrabGoExclusive;
  final DateTime? isGrabGoExclusiveUntil;
  final String? vendorType;
  final DateTime? lastOnlineAt;
  final double? distance;

  // Audit
  final DateTime? createdAt;
  final DateTime? updatedAt;

  @JsonKey(includeFromJson: false, includeToJson: false)
  final VendorType vendorTypeEnum;

  VendorModel({
    required this.id,
    this.storeName,
    this.restaurantName,
    this.name,
    this.logo,
    this.description,
    required this.phone,
    required this.email,
    this.isOpen = true,
    this.isAcceptingOrders = true,
    this.deliveryFee = 0.0,
    this.minOrder = 0.0,
    this.rating = 0.0,
    this.totalReviews = 0,
    this.categories,
    this.foodType,
    this.location,
    this.openingHours,
    this.deliveryTime,
    this.averageDeliveryTime,
    this.averagePreparationTime,
    this.deliveryRadius,
    this.features,
    this.tags,
    this.featured,
    this.featuredUntil,
    this.isVerified,
    this.verifiedAt,
    this.whatsappNumber,
    this.paymentMethods,
    this.bannerImages,
    this.isGrabGoExclusive,
    this.isGrabGoExclusiveUntil,
    this.vendorType,
    this.lastOnlineAt,
    this.distance,
    this.createdAt,
    this.updatedAt,
    this.vendorTypeEnum = VendorType.food,
  });

  factory VendorModel.fromJson(Map<String, dynamic> json) {
    return VendorModel(
      id: json['_id'] ?? (json['id'] ?? '').toString(),
      storeName: json['storeName']?.toString() ?? json['store_name']?.toString(),
      restaurantName: json['restaurantName']?.toString() ?? json['restaurant_name']?.toString(),
      name: json['name']?.toString(),
      logo: json['logo']?.toString(),
      description: json['description']?.toString(),
      phone: (json['phone'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      isOpen: json['isOpen'] as bool? ?? json['is_open'] as bool? ?? true,
      isAcceptingOrders: json['isAcceptingOrders'] as bool? ?? true,
      deliveryFee: (json['deliveryFee'] ?? json['delivery_fee'] ?? 0.0).toDouble(),
      minOrder: (json['minOrder'] ?? json['min_order'] ?? 0.0).toDouble(),
      rating: (json['rating'] ?? 0.0).toDouble(),
      totalReviews: (json['totalReviews'] ?? json['total_reviews'] ?? 0) as int,
      categories: (json['categories'] as List?)?.map((e) => e.toString()).toList(),
      foodType: json['foodType']?.toString() ?? json['food_type']?.toString(),
      location: json['location'] != null ? VendorLocation.fromJson(json['location'] as Map<String, dynamic>) : null,
      openingHours: json['openingHours'] != null ? OpeningHours.fromJson(json['openingHours'] as Map<String, dynamic>) : null,
      deliveryTime: json['deliveryTime']?.toString() ?? json['average_delivery_time']?.toString(),
      averageDeliveryTime: json['averageDeliveryTime'] as int? ?? (json['average_delivery_time'] is int ? json['average_delivery_time'] as int : null),
      averagePreparationTime: json['averagePreparationTime'] as int? ?? json['average_preparation_time'] as int?,
      deliveryRadius: (json['deliveryRadius'] ?? json['delivery_radius'] ?? 5.0).toDouble(),
      features: (json['features'] as List?)?.map((e) => e.toString()).toList(),
      tags: (json['tags'] as List?)?.map((e) => e.toString()).toList(),
      featured: json['featured'] as bool?,
      featuredUntil: json['featuredUntil'] != null ? DateTime.tryParse(json['featuredUntil'].toString()) : null,
      isVerified: json['isVerified'] as bool?,
      verifiedAt: json['verifiedAt'] != null ? DateTime.tryParse(json['verifiedAt'].toString()) : null,
      whatsappNumber: json['whatsappNumber']?.toString(),
      paymentMethods: (json['paymentMethods'] ?? json['payment_methods'] as List?)?.map((e) => e.toString()).toList(),
      bannerImages: (json['bannerImages'] ?? json['banner_images'] as List?)?.map((e) => e.toString()).toList(),
      isGrabGoExclusive: json['isGrabGoExclusive'] as bool? ?? json['is_exclusive'] as bool?,
      isGrabGoExclusiveUntil: json['isGrabGoExclusiveUntil'] != null ? DateTime.tryParse(json['isGrabGoExclusiveUntil'].toString()) : null,
      vendorType: json['vendorType']?.toString(),
      lastOnlineAt: json['lastOnlineAt'] != null ? DateTime.tryParse(json['lastOnlineAt'].toString()) : null,
      distance: (json['distance'] != null) ? (json['distance'] as num).toDouble() : null,
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'].toString()) : null,
      updatedAt: json['updatedAt'] != null ? DateTime.tryParse(json['updatedAt'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() => _$VendorModelToJson(this);

  // Helper getters for backward compatibility
  String get address => location?.address ?? '';
  String get city => location?.city ?? '';
  String? get area => location?.area;
  double get latitude => location?.lat ?? 0.0;
  double get longitude => location?.lng ?? 0.0;

  String get distanceText {
    if (distance == null) return '';
    if (distance! < 1) {
      return '${(distance! * 1000).toStringAsFixed(0)}m away';
    }
    return '${distance!.toStringAsFixed(1)}km away';
  }

  String get deliveryFeeText {
    if (deliveryFee == 0) return 'Free delivery';
    return 'GHS ${deliveryFee.toStringAsFixed(0)}';
  }

  String get minOrderText {
    return 'Min. GHS ${minOrder.toStringAsFixed(0)}';
  }
  
  String get deliveryTimeText {
    if (averageDeliveryTime != null) {
      return '$averageDeliveryTime mins';
    }
    return deliveryTime ?? '30 mins';
  }
}
