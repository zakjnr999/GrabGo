import 'package:json_annotation/json_annotation.dart';
import 'vendor_type.dart';

part 'vendor_model.g.dart';

@JsonSerializable()
class VendorModel {
  @JsonKey(name: '_id')
  final String id;

  @JsonKey(name: 'store_name')
  final String? _storeName;

  @JsonKey(name: 'restaurant_name')
  final String? _restaurantName;

  @JsonKey(name: 'name')
  final String? _name;

  @JsonKey(name: 'storeName')
  final String? _storeNameCamel;

  // Computed property that returns whichever name is available
  String get storeName => _storeName ?? _storeNameCamel ?? _restaurantName ?? _name ?? '';

  final String? logo;
  final String? description;
  final String address;
  final String phone;
  final String email;

  @JsonKey(name: 'isOpen')
  final bool? _isOpen;

  @JsonKey(name: 'is_open')
  final bool? _isOpenSnake;

  bool get isOpen => _isOpen ?? _isOpenSnake ?? true;

  @JsonKey(name: 'deliveryFee')
  final double? _deliveryFee;

  @JsonKey(name: 'delivery_fee')
  final double? _deliveryFeeSnake;

  double get deliveryFee => _deliveryFee ?? _deliveryFeeSnake ?? 0.0;

  @JsonKey(name: 'minOrder')
  final double? _minOrder;

  @JsonKey(name: 'min_order')
  final double? _minOrderSnake;

  double get minOrder => _minOrder ?? _minOrderSnake ?? 0.0;

  @JsonKey(defaultValue: 0.0)
  final double rating;

  @JsonKey(name: 'totalReviews')
  final int? _totalReviews;

  @JsonKey(name: 'total_reviews')
  final int? _totalReviewsSnake;

  int get totalReviews => _totalReviews ?? _totalReviewsSnake ?? 0;

  final List<String>? categories;

  @JsonKey(name: 'food_type')
  final String? foodType;

  // Computed categories that includes food_type if categories is empty
  List<String> get vendorCategories {
    if (categories != null && categories!.isNotEmpty) return categories!;
    if (foodType != null) return [foodType!];
    return [];
  }

  @JsonKey(defaultValue: 0.0)
  final double latitude;

  @JsonKey(defaultValue: 0.0)
  final double longitude;

  @JsonKey(name: 'operatingHours')
  final String? _operatingHours;

  @JsonKey(name: 'opening_hours')
  final String? _openingHoursSnake;

  String? get operatingHours => _operatingHours ?? _openingHoursSnake;

  @JsonKey(name: 'average_delivery_time')
  final String? deliveryTime;

  // Pharmacy-specific fields
  final String? licenseNumber;
  final String? pharmacistName;
  final String? pharmacistLicense;
  final bool? prescriptionRequired;
  final bool? emergencyService;
  final List<String>? insuranceAccepted;

  // GrabMart-specific fields
  final bool? is24Hours;
  final bool? hasParking;
  final bool? acceptsCash;
  final bool? acceptsCard;
  final bool? acceptsMobileMoney;
  final List<String>? services;
  final List<String>? productTypes;

  // Additional fields
  final bool? isExclusive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // Distance (calculated on client side)
  @JsonKey(includeFromJson: false, includeToJson: false)
  final double? distance;

  // Vendor type (determined by which endpoint it came from)
  @JsonKey(includeFromJson: false, includeToJson: false)
  final VendorType vendorType;

  VendorModel({
    required this.id,
    String? storeName,
    String? restaurantName,
    String? name,
    String? storeNameCamel,
    this.logo,
    this.description,
    required this.address,
    required this.phone,
    required this.email,
    bool? isOpen,
    bool? isOpenSnake,
    double? deliveryFee,
    double? deliveryFeeSnake,
    double? minOrder,
    double? minOrderSnake,
    required this.rating,
    int? totalReviews,
    int? totalReviewsSnake,
    this.categories,
    this.foodType,
    required this.latitude,
    required this.longitude,
    String? operatingHours,
    String? openingHoursSnake,
    this.deliveryTime,
    this.licenseNumber,
    this.pharmacistName,
    this.pharmacistLicense,
    this.prescriptionRequired,
    this.emergencyService,
    this.insuranceAccepted,
    this.is24Hours,
    this.hasParking,
    this.acceptsCash,
    this.acceptsCard,
    this.acceptsMobileMoney,
    this.services,
    this.productTypes,
    this.isExclusive,
    this.createdAt,
    this.updatedAt,
    this.distance,
    this.vendorType = VendorType.food,
  }) : _storeName = storeName,
       _restaurantName = restaurantName,
       _name = name,
       _storeNameCamel = storeNameCamel,
       _isOpen = isOpen,
       _isOpenSnake = isOpenSnake,
       _deliveryFee = deliveryFee,
       _deliveryFeeSnake = deliveryFeeSnake,
       _minOrder = minOrder,
       _minOrderSnake = minOrderSnake,
       _totalReviews = totalReviews,
       _totalReviewsSnake = totalReviewsSnake,
       _operatingHours = operatingHours,
       _openingHoursSnake = openingHoursSnake;

