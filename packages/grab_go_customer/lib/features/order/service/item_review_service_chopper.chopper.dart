// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

part of 'item_review_service_chopper.dart';

// **************************************************************************
// ChopperGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: type=lint
final class _$ItemReviewServiceChopper extends ItemReviewServiceChopper {
  _$ItemReviewServiceChopper([ChopperClient? client]) {
    if (client == null) return;
    this.client = client;
  }

  @override
  final Type definitionType = ItemReviewServiceChopper;

  @override
  Future<Response<Map<String, dynamic>>> getItemReviews(
    String itemType,
    String itemId, {
    String? sort,
    int? page,
    int? limit,
  }) {
    final Uri $url = Uri.parse('/item-reviews/${itemType}/${itemId}');
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
  Future<Response<Map<String, dynamic>>> reportItemReview(
    String reviewId,
    Map<String, dynamic> body,
  ) {
    final Uri $url = Uri.parse('/item-reviews/${reviewId}/report');
    final Request $request = Request('POST', $url, client.baseUrl, body: body);
    return client.send<Map<String, dynamic>, Map<String, dynamic>>($request);
  }
}
