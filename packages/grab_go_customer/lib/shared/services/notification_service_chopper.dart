import 'package:chopper/chopper.dart';

part 'notification_service_chopper.chopper.dart';

@ChopperApi(baseUrl: '/notifications')
abstract class NotificationServiceChopper extends ChopperService {
  @GET(path: '')
  Future<Response> getNotifications(@Query('limit') int limit, @Query('page') int page);

  @GET(path: '/unread-count')
  Future<Response> getUnreadCount();

  @PATCH(path: '/{id}/read')
  Future<Response> markAsRead(@Path('id') String id);

  @PATCH(path: '/read-all')
  Future<Response> markAllAsRead();

  @DELETE(path: '')
  Future<Response> clearAll();

  static NotificationServiceChopper create([ChopperClient? client]) => _$NotificationServiceChopper(client);
}
