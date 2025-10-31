// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

part of 'restaurant_service.dart';

// **************************************************************************
// ChopperGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: type=lint
final class _$RestaurantService extends RestaurantService {
  _$RestaurantService([ChopperClient? client]) {
    if (client == null) return;
    this.client = client;
  }

  @override
  final Type definitionType = RestaurantService;

  @override
  Future<Response<List<RestaurantData>>> getRestaurants() {
    final Uri $url = Uri.parse('/restaurants');
    final Request $request = Request('GET', $url, client.baseUrl);
    return client.send<List<RestaurantData>, RestaurantData>($request);
  }

  @override
  Future<Response<RestaurantResponse>> registerRestaurant({
    required String restaurantName,
    required String email,
    required String phone,
    required String address,
    required String city,
    required String ownerFullName,
    required String ownerContactNumber,
    required String businessIdNumber,
    required String password,
    String? logo,
    String? businessIdPhoto,
    String? ownerPhoto,
  }) {
    final Uri $url = Uri.parse('/restaurants/register');
    final List<PartValue> $parts = <PartValue>[
      PartValue<String>('name', restaurantName),
      PartValue<String>('email', email),
      PartValue<String>('phone', phone),
      PartValue<String>('address', address),
      PartValue<String>('city', city),
      PartValue<String>('owner_full_name', ownerFullName),
      PartValue<String>('owner_contact_number', ownerContactNumber),
      PartValue<String>('business_id_number', businessIdNumber),
      PartValue<String>('password', password),
      PartValueFile<String?>('logo', logo),
      PartValueFile<String?>('business_id_photo', businessIdPhoto),
      PartValueFile<String?>('owner_photo', ownerPhoto),
    ];
    final Request $request = Request(
      'POST',
      $url,
      client.baseUrl,
      parts: $parts,
      multipart: true,
    );
    return client.send<RestaurantResponse, RestaurantResponse>($request);
  }
}
