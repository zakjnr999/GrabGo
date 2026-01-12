import 'package:dio/dio.dart';
import '../models/tracking_models.dart';

/// Service for tracking API calls
class TrackingApiService {
  final Dio _dio;
  final String baseUrl;

  TrackingApiService({required Dio dio, required this.baseUrl}) : _dio = dio;

  /// Get tracking information for an order
  ///
  /// Endpoint: GET /api/tracking/:orderId
  /// Returns: TrackingData with current location, ETA, route, etc.
  Future<TrackingData> getTrackingInfo(String orderId) async {
    try {
      final response = await _dio.get('$baseUrl/api/tracking/$orderId');

      if (response.data['success'] == true) {
        return TrackingData.fromJson(response.data['data']);
      } else {
        throw TrackingException(
          message: response.data['message'] ?? 'Failed to get tracking info',
          statusCode: response.statusCode,
        );
      }
    } on DioException catch (e) {
      throw _handleDioError(e);
    } catch (e) {
      throw TrackingException(message: 'Unexpected error: $e', statusCode: null);
    }
  }

  /// Initialize tracking for an order
  ///
  /// Endpoint: POST /api/tracking/initialize
  /// Used when order is first assigned to rider
  Future<TrackingData> initializeTracking({
    required String orderId,
    required String riderId,
    required String customerId,
    required Map<String, double> pickupLocation,
    required Map<String, double> destination,
  }) async {
    try {
      final response = await _dio.post(
        '$baseUrl/api/tracking/initialize',
        data: {
          'orderId': orderId,
          'riderId': riderId,
          'customerId': customerId,
          'pickupLocation': pickupLocation,
          'destination': destination,
        },
      );

      if (response.data['success'] == true) {
        return TrackingData.fromJson(response.data['data']);
      } else {
        throw TrackingException(
          message: response.data['message'] ?? 'Failed to initialize tracking',
          statusCode: response.statusCode,
        );
      }
    } on DioException catch (e) {
      throw _handleDioError(e);
    } catch (e) {
      throw TrackingException(message: 'Unexpected error: $e', statusCode: null);
    }
  }

  /// Handle Dio errors and convert to TrackingException
  TrackingException _handleDioError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return TrackingException(
          message: 'Connection timeout. Please check your internet connection.',
          statusCode: null,
        );
      case DioExceptionType.badResponse:
        final statusCode = e.response?.statusCode;
        final message = e.response?.data['message'] ?? 'Server error occurred';
        return TrackingException(message: message, statusCode: statusCode);
      case DioExceptionType.cancel:
        return TrackingException(message: 'Request was cancelled', statusCode: null);
      default:
        return TrackingException(message: 'Network error: ${e.message}', statusCode: null);
    }
  }
}

/// Custom exception for tracking errors
class TrackingException implements Exception {
  final String message;
  final int? statusCode;

  TrackingException({required this.message, this.statusCode});

  @override
  String toString() {
    if (statusCode != null) {
      return 'TrackingException ($statusCode): $message';
    }
    return 'TrackingException: $message';
  }
}
