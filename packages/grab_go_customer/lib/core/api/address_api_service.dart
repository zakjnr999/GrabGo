import 'package:chopper/chopper.dart';

part 'address_api_service.chopper.dart';

@ChopperApi(baseUrl: '/addresses')
abstract class AddressApiService extends ChopperService {
  @GET()
  Future<Response<List<Map<String, dynamic>>>> getUserAddresses();

  @POST()
  Future<Response<Map<String, dynamic>>> addUserAddress(@Body() Map<String, dynamic> body);

  @PUT(path: '/{id}')
  Future<Response<Map<String, dynamic>>> updateUserAddress(@Path('id') String id, @Body() Map<String, dynamic> body);

  @DELETE(path: '/{id}')
  Future<Response<Map<String, dynamic>>> deleteUserAddress(@Path('id') String id);

  @PATCH(path: '/{id}/default')
  Future<Response<Map<String, dynamic>>> setDefaultAddress(@Path('id') String id);

  static AddressApiService create([ChopperClient? client]) => _$AddressApiService(client);
}
