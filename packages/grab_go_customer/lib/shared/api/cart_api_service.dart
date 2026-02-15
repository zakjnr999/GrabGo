import 'package:chopper/chopper.dart';

part 'cart_api_service.chopper.dart';

@ChopperApi(baseUrl: '/cart')
abstract class CartApiService extends ChopperService {
  /// Get user's active cart
  @GET()
  Future<Response<Map<String, dynamic>>> getCart({
    @Query('type') String? type,
    @Query('fulfillmentMode') String? fulfillmentMode,
    @Query('lat') double? lat,
    @Query('lng') double? lng,
    @Query('useCredits') bool? useCredits,
  });

  /// Add item to cart
  @POST(path: '/add')
  Future<Response<Map<String, dynamic>>> addToCart(
    @Body() Map<String, dynamic> body, {
    @Query('fulfillmentMode') String? fulfillmentMode,
    @Query('lat') double? lat,
    @Query('lng') double? lng,
    @Query('useCredits') bool? useCredits,
  });

  /// Update cart item quantity
  @PATCH(path: '/update/{itemId}')
  Future<Response<Map<String, dynamic>>> updateCartItem(
    @Path('itemId') String itemId,
    @Body() Map<String, dynamic> body, {
    @Query('fulfillmentMode') String? fulfillmentMode,
    @Query('lat') double? lat,
    @Query('lng') double? lng,
    @Query('useCredits') bool? useCredits,
  });

  /// Remove item from cart
  @DELETE(path: '/remove/{itemId}')
  Future<Response<Map<String, dynamic>>> removeFromCart(
    @Path('itemId') String itemId, {
    @Query('fulfillmentMode') String? fulfillmentMode,
    @Query('lat') double? lat,
    @Query('lng') double? lng,
    @Query('useCredits') bool? useCredits,
  });

  /// Clear entire cart
  @DELETE(path: '/clear')
  Future<Response<Map<String, dynamic>>> clearCart({
    @Query('fulfillmentMode') String? fulfillmentMode,
    @Query('lat') double? lat,
    @Query('lng') double? lng,
    @Query('useCredits') bool? useCredits,
  });

  static CartApiService create([ChopperClient? client]) {
    return _$CartApiService(client);
  }
}
