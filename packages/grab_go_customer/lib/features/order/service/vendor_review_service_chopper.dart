import 'package:chopper/chopper.dart';

part 'vendor_review_service_chopper.chopper.dart';

@ChopperApi()
abstract class VendorReviewServiceChopper extends ChopperService {
  @GET(path: '/vendor-reviews/{vendorType}/{vendorId}')
  Future<Response<Map<String, dynamic>>> getVendorReviews(
    @Path() String vendorType,
    @Path() String vendorId, {
    @Query('sort') String? sort,
    @Query('page') int? page,
    @Query('limit') int? limit,
  });

  @POST(path: '/vendor-reviews/{reviewId}/report')
  Future<Response<Map<String, dynamic>>> reportVendorReview(
    @Path() String reviewId,
    @Body() Map<String, dynamic> body,
  );

  static VendorReviewServiceChopper create([ChopperClient? client]) =>
      _$VendorReviewServiceChopper(client);
}
