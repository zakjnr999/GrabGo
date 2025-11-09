// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

part of 'auth_service.dart';

// **************************************************************************
// ChopperGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: type=lint
final class _$AuthService extends AuthService {
  _$AuthService([ChopperClient? client]) {
    if (client == null) return;
    this.client = client;
  }

  @override
  final Type definitionType = AuthService;

  @override
  Future<Response<UserResponse>> registerUser(RegisterRequest request) {
    final Uri $url = Uri.parse('/users');
    final $body = request;
    final Request $request = Request('POST', $url, client.baseUrl, body: $body);
    return client.send<UserResponse, UserResponse>($request);
  }

  @override
  Future<Response<UserResponse>> loginUser(LoginRequest request) {
    final Uri $url = Uri.parse('/users/login');
    final $body = request;
    final Request $request = Request('POST', $url, client.baseUrl, body: $body);
    return client.send<UserResponse, UserResponse>($request);
  }

  @override
  Future<Response<UserResponse>> googleSignUp(GoogleSignInRequest request) {
    final Uri $url = Uri.parse('/users');
    final $body = request;
    final Request $request = Request('POST', $url, client.baseUrl, body: $body);
    return client.send<UserResponse, UserResponse>($request);
  }

  @override
  Future<Response<UserResponse>> googleSignIn(GoogleSignInRequest request) {
    final Uri $url = Uri.parse('/users/login');
    final $body = request;
    final Request $request = Request('POST', $url, client.baseUrl, body: $body);
    return client.send<UserResponse, UserResponse>($request);
  }

  @override
  Future<Response<UserResponse>> verifyPhone(
    String userId,
    PhoneVerificationRequest request,
  ) {
    final Uri $url = Uri.parse('/users/${userId}');
    final $body = request;
    final Request $request = Request('PUT', $url, client.baseUrl, body: $body);
    return client.send<UserResponse, UserResponse>($request);
  }

  @override
  Future<Response<UserResponse>> uploadProfile(
    String userId,
    String imagePath,
  ) {
    final Uri $url = Uri.parse('/users/${userId}');
    final List<PartValue> $parts = <PartValue>[
      PartValueFile<String>('profilePicture', imagePath),
    ];
    final Request $request = Request(
      'PUT',
      $url,
      client.baseUrl,
      parts: $parts,
      multipart: true,
    );
    return client.send<UserResponse, UserResponse>($request);
  }

  @override
  Future<Response<UserResponse>> uploadProfileWithFile(
    String userId,
    String imagePath,
  ) {
    final Uri $url = Uri.parse('/users/${userId}');
    final List<PartValue> $parts = <PartValue>[
      PartValueFile<String>('profilePicture', imagePath),
    ];
    final Request $request = Request(
      'PUT',
      $url,
      client.baseUrl,
      parts: $parts,
      multipart: true,
    );
    return client.send<UserResponse, UserResponse>($request);
  }

  @override
  Future<Response<UserResponse>> uploadProfileAsBase64(
    String userId,
    Map<String, dynamic> request,
  ) {
    final Uri $url = Uri.parse('/users/${userId}');
    final $body = request;
    final Request $request = Request('PUT', $url, client.baseUrl, body: $body);
    return client.send<UserResponse, UserResponse>($request);
  }

  @override
  Future<Response<UserResponse>> uploadProfileWithFileAlt(
    String userId,
    String imagePath,
  ) {
    final Uri $url = Uri.parse('/users/${userId}');
    final List<PartValue> $parts = <PartValue>[
      PartValueFile<String>('file', imagePath),
    ];
    final Request $request = Request(
      'PUT',
      $url,
      client.baseUrl,
      parts: $parts,
      multipart: true,
    );
    return client.send<UserResponse, UserResponse>($request);
  }

  @override
  Future<Response<UserResponse>> uploadProfileWithFileAlt2(
    String userId,
    String imagePath,
  ) {
    final Uri $url = Uri.parse('/users/${userId}');
    final List<PartValue> $parts = <PartValue>[
      PartValueFile<String>('image', imagePath),
    ];
    final Request $request = Request(
      'PUT',
      $url,
      client.baseUrl,
      parts: $parts,
      multipart: true,
    );
    return client.send<UserResponse, UserResponse>($request);
  }

  @override
  Future<Response<UserResponse>> getUser(String userId) {
    final Uri $url = Uri.parse('/users/${userId}');
    final Request $request = Request('GET', $url, client.baseUrl);
    return client.send<UserResponse, UserResponse>($request);
  }

  @override
  Future<Response<Map<String, dynamic>>> verifyEmail(
    Map<String, dynamic> request,
  ) {
    final Uri $url = Uri.parse('/users/verify-email');
    final $body = request;
    final Request $request = Request('POST', $url, client.baseUrl, body: $body);
    return client.send<Map<String, dynamic>, Map<String, dynamic>>($request);
  }

  @override
  Future<Response<Map<String, dynamic>>> resendVerification(
    Map<String, dynamic> request,
  ) {
    final Uri $url = Uri.parse('/users/resend-verification');
    final $body = request;
    final Request $request = Request('POST', $url, client.baseUrl, body: $body);
    return client.send<Map<String, dynamic>, Map<String, dynamic>>($request);
  }

  @override
  Future<Response<Map<String, dynamic>>> sendVerification() {
    final Uri $url = Uri.parse('/users/send-verification');
    final Request $request = Request('POST', $url, client.baseUrl);
    return client.send<Map<String, dynamic>, Map<String, dynamic>>($request);
  }
}
