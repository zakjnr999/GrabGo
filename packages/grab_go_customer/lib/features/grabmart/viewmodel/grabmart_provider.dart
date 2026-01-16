import 'package:flutter/foundation.dart';
import 'package:grab_go_customer/core/api/api_client.dart';
import 'package:grab_go_customer/features/grabmart/model/grabmart_category.dart';
import 'package:grab_go_shared/shared/services/cache_service.dart';

class GrabMartProvider extends ChangeNotifier {
  final ApiClient _apiClient = ApiClient();

  // Categories
  List<GrabMartCategory> _categories = [];
  bool _isLoadingCategories = false;

  // Getters
  List<GrabMartCategory> get categories => _categories;
  bool get isLoadingCategories => _isLoadingCategories;

  /// Fetch all GrabMart categories
  Future<void> fetchCategories({bool forceRefresh = false}) async {
    if (!forceRefresh && _categories.isEmpty) {
      final cached = CacheService.getGrabMartCategories();
      if (cached.isNotEmpty) {
        _categories = cached.map((json) => GrabMartCategory.fromJson(json)).toList();
        notifyListeners();
      }
    }

    _isLoadingCategories = true;
    notifyListeners();

    try {
      final response = await _apiClient.get('/grabmart/categories');
      
      if (response['success'] == true && response['data'] != null) {
        final List<dynamic> data = response['data'];
        _categories = data.map((json) => GrabMartCategory.fromJson(json)).toList();
        await CacheService.saveGrabMartCategories(_categories.map((c) => c.toJson()).toList());
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error fetching GrabMart categories: $e');
      }
    } finally {
      _isLoadingCategories = false;
      notifyListeners();
    }
  }

  /// Clear all GrabMart data
  void clearData() {
    _categories = [];
    notifyListeners();
  }
}
