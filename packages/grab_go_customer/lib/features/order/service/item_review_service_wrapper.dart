import 'dart:convert';

import 'package:chopper/chopper.dart';
import 'package:grab_go_customer/core/api/api_client.dart';
import 'package:grab_go_customer/features/order/model/item_review_models.dart';
import 'package:grab_go_customer/features/order/service/item_review_service_chopper.dart';

class ItemReviewServiceWrapper {
  final ItemReviewServiceChopper _itemReviewService;

  ItemReviewServiceWrapper()
    : _itemReviewService = chopperClient.getService<ItemReviewServiceChopper>();

  Future<ItemReviewFeed> getItemReviews({
    required String itemType,
    required String itemId,
    String sort = 'popular',
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final response = await _itemReviewService.getItemReviews(
        itemType,
        itemId,
        sort: sort,
        page: page,
        limit: limit,
      );
      final body = _resolveResponseMap(response);

      if (body == null) {
        throw Exception('Unable to load item reviews right now.');
      }

      if (body['success'] != true) {
        throw Exception(body['message']?.toString() ?? 'Failed to load item reviews');
      }

      final data = body['data'] as Map<String, dynamic>?;
      if (data == null) {
        throw Exception('Item review response was empty');
      }

      return ItemReviewFeed.fromJson(data);
    } catch (e) {
      throw Exception('Failed to load item reviews: $e');
    }
  }

  Map<String, dynamic>? _resolveResponseMap(
    Response<Map<String, dynamic>> response,
  ) {
    if (response.body != null) return response.body;

    final dynamic errorPayload = response.error;
    if (errorPayload is Map<String, dynamic>) return errorPayload;
    if (errorPayload is Map) return Map<String, dynamic>.from(errorPayload);
    if (errorPayload is String && errorPayload.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(errorPayload);
        if (decoded is Map<String, dynamic>) return decoded;
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {
        return null;
      }
    }
    return null;
  }
}
