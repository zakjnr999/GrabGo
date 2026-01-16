import 'package:flutter/foundation.dart';
import 'package:grab_go_customer/core/api/api_client.dart';
import 'package:grab_go_customer/features/pharmacy/model/pharmacy_category.dart';
import 'package:grab_go_shared/shared/services/cache_service.dart';

class PharmacyProvider extends ChangeNotifier {
  final ApiClient _apiClient = ApiClient();

  // Categories
  List<PharmacyCategory> _categories = [];
  bool _isLoadingCategories = false;

  // Getters
  List<PharmacyCategory> get categories => _categories;
  bool get isLoadingCategories => _isLoadingCategories;

  /// Fetch all pharmacy categories
  Future<void> fetchCategories({bool forceRefresh = false}) async {
    if (!forceRefresh && _categories.isEmpty) {
      final cached = CacheService.getPharmacyCategories();
      if (cached.isNotEmpty) {
        _categories = cached.map((json) => PharmacyCategory.fromJson(json)).toList();
        notifyListeners();
      }
    }

    _isLoadingCategories = true;
    notifyListeners();

    try {
      final response = await _apiClient.get('/pharmacies/categories');
      
      if (response['success'] == true && response['data'] != null) {
        final List<dynamic> data = response['data'];
        _categories = data.map((json) => PharmacyCategory.fromJson(json)).toList();
        await CacheService.savePharmacyCategories(_categories.map((c) => c.toJson()).toList());
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error fetching pharmacy categories: $e');
      }
    } finally {
      _isLoadingCategories = false;
      notifyListeners();
    }
  }

  /// Clear all pharmacy data
  void clearData() {
    _categories = [];
    notifyListeners();
  }
}
