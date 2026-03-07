import 'dart:convert';

import 'package:chopper/chopper.dart';
import 'package:grab_go_customer/core/api/api_client.dart';
import 'package:grab_go_customer/features/order/model/vendor_review_models.dart';
import 'package:grab_go_customer/features/order/service/vendor_review_service_chopper.dart';

class VendorReviewServiceWrapper {
  final VendorReviewServiceChopper _vendorReviewService;

  VendorReviewServiceWrapper()
    : _vendorReviewService = chopperClient
          .getService<VendorReviewServiceChopper>();

  Future<VendorReviewFeed> getVendorReviews({
    required String vendorType,
    required String vendorId,
    String sort = 'popular',
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final response = await _vendorReviewService.getVendorReviews(
        vendorType,
        vendorId,
        sort: sort,
        page: page,
        limit: limit,
      );
      final body = _resolveResponseMap(response);

      if (body == null) {
        throw Exception('Unable to load vendor reviews right now.');
      }

      if (body['success'] != true) {
        throw Exception(
          body['message']?.toString() ?? 'Failed to load vendor reviews',
        );
      }

      final data = body['data'] as Map<String, dynamic>?;
      if (data == null) {
        throw Exception('Vendor review response was empty');
      }

      return VendorReviewFeed.fromJson(data);
    } catch (e) {
      throw Exception('Failed to load vendor reviews: $e');
    }
  }

  Future<void> reportVendorReview({
    required String reviewId,
    required String reason,
    String? details,
  }) async {
    try {
      final response = await _vendorReviewService.reportVendorReview(reviewId, {
        'reason': reason,
        if (details != null && details.trim().isNotEmpty)
          'details': details.trim(),
      });
      final body = _resolveResponseMap(response);

      if (body == null) {
        throw Exception('Unable to report this review right now.');
      }

      if (body['success'] != true) {
        throw Exception(
          body['message']?.toString() ?? 'Failed to report this review',
        );
      }
    } catch (e) {
      throw Exception('Failed to report vendor review: $e');
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
