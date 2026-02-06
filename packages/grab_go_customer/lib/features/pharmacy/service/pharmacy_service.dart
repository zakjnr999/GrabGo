import 'package:chopper/chopper.dart';

part 'pharmacy_service.chopper.dart';

@ChopperApi()
abstract class PharmacyService extends ChopperService {
  @GET(path: '/pharmacies/categories')
  Future<Response> getCategories();

  @GET(path: '/pharmacies/items')
  Future<Response> getItems({
    @Query('category') String? category,
    @Query('store') String? store,
    @Query('minPrice') String? minPrice,
    @Query('maxPrice') String? maxPrice,
    @Query('tags') String? tags,
    @Query('userLat') double? userLat,
    @Query('userLng') double? userLng,
  });

  static PharmacyService create([ChopperClient? client]) => _$PharmacyService(client);
}
