import 'package:chopper/chopper.dart';

part 'food_service.chopper.dart';

@ChopperApi()
abstract class FoodService extends ChopperService {
  @GET(path: '/categories')
  Future<Response> getCategories();

  @GET(path: '/foods')
  Future<Response> getFoods({
    @Query('restaurant') String? restaurant,
    @Query('category') String? category,
    @Query('isAvailable') String? isAvailable,
  });

  static FoodService create([ChopperClient? client]) => _$FoodService(client);
}
