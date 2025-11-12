// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'payment_service.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MtnMomoInitiateRequest _$MtnMomoInitiateRequestFromJson(
  Map<String, dynamic> json,
) => MtnMomoInitiateRequest(
  orderId: json['orderId'] as String,
  phoneNumber: json['phoneNumber'] as String,
);

Map<String, dynamic> _$MtnMomoInitiateRequestToJson(
  MtnMomoInitiateRequest instance,
) => <String, dynamic>{
  'orderId': instance.orderId,
  'phoneNumber': instance.phoneNumber,
};

MtnMomoInitiateResponse _$MtnMomoInitiateResponseFromJson(
  Map<String, dynamic> json,
) => MtnMomoInitiateResponse(
  paymentId: json['paymentId'] as String,
  referenceId: json['referenceId'] as String,
  externalReferenceId: json['externalReferenceId'] as String,
  status: json['status'] as String,
  amount: (json['amount'] as num).toDouble(),
  currency: json['currency'] as String,
  phoneNumber: json['phoneNumber'] as String,
);

Map<String, dynamic> _$MtnMomoInitiateResponseToJson(
  MtnMomoInitiateResponse instance,
) => <String, dynamic>{
  'paymentId': instance.paymentId,
  'referenceId': instance.referenceId,
  'externalReferenceId': instance.externalReferenceId,
  'status': instance.status,
  'amount': instance.amount,
  'currency': instance.currency,
  'phoneNumber': instance.phoneNumber,
};

MtnMomoStatusResponse _$MtnMomoStatusResponseFromJson(
  Map<String, dynamic> json,
) => MtnMomoStatusResponse(
  paymentId: json['paymentId'] as String,
  status: json['status'] as String,
  amount: (json['amount'] as num).toDouble(),
  currency: json['currency'] as String,
  financialTransactionId: json['financialTransactionId'] as String?,
  completedAt: json['completedAt'] == null
      ? null
      : DateTime.parse(json['completedAt'] as String),
  errorMessage: json['errorMessage'] as String?,
  expiresAt: json['expiresAt'] == null
      ? null
      : DateTime.parse(json['expiresAt'] as String),
);

Map<String, dynamic> _$MtnMomoStatusResponseToJson(
  MtnMomoStatusResponse instance,
) => <String, dynamic>{
  'paymentId': instance.paymentId,
  'status': instance.status,
  'amount': instance.amount,
  'currency': instance.currency,
  'financialTransactionId': instance.financialTransactionId,
  'completedAt': instance.completedAt?.toIso8601String(),
  'errorMessage': instance.errorMessage,
  'expiresAt': instance.expiresAt?.toIso8601String(),
};
