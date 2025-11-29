// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'status_service.dart';

// **************************************************************************
// ChopperGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: type=lint
final class _$StatusService extends StatusService {
  _$StatusService([ChopperClient? client]) {
    if (client == null) return;
    this.client = client;
  }

  @override
  final Type definitionType = StatusService;

  @override
  Future<Response<dynamic>> getStatuses({
    String? category,
    String? restaurant,
    String? recommended,
    int? limit,
    int? page,
  }) {
    final Uri $url = Uri.parse('/statuses');
    final Map<String, dynamic> $params = <String, dynamic>{
      'category': category,
      'restaurant': restaurant,
      'recommended': recommended,
      'limit': limit,
      'page': page,
    };
    final Request $request = Request('GET', $url, client.baseUrl, parameters: $params);
    return client.send<dynamic, dynamic>($request);
  }

  @override
  Future<Response<dynamic>> getStories({int? limit, String? sortBy}) {
    final Uri $url = Uri.parse('/statuses/stories');
    final Map<String, dynamic> $params = <String, dynamic>{'limit': limit, 'sortBy': sortBy};
    final Request $request = Request('GET', $url, client.baseUrl, parameters: $params);
    return client.send<dynamic, dynamic>($request);
  }

  @override
  Future<Response<dynamic>> getRestaurantStories(String restaurantId) {
    final Uri $url = Uri.parse('/statuses/stories/${restaurantId}');
    final Request $request = Request('GET', $url, client.baseUrl);
    return client.send<dynamic, dynamic>($request);
  }

  @override
  Future<Response<dynamic>> getStatus(String statusId) {
    final Uri $url = Uri.parse('/statuses/${statusId}');
    final Request $request = Request('GET', $url, client.baseUrl);
    return client.send<dynamic, dynamic>($request);
  }

  @override
  Future<Response<dynamic>> getViewedStatuses() {
    final Uri $url = Uri.parse('/statuses/user/viewed');
    final Request $request = Request('GET', $url, client.baseUrl);
    return client.send<dynamic, dynamic>($request);
  }

  @override
  Future<Response<dynamic>> recordView(String statusId, Map<String, dynamic> body) {
    final Uri $url = Uri.parse('/statuses/${statusId}/view');
    final $body = body;
    final Request $request = Request('POST', $url, client.baseUrl, body: $body);
    return client.send<dynamic, dynamic>($request);
  }

  @override
  Future<Response<dynamic>> recordBatchViews(Map<String, dynamic> body) {
    final Uri $url = Uri.parse('/statuses/views/batch');
    final $body = body;
    final Request $request = Request('POST', $url, client.baseUrl, body: $body);
    return client.send<dynamic, dynamic>($request);
  }

  @override
  Future<Response<dynamic>> toggleLike(String statusId) {
    final Uri $url = Uri.parse('/statuses/${statusId}/like');
    final Request $request = Request('POST', $url, client.baseUrl);
    return client.send<dynamic, dynamic>($request);
  }
}
