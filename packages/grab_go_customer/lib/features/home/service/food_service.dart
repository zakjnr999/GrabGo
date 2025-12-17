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

  @GET(path: '/foods/deals')
  Future<Response> getDeals();

  @GET(path: '/promotions/banners')
  Future<Response> getPromotionalBanners();

  @GET(path: '/foods/order-history')
  Future<Response> getOrderHistory();

  @GET(path: '/foods/popular')
  Future<Response> getPopularItems(@Query('limit') int? limit);

  @GET(path: '/foods/top-rated')
  Future<Response> getTopRatedItems(@Query('limit') int? limit, @Query('minRating') double? minRating);

  static FoodService create([ChopperClient? client]) => _$FoodService(client);
}
