import 'package:chopper/chopper.dart';
import 'package:json_annotation/json_annotation.dart';

part 'payment_service.chopper.dart';
part 'payment_service.g.dart';

@ChopperApi()
abstract class PaymentService extends ChopperService {
  @POST(path: '/payments/mtn-momo/initiate')
  Future<Response<Map<String, dynamic>>> initiateMtnMomoPayment(@Body() MtnMomoInitiateRequest request);

  @GET(path: '/payments/mtn-momo/status/{paymentId}')
  Future<Response<Map<String, dynamic>>> checkPaymentStatus(@Path() String paymentId);

  @PUT(path: '/payments/{paymentId}/cancel')
  Future<Response<Map<String, dynamic>>> cancelPayment(@Path() String paymentId);

  @GET(path: '/payments/my-payments')
  Future<Response<Map<String, dynamic>>> getUserPayments(@Query('page') int page, @Query('limit') int limit);

  static PaymentService create([ChopperClient? client]) => _$PaymentService(client);
}

// Request/Response models for MTN MOMO
@JsonSerializable()
class MtnMomoInitiateRequest {
  final String orderId;
  final String phoneNumber;

  MtnMomoInitiateRequest({
    required this.orderId,
    required this.phoneNumber,
  });

  Map<String, dynamic> toJson() => _$MtnMomoInitiateRequestToJson(this);
  factory MtnMomoInitiateRequest.fromJson(Map<String, dynamic> json) => _$MtnMomoInitiateRequestFromJson(json);
}

@JsonSerializable()
class MtnMomoInitiateResponse {
  final String paymentId;
  final String referenceId;
  final String externalReferenceId;
  final String status;
  final double amount;
  final String currency;
  final String phoneNumber;

  MtnMomoInitiateResponse({
    required this.paymentId,
    required this.referenceId,
    required this.externalReferenceId,
    required this.status,
    required this.amount,
    required this.currency,
    required this.phoneNumber,
  });

  factory MtnMomoInitiateResponse.fromJson(Map<String, dynamic> json) => _$MtnMomoInitiateResponseFromJson(json);
  Map<String, dynamic> toJson() => _$MtnMomoInitiateResponseToJson(this);
}

@JsonSerializable()
class MtnMomoStatusResponse {
  final String paymentId;
  final String status;
  final double amount;
  final String currency;
  final String? financialTransactionId;
  final DateTime? completedAt;
  final String? errorMessage;
  final DateTime? expiresAt;

  MtnMomoStatusResponse({
    required this.paymentId,
    required this.status,
    required this.amount,
    required this.currency,
    this.financialTransactionId,
    this.completedAt,
    this.errorMessage,
    this.expiresAt,
  });

  factory MtnMomoStatusResponse.fromJson(Map<String, dynamic> json) => _$MtnMomoStatusResponseFromJson(json);
  Map<String, dynamic> toJson() => _$MtnMomoStatusResponseToJson(this);

  bool get isCompleted => status == 'successful' || status == 'failed';
  bool get isSuccessful => status == 'successful';
  bool get isFailed => status == 'failed';
  bool get isPending => status == 'pending' || status == 'processing';
}