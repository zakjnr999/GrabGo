import 'dart:io';
import 'package:chopper/chopper.dart';
import 'package:flutter/foundation.dart';
import 'package:grab_go_customer/features/restaurant/model/restaurant_response.dart';

part 'restaurant_service.chopper.dart';

@ChopperApi()
abstract class RestaurantService extends ChopperService {
  @GET(path: '/restaurants')
  Future<Response<List<RestaurantData>>> getRestaurants();

  @POST(path: '/restaurants/register')
  @multipart
  Future<Response<RestaurantResponse>> registerRestaurant({
    @Part('name') required String restaurantName,
    @Part('email') required String email,
    @Part('phone') required String phone,
    @Part('address') required String address,
    @Part('city') required String city,
    @Part('owner_full_name') required String ownerFullName,
    @Part('owner_contact_number') required String ownerContactNumber,
    @Part('business_id_number') required String businessIdNumber,
    @Part('password') required String password,
    @PartFile('logo') String? logo,
    @PartFile('business_id_photo') String? businessIdPhoto,
    @PartFile('owner_photo') String? ownerPhoto,
  });

  static RestaurantService create([ChopperClient? client]) => _$RestaurantService(client);
}

extension RestaurantServiceDebug on RestaurantService {
  Future<Response<RestaurantResponse>> registerRestaurantWithDebug({
    required String restaurantName,
    required String email,
    required String phone,
    required String address,
    required String city,
    required String ownerFullName,
    required String ownerContactNumber,
    required String businessIdNumber,
    required String password,
    String? logo,
    String? businessIdPhoto,
    String? ownerPhoto,
  }) async {
    _debugLogMultipartRequest(
      restaurantName: restaurantName,
      email: email,
      phone: phone,
      address: address,
      city: city,
      ownerFullName: ownerFullName,
      ownerContactNumber: ownerContactNumber,
      businessIdNumber: businessIdNumber,
      password: password,
      logo: logo,
      businessIdPhoto: businessIdPhoto,
      ownerPhoto: ownerPhoto,
    );

    final response = await registerRestaurant(
      restaurantName: restaurantName,
      email: email,
      phone: phone,
      address: address,
      city: city,
      ownerFullName: ownerFullName,
      ownerContactNumber: ownerContactNumber,
      businessIdNumber: businessIdNumber,
      password: password,
      logo: logo,
      businessIdPhoto: businessIdPhoto,
      ownerPhoto: ownerPhoto,
    );

    _debugLogMultipartResponse(response);

    return response;
  }

  void _debugLogMultipartRequest({
    required String restaurantName,
    required String email,
    required String phone,
    required String address,
    required String city,
    required String ownerFullName,
    required String ownerContactNumber,
    required String businessIdNumber,
    required String password,
    String? logo,
    String? businessIdPhoto,
    String? ownerPhoto,
  }) {
    if (!kDebugMode) return;

    debugPrint('📤 MULTIPART REQUEST PREPARATION');
    debugPrint('├─ Text Fields:');
    debugPrint('│  ├─ name: $restaurantName');
    debugPrint('│  ├─ email: $email');
    debugPrint('│  ├─ phone: $phone');
    debugPrint('│  ├─ address: $address');
    debugPrint('│  ├─ city: $city');
    debugPrint('│  ├─ owner_full_name: $ownerFullName');
    debugPrint('│  ├─ owner_contact_number: $ownerContactNumber');
    debugPrint('│  ├─ business_id_number: $businessIdNumber');
    debugPrint('│  └─ password: [${password.length} characters]');

    debugPrint('├─ File Fields:');
    debugPrint('│  ├─ logo: ${logo ?? "null"}');
    debugPrint('│  ├─ business_id_photo: ${businessIdPhoto ?? "null"}');
    debugPrint('│  └─ owner_photo: ${ownerPhoto ?? "null"}');

    if (logo != null) {
      final file = File(logo);
      if (file.existsSync()) {
        debugPrint('│  ├─ Logo File Size: ${file.lengthSync()} bytes');
        debugPrint('│  ├─ Logo File Exists: true');
      } else {
        debugPrint('│  ├─ Logo File Exists: false');
      }
    }
    if (businessIdPhoto != null) {
      final file = File(businessIdPhoto);
      if (file.existsSync()) {
        debugPrint('│  ├─ Business ID File Size: ${file.lengthSync()} bytes');
        debugPrint('│  ├─ Business ID File Exists: true');
      } else {
        debugPrint('│  ├─ Business ID File Exists: false');
      }
    }
    if (ownerPhoto != null) {
      final file = File(ownerPhoto);
      if (file.existsSync()) {
        debugPrint('│  ├─ Owner Photo File Size: ${file.lengthSync()} bytes');
        debugPrint('│  ├─ Owner Photo File Exists: true');
      } else {
        debugPrint('│  ├─ Owner Photo File Exists: false');
      }
    }

    debugPrint('└─────────────────────────────────────────');
  }

  void _debugLogMultipartResponse(Response<RestaurantResponse> response) {
    if (!kDebugMode) return;

    debugPrint('📥 MULTIPART RESPONSE RECEIVED');
    debugPrint('├─ Status Code: ${response.statusCode}');
    debugPrint('├─ Reason Phrase: ${response.base.reasonPhrase}');
    debugPrint('├─ Headers: ${response.base.headers}');
    debugPrint('├─ Body Type: ${response.body.runtimeType}');
    debugPrint('├─ Is Successful: ${response.isSuccessful}');

    if (response.body != null) {
      debugPrint('├─ Response Body: ${response.body}');
    }

    if (response.error != null) {
      debugPrint('├─ Error: ${response.error}');
    }

    debugPrint('└─────────────────────────────────────────');
  }
}
