class ServiceModel {
  final String id;
  final String name;
  final String emoji;
  final String colorHex; // For future service-specific theming

  const ServiceModel({required this.id, required this.name, required this.emoji, required this.colorHex});

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
    colorHex: '#FE6132', // Orange
  );

  static const ServiceModel groceries = ServiceModel(
    id: 'groceries',
    name: 'Groceries',
    emoji: '🛒',
    colorHex: '#4CAF50', // Green
  );

  static const ServiceModel pharmacy = ServiceModel(
    id: 'pharmacy',
    name: 'Pharmacy',
    emoji: '💊',
    colorHex: '#009688', // Teal
  );

  static const ServiceModel convenience = ServiceModel(
    id: 'convenience',
    name: 'GrabMart',
    emoji: '🏪',
    colorHex: '#9C27B0', // Purple
  );

  /// List of all available services (main services only)
  static const List<ServiceModel> all = [food, groceries, pharmacy, convenience];

  /// Get service by ID
  static ServiceModel? getById(String id) {
    try {
      return all.firstWhere((service) => service.id == id);
    } catch (e) {
      return null;
    }
  }
}
