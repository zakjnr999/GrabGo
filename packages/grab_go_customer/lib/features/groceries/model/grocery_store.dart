class GroceryStore {
  final String id;
  final String storeName;
  final String logo;
  final String description;
  final String address;
  final String phone;
  final String email;
  final bool isOpen;
  final double deliveryFee;
  final double minOrder;
  final double rating;
  final List<String> categories;
  final double latitude;
  final double longitude;

  GroceryStore({
    required this.id,
    required this.storeName,
    required this.logo,
    required this.description,
    required this.address,
    required this.phone,
    required this.email,
    required this.isOpen,
    required this.deliveryFee,
    required this.minOrder,
    required this.rating,
    required this.categories,
    required this.latitude,
    required this.longitude,
  });

  factory GroceryStore.fromJson(Map<String, dynamic> json) {
    return GroceryStore(
      id: json['_id'] ?? '',
      storeName: json['store_name'] ?? '',
      logo: json['logo'] ?? '',
      description: json['description'] ?? '',
      address: json['address'] ?? '',
      phone: json['phone'] ?? '',
      email: json['email'] ?? '',
      isOpen: json['isOpen'] ?? true,
      deliveryFee: (json['deliveryFee'] ?? 0).toDouble(),
      minOrder: (json['minOrder'] ?? 0).toDouble(),
      rating: (json['rating'] ?? 0).toDouble(),
      categories: (json['categories'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      latitude: (json['latitude'] ?? 0).toDouble(),
      longitude: (json['longitude'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'store_name': storeName,
      'logo': logo,
      'description': description,
      'address': address,
      'phone': phone,
      'email': email,
      'isOpen': isOpen,
      'deliveryFee': deliveryFee,
      'minOrder': minOrder,
      'rating': rating,
      'categories': categories,
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is GroceryStore && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
