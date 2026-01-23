// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'vendor_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DaySchedule _$DayScheduleFromJson(Map<String, dynamic> json) => DaySchedule(
  open: json['open'] as String? ?? '09:00',
  close: json['close'] as String? ?? '21:00',
  isClosed: json['isClosed'] as bool? ?? false,
);

Map<String, dynamic> _$DayScheduleToJson(DaySchedule instance) =>
    <String, dynamic>{
      'open': instance.open,
      'close': instance.close,
      'isClosed': instance.isClosed,
    };

OpeningHours _$OpeningHoursFromJson(Map<String, dynamic> json) => OpeningHours(
  monday: json['monday'] == null
      ? null
      : DaySchedule.fromJson(json['monday'] as Map<String, dynamic>),
  tuesday: json['tuesday'] == null
      ? null
      : DaySchedule.fromJson(json['tuesday'] as Map<String, dynamic>),
  wednesday: json['wednesday'] == null
      ? null
      : DaySchedule.fromJson(json['wednesday'] as Map<String, dynamic>),
  thursday: json['thursday'] == null
      ? null
      : DaySchedule.fromJson(json['thursday'] as Map<String, dynamic>),
  friday: json['friday'] == null
      ? null
      : DaySchedule.fromJson(json['friday'] as Map<String, dynamic>),
  saturday: json['saturday'] == null
      ? null
      : DaySchedule.fromJson(json['saturday'] as Map<String, dynamic>),
  sunday: json['sunday'] == null
      ? null
      : DaySchedule.fromJson(json['sunday'] as Map<String, dynamic>),
);

Map<String, dynamic> _$OpeningHoursToJson(OpeningHours instance) =>
    <String, dynamic>{
      'monday': instance.monday,
      'tuesday': instance.tuesday,
      'wednesday': instance.wednesday,
      'thursday': instance.thursday,
      'friday': instance.friday,
      'saturday': instance.saturday,
      'sunday': instance.sunday,
    };

VendorLocation _$VendorLocationFromJson(Map<String, dynamic> json) =>
    VendorLocation(
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      address: json['address'] as String,
      city: json['city'] as String,
      area: json['area'] as String?,
    );

Map<String, dynamic> _$VendorLocationToJson(VendorLocation instance) =>
    <String, dynamic>{
      'lat': instance.lat,
      'lng': instance.lng,
      'address': instance.address,
      'city': instance.city,
      'area': instance.area,
    };

