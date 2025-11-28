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
  @multipart
  Future<Response<UserResponse>> uploadProfileWithFileAlt(@Path() String userId, @PartFile('file') String imagePath);

  @PUT(path: '/users/{userId}')
  @multipart
  Future<Response<UserResponse>> uploadProfileWithFileAlt2(@Path() String userId, @PartFile('image') String imagePath);

  @GET(path: '/users/{userId}')
  Future<Response<UserResponse>> getUser(@Path() String userId);

  // Phone OTP endpoints
  @POST(path: '/users/send-phone-otp')
  Future<Response<Map<String, dynamic>>> sendPhoneOTP(@Body() Map<String, dynamic> body);

  @POST(path: '/users/verify-phone-otp')
  Future<Response<Map<String, dynamic>>> verifyPhoneOTP(@Body() Map<String, dynamic> body);

  @POST(path: '/users/resend-phone-otp')
  Future<Response<Map<String, dynamic>>> resendPhoneOTP(@Body() Map<String, dynamic> body);

  // FCM token endpoints
  @POST(path: '/users/fcm-token')
  Future<Response<Map<String, dynamic>>> registerFcmToken(@Body() Map<String, dynamic> request);

  @DELETE(path: '/users/fcm-token')
  Future<Response<Map<String, dynamic>>> removeFcmToken(@Body() Map<String, dynamic> request);

  @PUT(path: '/users/notification-settings')
  Future<Response<Map<String, dynamic>>> updateNotificationSettings(@Body() Map<String, dynamic> request);

  static AuthService create([ChopperClient? client]) => _$AuthService(client);
}
