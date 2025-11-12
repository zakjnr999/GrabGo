import 'package:json_annotation/json_annotation.dart';

part 'order_response.g.dart';

@JsonSerializable()
class OrderResponse {
  final bool success;
  final String message;
  final List<OrderData> data;

  const OrderResponse({
    required this.success,
    required this.message,
    required this.data,
  });

  factory OrderResponse.fromJson(Map<String, dynamic> json) => _$OrderResponseFromJson(json);
  Map<String, dynamic> toJson() => _$OrderResponseToJson(this);
}

@JsonSerializable()
class OrderData {
  @JsonKey(name: '_id')
  final String id;
  final String orderNumber;
  final CustomerInfo customer;
  final RestaurantInfo restaurant;
  final RiderInfo? rider;
  final List<OrderItem> items;
  final double subtotal;
  final double deliveryFee;
  final double tax;
  final double totalAmount;
  final DeliveryAddress deliveryAddress;
  final String paymentMethod;
  final String? paymentProvider;
  final String? paymentReferenceId;
  final String paymentStatus;
  final String status;
  final String? expectedDelivery;
  final String? deliveredDate;
  final String? cancelledDate;
  final String? cancellationReason;
  final String? notes;
  final String orderDate;
  final String createdAt;
  final String updatedAt;

  const OrderData({
    required this.id,
    required this.orderNumber,
    required this.customer,
    required this.restaurant,
    this.rider,
    required this.items,
    required this.subtotal,
    required this.deliveryFee,
    required this.tax,
    required this.totalAmount,
    required this.deliveryAddress,
    required this.paymentMethod,
    this.paymentProvider,
    this.paymentReferenceId,
    required this.paymentStatus,
    required this.status,
    this.expectedDelivery,
    this.deliveredDate,
    this.cancelledDate,
    this.cancellationReason,
    this.notes,
    required this.orderDate,
    required this.createdAt,
    required this.updatedAt,
  });

  factory OrderData.fromJson(Map<String, dynamic> json) => _$OrderDataFromJson(json);
  Map<String, dynamic> toJson() => _$OrderDataToJson(this);
}

@JsonSerializable()
class CustomerInfo {
  @JsonKey(name: '_id')
  final String id;
  final String username;
  final String email;
  final String? phone;

  const CustomerInfo({
    required this.id,
    required this.username,
    required this.email,
    this.phone,
  });

  factory CustomerInfo.fromJson(Map<String, dynamic> json) => _$CustomerInfoFromJson(json);
  Map<String, dynamic> toJson() => _$CustomerInfoToJson(this);
}

@JsonSerializable()
class RestaurantInfo {
  @JsonKey(name: '_id')
  final String id;
  @JsonKey(name: 'restaurant_name')
  final String restaurantName;
  final String? logo;

  const RestaurantInfo({
    required this.id,
    required this.restaurantName,
    this.logo,
  });

  factory RestaurantInfo.fromJson(Map<String, dynamic> json) => _$RestaurantInfoFromJson(json);
  Map<String, dynamic> toJson() => _$RestaurantInfoToJson(this);
}

@JsonSerializable()
class RiderInfo {
  @JsonKey(name: '_id')
  final String id;
  final String username;
  final String email;
  final String? phone;

  const RiderInfo({
    required this.id,
    required this.username,
    required this.email,
    this.phone,
  });

  factory RiderInfo.fromJson(Map<String, dynamic> json) => _$RiderInfoFromJson(json);
  Map<String, dynamic> toJson() => _$RiderInfoToJson(this);
}

@JsonSerializable()
class OrderItem {
  final FoodInfo food;
  final String name;
  final int quantity;
  final double price;
  final String? image;

  const OrderItem({
    required this.food,
    required this.name,
    required this.quantity,
    required this.price,
    this.image,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) => _$OrderItemFromJson(json);
  Map<String, dynamic> toJson() => _$OrderItemToJson(this);
}

@JsonSerializable()
class FoodInfo {
  @JsonKey(name: '_id')
  final String id;
  final String name;
  final double price;
  final String? image;

  const FoodInfo({
    required this.id,
    required this.name,
    required this.price,
    this.image,
  });

  factory FoodInfo.fromJson(Map<String, dynamic> json) => _$FoodInfoFromJson(json);
  Map<String, dynamic> toJson() => _$FoodInfoToJson(this);
}

@JsonSerializable()
class DeliveryAddress {
  final String street;
  final String city;
  final String? state;
  final String? zipCode;
  final double? latitude;
  final double? longitude;

  const DeliveryAddress({
    required this.street,
    required this.city,
    this.state,
    this.zipCode,
    this.latitude,
    this.longitude,
  });

  factory DeliveryAddress.fromJson(Map<String, dynamic> json) => _$DeliveryAddressFromJson(json);
  Map<String, dynamic> toJson() => _$DeliveryAddressToJson(this);
}