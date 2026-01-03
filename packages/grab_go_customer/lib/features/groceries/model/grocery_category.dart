class GroceryCategory {
  final String id;
  final String name;
  final String emoji;
  final String description;
  final String image;
  final int sortOrder;
  final bool isActive;

  GroceryCategory({
    required this.id,
    required this.name,
    required this.emoji,
    required this.description,
    required this.image,
    required this.sortOrder,
    required this.isActive,
  });

  factory GroceryCategory.fromJson(Map<String, dynamic> json) {
    return GroceryCategory(
      id: json['_id'] ?? '',
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
    return other is GroceryCategory && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