  factory VendorModel.fromJson(Map<String, dynamic> json) {
    // Manually handle some fields for robustness if generator hasn't run
    return VendorModel(
      id: json['_id'] ?? json['id'] ?? '',
      storeName: json['store_name']?.toString(),
      restaurantName: json['restaurant_name']?.toString(),
      name: json['name']?.toString(),
      storeNameCamel: json['storeName']?.toString(),
      logo: json['logo']?.toString(),
      description: json['description']?.toString(),
      address: (json['address'] ?? '').toString(),
      phone: (json['phone'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      isOpen: json['isOpen'] as bool?,
      isOpenSnake: json['is_open'] as bool?,
      deliveryFee: (json['deliveryFee'] ?? json['delivery_fee'])?.toDouble(),
      minOrder: (json['minOrder'] ?? json['min_order'])?.toDouble(),
      rating: (json['rating'] ?? 0.0).toDouble(),
      totalReviews: (json['totalReviews'] ?? json['total_reviews']) as int?,
      categories: (json['categories'] as List?)?.map((e) => e.toString()).toList(),
      foodType: json['food_type']?.toString(),
      latitude: (json['latitude'] ?? 0.0).toDouble(),
      longitude: (json['longitude'] ?? 0.0).toDouble(),
      operatingHours: json['operatingHours']?.toString(),
      openingHoursSnake: json['opening_hours']?.toString(),
      deliveryTime: json['average_delivery_time']?.toString(),
      emergencyService: json['emergencyService'] as bool?,
      is24Hours: json['is24Hours'] as bool?,
      isExclusive: (json['is_exclusive'] ?? json['isExclusive'] ?? json['isGrabGoExclusive']) as bool?,
    );
  }

  Map<String, dynamic> toJson() => _$VendorModelToJson(this);

  /// Create a copy with updated fields
  VendorModel copyWith({
    String? id,
    String? storeName,
    String? restaurantName,
    String? name,
    String? storeNameCamel,
    String? logo,
    String? description,
    String? address,
    String? phone,
    String? email,
    bool? isOpen,
    double? deliveryFee,
    double? minOrder,
    double? rating,
    int? totalReviews,
    List<String>? categories,
    String? foodType,
    double? latitude,
    double? longitude,
    String? operatingHours,
    String? deliveryTime,
    String? licenseNumber,
    String? pharmacistName,
    String? pharmacistLicense,
    bool? prescriptionRequired,
    bool? emergencyService,
    List<String>? insuranceAccepted,
    bool? is24Hours,
    bool? hasParking,
    bool? acceptsCash,
    bool? acceptsCard,
    bool? acceptsMobileMoney,
    List<String>? services,
    List<String>? productTypes,
    DateTime? createdAt,
    DateTime? updatedAt,
    double? distance,
    bool? isExclusive,
    VendorType? vendorType,
  }) {
    return VendorModel(
      id: id ?? this.id,
      storeName: storeName ?? _storeName,
      restaurantName: restaurantName ?? _restaurantName,
      name: name ?? _name,
      storeNameCamel: storeNameCamel ?? _storeNameCamel,
      logo: logo ?? this.logo,
      description: description ?? this.description,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      isOpen: isOpen ?? _isOpen,
      isOpenSnake: _isOpenSnake,
      deliveryFee: deliveryFee ?? _deliveryFee,
      deliveryFeeSnake: _deliveryFeeSnake,
      minOrder: minOrder ?? _minOrder,
      minOrderSnake: _minOrderSnake,
      rating: rating ?? this.rating,
      totalReviews: totalReviews ?? _totalReviews,
      totalReviewsSnake: _totalReviewsSnake,
      categories: categories ?? this.categories,
      foodType: foodType ?? this.foodType,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      operatingHours: operatingHours ?? _operatingHours,
      openingHoursSnake: _openingHoursSnake,
      deliveryTime: deliveryTime ?? this.deliveryTime,
      licenseNumber: licenseNumber ?? this.licenseNumber,
      pharmacistName: pharmacistName ?? this.pharmacistName,
      pharmacistLicense: pharmacistLicense ?? this.pharmacistLicense,
      prescriptionRequired: prescriptionRequired ?? this.prescriptionRequired,
      emergencyService: emergencyService ?? this.emergencyService,
      insuranceAccepted: insuranceAccepted ?? this.insuranceAccepted,
      is24Hours: is24Hours ?? this.is24Hours,
      hasParking: hasParking ?? this.hasParking,
      acceptsCash: acceptsCash ?? this.acceptsCash,
      acceptsCard: acceptsCard ?? this.acceptsCard,
      acceptsMobileMoney: acceptsMobileMoney ?? this.acceptsMobileMoney,
      services: services ?? this.services,
      productTypes: productTypes ?? this.productTypes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      distance: distance ?? this.distance,
      isExclusive: isExclusive ?? this.isExclusive,
      vendorType: vendorType ?? this.vendorType,
    );
  }

  /// Check if vendor is currently open based on operating hours
  bool get isCurrentlyOpen {
    if (!isOpen) return false;
    if (operatingHours == '24/7' || is24Hours == true) return true;
    // TODO: Implement actual time-based logic
    return isOpen;
  }

  /// Get formatted distance string
  String get distanceText {
    if (distance == null || (latitude == 0.0 && longitude == 0.0)) return '';
    if (distance! < 1) {
      return '${(distance! * 1000).toStringAsFixed(0)}m away';
    }
    return '${distance!.toStringAsFixed(1)}km away';
  }

  /// Get formatted delivery fee
  String get deliveryFeeText {
    if (deliveryFee == 0) return 'Free delivery';
    return 'GHS ${deliveryFee.toStringAsFixed(0)}';
  }

  /// Get formatted minimum order
  String get minOrderText {
    return 'Min. GHS ${minOrder.toStringAsFixed(0)}';
  }
}
