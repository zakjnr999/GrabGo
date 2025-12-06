// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

part of 'notification_service_chopper.dart';

// **************************************************************************
// ChopperGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: type=lint
final class _$NotificationServiceChopper extends NotificationServiceChopper {
  _$NotificationServiceChopper([ChopperClient? client]) {
    if (client == null) return;
    this.client = client;
  }

  @override
  final Type definitionType = NotificationServiceChopper;

  @override
  Future<Response<dynamic>> getNotifications(int limit, int page) {
    final Uri $url = Uri.parse('/notifications');
    final Map<String, dynamic> $params = <String, dynamic>{
      'limit': limit,
      'page': page,
    };
    final Request $request = Request(
      'GET',
      $url,
      client.baseUrl,
      parameters: $params,
    );
    return client.send<dynamic, dynamic>($request);
  }

  @override
  Future<Response<dynamic>> getUnreadCount() {
    final Uri $url = Uri.parse('/notifications/unread-count');
    final Request $request = Request('GET', $url, client.baseUrl);
    return client.send<dynamic, dynamic>($request);
  }

  @override
  Future<Response<dynamic>> markAsRead(String id) {
    final Uri $url = Uri.parse('/notifications/${id}/read');
    final Request $request = Request('PATCH', $url, client.baseUrl);
    return client.send<dynamic, dynamic>($request);
  }

  @override
  Future<Response<dynamic>> markAllAsRead() {
    final Uri $url = Uri.parse('/notifications/read-all');
    final Request $request = Request('PATCH', $url, client.baseUrl);
    return client.send<dynamic, dynamic>($request);
  }

  @override
  Future<Response<dynamic>> clearAll() {
    final Uri $url = Uri.parse('/notifications');
    final Request $request = Request('DELETE', $url, client.baseUrl);
    return client.send<dynamic, dynamic>($request);
  }
}
