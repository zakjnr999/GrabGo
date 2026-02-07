enum AddressLabel { home, work, other }

enum BuildingType { apartment, house, office, villa, hostel, other }

class AddressModel {
  final String? id;
  final String? userId;
  final double latitude;
  final double longitude;
  final String formattedAddress;
  final String? city;
  final String? area;
  final AddressLabel label;
  final String? customLabel;
  final BuildingType buildingType;
  final String? unitNumber;
  final String? floor;
  final String? instructions;
  final bool isComplete;
  final bool isTemporary;
  final bool isDefault;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  AddressModel({
    this.id,
    this.userId,
    required this.latitude,
    required this.longitude,
    required this.formattedAddress,
    this.city,
    this.area,
    this.label = AddressLabel.home,
    this.customLabel,
    this.buildingType = BuildingType.apartment,
    this.unitNumber,
    this.floor,
    this.instructions,
    this.isComplete = false,
    this.isTemporary = false,
    this.isDefault = false,
    this.createdAt,
    this.updatedAt,
  });

  AddressModel copyWith({
    String? id,
    String? userId,
    double? latitude,
    double? longitude,
    String? formattedAddress,
    String? city,
    String? area,
    AddressLabel? label,
    String? customLabel,
    BuildingType? buildingType,
    String? unitNumber,
    String? floor,
    String? instructions,
    bool? isComplete,
    bool? isTemporary,
    bool? isDefault,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AddressModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      formattedAddress: formattedAddress ?? this.formattedAddress,
      city: city ?? this.city,
      area: area ?? this.area,
      label: label ?? this.label,
      customLabel: customLabel ?? this.customLabel,
      buildingType: buildingType ?? this.buildingType,
      unitNumber: unitNumber ?? this.unitNumber,
      floor: floor ?? this.floor,
      instructions: instructions ?? this.instructions,
      isComplete: isComplete ?? this.isComplete,
      isTemporary: isTemporary ?? this.isTemporary,
      isDefault: isDefault ?? this.isDefault,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'latitude': latitude,
      'longitude': longitude,
      'formatted_address': formattedAddress,
      'city': city,
      'area': area,
      'label': label.name,
      'custom_label': customLabel,
      'building_type': buildingType.name,
      'unit_number': unitNumber,
      'floor': floor,
      'instructions': instructions,
      'is_complete': isComplete,
      'is_temporary': isTemporary,
      'is_default': isDefault,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  factory AddressModel.fromJson(Map<String, dynamic> json) {
    return AddressModel(
      id: json['id'],
      userId: json['userId'] ?? json['user_id'],
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      formattedAddress: json['formattedAddress'] ?? json['formatted_address'] ?? '',
      city: json['city'],
      area: json['area'],
      label: AddressLabel.values.firstWhere((e) => e.name == json['label'], orElse: () => AddressLabel.home),
      customLabel: json['customLabel'] ?? json['custom_label'],
      buildingType: BuildingType.values.firstWhere(
        (e) => e.name == (json['buildingType'] ?? json['building_type']),
        orElse: () => BuildingType.apartment,
      ),
      unitNumber: json['unitNumber'] ?? json['unit_number'],
      floor: json['floor'],
      instructions: json['instructions'],
      isComplete: json['isComplete'] ?? json['is_complete'] ?? false,
      isTemporary: json['isTemporary'] ?? json['is_temporary'] ?? false,
      isDefault: json['isDefault'] ?? json['is_default'] ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
    );
  }

  @override
  String toString() {
    return 'AddressModel(label: $label, customLabel: $customLabel, address: $formattedAddress)';
  }
}
