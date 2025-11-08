import 'package:chopper/chopper.dart';
import 'package:grab_go_customer/features/restaurant/model/restaurant_response.dart';

part 'restaurant_service.chopper.dart';

@ChopperApi()
abstract class RestaurantService extends ChopperService {
  @GET(path: '/restaurants')
  Future<Response<dynamic>> getRestaurants();

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
    return response;
  }
}
