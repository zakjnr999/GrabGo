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

  factory DaySchedule.fromJson(Map<String, dynamic> json) =>
      _$DayScheduleFromJson(json);
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

  factory OpeningHours.fromJson(Map<String, dynamic> json) =>
      _$OpeningHoursFromJson(json);
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

OpeningHours? _parseOpeningHours(dynamic raw) {
  if (raw == null) return null;
  if (raw is Map<String, dynamic>) {
    return OpeningHours.fromJson(raw);
  }
  if (raw is List) {
    final hoursMap = <String, dynamic>{};
    const dayMap = {
      0: 'sunday',
      1: 'monday',
      2: 'tuesday',
      3: 'wednesday',
      4: 'thursday',
      5: 'friday',
      6: 'saturday',
    };

    for (final entry in raw) {
      if (entry is! Map) continue;
      final dayOfWeekValue = entry['dayOfWeek'];
      final int? dayOfWeek = dayOfWeekValue is num
          ? dayOfWeekValue.toInt()
          : int.tryParse(dayOfWeekValue?.toString() ?? '');
      final key = dayMap[dayOfWeek];
      if (key == null) continue;

      hoursMap[key] = {
        'open': (entry['open'] ?? entry['openTime'] ?? '09:00').toString(),
        'close': (entry['close'] ?? entry['closeTime'] ?? '21:00').toString(),
        'isClosed': entry['isClosed'] == true,
      };
    }

    if (hoursMap.isEmpty) return null;
    return OpeningHours.fromJson(hoursMap);
  }
  return null;
}

@JsonSerializable()
class VendorModel {
  @JsonKey(name: '_id')
  final String id;

  final String? storeName;
  final String? restaurantName;
  final String? name;

  String get displayName =>
      storeName ?? restaurantName ?? name ?? 'Unknown Vendor';

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
  final String? facebookUrl;
  final String? instagramUrl;
  final String? twitterUrl;
  final String? websiteUrl;
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
    this.facebookUrl,
    this.instagramUrl,
    this.twitterUrl,
    this.websiteUrl,
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
    String? facebookUrl,
    String? instagramUrl,
    String? twitterUrl,
    String? websiteUrl,
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
      averagePreparationTime:
          averagePreparationTime ?? this.averagePreparationTime,
      deliveryRadius: deliveryRadius ?? this.deliveryRadius,
      features: features ?? this.features,
      tags: tags ?? this.tags,
      featured: featured ?? this.featured,
      featuredUntil: featuredUntil ?? this.featuredUntil,
      isVerified: isVerified ?? this.isVerified,
      verifiedAt: verifiedAt ?? this.verifiedAt,
      whatsappNumber: whatsappNumber ?? this.whatsappNumber,
      facebookUrl: facebookUrl ?? this.facebookUrl,
      instagramUrl: instagramUrl ?? this.instagramUrl,
      twitterUrl: twitterUrl ?? this.twitterUrl,
      websiteUrl: websiteUrl ?? this.websiteUrl,
      paymentMethods: paymentMethods ?? this.paymentMethods,
      bannerImages: bannerImages ?? this.bannerImages,
      isGrabGoExclusive: isGrabGoExclusive ?? this.isGrabGoExclusive,
      isGrabGoExclusiveUntil:
          isGrabGoExclusiveUntil ?? this.isGrabGoExclusiveUntil,
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

  static bool _hasAnyKey(Map<String, dynamic> json, List<String> keys) {
    return keys.any(json.containsKey);
  }

