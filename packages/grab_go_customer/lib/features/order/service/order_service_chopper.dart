import 'package:chopper/chopper.dart';
import 'package:json_annotation/json_annotation.dart';

part 'order_service_chopper.chopper.dart';
part 'order_service_chopper.g.dart';

@ChopperApi()
abstract class OrderServiceChopper extends ChopperService {
  @POST(path: '/orders')
  Future<Response<Map<String, dynamic>>> createOrder(@Body() CreateOrderRequest request);

  @GET(path: '/orders/{orderId}')
  Future<Response<Map<String, dynamic>>> getOrder(@Path() String orderId);

  @GET(path: '/orders/my-orders')
  Future<Response<Map<String, dynamic>>> getUserOrders(@Query('page') int page, @Query('limit') int limit);

  static OrderServiceChopper create([ChopperClient? client]) => _$OrderServiceChopper(client);
}

@JsonSerializable()
class CreateOrderRequest {
  final String orderNumber;
  final String restaurant;
  final List<OrderItem> items;
  final DeliveryAddress deliveryAddress;
  final String paymentMethod;
  final String? notes;
  final OrderPricing pricing;

  CreateOrderRequest({
    required this.orderNumber,
    required this.restaurant,
    required this.items,
    required this.deliveryAddress,
    required this.paymentMethod,
    this.notes,
    required this.pricing,
  });

  Map<String, dynamic> toJson() => _$CreateOrderRequestToJson(this);
  factory CreateOrderRequest.fromJson(Map<String, dynamic> json) => _$CreateOrderRequestFromJson(json);
}

@JsonSerializable()
class DeliveryAddress {
  final String street;
  final String city;
  final String? state;
  final String? zipCode;
  final double? latitude;
  final double? longitude;

  DeliveryAddress({required this.street, required this.city, this.state, this.zipCode, this.latitude, this.longitude});

  Map<String, dynamic> toJson() => _$DeliveryAddressToJson(this);
  factory DeliveryAddress.fromJson(Map<String, dynamic> json) => _$DeliveryAddressFromJson(json);
}

@JsonSerializable()
class OrderItem {
  final String food;
  final int quantity;
  final double price;

  OrderItem({required this.food, required this.quantity, required this.price});

  Map<String, dynamic> toJson() => _$OrderItemToJson(this);
  factory OrderItem.fromJson(Map<String, dynamic> json) => _$OrderItemFromJson(json);
}

@JsonSerializable()
class OrderPricing {
  final double subtotal;
  final double deliveryFee;
  final double total;

  OrderPricing({required this.subtotal, required this.deliveryFee, required this.total});

  Map<String, dynamic> toJson() => _$OrderPricingToJson(this);
  factory OrderPricing.fromJson(Map<String, dynamic> json) => _$OrderPricingFromJson(json);
}
