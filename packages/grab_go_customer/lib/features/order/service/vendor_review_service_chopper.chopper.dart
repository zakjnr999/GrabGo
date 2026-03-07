// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

part of 'vendor_review_service_chopper.dart';

// **************************************************************************
// ChopperGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: type=lint
final class _$VendorReviewServiceChopper extends VendorReviewServiceChopper {
  _$VendorReviewServiceChopper([ChopperClient? client]) {
    if (client == null) return;
    this.client = client;
  }

  @override
  final Type definitionType = VendorReviewServiceChopper;

  @override
  Future<Response<Map<String, dynamic>>> getVendorReviews(
    String vendorType,
    String vendorId, {
    String? sort,
    int? page,
    int? limit,
  }) {
    final Uri $url = Uri.parse('/vendor-reviews/${vendorType}/${vendorId}');
    final Map<String, dynamic> $params = <String, dynamic>{
      'sort': sort,
      'page': page,
      'limit': limit,
    };
    final Request $request = Request(
      'GET',
      $url,
      client.baseUrl,
      parameters: $params,
    );
    return client.send<Map<String, dynamic>, Map<String, dynamic>>($request);
  }

  @override
  Future<Response<Map<String, dynamic>>> reportVendorReview(
    String reviewId,
    Map<String, dynamic> body,
  ) {
    final Uri $url = Uri.parse('/vendor-reviews/${reviewId}/report');
    final Request $request = Request('POST', $url, client.baseUrl, body: body);
    return client.send<Map<String, dynamic>, Map<String, dynamic>>($request);
  }
}
