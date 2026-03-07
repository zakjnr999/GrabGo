import 'package:chopper/chopper.dart';

part 'food_service.chopper.dart';

@ChopperApi()
abstract class FoodService extends ChopperService {
  @GET(path: '/categories')
  Future<Response> getCategories({
    @Query('userLat') double? userLat,
    @Query('userLng') double? userLng,
  });

  @GET(path: '/foods')
  Future<Response> getFoods({
    @Query('restaurant') String? restaurant,
    @Query('category') String? category,
    @Query('isAvailable') String? isAvailable,
    @Query('userLat') double? userLat,
    @Query('userLng') double? userLng,
  });

  @GET(path: '/foods/deals')
  Future<Response> getDeals();

  @GET(path: '/promotions/banners')
  Future<Response> getPromotionalBanners();

  @GET(path: '/home/food-feed')
  Future<Response> getHomeFeed({
    @Query('userLat') double? userLat,
    @Query('userLng') double? userLng,
  });

  @GET(path: '/foods/order-history')
  Future<Response> getOrderHistory();

  @GET(path: '/foods/popular')
  Future<Response> getPopularItems(
    @Query('limit') int? limit,
    @Query('userLat') double? userLat,
    @Query('userLng') double? userLng,
  );

  @GET(path: '/foods/top-rated')
  Future<Response> getTopRatedItems(
    @Query('limit') int? limit,
    @Query('minRating') double? minRating,
    @Query('userLat') double? userLat,
    @Query('userLng') double? userLng,
  );

  @GET(path: '/foods/recommended')
  Future<Response> getRecommendedItems(
    @Query('limit') int? limit,
    @Query('page') int? page,
    @Query('userLat') double? userLat,
    @Query('userLng') double? userLng,
  );

  static FoodService create([ChopperClient? client]) => _$FoodService(client);
}
