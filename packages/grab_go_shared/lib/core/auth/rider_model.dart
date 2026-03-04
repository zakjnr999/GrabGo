import 'package:json_annotation/json_annotation.dart';

part 'rider_model.g.dart';

@JsonSerializable()
class RiderVerificationRequest {
  final String? vehicleType;
  final String? licensePlateNumber;
  final String? vehicleBrand;
  final String? vehicleModel;
  final String? nationalIdType;
  final String? nationalIdNumber;
  final String? paymentMethod;
  final String? bankName;
  final String? accountNumber;
  final String? accountHolderName;
  final String? mobileMoneyProvider;
  final String? mobileMoneyNumber;
  final bool? agreedToTerms;
  final bool? agreedToLocationAccess;
  final bool? agreedToAccuracy;

  RiderVerificationRequest({
    this.vehicleType,
    this.licensePlateNumber,
    this.vehicleBrand,
    this.vehicleModel,
    this.nationalIdType,
    this.nationalIdNumber,
    this.paymentMethod,
    this.bankName,
    this.accountNumber,
    this.accountHolderName,
    this.mobileMoneyProvider,
    this.mobileMoneyNumber,
    this.agreedToTerms,
    this.agreedToLocationAccess,
    this.agreedToAccuracy,
  });

  factory RiderVerificationRequest.fromJson(Map<String, dynamic> json) => _$RiderVerificationRequestFromJson(json);

  Map<String, dynamic> toJson() => _$RiderVerificationRequestToJson(this);
}

@JsonSerializable()
class Rider {
  @JsonKey(name: '_id')
  final String? id;
  final String? user;

  // Vehicle Information
  final String? vehicleType;
  final String? licensePlateNumber;
  final String? vehicleBrand;
  final String? vehicleModel;
  final String? vehicleImage;

  // Identity Verification
  final String? nationalIdType;
  final String? nationalIdNumber;
  final String? idFrontImage;
  final String? idBackImage;
  final String? selfiePhoto;

  // Payment Information
  final String? paymentMethod;
  final String? bankName;
  final String? accountNumber;
  final String? accountHolderName;
  final String? mobileMoneyProvider;
  final String? mobileMoneyNumber;

  // Verification Status
  final String? verificationStatus;
  final String? rejectionReason;
  final String? verifiedAt;

  // Agreements
  final bool? agreedToTerms;
  final bool? agreedToLocationAccess;
  final bool? agreedToAccuracy;

  // Additional
  final double? rating;
  final int? ratingCount;
  final int? totalDeliveries;
  final int? activeDays;
  final String? notes;
  final String? createdAt;
  final String? updatedAt;

  Rider({
    this.id,
    this.user,
    this.vehicleType,
    this.licensePlateNumber,
    this.vehicleBrand,
    this.vehicleModel,
    this.vehicleImage,
    this.nationalIdType,
    this.nationalIdNumber,
    this.idFrontImage,
    this.idBackImage,
    this.selfiePhoto,
    this.paymentMethod,
    this.bankName,
    this.accountNumber,
    this.accountHolderName,
    this.mobileMoneyProvider,
    this.mobileMoneyNumber,
    this.verificationStatus,
    this.rejectionReason,
    this.verifiedAt,
    this.agreedToTerms,
    this.agreedToLocationAccess,
    this.agreedToAccuracy,
    this.rating,
    this.ratingCount,
    this.totalDeliveries,
    this.activeDays,
    this.notes,
    this.createdAt,
    this.updatedAt,
  });

  factory Rider.fromJson(Map<String, dynamic> json) => _$RiderFromJson(json);

  Map<String, dynamic> toJson() => _$RiderToJson(this);
}

@JsonSerializable()
class RiderResponse {
  final String message;
  final Rider? data;
  final bool? success;

  RiderResponse({required this.message, this.data, this.success});

  factory RiderResponse.fromJson(Map<String, dynamic> json) {
    // Prefer generated parsing for standard `{message, data, success}` shape.
    if (json['message'] is String && (json['data'] == null || json['data'] is Map<String, dynamic>)) {
      final parsed = _$RiderResponseFromJson(json);
      if (parsed.data != null || json['data'] == null) {
        return parsed;
      }
    }

    Rider? riderData;
    if (json['data'] is Map<String, dynamic>) {
      riderData = Rider.fromJson(json['data'] as Map<String, dynamic>);
    } else if (json.containsKey('vehicleType') || json.containsKey('verificationStatus')) {
      // Backward compatibility: some endpoints may return rider fields at root.
      riderData = Rider.fromJson(json);
    }

    return RiderResponse(
      message: json['message'] as String? ?? '',
      data: riderData,
      success: json['success'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => _$RiderResponseToJson(this);
}
