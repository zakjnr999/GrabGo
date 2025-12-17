import 'package:chopper/chopper.dart';

part 'grocery_service.chopper.dart';

@ChopperApi()
abstract class GroceryService extends ChopperService {
  @GET(path: '/groceries/stores')
  Future<Response> getStores();

  @GET(path: '/groceries/stores/{id}')
  Future<Response> getStoreById(@Path('id') String id);

  @GET(path: '/groceries/categories')
  Future<Response> getCategories();

  @GET(path: '/groceries/items')
  Future<Response> getItems({
    @Query('category') String? category,
    @Query('store') String? store,
    @Query('minPrice') String? minPrice,
    @Query('maxPrice') String? maxPrice,
    @Query('tags') String? tags,
  });

  @GET(path: '/groceries/items/{id}')
  Future<Response> getItemById(@Path('id') String id);

  @GET(path: '/groceries/search')
  Future<Response> searchItems(@Query('q') String query);

  @GET(path: '/groceries/deals')
  Future<Response> getDeals();

  @GET(path: '/groceries/stores/{id}/items')
  Future<Response> getStoreItems(@Path('id') String storeId);

  @GET(path: '/groceries/order-history')
  Future<Response> getOrderHistory();

  @GET(path: '/groceries/store-specials')
  Future<Response> getStoreSpecials();

  @GET(path: '/groceries/popular')
  Future<Response> getPopularItems(@Query('limit') int? limit);

  @GET(path: '/groceries/top-rated')
  Future<Response> getTopRatedItems(@Query('limit') int? limit, @Query('minRating') double? minRating);

  static GroceryService create([ChopperClient? client]) => _$GroceryService(client);
}
