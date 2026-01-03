import 'package:chopper/chopper.dart';

part 'restaurant_service.chopper.dart';

@ChopperApi()
abstract class RestaurantService extends ChopperService {
  @GET(path: '/restaurants')
  Future<Response> getRestaurants();

  static RestaurantService create([ChopperClient? client]) => _$RestaurantService(client);
}


