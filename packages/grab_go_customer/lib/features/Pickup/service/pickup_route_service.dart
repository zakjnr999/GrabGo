import 'package:dio/dio.dart';
import 'package:grab_go_customer/features/Pickup/model/pickup_route_data.dart';
import 'package:grab_go_shared/grub_go_shared.dart';

class PickupRouteService {
  final Dio _dio;

  PickupRouteService({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: AppConfig.apiBaseUrl,
              connectTimeout: const Duration(seconds: 20),
              receiveTimeout: const Duration(seconds: 20),
            ),
          );

  Future<PickupRouteData> fetchWalkingRoute({
    required double originLat,
    required double originLng,
    required double destinationLat,
    required double destinationLng,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/pickup/route',
        queryParameters: {
          'originLat': originLat,
          'originLng': originLng,
          'destinationLat': destinationLat,
          'destinationLng': destinationLng,
          'mode': 'walking',
        },
      );

      final body = response.data;
      if (body == null) {
        throw Exception('Unable to load walking route right now.');
      }

      if (body['success'] != true) {
        throw Exception(
          body['message']?.toString() ?? 'Failed to load walking route',
        );
      }

      final data = body['data'] as Map<String, dynamic>?;
      if (data == null) {
        throw Exception('Walking route response was empty');
      }

      return PickupRouteData.fromJson(data);
    } on DioException catch (error) {
      final responseData = error.response?.data;
      if (responseData is Map<String, dynamic>) {
        throw Exception(
          responseData['message']?.toString() ?? 'Failed to load walking route',
        );
      }
      if (responseData is Map) {
        final body = Map<String, dynamic>.from(responseData);
        throw Exception(
          body['message']?.toString() ?? 'Failed to load walking route',
        );
      }
      throw Exception('Failed to load walking route: ${error.message}');
    } catch (error) {
      throw Exception('Failed to load walking route: $error');
    }
  }
}
