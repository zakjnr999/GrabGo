import 'package:flutter/foundation.dart';
import 'package:grab_go_customer/core/api/api_client.dart' as chopper_client_service;
import 'package:grab_go_customer/features/grabmart/model/grabmart_category.dart';
import 'package:grab_go_customer/features/grabmart/model/grabmart_item.dart';
import 'package:grab_go_customer/features/grabmart/service/grabmart_service.dart';

class GrabMartRepository {
  final GrabMartService _grabMartService;

  GrabMartRepository() : _grabMartService = GrabMartService.create(chopper_client_service.chopperClient);

  /// Fetch all GrabMart categories
  Future<List<GrabMartCategory>> fetchCategories() async {
    try {
      final response = await _grabMartService.getCategories();

      if (response.isSuccessful && response.body != null) {
        final data = response.body as Map<String, dynamic>;
        if (data['success'] == true && data['data'] != null) {
          final categories = (data['data'] as List).map((json) => GrabMartCategory.fromJson(json)).toList();
          return categories;
        }
      }

      if (kDebugMode) {
        print('❌ Failed to fetch GrabMart categories: ${response.error}');
      }
      return [];
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error fetching GrabMart categories: $e');
      }
      return [];
    }
  }

  /// Fetch GrabMart items with optional filters
  Future<List<GrabMartItem>> fetchItems({
    String? category,
    String? store,
    String? minPrice,
    String? maxPrice,
    String? tags,
  }) async {
    try {
      final response = await _grabMartService.getItems(
        category: category,
        store: store,
        minPrice: minPrice,
        maxPrice: maxPrice,
        tags: tags,
      );

      if (response.isSuccessful && response.body != null) {
        final data = response.body as Map<String, dynamic>;
        if (data['success'] == true && data['data'] != null) {
          final items = (data['data'] as List).map((json) => GrabMartItem.fromJson(json)).toList();
          return items;
        }
      }

      if (kDebugMode) {
        print('❌ Failed to fetch GrabMart items: ${response.error}');
      }
      return [];
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error fetching GrabMart items: $e');
      }
      return [];
    }
  }
}
