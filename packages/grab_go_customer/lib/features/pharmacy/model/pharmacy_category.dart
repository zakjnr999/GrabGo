class PharmacyCategory {
  final String id;
  final String name;
  final String emoji;
  final String description;
  final String image;
  final int sortOrder;
  final bool isActive;

  PharmacyCategory({
    required this.id,
    required this.name,
    required this.emoji,
    required this.description,
    required this.image,
    required this.sortOrder,
    required this.isActive,
  });

  factory PharmacyCategory.fromJson(Map<String, dynamic> json) {
    return PharmacyCategory(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      emoji: json['emoji'] ?? '',
      description: json['description'] ?? '',
      image: json['image'] ?? '',
      sortOrder: json['sortOrder'] ?? 0,
      isActive: json['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'id': id,
      'name': name,
      'emoji': emoji,
      'description': description,
      'image': image,
      'sortOrder': sortOrder,
      'isActive': isActive,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PharmacyCategory && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
