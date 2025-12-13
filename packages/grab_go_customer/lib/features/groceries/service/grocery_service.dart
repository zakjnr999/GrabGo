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

  static GroceryService create([ChopperClient? client]) => _$GroceryService(client);
}
