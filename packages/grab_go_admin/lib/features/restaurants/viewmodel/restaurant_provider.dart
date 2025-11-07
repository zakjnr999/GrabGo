import 'package:flutter/foundation.dart';
import 'package:grab_go_admin/core/api/api_client.dart';
import 'package:grab_go_admin/features/restaurants/model/restaurant_response.dart';

class RestaurantProvider extends ChangeNotifier {
  List<RestaurantData> _restaurants = [];
  bool _isLoading = false;
  String? _error;

  List<RestaurantData> get restaurants => _restaurants;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetchRestaurants() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await restaurantService.getRestaurants();

      if (response.isSuccessful && response.body != null) {
        _restaurants = response.body!;
        _error = null;
      } else {
        _error = 'Failed to load restaurants: ${response.statusCode}';
        _restaurants = [];
      }
    } catch (e) {
      _error = 'Error loading restaurants: ${e.toString()}';
      _restaurants = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void refreshRestaurants() {
    fetchRestaurants();
  }

  Future<bool> approveRestaurant(String restaurantId) async {
    try {
      final requestBody = {'status': 'approved'};
      final response = await restaurantService.updateRestaurantStatus(restaurantId, requestBody);

      if (response.isSuccessful && response.body != null) {
        final updatedRestaurant = response.body!;
        final index = _restaurants.indexWhere((r) => r.id == restaurantId);
        if (index != -1) {
          _restaurants[index] = updatedRestaurant;
          notifyListeners();
        }
        final requestedStatus = requestBody['status'].toString().toLowerCase();
        final receivedStatus = updatedRestaurant.status.toLowerCase();

        if (requestedStatus != receivedStatus) {
          _error =
              'Status was not updated. Requested: ${requestBody['status']}, but server returned: ${updatedRestaurant.status}. The backend may require additional authentication or permissions.';
          notifyListeners();
          return false;
        }

        _error = null;
        return true;
      } else {
        final errorMsg =
            response.error?.toString() ?? response.body?.toString() ?? 'Unknown error (Status: ${response.statusCode})';
        _error = 'Failed to approve restaurant: $errorMsg';
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = 'Error approving restaurant: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateRestaurantStatus(String restaurantId, String status) async {
    try {
      final capitalizedStatus = status[0].toUpperCase() + status.substring(1);
      final requestBody = {'status': capitalizedStatus};
      final response = await restaurantService.updateRestaurantStatus(restaurantId, requestBody);

      if (response.isSuccessful && response.body != null) {
        final updatedRestaurant = response.body!;
        final index = _restaurants.indexWhere((r) => r.id == restaurantId);
        if (index != -1) {
          _restaurants[index] = updatedRestaurant;
          notifyListeners();
        }
        final requestedStatus = requestBody['status'].toString().toLowerCase();
        final receivedStatus = updatedRestaurant.status.toLowerCase();

        if (requestedStatus != receivedStatus) {
          _error =
              'Status was not updated. Requested: ${requestBody['status']}, but server returned: ${updatedRestaurant.status}. The backend may require additional authentication or permissions.';
          notifyListeners();
          return false;
        }

        _error = null;
        return true;
      } else {
        final errorMsg =
            response.error?.toString() ?? response.body?.toString() ?? 'Unknown error (Status: ${response.statusCode})';
        _error = 'Failed to update restaurant status: $errorMsg';
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = 'Error updating restaurant status: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }
}
