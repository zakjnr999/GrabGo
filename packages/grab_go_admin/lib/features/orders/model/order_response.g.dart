// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'order_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

OrderResponse _$OrderResponseFromJson(Map<String, dynamic> json) =>
    OrderResponse(
      success: json['success'] as bool,
      message: json['message'] as String,
      data: (json['data'] as List<dynamic>)
          .map((e) => OrderData.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$OrderResponseToJson(OrderResponse instance) =>
    <String, dynamic>{
      'success': instance.success,
      'message': instance.message,
      'data': instance.data,
    };

OrderData _$OrderDataFromJson(Map<String, dynamic> json) => OrderData(
      id: json['_id'] as String,
      orderNumber: json['orderNumber'] as String,
      customer: CustomerInfo.fromJson(json['customer'] as Map<String, dynamic>),
      restaurant:
          RestaurantInfo.fromJson(json['restaurant'] as Map<String, dynamic>),
      rider: json['rider'] == null
          ? null
          : RiderInfo.fromJson(json['rider'] as Map<String, dynamic>),
      items: (json['items'] as List<dynamic>)
          .map((e) => OrderItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      subtotal: (json['subtotal'] as num).toDouble(),
      deliveryFee: (json['deliveryFee'] as num).toDouble(),
      tax: (json['tax'] as num).toDouble(),
      totalAmount: (json['totalAmount'] as num).toDouble(),
      deliveryAddress: DeliveryAddress.fromJson(
          json['deliveryAddress'] as Map<String, dynamic>),
      paymentMethod: json['paymentMethod'] as String,
      paymentProvider: json['paymentProvider'] as String?,
      paymentReferenceId: json['paymentReferenceId'] as String?,
      paymentStatus: json['paymentStatus'] as String,
      status: json['status'] as String,
      expectedDelivery: json['expectedDelivery'] as String?,
      deliveredDate: json['deliveredDate'] as String?,
      cancelledDate: json['cancelledDate'] as String?,
      cancellationReason: json['cancellationReason'] as String?,
      notes: json['notes'] as String?,
      orderDate: json['orderDate'] as String,
      createdAt: json['createdAt'] as String,
      updatedAt: json['updatedAt'] as String,
    );

Map<String, dynamic> _$OrderDataToJson(OrderData instance) => <String, dynamic>{
      '_id': instance.id,
      'orderNumber': instance.orderNumber,
      'customer': instance.customer,
      'restaurant': instance.restaurant,
      'rider': instance.rider,
      'items': instance.items,
      'subtotal': instance.subtotal,
      'deliveryFee': instance.deliveryFee,
      'tax': instance.tax,
      'totalAmount': instance.totalAmount,
      'deliveryAddress': instance.deliveryAddress,
      'paymentMethod': instance.paymentMethod,
      'paymentProvider': instance.paymentProvider,
      'paymentReferenceId': instance.paymentReferenceId,
      'paymentStatus': instance.paymentStatus,
      'status': instance.status,
      'expectedDelivery': instance.expectedDelivery,
      'deliveredDate': instance.deliveredDate,
      'cancelledDate': instance.cancelledDate,
      'cancellationReason': instance.cancellationReason,
      'notes': instance.notes,
      'orderDate': instance.orderDate,
      'createdAt': instance.createdAt,
      'updatedAt': instance.updatedAt,
    };

CustomerInfo _$CustomerInfoFromJson(Map<String, dynamic> json) => CustomerInfo(
      id: json['_id'] as String,
      username: json['username'] as String,
      email: json['email'] as String,
      phone: json['phone'] as String?,
    );

Map<String, dynamic> _$CustomerInfoToJson(CustomerInfo instance) =>
    <String, dynamic>{
      '_id': instance.id,
      'username': instance.username,
      'email': instance.email,
      'phone': instance.phone,
    };

RestaurantInfo _$RestaurantInfoFromJson(Map<String, dynamic> json) =>
    RestaurantInfo(
      id: json['_id'] as String,
      restaurantName: json['restaurant_name'] as String,
      logo: json['logo'] as String?,
    );

Map<String, dynamic> _$RestaurantInfoToJson(RestaurantInfo instance) =>
    <String, dynamic>{
      '_id': instance.id,
      'restaurant_name': instance.restaurantName,
      'logo': instance.logo,
    };

RiderInfo _$RiderInfoFromJson(Map<String, dynamic> json) => RiderInfo(
      id: json['_id'] as String,
      username: json['username'] as String,
      email: json['email'] as String,
      phone: json['phone'] as String?,
    );

Map<String, dynamic> _$RiderInfoToJson(RiderInfo instance) => <String, dynamic>{
      '_id': instance.id,
      'username': instance.username,
      'email': instance.email,
      'phone': instance.phone,
    };

OrderItem _$OrderItemFromJson(Map<String, dynamic> json) => OrderItem(
      food: FoodInfo.fromJson(json['food'] as Map<String, dynamic>),
      name: json['name'] as String,
      quantity: json['quantity'] as int,
      price: (json['price'] as num).toDouble(),
      image: json['image'] as String?,
    );

Map<String, dynamic> _$OrderItemToJson(OrderItem instance) => <String, dynamic>{
      'food': instance.food,
      'name': instance.name,
      'quantity': instance.quantity,
      'price': instance.price,
      'image': instance.image,
    };

FoodInfo _$FoodInfoFromJson(Map<String, dynamic> json) => FoodInfo(
      id: json['_id'] as String,
      name: json['name'] as String,
      price: (json['price'] as num).toDouble(),
      image: json['image'] as String?,
    );

Map<String, dynamic> _$FoodInfoToJson(FoodInfo instance) => <String, dynamic>{
      '_id': instance.id,
      'name': instance.name,
      'price': instance.price,
      'image': instance.image,
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