VendorModel _$VendorModelFromJson(Map<String, dynamic> json) => VendorModel(
  id: json['_id'] as String,
  storeName: json['storeName'] as String?,
  restaurantName: json['restaurantName'] as String?,
  name: json['name'] as String?,
  logo: json['logo'] as String?,
  description: json['description'] as String?,
  phone: json['phone'] as String,
  email: json['email'] as String,
  isOpen: json['isOpen'] as bool? ?? true,
  isAcceptingOrders: json['isAcceptingOrders'] as bool? ?? true,
  deliveryFee: (json['deliveryFee'] as num?)?.toDouble() ?? 0.0,
  minOrder: (json['minOrder'] as num?)?.toDouble() ?? 0.0,
  rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
  totalReviews: (json['totalReviews'] as num?)?.toInt() ?? 0,
  categories: (json['categories'] as List<dynamic>?)
      ?.map((e) => e as String)
      .toList(),
  foodType: json['foodType'] as String?,
  location: json['location'] == null
      ? null
      : VendorLocation.fromJson(json['location'] as Map<String, dynamic>),
  openingHours: json['openingHours'] == null
      ? null
      : OpeningHours.fromJson(json['openingHours'] as Map<String, dynamic>),
  deliveryTime: json['deliveryTime'] as String?,
  averageDeliveryTime: (json['averageDeliveryTime'] as num?)?.toInt(),
  averagePreparationTime: (json['averagePreparationTime'] as num?)?.toInt(),
  deliveryRadius: (json['deliveryRadius'] as num?)?.toDouble(),
  features: (json['features'] as List<dynamic>?)
      ?.map((e) => e as String)
      .toList(),
  tags: (json['tags'] as List<dynamic>?)?.map((e) => e as String).toList(),
  featured: json['featured'] as bool?,
  featuredUntil: json['featuredUntil'] == null
      ? null
      : DateTime.parse(json['featuredUntil'] as String),
  isVerified: json['isVerified'] as bool?,
  verifiedAt: json['verifiedAt'] == null
      ? null
      : DateTime.parse(json['verifiedAt'] as String),
  whatsappNumber: json['whatsappNumber'] as String?,
  paymentMethods: (json['paymentMethods'] as List<dynamic>?)
      ?.map((e) => e as String)
      .toList(),
  bannerImages: (json['bannerImages'] as List<dynamic>?)
      ?.map((e) => e as String)
      .toList(),
  isGrabGoExclusive: json['isGrabGoExclusive'] as bool?,
  isGrabGoExclusiveUntil: json['isGrabGoExclusiveUntil'] == null
      ? null
      : DateTime.parse(json['isGrabGoExclusiveUntil'] as String),
  vendorType: json['vendorType'] as String?,
  lastOnlineAt: json['lastOnlineAt'] == null
      ? null
      : DateTime.parse(json['lastOnlineAt'] as String),
  distance: (json['distance'] as num?)?.toDouble(),
  emergencyService: json['emergencyService'] as bool?,
  licenseNumber: json['licenseNumber'] as String?,
  pharmacistName: json['pharmacistName'] as String?,
  insuranceAccepted: (json['insuranceAccepted'] as List<dynamic>?)
      ?.map((e) => e as String)
      .toList(),
  prescriptionRequired: json['prescriptionRequired'] as bool?,
  is24Hours: json['is24Hours'] as bool?,
  hasParking: json['hasParking'] as bool?,
  services: (json['services'] as List<dynamic>?)
      ?.map((e) => e as String)
      .toList(),
  productTypes: (json['productTypes'] as List<dynamic>?)
      ?.map((e) => e as String)
      .toList(),
  businessIdNumber: json['businessIdNumber'] as String?,
  createdAt: json['createdAt'] == null
      ? null
      : DateTime.parse(json['createdAt'] as String),
  updatedAt: json['updatedAt'] == null
      ? null
      : DateTime.parse(json['updatedAt'] as String),
);

Map<String, dynamic> _$VendorModelToJson(
  VendorModel instance,
) => <String, dynamic>{
  '_id': instance.id,
  'storeName': instance.storeName,
  'restaurantName': instance.restaurantName,
  'name': instance.name,
  'logo': instance.logo,
  'description': instance.description,
  'phone': instance.phone,
  'email': instance.email,
  'isOpen': instance.isOpen,
  'isAcceptingOrders': instance.isAcceptingOrders,
  'deliveryFee': instance.deliveryFee,
  'minOrder': instance.minOrder,
  'rating': instance.rating,
  'totalReviews': instance.totalReviews,
  'categories': instance.categories,
  'foodType': instance.foodType,
  'location': instance.location,
  'openingHours': instance.openingHours,
  'deliveryTime': instance.deliveryTime,
  'averageDeliveryTime': instance.averageDeliveryTime,
  'averagePreparationTime': instance.averagePreparationTime,
  'deliveryRadius': instance.deliveryRadius,
  'features': instance.features,
  'tags': instance.tags,
  'featured': instance.featured,
  'featuredUntil': instance.featuredUntil?.toIso8601String(),
  'isVerified': instance.isVerified,
  'verifiedAt': instance.verifiedAt?.toIso8601String(),
  'whatsappNumber': instance.whatsappNumber,
  'paymentMethods': instance.paymentMethods,
  'bannerImages': instance.bannerImages,
  'isGrabGoExclusive': instance.isGrabGoExclusive,
  'isGrabGoExclusiveUntil': instance.isGrabGoExclusiveUntil?.toIso8601String(),
  'vendorType': instance.vendorType,
  'lastOnlineAt': instance.lastOnlineAt?.toIso8601String(),
  'distance': instance.distance,
  'emergencyService': instance.emergencyService,
  'licenseNumber': instance.licenseNumber,
  'pharmacistName': instance.pharmacistName,
  'insuranceAccepted': instance.insuranceAccepted,
  'prescriptionRequired': instance.prescriptionRequired,
  'is24Hours': instance.is24Hours,
  'hasParking': instance.hasParking,
  'services': instance.services,
  'productTypes': instance.productTypes,
  'businessIdNumber': instance.businessIdNumber,
  'createdAt': instance.createdAt?.toIso8601String(),
  'updatedAt': instance.updatedAt?.toIso8601String(),
};
