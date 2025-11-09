// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

part of 'rider_service.dart';

// **************************************************************************
// ChopperGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: type=lint
final class _$RiderService extends RiderService {
  _$RiderService([ChopperClient? client]) {
    if (client == null) return;
    this.client = client;
  }

  @override
  final Type definitionType = RiderService;

  @override
  Future<Response<RiderResponse>> submitVerification({
    String? vehicleType,
    String? licensePlateNumber,
    String? vehicleBrand,
    String? vehicleModel,
    String? nationalIdType,
    String? nationalIdNumber,
    String? paymentMethod,
    String? bankName,
    String? accountNumber,
    String? accountHolderName,
    String? mobileMoneyProvider,
    String? mobileMoneyNumber,
    String? agreedToTerms,
    String? agreedToLocationAccess,
    String? agreedToAccuracy,
    String? vehicleImagePath,
  }) {
    final Uri $url = Uri.parse('/riders/verification');
    final List<PartValue> $parts = <PartValue>[
      PartValue<String?>('vehicleType', vehicleType),
      PartValue<String?>('licensePlateNumber', licensePlateNumber),
      PartValue<String?>('vehicleBrand', vehicleBrand),
      PartValue<String?>('vehicleModel', vehicleModel),
      PartValue<String?>('nationalIdType', nationalIdType),
      PartValue<String?>('nationalIdNumber', nationalIdNumber),
      PartValue<String?>('paymentMethod', paymentMethod),
      PartValue<String?>('bankName', bankName),
      PartValue<String?>('accountNumber', accountNumber),
      PartValue<String?>('accountHolderName', accountHolderName),
      PartValue<String?>('mobileMoneyProvider', mobileMoneyProvider),
      PartValue<String?>('mobileMoneyNumber', mobileMoneyNumber),
      PartValue<String?>('agreedToTerms', agreedToTerms),
      PartValue<String?>('agreedToLocationAccess', agreedToLocationAccess),
      PartValue<String?>('agreedToAccuracy', agreedToAccuracy),
      PartValueFile<String?>('vehicleImage', vehicleImagePath),
    ];
    final Request $request = Request(
      'POST',
      $url,
      client.baseUrl,
      parts: $parts,
      multipart: true,
    );
    return client.send<RiderResponse, RiderResponse>($request);
  }

  @override
  Future<Response<RiderResponse>> getVerification() {
    final Uri $url = Uri.parse('/riders/verification');
    final Request $request = Request('GET', $url, client.baseUrl);
    return client.send<RiderResponse, RiderResponse>($request);
  }

  @override
  Future<Response<RiderResponse>> updateVerification({
    String? vehicleType,
    String? licensePlateNumber,
    String? vehicleBrand,
    String? vehicleModel,
    String? nationalIdType,
    String? nationalIdNumber,
    String? paymentMethod,
    String? bankName,
    String? accountNumber,
    String? accountHolderName,
    String? mobileMoneyProvider,
    String? mobileMoneyNumber,
    String? agreedToTerms,
    String? agreedToLocationAccess,
    String? agreedToAccuracy,
    String? vehicleImagePath,
  }) {
    final Uri $url = Uri.parse('/riders/verification');
    final List<PartValue> $parts = <PartValue>[
      PartValue<String?>('vehicleType', vehicleType),
      PartValue<String?>('licensePlateNumber', licensePlateNumber),
      PartValue<String?>('vehicleBrand', vehicleBrand),
      PartValue<String?>('vehicleModel', vehicleModel),
      PartValue<String?>('nationalIdType', nationalIdType),
      PartValue<String?>('nationalIdNumber', nationalIdNumber),
      PartValue<String?>('paymentMethod', paymentMethod),
      PartValue<String?>('bankName', bankName),
      PartValue<String?>('accountNumber', accountNumber),
      PartValue<String?>('accountHolderName', accountHolderName),
      PartValue<String?>('mobileMoneyProvider', mobileMoneyProvider),
      PartValue<String?>('mobileMoneyNumber', mobileMoneyNumber),
      PartValue<String?>('agreedToTerms', agreedToTerms),
      PartValue<String?>('agreedToLocationAccess', agreedToLocationAccess),
      PartValue<String?>('agreedToAccuracy', agreedToAccuracy),
      PartValueFile<String?>('vehicleImage', vehicleImagePath),
    ];
    final Request $request = Request(
      'PUT',
      $url,
      client.baseUrl,
      parts: $parts,
      multipart: true,
    );
    return client.send<RiderResponse, RiderResponse>($request);
  }

  @override
  Future<Response<RiderResponse>> uploadIdImage({
    required String imageType,
    required String imagePath,
  }) {
    final Uri $url = Uri.parse('/riders/verification/upload-id');
    final List<PartValue> $parts = <PartValue>[
      PartValue<String>('imageType', imageType),
      PartValueFile<String>('idImage', imagePath),
    ];
    final Request $request = Request(
      'POST',
      $url,
      client.baseUrl,
      parts: $parts,
      multipart: true,
    );
    return client.send<RiderResponse, RiderResponse>($request);
  }

  @override
  Future<Response<Map<String, dynamic>>> getWallet() {
    final Uri $url = Uri.parse('/riders/wallet');
    final Request $request = Request('GET', $url, client.baseUrl);
    return client.send<Map<String, dynamic>, Map<String, dynamic>>($request);
  }
}
