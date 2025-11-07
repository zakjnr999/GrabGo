import 'package:chopper/chopper.dart';
import 'package:grab_go_admin/core/api/api_client.dart';

part 'auth_service.chopper.dart';

@ChopperApi()
abstract class AuthService extends ChopperService {
  @POST(path: '/users/login')
  Future<Response<Map<String, dynamic>>> login({@Body() required Map<String, dynamic> credentials});

  static AuthService create([ChopperClient? client]) => _$AuthService(client);
}
