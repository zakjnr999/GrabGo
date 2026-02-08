// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

part of 'address_api_service.dart';

// **************************************************************************
// ChopperGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: type=lint
final class _$AddressApiService extends AddressApiService {
  _$AddressApiService([ChopperClient? client]) {
    if (client == null) return;
    this.client = client;
  }

  @override
  final Type definitionType = AddressApiService;

  @override
  Future<Response<Map<String, dynamic>>> getUserAddresses() {
    final Uri $url = Uri.parse('/addresses');
    final Request $request = Request('GET', $url, client.baseUrl);
    return client.send<Map<String, dynamic>, Map<String, dynamic>>($request);
  }

  @override
  Future<Response<Map<String, dynamic>>> addUserAddress(
    Map<String, dynamic> body,
  ) {
    final Uri $url = Uri.parse('/addresses');
    final $body = body;
    final Request $request = Request('POST', $url, client.baseUrl, body: $body);
    return client.send<Map<String, dynamic>, Map<String, dynamic>>($request);
  }

  @override
  Future<Response<Map<String, dynamic>>> updateUserAddress(
    String id,
    Map<String, dynamic> body,
  ) {
    final Uri $url = Uri.parse('/addresses/${id}');
    final $body = body;
    final Request $request = Request('PUT', $url, client.baseUrl, body: $body);
    return client.send<Map<String, dynamic>, Map<String, dynamic>>($request);
  }

  @override
  Future<Response<Map<String, dynamic>>> deleteUserAddress(String id) {
    final Uri $url = Uri.parse('/addresses/${id}');
    final Request $request = Request('DELETE', $url, client.baseUrl);
    return client.send<Map<String, dynamic>, Map<String, dynamic>>($request);
  }

  @override
  Future<Response<Map<String, dynamic>>> setDefaultAddress(String id) {
    final Uri $url = Uri.parse('/addresses/${id}/default');
    final Request $request = Request('PATCH', $url, client.baseUrl);
    return client.send<Map<String, dynamic>, Map<String, dynamic>>($request);
  }
}
