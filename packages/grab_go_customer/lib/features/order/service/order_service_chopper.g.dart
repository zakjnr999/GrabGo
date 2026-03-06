// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'order_service_chopper.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CreateOrderRequest _$CreateOrderRequestFromJson(Map<String, dynamic> json) =>
    CreateOrderRequest(
      orderNumber: json['orderNumber'] as String,
      restaurant: json['restaurant'] as String,
      items: (json['items'] as List<dynamic>)
          .map((e) => OrderItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      fulfillmentMode: json['fulfillmentMode'] as String,
      deliveryTimeType: json['deliveryTimeType'] as String?,
      scheduledForAt: json['scheduledForAt'] as String?,
      deliveryAddress: json['deliveryAddress'] == null
          ? null
          : DeliveryAddress.fromJson(
              json['deliveryAddress'] as Map<String, dynamic>,
            ),
      pickupContactName: json['pickupContactName'] as String?,
      pickupContactPhone: json['pickupContactPhone'] as String?,
      acceptNoShowPolicy: json['acceptNoShowPolicy'] as bool?,
      noShowPolicyVersion: json['noShowPolicyVersion'] as String?,
      paymentMethod: json['paymentMethod'] as String,
      useCredits: json['useCredits'] as bool?,
      promoCode: json['promoCode'] as String?,
      notes: json['notes'] as String?,
      isGiftOrder: json['isGiftOrder'] as bool?,
      giftRecipientName: json['giftRecipientName'] as String?,
      giftRecipientPhone: json['giftRecipientPhone'] as String?,
      giftNote: json['giftNote'] as String?,
      pricing: OrderPricing.fromJson(json['pricing'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$CreateOrderRequestToJson(
  CreateOrderRequest instance,
) => <String, dynamic>{
  'orderNumber': instance.orderNumber,
  'restaurant': instance.restaurant,
  'items': instance.items.map((e) => e.toJson()).toList(),
  'fulfillmentMode': instance.fulfillmentMode,
  if (instance.deliveryTimeType case final value?) 'deliveryTimeType': value,
  if (instance.scheduledForAt case final value?) 'scheduledForAt': value,
  if (instance.deliveryAddress?.toJson() case final value?)
    'deliveryAddress': value,
  if (instance.pickupContactName case final value?) 'pickupContactName': value,
  if (instance.pickupContactPhone case final value?)
    'pickupContactPhone': value,
  if (instance.acceptNoShowPolicy case final value?)
    'acceptNoShowPolicy': value,
  if (instance.noShowPolicyVersion case final value?)
    'noShowPolicyVersion': value,
  'paymentMethod': instance.paymentMethod,
  if (instance.useCredits case final value?) 'useCredits': value,
  if (instance.promoCode case final value?) 'promoCode': value,
  if (instance.notes case final value?) 'notes': value,
  if (instance.isGiftOrder case final value?) 'isGiftOrder': value,
  if (instance.giftRecipientName case final value?) 'giftRecipientName': value,
  if (instance.giftRecipientPhone case final value?)
    'giftRecipientPhone': value,
  if (instance.giftNote case final value?) 'giftNote': value,
  'pricing': instance.pricing.toJson(),
};

DeliveryAddress _$DeliveryAddressFromJson(Map<String, dynamic> json) =>
    DeliveryAddress(
      street: json['street'] as String,
      city: json['city'] as String,
      state: json['state'] as String?,
      zipCode: json['zipCode'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
    );

Map<String, dynamic> _$DeliveryAddressToJson(DeliveryAddress instance) =>
    <String, dynamic>{
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
  itemType: json['itemType'] as String,
  selectedPortionId: json['selectedPortionId'] as String?,
  selectedPreferenceOptionIds:
      (json['selectedPreferenceOptionIds'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
  itemNote: json['itemNote'] as String?,
);

Map<String, dynamic> _$OrderItemToJson(OrderItem instance) => <String, dynamic>{
  'food': instance.food,
  'quantity': instance.quantity,
  'price': instance.price,
  'itemType': instance.itemType,
  'selectedPortionId': instance.selectedPortionId,
  'selectedPreferenceOptionIds': instance.selectedPreferenceOptionIds,
  'itemNote': instance.itemNote,
};

OrderPricing _$OrderPricingFromJson(Map<String, dynamic> json) => OrderPricing(
  subtotal: (json['subtotal'] as num).toDouble(),
  deliveryFee: (json['deliveryFee'] as num).toDouble(),
  total: (json['total'] as num).toDouble(),
);

Map<String, dynamic> _$OrderPricingToJson(OrderPricing instance) =>
    <String, dynamic>{
      'subtotal': instance.subtotal,
      'deliveryFee': instance.deliveryFee,
      'total': instance.total,
    };
