// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'vendor_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

VendorModel _$VendorModelFromJson(Map<String, dynamic> json) => VendorModel(
  id: json['_id'] as String,
  storeName: json['storeName'] as String?,
  logo: json['logo'] as String?,
  description: json['description'] as String?,
  address: json['address'] as String,
  phone: json['phone'] as String,
  email: json['email'] as String,
  isOpen: json['isOpen'] as bool?,
  deliveryFee: (json['deliveryFee'] as num?)?.toDouble(),
  minOrder: (json['minOrder'] as num?)?.toDouble(),
  rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
  totalReviews: (json['totalReviews'] as num?)?.toInt(),
  categories: (json['categories'] as List<dynamic>?)
      ?.map((e) => e as String)
      .toList(),
  foodType: json['food_type'] as String?,
  latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
  longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
  operatingHours: json['operatingHours'] as String?,
  deliveryTime: json['average_delivery_time'] as String?,
  licenseNumber: json['licenseNumber'] as String?,
  pharmacistName: json['pharmacistName'] as String?,
  pharmacistLicense: json['pharmacistLicense'] as String?,
  prescriptionRequired: json['prescriptionRequired'] as bool?,
  emergencyService: json['emergencyService'] as bool?,
  insuranceAccepted: (json['insuranceAccepted'] as List<dynamic>?)
      ?.map((e) => e as String)
      .toList(),
  is24Hours: json['is24Hours'] as bool?,
  hasParking: json['hasParking'] as bool?,
  acceptsCash: json['acceptsCash'] as bool?,
  acceptsCard: json['acceptsCard'] as bool?,
  acceptsMobileMoney: json['acceptsMobileMoney'] as bool?,
  services: (json['services'] as List<dynamic>?)
      ?.map((e) => e as String)
      .toList(),
  productTypes: (json['productTypes'] as List<dynamic>?)
      ?.map((e) => e as String)
      .toList(),
  isExclusive: json['isExclusive'] as bool?,
  createdAt: json['createdAt'] == null
      ? null
      : DateTime.parse(json['createdAt'] as String),
  updatedAt: json['updatedAt'] == null
      ? null
      : DateTime.parse(json['updatedAt'] as String),
);

Map<String, dynamic> _$VendorModelToJson(VendorModel instance) =>
    <String, dynamic>{
      '_id': instance.id,
      'storeName': instance.storeName,
      'logo': instance.logo,
      'description': instance.description,
      'address': instance.address,
      'phone': instance.phone,
      'email': instance.email,
      'isOpen': instance.isOpen,
      'deliveryFee': instance.deliveryFee,
      'minOrder': instance.minOrder,
      'rating': instance.rating,
      'totalReviews': instance.totalReviews,
      'categories': instance.categories,
      'food_type': instance.foodType,
      'latitude': instance.latitude,
      'longitude': instance.longitude,
      'operatingHours': instance.operatingHours,
      'average_delivery_time': instance.deliveryTime,
      'licenseNumber': instance.licenseNumber,
      'pharmacistName': instance.pharmacistName,
      'pharmacistLicense': instance.pharmacistLicense,
      'prescriptionRequired': instance.prescriptionRequired,
      'emergencyService': instance.emergencyService,
      'insuranceAccepted': instance.insuranceAccepted,
      'is24Hours': instance.is24Hours,
      'hasParking': instance.hasParking,
      'acceptsCash': instance.acceptsCash,
      'acceptsCard': instance.acceptsCard,
      'acceptsMobileMoney': instance.acceptsMobileMoney,
      'services': instance.services,
      'productTypes': instance.productTypes,
      'isExclusive': instance.isExclusive,
      'createdAt': instance.createdAt?.toIso8601String(),
      'updatedAt': instance.updatedAt?.toIso8601String(),
    };
