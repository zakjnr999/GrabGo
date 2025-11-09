// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'rider_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RiderVerificationRequest _$RiderVerificationRequestFromJson(
  Map<String, dynamic> json,
) => RiderVerificationRequest(
  vehicleType: json['vehicleType'] as String?,
  licensePlateNumber: json['licensePlateNumber'] as String?,
  vehicleBrand: json['vehicleBrand'] as String?,
  vehicleModel: json['vehicleModel'] as String?,
  nationalIdType: json['nationalIdType'] as String?,
  nationalIdNumber: json['nationalIdNumber'] as String?,
  paymentMethod: json['paymentMethod'] as String?,
  bankName: json['bankName'] as String?,
  accountNumber: json['accountNumber'] as String?,
  accountHolderName: json['accountHolderName'] as String?,
  mobileMoneyProvider: json['mobileMoneyProvider'] as String?,
  mobileMoneyNumber: json['mobileMoneyNumber'] as String?,
  agreedToTerms: json['agreedToTerms'] as bool?,
  agreedToLocationAccess: json['agreedToLocationAccess'] as bool?,
  agreedToAccuracy: json['agreedToAccuracy'] as bool?,
);

Map<String, dynamic> _$RiderVerificationRequestToJson(
  RiderVerificationRequest instance,
) => <String, dynamic>{
  'vehicleType': instance.vehicleType,
  'licensePlateNumber': instance.licensePlateNumber,
  'vehicleBrand': instance.vehicleBrand,
  'vehicleModel': instance.vehicleModel,
  'nationalIdType': instance.nationalIdType,
  'nationalIdNumber': instance.nationalIdNumber,
  'paymentMethod': instance.paymentMethod,
  'bankName': instance.bankName,
  'accountNumber': instance.accountNumber,
  'accountHolderName': instance.accountHolderName,
  'mobileMoneyProvider': instance.mobileMoneyProvider,
  'mobileMoneyNumber': instance.mobileMoneyNumber,
  'agreedToTerms': instance.agreedToTerms,
  'agreedToLocationAccess': instance.agreedToLocationAccess,
  'agreedToAccuracy': instance.agreedToAccuracy,
};

Rider _$RiderFromJson(Map<String, dynamic> json) => Rider(
  id: json['_id'] as String?,
  user: json['user'] as String?,
  vehicleType: json['vehicleType'] as String?,
  licensePlateNumber: json['licensePlateNumber'] as String?,
  vehicleBrand: json['vehicleBrand'] as String?,
  vehicleModel: json['vehicleModel'] as String?,
  vehicleImage: json['vehicleImage'] as String?,
  nationalIdType: json['nationalIdType'] as String?,
  nationalIdNumber: json['nationalIdNumber'] as String?,
  idFrontImage: json['idFrontImage'] as String?,
  idBackImage: json['idBackImage'] as String?,
  selfiePhoto: json['selfiePhoto'] as String?,
  paymentMethod: json['paymentMethod'] as String?,
  bankName: json['bankName'] as String?,
  accountNumber: json['accountNumber'] as String?,
  accountHolderName: json['accountHolderName'] as String?,
  mobileMoneyProvider: json['mobileMoneyProvider'] as String?,
  mobileMoneyNumber: json['mobileMoneyNumber'] as String?,
  verificationStatus: json['verificationStatus'] as String?,
  rejectionReason: json['rejectionReason'] as String?,
  verifiedAt: json['verifiedAt'] as String?,
  agreedToTerms: json['agreedToTerms'] as bool?,
  agreedToLocationAccess: json['agreedToLocationAccess'] as bool?,
  agreedToAccuracy: json['agreedToAccuracy'] as bool?,
  notes: json['notes'] as String?,
  createdAt: json['createdAt'] as String?,
  updatedAt: json['updatedAt'] as String?,
);

Map<String, dynamic> _$RiderToJson(Rider instance) => <String, dynamic>{
  '_id': instance.id,
  'user': instance.user,
  'vehicleType': instance.vehicleType,
  'licensePlateNumber': instance.licensePlateNumber,
  'vehicleBrand': instance.vehicleBrand,
  'vehicleModel': instance.vehicleModel,
  'vehicleImage': instance.vehicleImage,
  'nationalIdType': instance.nationalIdType,
  'nationalIdNumber': instance.nationalIdNumber,
  'idFrontImage': instance.idFrontImage,
  'idBackImage': instance.idBackImage,
  'selfiePhoto': instance.selfiePhoto,
  'paymentMethod': instance.paymentMethod,
  'bankName': instance.bankName,
  'accountNumber': instance.accountNumber,
  'accountHolderName': instance.accountHolderName,
  'mobileMoneyProvider': instance.mobileMoneyProvider,
  'mobileMoneyNumber': instance.mobileMoneyNumber,
  'verificationStatus': instance.verificationStatus,
  'rejectionReason': instance.rejectionReason,
  'verifiedAt': instance.verifiedAt,
  'agreedToTerms': instance.agreedToTerms,
  'agreedToLocationAccess': instance.agreedToLocationAccess,
  'agreedToAccuracy': instance.agreedToAccuracy,
  'notes': instance.notes,
  'createdAt': instance.createdAt,
  'updatedAt': instance.updatedAt,
};

RiderResponse _$RiderResponseFromJson(Map<String, dynamic> json) =>
    RiderResponse(
      message: json['message'] as String,
      data: json['data'] == null
          ? null
          : Rider.fromJson(json['data'] as Map<String, dynamic>),
      success: json['success'] as bool?,
    );

Map<String, dynamic> _$RiderResponseToJson(RiderResponse instance) =>
    <String, dynamic>{
      'message': instance.message,
      'data': instance.data,
      'success': instance.success,
    };
