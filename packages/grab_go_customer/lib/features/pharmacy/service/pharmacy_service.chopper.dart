// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

part of 'pharmacy_service.dart';

// **************************************************************************
// ChopperGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: type=lint
final class _$PharmacyService extends PharmacyService {
  _$PharmacyService([ChopperClient? client]) {
    if (client == null) return;
    this.client = client;
  }

  @override
  final Type definitionType = PharmacyService;

  @override
  Future<Response<dynamic>> getCategories() {
    final Uri $url = Uri.parse('/pharmacies/categories');
    final Request $request = Request('GET', $url, client.baseUrl);
    return client.send<dynamic, dynamic>($request);
  }

  @override
  Future<Response<dynamic>> getItems({
    String? category,
    String? store,
    String? minPrice,
    String? maxPrice,
    String? tags,
  }) {
    final Uri $url = Uri.parse('/pharmacies/items');
    final Map<String, dynamic> $params = <String, dynamic>{
      'category': category,
      'store': store,
      'minPrice': minPrice,
      'maxPrice': maxPrice,
      'tags': tags,
    };
    final Request $request = Request(
      'GET',
      $url,
      client.baseUrl,
      parameters: $params,
    );
    return client.send<dynamic, dynamic>($request);
  }
}
