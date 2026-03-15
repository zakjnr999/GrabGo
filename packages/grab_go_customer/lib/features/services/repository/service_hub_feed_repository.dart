import 'package:chopper/chopper.dart';
import 'package:grab_go_customer/core/api/api_client.dart'
    as chopper_client_service;
import 'package:grab_go_customer/features/services/model/service_hub_feed.dart';

class ServiceHubFeedRepository {
  Future<ServiceHubFeed> fetchFeed({
    required String serviceId,
    double? userLat,
    double? userLng,
    double? maxDistance,
  }) async {
    final queryParameters = <String, String>{
      'service': serviceId,
      if (userLat != null) 'userLat': '$userLat',
      if (userLng != null) 'userLng': '$userLng',
      if (maxDistance != null) 'maxDistance': '$maxDistance',
    };

    final Response response = await chopper_client_service.chopperClient.get(
      Uri(path: '/home/service-feed', queryParameters: queryParameters),
    );

    if (response.isSuccessful && response.body != null) {
      final body = response.body as Map<String, dynamic>;
      final payload = body['data'];

      if (payload is Map<String, dynamic>) {
        return ServiceHubFeed.fromJson(payload);
      }

      if (payload is Map) {
        return ServiceHubFeed.fromJson(Map<String, dynamic>.from(payload));
      }

      throw Exception('Invalid service hub feed payload');
    }

    throw Exception('Failed to load service hub feed: ${response.statusCode}');
  }
}
