// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'order_service_chopper.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CreateOrderRequest _$CreateOrderRequestFromJson(Map<String, dynamic> json) => CreateOrderRequest(
  orderNumber: json['orderNumber'] as String,
  restaurant: json['restaurant'] as String,
  items: (json['items'] as List<dynamic>).map((e) => OrderItem.fromJson(e as Map<String, dynamic>)).toList(),
  deliveryAddress: DeliveryAddress.fromJson(json['deliveryAddress'] as Map<String, dynamic>),
  paymentMethod: json['paymentMethod'] as String,
  notes: json['notes'] as String?,
  pricing: OrderPricing.fromJson(json['pricing'] as Map<String, dynamic>),
);

Map<String, dynamic> _$CreateOrderRequestToJson(CreateOrderRequest instance) => <String, dynamic>{
  'orderNumber': instance.orderNumber,
  'restaurant': instance.restaurant,
  'items': instance.items,
  'deliveryAddress': instance.deliveryAddress,
  'paymentMethod': instance.paymentMethod,
  'notes': instance.notes,
  'pricing': instance.pricing,
};

DeliveryAddress _$DeliveryAddressFromJson(Map<String, dynamic> json) => DeliveryAddress(
  street: json['street'] as String,
  city: json['city'] as String,
  state: json['state'] as String?,
  zipCode: json['zipCode'] as String?,
  latitude: (json['latitude'] as num?)?.toDouble(),
  longitude: (json['longitude'] as num?)?.toDouble(),
);

Map<String, dynamic> _$DeliveryAddressToJson(DeliveryAddress instance) => <String, dynamic>{
  'street': instance.street,
  'city': instance.city,
  'state': instance.state,
  'zipCode': instance.zipCode,
  'latitude': instance.latitude,
  'longitude': instance.longitude,
};

OrderItem _$OrderItemFromJson(Map<String, dynamic> json) => OrderItem(
  food: json['food'] as String,
  quantity: (json['quantity'] as num).toInt(),
  price: (json['price'] as num).toDouble(),
);

Map<String, dynamic> _$OrderItemToJson(OrderItem instance) => <String, dynamic>{
  'food': instance.food,
  'quantity': instance.quantity,
  'price': instance.price,
};

OrderPricing _$OrderPricingFromJson(Map<String, dynamic> json) => OrderPricing(
  subtotal: (json['subtotal'] as num).toDouble(),
  deliveryFee: (json['deliveryFee'] as num).toDouble(),
  total: (json['total'] as num).toDouble(),
);

Map<String, dynamic> _$OrderPricingToJson(OrderPricing instance) => <String, dynamic>{
  'subtotal': instance.subtotal,
  'deliveryFee': instance.deliveryFee,
  'total': instance.total,
};
