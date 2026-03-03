import 'package:grab_go_shared/grub_go_shared.dart';

class ServiceModel {
  final String id;
  final String name;
  final String emoji;
  final String colorHex; // For future service-specific theming

  const ServiceModel({
    required this.id,
    required this.name,
    required this.emoji,
    required this.colorHex,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ServiceModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// Predefined services available in the app
class AppServices {
  static const ServiceModel food = ServiceModel(
    id: 'food',
    name: 'Foods',
    emoji: '🍔',
    colorHex: AppColors.serviceFoodHex,
  );

  static const ServiceModel groceries = ServiceModel(
    id: 'groceries',
    name: 'Groceries',
    emoji: '🛒',
    colorHex: AppColors.serviceGroceryHex,
  );

  static const ServiceModel pharmacy = ServiceModel(
    id: 'pharmacy',
    name: 'Pharmacy',
    emoji: '💊',
    colorHex: AppColors.servicePharmacyHex,
  );

  static const ServiceModel convenience = ServiceModel(
    id: 'convenience',
    name: 'GrabMart',
    emoji: '🏪',
    colorHex: AppColors.serviceGrabMartHex,
  );

  static const ServiceModel parcel = ServiceModel(
    id: 'parcel',
    name: 'Parcel',
    emoji: '📦',
    colorHex: '#546E7A',
  );

  /// List of all available services (main services only)
  static const List<ServiceModel> all = [
    food,
    groceries,
    pharmacy,
    convenience,
    parcel,
  ];

  /// Get service by ID
  static ServiceModel? getById(String id) {
    try {
      return all.firstWhere((service) => service.id == id);
    } catch (e) {
      return null;
    }
  }
}