  VendorModel mergeDetailSnapshot(Map<String, dynamic> json) {
    final detail = VendorModel.fromJson(
      json,
    ).copyWith(vendorTypeEnum: vendorTypeEnum, distance: distance);

    final hasLocationData = _hasAnyKey(json, [
      'location',
      'longitude',
      'latitude',
      'address',
      'city',
      'area',
    ]);
    final hasRatingData = _hasAnyKey(json, [
      'weightedRating',
      'displayRating',
      'rating',
    ]);
    final hasReviewData = _hasAnyKey(json, [
      'totalReviews',
      'total_reviews',
      'reviewCount',
      'ratingCount',
    ]);

    return copyWith(
      id: _hasAnyKey(json, ['_id', 'id']) ? detail.id : id,
      storeName: _hasAnyKey(json, ['storeName', 'store_name'])
          ? detail.storeName
          : storeName,
      restaurantName: _hasAnyKey(json, ['restaurantName', 'restaurant_name'])
          ? detail.restaurantName
          : restaurantName,
      name: json.containsKey('name') ? detail.name : name,
      logo:
          json.containsKey('logo') && (detail.logo?.trim().isNotEmpty ?? false)
          ? detail.logo
          : logo,
      description: json.containsKey('description')
          ? detail.description
          : description,
      phone: json.containsKey('phone') ? detail.phone : phone,
      email: json.containsKey('email') ? detail.email : email,
      isOpen: _hasAnyKey(json, ['isOpen', 'is_open']) ? detail.isOpen : isOpen,
      isAcceptingOrders: json.containsKey('isAcceptingOrders')
          ? detail.isAcceptingOrders
          : isAcceptingOrders,
      deliveryFee: _hasAnyKey(json, ['deliveryFee', 'delivery_fee'])
          ? detail.deliveryFee
          : deliveryFee,
      minOrder: _hasAnyKey(json, ['minOrder', 'min_order'])
          ? detail.minOrder
          : minOrder,
      rating: hasRatingData ? detail.rating : rating,
      totalReviews: hasReviewData ? detail.totalReviews : totalReviews,
      categories: json.containsKey('categories')
          ? detail.categories
          : categories,
      foodType: _hasAnyKey(json, ['foodType', 'food_type'])
          ? detail.foodType
          : foodType,
      location: hasLocationData && detail.location != null
          ? detail.location
          : location,
      openingHours: json.containsKey('openingHours')
          ? detail.openingHours
          : openingHours,
      deliveryTime: _hasAnyKey(json, ['deliveryTime', 'average_delivery_time'])
          ? detail.deliveryTime
          : deliveryTime,
      averageDeliveryTime:
          _hasAnyKey(json, ['averageDeliveryTime', 'average_delivery_time'])
          ? detail.averageDeliveryTime
          : averageDeliveryTime,
      averagePreparationTime:
          _hasAnyKey(json, [
            'averagePreparationTime',
            'average_preparation_time',
          ])
          ? detail.averagePreparationTime
          : averagePreparationTime,
      deliveryRadius: _hasAnyKey(json, ['deliveryRadius', 'delivery_radius'])
          ? detail.deliveryRadius
          : deliveryRadius,
      features: json.containsKey('features') ? detail.features : features,
      tags: json.containsKey('tags') ? detail.tags : tags,
      featured: json.containsKey('featured') ? detail.featured : featured,
      featuredUntil: json.containsKey('featuredUntil')
          ? detail.featuredUntil
          : featuredUntil,
      isVerified: json.containsKey('isVerified')
          ? detail.isVerified
          : isVerified,
      verifiedAt: json.containsKey('verifiedAt')
          ? detail.verifiedAt
          : verifiedAt,
      whatsappNumber: json.containsKey('whatsappNumber')
          ? detail.whatsappNumber
          : whatsappNumber,
      facebookUrl: json.containsKey('facebookUrl')
          ? detail.facebookUrl
          : facebookUrl,
      instagramUrl: json.containsKey('instagramUrl')
          ? detail.instagramUrl
          : instagramUrl,
      twitterUrl: json.containsKey('twitterUrl')
          ? detail.twitterUrl
          : twitterUrl,
      websiteUrl: json.containsKey('websiteUrl')
          ? detail.websiteUrl
          : websiteUrl,
      paymentMethods: _hasAnyKey(json, ['paymentMethods', 'payment_methods'])
          ? detail.paymentMethods
          : paymentMethods,
      bannerImages:
          _hasAnyKey(json, ['bannerImages', 'banner_images']) &&
              (detail.bannerImages?.isNotEmpty ?? false)
          ? detail.bannerImages
          : bannerImages,
      isGrabGoExclusive: _hasAnyKey(json, ['isGrabGoExclusive', 'is_exclusive'])
          ? detail.isGrabGoExclusive
          : isGrabGoExclusive,
      isGrabGoExclusiveUntil: json.containsKey('isGrabGoExclusiveUntil')
          ? detail.isGrabGoExclusiveUntil
          : isGrabGoExclusiveUntil,
      vendorType: json.containsKey('vendorType')
          ? detail.vendorType
          : vendorType,
      lastOnlineAt: json.containsKey('lastOnlineAt')
          ? detail.lastOnlineAt
          : lastOnlineAt,
      emergencyService:
          _hasAnyKey(json, ['emergencyService', 'emergency_service'])
          ? detail.emergencyService
          : emergencyService,
      licenseNumber: _hasAnyKey(json, ['licenseNumber', 'license_number'])
          ? detail.licenseNumber
          : licenseNumber,
      pharmacistName: _hasAnyKey(json, ['pharmacistName', 'pharmacist_name'])
          ? detail.pharmacistName
          : pharmacistName,
      insuranceAccepted:
          _hasAnyKey(json, ['insuranceAccepted', 'insurance_accepted'])
          ? detail.insuranceAccepted
          : insuranceAccepted,
      prescriptionRequired:
          _hasAnyKey(json, ['prescriptionRequired', 'prescription_required'])
          ? detail.prescriptionRequired
          : prescriptionRequired,
      is24Hours: _hasAnyKey(json, ['is24Hours', 'is_24_hours'])
          ? detail.is24Hours
          : is24Hours,
      hasParking: _hasAnyKey(json, ['hasParking', 'has_parking'])
          ? detail.hasParking
          : hasParking,
      services: json.containsKey('services') ? detail.services : services,
      productTypes: _hasAnyKey(json, ['productTypes', 'product_types'])
          ? detail.productTypes
          : productTypes,
      businessIdNumber:
          _hasAnyKey(json, ['businessIdNumber', 'business_id_number'])
          ? detail.businessIdNumber
          : businessIdNumber,
      createdAt: json.containsKey('createdAt') ? detail.createdAt : createdAt,
      updatedAt: json.containsKey('updatedAt') ? detail.updatedAt : updatedAt,
      vendorTypeEnum: vendorTypeEnum,
      distance: distance,
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

    final rawIsOpen = json['isOpen'] ?? json['is_open'];
    final bool parsedIsOpen = rawIsOpen is bool
        ? rawIsOpen
        : rawIsOpen is String
        ? rawIsOpen.toLowerCase() == 'true'
        : rawIsOpen is num
        ? rawIsOpen != 0
        : true;
    final totalReviewsValue =
        json['totalReviews'] ??
        json['total_reviews'] ??
        json['reviewCount'] ??
        json['ratingCount'] ??
        0;
    final int parsedTotalReviews = totalReviewsValue is num
        ? totalReviewsValue.toInt()
        : int.tryParse(totalReviewsValue.toString()) ?? 0;

    return VendorModel(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      storeName:
          json['storeName']?.toString() ?? json['store_name']?.toString(),
      restaurantName:
          json['restaurantName']?.toString() ??
          json['restaurant_name']?.toString(),
      name: json['name']?.toString(),
      logo: json['logo']?.toString(),
      description: json['description']?.toString(),
      phone: (json['phone'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      isOpen: parsedIsOpen,
      isAcceptingOrders: json['isAcceptingOrders'] as bool? ?? true,
      deliveryFee: (json['deliveryFee'] ?? json['delivery_fee'] ?? 0.0)
          .toDouble(),
      minOrder: (json['minOrder'] ?? json['min_order'] ?? 0.0).toDouble(),
      rating:
          (json['weightedRating'] ??
                  json['displayRating'] ??
                  json['rating'] ??
                  0.0)
              .toDouble(),
      totalReviews: parsedTotalReviews,
      categories: parseStringList(json['categories']),
      foodType: json['foodType']?.toString() ?? json['food_type']?.toString(),
      location: json['location'] != null
          ? VendorLocation.fromJson(json['location'] as Map<String, dynamic>)
          : null,
      openingHours: _parseOpeningHours(json['openingHours']),
      deliveryTime:
          json['deliveryTime']?.toString() ??
          json['average_delivery_time']?.toString(),
      averageDeliveryTime:
          json['averageDeliveryTime'] as int? ??
          (json['average_delivery_time'] is int
              ? json['average_delivery_time'] as int
              : null),
      averagePreparationTime:
          json['averagePreparationTime'] as int? ??
          json['average_preparation_time'] as int?,
      deliveryRadius: (json['deliveryRadius'] ?? json['delivery_radius'] ?? 5.0)
          .toDouble(),
      features: parseStringList(json['features']),
      tags: parseStringList(json['tags']),
      featured: json['featured'] as bool?,
      featuredUntil: json['featuredUntil'] != null
          ? DateTime.tryParse(json['featuredUntil'].toString())
          : null,
      isVerified: json['isVerified'] as bool?,
      verifiedAt: json['verifiedAt'] != null
          ? DateTime.tryParse(json['verifiedAt'].toString())
          : null,
      whatsappNumber: json['whatsappNumber']?.toString(),
      facebookUrl: json['facebookUrl']?.toString(),
      instagramUrl: json['instagramUrl']?.toString(),
      twitterUrl: json['twitterUrl']?.toString(),
      websiteUrl: json['websiteUrl']?.toString(),
      paymentMethods: parseStringList(
        json['paymentMethods'] ?? json['payment_methods'],
      ),
      bannerImages: parseStringList(
        json['bannerImages'] ?? json['banner_images'],
      ),
      isGrabGoExclusive:
          json['isGrabGoExclusive'] as bool? ?? json['is_exclusive'] as bool?,
      isGrabGoExclusiveUntil: json['isGrabGoExclusiveUntil'] != null
          ? DateTime.tryParse(json['isGrabGoExclusiveUntil'].toString())
          : null,
      vendorType: json['vendorType']?.toString(),
      lastOnlineAt: json['lastOnlineAt'] != null
          ? DateTime.tryParse(json['lastOnlineAt'].toString())
          : null,
      distance: (json['distance'] != null)
          ? (json['distance'] as num).toDouble()
          : null,
      emergencyService:
          json['emergencyService'] as bool? ??
          json['emergency_service'] as bool?,
      licenseNumber:
          json['licenseNumber']?.toString() ??
          json['license_number']?.toString(),
      pharmacistName:
          json['pharmacistName']?.toString() ??
          json['pharmacist_name']?.toString(),
      insuranceAccepted: parseStringList(
        json['insuranceAccepted'] ?? json['insurance_accepted'],
      ),
      prescriptionRequired:
          json['prescriptionRequired'] as bool? ??
          json['prescription_required'] as bool?,
      is24Hours: json['is24Hours'] as bool? ?? json['is_24_hours'] as bool?,
      hasParking: json['hasParking'] as bool? ?? json['has_parking'] as bool?,
      services: parseStringList(json['services']),
      productTypes: parseStringList(
        json['productTypes'] ?? json['product_types'],
      ),
      businessIdNumber:
          json['businessIdNumber']?.toString() ??
          json['business_id_number']?.toString(),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() => _$VendorModelToJson(this);

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

  bool get isAvailableForOrders => isOpen && isAcceptingOrders;

  bool get isTemporarilyUnavailableButOpen => isOpen && !isAcceptingOrders;

  String get shortAvailabilityLabel => isAvailableForOrders ? 'Open' : 'Closed';

  String get overlayAvailabilityLabel =>
      isTemporarilyUnavailableButOpen ? 'Not accepting' : "We're closed";
}
