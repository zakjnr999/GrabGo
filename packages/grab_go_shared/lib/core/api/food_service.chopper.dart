// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

part of 'food_service.dart';

// **************************************************************************
// ChopperGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: type=lint
final class _$FoodService extends FoodService {
  _$FoodService([ChopperClient? client]) {
    if (client == null) return;
    this.client = client;
  }

  @override
  final Type definitionType = FoodService;

  @override
  Future<Response<dynamic>> getCategories() {
    final Uri $url = Uri.parse('/categories');
    final Request $request = Request('GET', $url, client.baseUrl);
    return client.send<dynamic, dynamic>($request);
  }
}
