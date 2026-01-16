import 'package:flutter/foundation.dart';
import 'package:grab_go_customer/core/api/api_client.dart' as chopper_client_service;
import 'package:grab_go_customer/features/pharmacy/model/pharmacy_category.dart';
import 'package:grab_go_customer/features/pharmacy/model/pharmacy_item.dart';
import 'package:grab_go_customer/features/pharmacy/service/pharmacy_service.dart';

class PharmacyRepository {
  final PharmacyService _pharmacyService;

  PharmacyRepository() : _pharmacyService = PharmacyService.create(chopper_client_service.chopperClient);

  /// Fetch all pharmacy categories
  Future<List<PharmacyCategory>> fetchCategories() async {
    try {
      final response = await _pharmacyService.getCategories();

      if (response.isSuccessful && response.body != null) {
        final data = response.body as Map<String, dynamic>;
        if (data['success'] == true && data['data'] != null) {
          final categories = (data['data'] as List).map((json) => PharmacyCategory.fromJson(json)).toList();
          return categories;
        }
      }

      if (kDebugMode) {
        print('❌ Failed to fetch pharmacy categories: ${response.error}');
      }
      return [];
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error fetching pharmacy categories: $e');
      }
      return [];
    }
  }

  /// Fetch pharmacy items with optional filters
  Future<List<PharmacyItem>> fetchItems({
    String? category,
    String? store,
    String? minPrice,
    String? maxPrice,
    String? tags,
  }) async {
    try {
      final response = await _pharmacyService.getItems(
        category: category,
        store: store,
        minPrice: minPrice,
        maxPrice: maxPrice,
        tags: tags,
      );

      if (response.isSuccessful && response.body != null) {
        final data = response.body as Map<String, dynamic>;
        if (data['success'] == true && data['data'] != null) {
          final items = (data['data'] as List).map((json) => PharmacyItem.fromJson(json)).toList();
          return items;
        }
      }

      if (kDebugMode) {
        print('❌ Failed to fetch pharmacy items: ${response.error}');
      }
      return [];
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error fetching pharmacy items: $e');
      }
      return [];
    }
  }
}
