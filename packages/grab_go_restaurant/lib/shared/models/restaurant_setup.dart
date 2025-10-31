class RestaurantSetup {
  final String? foodType;
  final String? description;
  final double? latitude;
  final double? longitude;
  final int? averageDeliveryTime; // in minutes
  final double? deliveryFee;
  final double? minOrder;
  final Map<String, String>? openingHours; // day -> hours
  final List<String>? paymentMethods;
  final RestaurantSocials? socials;

  RestaurantSetup({
    this.foodType,
    this.description,
    this.latitude,
    this.longitude,
    this.averageDeliveryTime,
    this.deliveryFee,
    this.minOrder,
    this.openingHours,
    this.paymentMethods,
    this.socials,
  });

  RestaurantSetup copyWith({
    String? foodType,
    String? description,
    double? latitude,
    double? longitude,
    int? averageDeliveryTime,
    double? deliveryFee,
    double? minOrder,
    Map<String, String>? openingHours,
    List<String>? paymentMethods,
    RestaurantSocials? socials,
  }) {
    return RestaurantSetup(
      foodType: foodType ?? this.foodType,
      description: description ?? this.description,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      averageDeliveryTime: averageDeliveryTime ?? this.averageDeliveryTime,
      deliveryFee: deliveryFee ?? this.deliveryFee,
      minOrder: minOrder ?? this.minOrder,
      openingHours: openingHours ?? this.openingHours,
      paymentMethods: paymentMethods ?? this.paymentMethods,
      socials: socials ?? this.socials,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'foodType': foodType,
      'description': description,
      'latitude': latitude,
      'longitude': longitude,
      'averageDeliveryTime': averageDeliveryTime,
      'deliveryFee': deliveryFee,
      'minOrder': minOrder,
      'openingHours': openingHours,
      'paymentMethods': paymentMethods,
      'socials': socials?.toJson(),
    };
  }

  factory RestaurantSetup.fromJson(Map<String, dynamic> json) {
    return RestaurantSetup(
      foodType: json['foodType'],
      description: json['description'],
      latitude: json['latitude']?.toDouble(),
      longitude: json['longitude']?.toDouble(),
      averageDeliveryTime: json['averageDeliveryTime'],
      deliveryFee: json['deliveryFee']?.toDouble(),
      minOrder: json['minOrder']?.toDouble(),
      openingHours: json['openingHours'] != null 
          ? Map<String, String>.from(json['openingHours'])
          : null,
      paymentMethods: json['paymentMethods'] != null
          ? List<String>.from(json['paymentMethods'])
          : null,
      socials: json['socials'] != null 
          ? RestaurantSocials.fromJson(json['socials'])
          : null,
    );
  }

  bool get isComplete {
    return foodType != null &&
        description != null &&
        averageDeliveryTime != null &&
        deliveryFee != null &&
        minOrder != null &&
        openingHours != null &&
        paymentMethods != null &&
        paymentMethods!.isNotEmpty;
  }
}

class RestaurantSocials {
  final String? instagram;
  final String? facebook;

  RestaurantSocials({
    this.instagram,
    this.facebook,
  });

  RestaurantSocials copyWith({
    String? instagram,
    String? facebook,
  }) {
    return RestaurantSocials(
      instagram: instagram ?? this.instagram,
      facebook: facebook ?? this.facebook,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'instagram': instagram,
      'facebook': facebook,
    };
  }

  factory RestaurantSocials.fromJson(Map<String, dynamic> json) {
    return RestaurantSocials(
      instagram: json['instagram'],
      facebook: json['facebook'],
    );
  }
}
