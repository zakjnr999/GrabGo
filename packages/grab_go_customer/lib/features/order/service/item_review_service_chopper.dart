import 'package:chopper/chopper.dart';

part 'item_review_service_chopper.chopper.dart';

@ChopperApi()
abstract class ItemReviewServiceChopper extends ChopperService {
  @GET(path: '/item-reviews/{itemType}/{itemId}')
  Future<Response<Map<String, dynamic>>> getItemReviews(
    @Path() String itemType,
    @Path() String itemId, {
    @Query('sort') String? sort,
    @Query('page') int? page,
    @Query('limit') int? limit,
  });

  static ItemReviewServiceChopper create([ChopperClient? client]) =>
      _$ItemReviewServiceChopper(client);
}
