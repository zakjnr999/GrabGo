import 'package:chopper/chopper.dart';

part 'food_service.chopper.dart';

@ChopperApi()
abstract class FoodService extends ChopperService {
  @GET(path: '/categories')
  Future<Response> getCategories();

  static FoodService create([ChopperClient? client]) => _$FoodService(client);
}

