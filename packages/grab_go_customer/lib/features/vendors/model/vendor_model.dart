import 'package:json_annotation/json_annotation.dart';
import 'vendor_type.dart';

part 'vendor_model.g.dart';

@JsonSerializable()
class DaySchedule {
  final String open;
  final String close;
  final bool isClosed;

  DaySchedule({this.open = '09:00', this.close = '21:00', this.isClosed = false});

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

  OpeningHours({this.monday, this.tuesday, this.wednesday, this.thursday, this.friday, this.saturday, this.sunday});

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

  VendorLocation({required this.lat, required this.lng, required this.address, required this.city, this.area});

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

  final bool? emergencyService;
  final String? licenseNumber;
  final String? pharmacistName;
  final List<String>? insuranceAccepted;
  final bool? prescriptionRequired;

  final bool? is24Hours;
  final bool? hasParking;
  final List<String>? services;
  final List<String>? productTypes;

  final String? businessIdNumber;

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
    this.emergencyService,
    this.licenseNumber,
    this.pharmacistName,
    this.insuranceAccepted,
    this.prescriptionRequired,
    this.is24Hours,
    this.hasParking,
    this.services,
    this.productTypes,
    this.businessIdNumber,
    this.createdAt,
    this.updatedAt,
    this.vendorTypeEnum = VendorType.food,
  });

  factory VendorModel.fromJson(Map<String, dynamic> json) {
    final normalized = Map<String, dynamic>.from(json);
    if (normalized['isOpen'] == null && normalized['is_open'] != null) {
      normalized['isOpen'] = normalized['is_open'];
    }
    final rawOpen = normalized['isOpen'];
    if (rawOpen is String) {
      normalized['isOpen'] = rawOpen.toLowerCase() == 'true';
    } else if (rawOpen is num) {
      normalized['isOpen'] = rawOpen != 0;
    }
    return _$VendorModelFromJson(normalized);
  }

  VendorModel copyWith({
    String? id,
    String? storeName,
    String? restaurantName,
    String? name,
    String? logo,
    String? description,
    String? phone,
    String? email,
    bool? isOpen,
    bool? isAcceptingOrders,
    double? deliveryFee,
    double? minOrder,
    double? rating,
    int? totalReviews,
    List<String>? categories,
    String? foodType,
    VendorLocation? location,
    OpeningHours? openingHours,
    String? deliveryTime,
    int? averageDeliveryTime,
    int? averagePreparationTime,
    double? deliveryRadius,
    List<String>? features,
    List<String>? tags,
    bool? featured,
    DateTime? featuredUntil,
    bool? isVerified,
    DateTime? verifiedAt,
    String? whatsappNumber,
    List<String>? paymentMethods,
    List<String>? bannerImages,
    bool? isGrabGoExclusive,
    DateTime? isGrabGoExclusiveUntil,
    String? vendorType,
    DateTime? lastOnlineAt,
    double? distance,
    bool? emergencyService,
    String? licenseNumber,
    String? pharmacistName,
    List<String>? insuranceAccepted,
    bool? prescriptionRequired,
    bool? is24Hours,
    bool? hasParking,
    List<String>? services,
    List<String>? productTypes,
    String? businessIdNumber,
    DateTime? createdAt,
    DateTime? updatedAt,
    VendorType? vendorTypeEnum,
  }) {
    return VendorModel(
      id: id ?? this.id,
      storeName: storeName ?? this.storeName,
      restaurantName: restaurantName ?? this.restaurantName,
      name: name ?? this.name,
      logo: logo ?? this.logo,
      description: description ?? this.description,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      isOpen: isOpen ?? this.isOpen,
      isAcceptingOrders: isAcceptingOrders ?? this.isAcceptingOrders,
      deliveryFee: deliveryFee ?? this.deliveryFee,
      minOrder: minOrder ?? this.minOrder,
      rating: rating ?? this.rating,
      totalReviews: totalReviews ?? this.totalReviews,
      categories: categories ?? this.categories,
      foodType: foodType ?? this.foodType,
      location: location ?? this.location,
      openingHours: openingHours ?? this.openingHours,
      deliveryTime: deliveryTime ?? this.deliveryTime,
      averageDeliveryTime: averageDeliveryTime ?? this.averageDeliveryTime,
      averagePreparationTime: averagePreparationTime ?? this.averagePreparationTime,
      deliveryRadius: deliveryRadius ?? this.deliveryRadius,
      features: features ?? this.features,
      tags: tags ?? this.tags,
      featured: featured ?? this.featured,
      featuredUntil: featuredUntil ?? this.featuredUntil,
      isVerified: isVerified ?? this.isVerified,
      verifiedAt: verifiedAt ?? this.verifiedAt,
      whatsappNumber: whatsappNumber ?? this.whatsappNumber,
      paymentMethods: paymentMethods ?? this.paymentMethods,
      bannerImages: bannerImages ?? this.bannerImages,
      isGrabGoExclusive: isGrabGoExclusive ?? this.isGrabGoExclusive,
      isGrabGoExclusiveUntil: isGrabGoExclusiveUntil ?? this.isGrabGoExclusiveUntil,
      vendorType: vendorType ?? this.vendorType,
      lastOnlineAt: lastOnlineAt ?? this.lastOnlineAt,
      distance: distance ?? this.distance,
      emergencyService: emergencyService ?? this.emergencyService,
      licenseNumber: licenseNumber ?? this.licenseNumber,
      pharmacistName: pharmacistName ?? this.pharmacistName,
      insuranceAccepted: insuranceAccepted ?? this.insuranceAccepted,
      prescriptionRequired: prescriptionRequired ?? this.prescriptionRequired,
      is24Hours: is24Hours ?? this.is24Hours,
      hasParking: hasParking ?? this.hasParking,
      services: services ?? this.services,
      productTypes: productTypes ?? this.productTypes,
      businessIdNumber: businessIdNumber ?? this.businessIdNumber,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      vendorTypeEnum: vendorTypeEnum ?? this.vendorTypeEnum,
    );
  }

  factory VendorModel.fromJson(Map<String, dynamic> json) {
    List<String>? parseStringList(dynamic val) {
      if (val == null) return null;
      if (val is List) {
        return val.map((e) => e.toString()).toList();
      }
      return null;
    }

    return VendorModel(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
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
      categories: parseStringList(json['categories']),
      foodType: json['foodType']?.toString() ?? json['food_type']?.toString(),
      location: json['location'] != null ? VendorLocation.fromJson(json['location'] as Map<String, dynamic>) : null,
      openingHours: json['openingHours'] != null
          ? OpeningHours.fromJson(json['openingHours'] as Map<String, dynamic>)
          : null,
      deliveryTime: json['deliveryTime']?.toString() ?? json['average_delivery_time']?.toString(),
      averageDeliveryTime:
          json['averageDeliveryTime'] as int? ??
          (json['average_delivery_time'] is int ? json['average_delivery_time'] as int : null),
      averagePreparationTime: json['averagePreparationTime'] as int? ?? json['average_preparation_time'] as int?,
      deliveryRadius: (json['deliveryRadius'] ?? json['delivery_radius'] ?? 5.0).toDouble(),
      features: parseStringList(json['features']),
      tags: parseStringList(json['tags']),
      featured: json['featured'] as bool?,
      featuredUntil: json['featuredUntil'] != null ? DateTime.tryParse(json['featuredUntil'].toString()) : null,
      isVerified: json['isVerified'] as bool?,
      verifiedAt: json['verifiedAt'] != null ? DateTime.tryParse(json['verifiedAt'].toString()) : null,
      whatsappNumber: json['whatsappNumber']?.toString(),
      paymentMethods: parseStringList(json['paymentMethods'] ?? json['payment_methods']),
      bannerImages: parseStringList(json['bannerImages'] ?? json['banner_images']),
      isGrabGoExclusive: json['isGrabGoExclusive'] as bool? ?? json['is_exclusive'] as bool?,
      isGrabGoExclusiveUntil: json['isGrabGoExclusiveUntil'] != null
          ? DateTime.tryParse(json['isGrabGoExclusiveUntil'].toString())
          : null,
      vendorType: json['vendorType']?.toString(),
      lastOnlineAt: json['lastOnlineAt'] != null ? DateTime.tryParse(json['lastOnlineAt'].toString()) : null,
      distance: (json['distance'] != null) ? (json['distance'] as num).toDouble() : null,
      emergencyService: json['emergencyService'] as bool? ?? json['emergency_service'] as bool?,
      licenseNumber: json['licenseNumber']?.toString() ?? json['license_number']?.toString(),
      pharmacistName: json['pharmacistName']?.toString() ?? json['pharmacist_name']?.toString(),
      insuranceAccepted: parseStringList(json['insuranceAccepted'] ?? json['insurance_accepted']),
      prescriptionRequired: json['prescriptionRequired'] as bool? ?? json['prescription_required'] as bool?,
      is24Hours: json['is24Hours'] as bool? ?? json['is_24_hours'] as bool?,
      hasParking: json['hasParking'] as bool? ?? json['has_parking'] as bool?,
      services: parseStringList(json['services']),
      productTypes: parseStringList(json['productTypes'] ?? json['product_types']),
      businessIdNumber: json['businessIdNumber']?.toString() ?? json['business_id_number']?.toString(),
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'].toString()) : null,
      updatedAt: json['updatedAt'] != null ? DateTime.tryParse(json['updatedAt'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() => _$VendorModelToJson(this);

  // Helper getters for backward compatibility
  bool get isExclusive => isGrabGoExclusive ?? false;
  List<String> get vendorCategories => categories ?? [];
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
