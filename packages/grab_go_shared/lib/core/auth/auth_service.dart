import 'package:chopper/chopper.dart';
import 'package:grab_go_shared/core/auth/user_model.dart';

part 'auth_service.chopper.dart';

@ChopperApi()
abstract class AuthService extends ChopperService {
  @POST(path: '/users')
  Future<Response<UserResponse>> registerUser(@Body() RegisterRequest request);

  @POST(path: '/users/login')
  Future<Response<UserResponse>> loginUser(@Body() LoginRequest request);

  @POST(path: '/users')
  Future<Response<UserResponse>> googleSignUp(@Body() GoogleSignInRequest request);

  @POST(path: '/users/login')
  Future<Response<UserResponse>> googleSignIn(@Body() GoogleSignInRequest request);

  @PUT(path: '/users/{userId}')
  Future<Response<UserResponse>> verifyPhone(@Path() String userId, @Body() PhoneVerificationRequest request);

  @PUT(path: '/users/{userId}')
  @multipart
  Future<Response<UserResponse>> uploadProfile(@Path() String userId, @PartFile('profilePicture') String imagePath);

  @PUT(path: '/users/{userId}')
  @multipart
  Future<Response<UserResponse>> uploadProfileWithFile(
    @Path() String userId,
    @PartFile('profilePicture') String imagePath,
  );

  @PUT(path: '/users/{userId}')
  Future<Response<UserResponse>> uploadProfileAsBase64(@Path() String userId, @Body() Map<String, dynamic> request);

  @PUT(path: '/users/{userId}')
  @multipart
  Future<Response<UserResponse>> uploadProfileWithFileAlt(@Path() String userId, @PartFile('file') String imagePath);

  @PUT(path: '/users/{userId}')
  @multipart
  Future<Response<UserResponse>> uploadProfileWithFileAlt2(@Path() String userId, @PartFile('image') String imagePath);

  @GET(path: '/users/{userId}')
  Future<Response<UserResponse>> getUser(@Path() String userId);

  @POST(path: '/users/verify-email')
  Future<Response<Map<String, dynamic>>> verifyEmail(@Body() Map<String, dynamic> request);

  @POST(path: '/users/resend-verification')
  Future<Response<Map<String, dynamic>>> resendVerification(@Body() Map<String, dynamic> request);

  @POST(path: '/users/send-verification')
  Future<Response<Map<String, dynamic>>> sendVerification();

  @POST(path: '/users/fcm-token')
  Future<Response<Map<String, dynamic>>> registerFcmToken(@Body() Map<String, dynamic> request);

  @DELETE(path: '/users/fcm-token')
  Future<Response<Map<String, dynamic>>> removeFcmToken(@Body() Map<String, dynamic> request);

  @PUT(path: '/users/notification-settings')
  Future<Response<Map<String, dynamic>>> updateNotificationSettings(@Body() Map<String, dynamic> request);

  static AuthService create([ChopperClient? client]) => _$AuthService(client);
}
