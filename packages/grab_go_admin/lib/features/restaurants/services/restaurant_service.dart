import 'package:chopper/chopper.dart';
import '../model/restaurant_response.dart';

part 'restaurant_service.chopper.dart';

@ChopperApi()
abstract class RestaurantService extends ChopperService {
  @GET(path: '/restaurants')
  Future<Response<List<RestaurantData>>> getRestaurants();

  @PUT(path: '/restaurants/{restaurantId}')
  Future<Response<RestaurantData>> updateRestaurantStatus(
    @Path('restaurantId') String restaurantId,
    @Body() Map<String, dynamic> data,
  );

  static RestaurantService create([ChopperClient? client]) => _$RestaurantService(client);
}
