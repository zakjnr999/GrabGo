import 'package:chopper/chopper.dart';

part 'vendor_service.chopper.dart';

@ChopperApi()
abstract class VendorService extends ChopperService {
  // ==================== RESTAURANT ENDPOINTS ====================

  @GET(path: '/restaurants')
  Future<Response<Map<String, dynamic>>> getRestaurants({
    @Query('isOpen') String? isOpen,
    @Query('minRating') double? minRating,
    @Query('limit') int? limit,
  });

  @GET(path: '/restaurants/{id}')
  Future<Response<Map<String, dynamic>>> getRestaurantById(@Path('id') String id);

  @GET(path: '/restaurants/search')
  Future<Response<Map<String, dynamic>>> searchRestaurants({@Query('q') required String query});

  @GET(path: '/restaurants/nearby')
  Future<Response<Map<String, dynamic>>> getNearbyRestaurants({
    @Query('lat') required double latitude,
    @Query('lng') required double longitude,
    @Query('radius') double? radius,
  });

  // ==================== GROCERY ENDPOINTS ====================

  @GET(path: '/groceries/stores')
  Future<Response<Map<String, dynamic>>> getGroceryStores({
    @Query('isOpen') String? isOpen,
    @Query('minRating') double? minRating,
    @Query('limit') int? limit,
  });

  @GET(path: '/groceries/stores/{id}')
  Future<Response<Map<String, dynamic>>> getGroceryStoreById(@Path('id') String id);

  @GET(path: '/groceries/search')
  Future<Response<Map<String, dynamic>>> searchGroceryStores({@Query('q') required String query});

  @GET(path: '/groceries/nearby')
  Future<Response<Map<String, dynamic>>> getNearbyGroceryStores({
    @Query('lat') required double latitude,
    @Query('lng') required double longitude,
    @Query('radius') double? radius,
  });

  // ==================== PHARMACY ENDPOINTS ====================

  @GET(path: '/pharmacies/stores')
  Future<Response<Map<String, dynamic>>> getPharmacyStores({
    @Query('isOpen') String? isOpen,
    @Query('minRating') double? minRating,
    @Query('limit') int? limit,
  });

  @GET(path: '/pharmacies/stores/{id}')
  Future<Response<Map<String, dynamic>>> getPharmacyStoreById(@Path('id') String id);

  @GET(path: '/pharmacies/search')
  Future<Response<Map<String, dynamic>>> searchPharmacies({
    @Query('q') required String query,
    @Query('emergencyService') String? emergencyService,
    @Query('prescriptionService') String? prescriptionService,
  });

  @GET(path: '/pharmacies/emergency')
  Future<Response<Map<String, dynamic>>> getEmergencyPharmacies();

  @GET(path: '/pharmacies/24-hours')
  Future<Response<Map<String, dynamic>>> get24HourPharmacies();

  @GET(path: '/pharmacies/nearby')
  Future<Response<Map<String, dynamic>>> getNearbyPharmacies({
    @Query('lat') required double latitude,
    @Query('lng') required double longitude,
    @Query('radius') double? radius,
  });

  // ==================== GRABMART ENDPOINTS ====================

  @GET(path: '/grabmart/stores')
  Future<Response<Map<String, dynamic>>> getGrabMartStores({
    @Query('isOpen') String? isOpen,
    @Query('is24Hours') String? is24Hours,
    @Query('minRating') double? minRating,
    @Query('limit') int? limit,
  });

  @GET(path: '/grabmart/stores/{id}')
  Future<Response<Map<String, dynamic>>> getGrabMartStoreById(@Path('id') String id);

  @GET(path: '/grabmart/search')
  Future<Response<Map<String, dynamic>>> searchGrabMarts({
    @Query('q') required String query,
    @Query('services') String? services,
    @Query('productTypes') String? productTypes,
  });

  @GET(path: '/grabmart/24-hours')
  Future<Response<Map<String, dynamic>>> get24HourGrabMarts();

  @GET(path: '/grabmart/with-services')
  Future<Response<Map<String, dynamic>>> getGrabMartsWithServices({@Query('services') required String services});

  @GET(path: '/grabmart/nearby')
  Future<Response<Map<String, dynamic>>> getNearbyGrabMarts({
    @Query('lat') required double latitude,
    @Query('lng') required double longitude,
    @Query('radius') double? radius,
  });

  @GET(path: '/grabmart/payment-methods')
  Future<Response<Map<String, dynamic>>> getGrabMartsByPaymentMethods({
    @Query('cash') String? cash,
    @Query('card') String? card,
    @Query('mobileMoney') String? mobileMoney,
  });

  static VendorService create([ChopperClient? client]) {
    return _$VendorService(client);
  }
}
