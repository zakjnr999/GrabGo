import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';
import '../service/tracking_api_service.dart';
import '../service/tracking_socket_service.dart';
import '../providers/tracking_provider.dart';

final trackingLocator = GetIt.instance;

/// Initialize tracking services
/// Call this before using tracking features
void setupTrackingServices({required String baseUrl, required String token}) {
  // Register Dio instance for tracking
  if (!trackingLocator.isRegistered<Dio>(instanceName: 'trackingDio')) {
    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
      ),
    );
    trackingLocator.registerSingleton<Dio>(dio, instanceName: 'trackingDio');
  }

  // Register API Service
  if (!trackingLocator.isRegistered<TrackingApiService>()) {
    trackingLocator.registerLazySingleton<TrackingApiService>(
      () => TrackingApiService(
        dio: trackingLocator<Dio>(instanceName: 'trackingDio'),
        baseUrl: baseUrl,
      ),
    );
  }

  // Register Socket Service
  if (!trackingLocator.isRegistered<TrackingSocketService>()) {
    trackingLocator.registerLazySingleton<TrackingSocketService>(
      () => TrackingSocketService(serverUrl: baseUrl, token: token),
    );
  }

  // Register Provider (Factory - new instance each time)
  if (!trackingLocator.isRegistered<TrackingProvider>()) {
    trackingLocator.registerFactory<TrackingProvider>(
      () => TrackingProvider(
        apiService: trackingLocator<TrackingApiService>(),
        socketService: trackingLocator<TrackingSocketService>(),
      ),
    );
  }
}

/// Clean up tracking services
void disposeTrackingServices() {
  if (trackingLocator.isRegistered<TrackingProvider>()) {
    trackingLocator.unregister<TrackingProvider>();
  }
  if (trackingLocator.isRegistered<TrackingSocketService>()) {
    final socketService = trackingLocator<TrackingSocketService>();
    socketService.dispose();
    trackingLocator.unregister<TrackingSocketService>();
  }
  if (trackingLocator.isRegistered<TrackingApiService>()) {
    trackingLocator.unregister<TrackingApiService>();
  }
  if (trackingLocator.isRegistered<Dio>(instanceName: 'trackingDio')) {
    trackingLocator.unregister<Dio>(instanceName: 'trackingDio');
  }
}
