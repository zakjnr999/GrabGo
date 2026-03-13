import 'package:chopper/chopper.dart';
import 'package:json_annotation/json_annotation.dart';

part 'order_service_chopper.chopper.dart';
part 'order_service_chopper.g.dart';

@ChopperApi()
abstract class OrderServiceChopper extends ChopperService {
  @POST(path: '/orders')
  Future<Response<Map<String, dynamic>>> createOrder(
    @Body() CreateOrderRequest request,
  );

  @POST(path: '/orders/{orderId}/delivery-code/resend')
  Future<Response<Map<String, dynamic>>> resendDeliveryCode(
    @Path() String orderId,
    @Body() Map<String, dynamic> body,
  );

  @POST(path: '/orders/{orderId}/confirm-payment')
  Future<Response<Map<String, dynamic>>> confirmPayment(
    @Path() String orderId,
    @Body() Map<String, dynamic> body,
  );

  @GET(path: '/orders/{orderId}/payment-status')
  Future<Response<Map<String, dynamic>>> getOrderPaymentStatus(
    @Path() String orderId,
  );

  @POST(path: '/orders/{orderId}/release-credit-hold')
  Future<Response<Map<String, dynamic>>> releaseCreditHold(
    @Path() String orderId,
  );

  @POST(path: '/orders/{orderId}/paystack/initialize')
  Future<Response<Map<String, dynamic>>> initializePaystack(
    @Path() String orderId,
  );

  @POST(path: '/checkout-sessions')
  Future<Response<Map<String, dynamic>>> createCheckoutSession(
    @Body() Map<String, dynamic> body,
  );

  @POST(path: '/checkout-sessions/{sessionId}/paystack/initialize')
  Future<Response<Map<String, dynamic>>> initializeCheckoutSessionPaystack(
    @Path() String sessionId,
  );

  @POST(path: '/checkout-sessions/{sessionId}/confirm-payment')
  Future<Response<Map<String, dynamic>>> confirmCheckoutSessionPayment(
    @Path() String sessionId,
    @Body() Map<String, dynamic> body,
  );

  @GET(path: '/checkout-sessions/{sessionId}/payment-status')
  Future<Response<Map<String, dynamic>>> getCheckoutSessionPaymentStatus(
    @Path() String sessionId,
  );

  @POST(path: '/checkout-sessions/{sessionId}/release-credit-hold')
  Future<Response<Map<String, dynamic>>> releaseCheckoutSessionCreditHold(
    @Path() String sessionId,
  );

  @GET(path: '/orders/{orderId}')
  Future<Response<Map<String, dynamic>>> getOrder(@Path() String orderId);

  @GET(path: '/orders')
  Future<Response<Map<String, dynamic>>> getUserOrders();

  @GET(path: '/orders/cod/eligibility')
  Future<Response<Map<String, dynamic>>> getCodEligibility();

  @POST(path: '/orders/{orderId}/vendor-rating')
  Future<Response<Map<String, dynamic>>> submitVendorRating(
    @Path() String orderId,
    @Body() Map<String, dynamic> body,
  );

  @POST(path: '/orders/{orderId}/item-reviews')
  Future<Response<Map<String, dynamic>>> submitItemReviews(
    @Path() String orderId,
    @Body() Map<String, dynamic> body,
  );

  static OrderServiceChopper create([ChopperClient? client]) =>
      _$OrderServiceChopper(client);
}

@JsonSerializable(explicitToJson: true, includeIfNull: false)
class CreateOrderRequest {
  final String orderNumber;
  final String restaurant;
  final List<OrderItem> items;
  final String fulfillmentMode;
  final String? deliveryTimeType;
  final String? scheduledForAt;
  final DeliveryAddress? deliveryAddress;
  final String? pickupContactName;
  final String? pickupContactPhone;
  final bool? acceptNoShowPolicy;
  final String? noShowPolicyVersion;
  final String paymentMethod;
  final bool? useCredits;
  final String? promoCode;
  final String? notes;
  final bool? isGiftOrder;
  final String? giftRecipientName;
  final String? giftRecipientPhone;
  final String? giftNote;
  final OrderPricing pricing;

  CreateOrderRequest({
    required this.orderNumber,
    required this.restaurant,
    required this.items,
    required this.fulfillmentMode,
    this.deliveryTimeType,
    this.scheduledForAt,
    this.deliveryAddress,
    this.pickupContactName,
    this.pickupContactPhone,
    this.acceptNoShowPolicy,
    this.noShowPolicyVersion,
    required this.paymentMethod,
    this.useCredits,
    this.promoCode,
    this.notes,
    this.isGiftOrder,
    this.giftRecipientName,
    this.giftRecipientPhone,
    this.giftNote,
    required this.pricing,
  });

  Map<String, dynamic> toJson() => _$CreateOrderRequestToJson(this);
  factory CreateOrderRequest.fromJson(Map<String, dynamic> json) =>
      _$CreateOrderRequestFromJson(json);
}

@JsonSerializable()
class DeliveryAddress {
  final String street;
  final String city;
  final String? state;
  final String? zipCode;
  final double? latitude;
  final double? longitude;

  DeliveryAddress({
    required this.street,
    required this.city,
    this.state,
    this.zipCode,
    this.latitude,
    this.longitude,
  });

  Map<String, dynamic> toJson() => _$DeliveryAddressToJson(this);
  factory DeliveryAddress.fromJson(Map<String, dynamic> json) =>
      _$DeliveryAddressFromJson(json);
}

@JsonSerializable()
class OrderItem {
  final String food;
  final int quantity;
  final double price;
  final String itemType; // 'food' or 'grocery'
  final String? selectedPortionId;
  final List<String>? selectedPreferenceOptionIds;
  final String? itemNote;

  OrderItem({
    required this.food,
    required this.quantity,
    required this.price,
    required this.itemType,
    this.selectedPortionId,
    this.selectedPreferenceOptionIds,
    this.itemNote,
  });

  Map<String, dynamic> toJson() => _$OrderItemToJson(this);
  factory OrderItem.fromJson(Map<String, dynamic> json) =>
      _$OrderItemFromJson(json);
}

@JsonSerializable()
class OrderPricing {
  final double subtotal;
  final double deliveryFee;
  final double total;

  OrderPricing({
    required this.subtotal,
    required this.deliveryFee,
    required this.total,
  });

  Map<String, dynamic> toJson() => _$OrderPricingToJson(this);
  factory OrderPricing.fromJson(Map<String, dynamic> json) =>
      _$OrderPricingFromJson(json);
}
