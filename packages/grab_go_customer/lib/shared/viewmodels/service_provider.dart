import 'package:flutter/material.dart';
import 'package:grab_go_customer/features/home/model/service_model.dart';

/// Provider for managing service selection (Food, Groceries, Pharmacy, Stores)
class ServiceProvider extends ChangeNotifier {
  ServiceModel _currentService = AppServices.food;

  ServiceModel get currentService => _currentService;

  /// Check if current service is Food
  bool get isFoodService => _currentService.id == 'food';

  /// Check if current service is Groceries
  bool get isGroceryService => _currentService.id == 'groceries';

  /// Check if current service is Pharmacy
  bool get isPharmacyService => _currentService.id == 'pharmacy';

  /// Check if current service is Stores
  bool get isStoresService => _currentService.id == 'convenience';

  /// Select a service
  void selectService(ServiceModel service) {
    if (_currentService.id != service.id) {
      _currentService = service;
      notifyListeners();
    }
  }

  /// Reset to default service (Food)
  void resetToDefault() {
    if (_currentService.id != AppServices.food.id) {
      _currentService = AppServices.food;
      notifyListeners();
    }
  }
}
