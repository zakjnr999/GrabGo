import 'package:chopper/chopper.dart';

part 'grabmart_service.chopper.dart';

@ChopperApi()
abstract class GrabMartService extends ChopperService {
  @GET(path: '/grabmart/categories')
  Future<Response> getCategories();

  @GET(path: '/grabmart/items')
  Future<Response> getItems({
    @Query('category') String? category,
    @Query('store') String? store,
    @Query('minPrice') String? minPrice,
    @Query('maxPrice') String? maxPrice,
    @Query('tags') String? tags,
  });

  static GrabMartService create([ChopperClient? client]) => _$GrabMartService(client);
}
