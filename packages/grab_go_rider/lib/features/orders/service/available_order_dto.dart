import 'package:flutter/material.dart';

class AvailableOrderDto {
  final String id;
  final String orderNumber;
  final String customerName;
  final String customerId;
  final String customerAddress;
  final String customerArea;
  final String customerPhone;
  final String? customerPhoto;
  final String restaurantName;
  final String restaurantAddress;
  final String? restaurantLogo;
  final double totalAmount;
  final List<String> orderItems;
  final String? notes;
  final String orderStatus;
  final String paymentMethod;
  final String? orderType;
  final int itemCount;
  final DateTime? createdAt;
  final double? distance;
  final double? riderEarnings;
  final double? distanceToPickup;
  final double? destinationLatitude;
  final double? destinationLongitude;
  final double? pickupLatitude;
  final double? pickupLongitude;

  AvailableOrderDto({
    required this.id,
    required this.orderNumber,
    required this.customerName,
    required this.customerId,
    required this.customerAddress,
    required this.customerArea,
    required this.customerPhone,
    this.customerPhoto,
    required this.restaurantName,
    required this.restaurantAddress,
    required this.totalAmount,
    required this.orderItems,
    required this.notes,
    required this.orderStatus,
    required this.paymentMethod,
    this.orderType,
    required this.itemCount,
    this.createdAt,
    this.distance,
    this.riderEarnings,
    this.distanceToPickup,
    this.destinationLatitude,
    this.destinationLongitude,
    this.pickupLatitude,
    this.pickupLongitude,
    this.restaurantLogo,
  });

  factory AvailableOrderDto.fromJson(Map<String, dynamic> json) {
    final customer = json['customer'] as Map<String, dynamic>?;
    final restaurant = json['restaurant'] as Map<String, dynamic>?;
    final groceryStore = json['groceryStore'] as Map<String, dynamic>?;
    final pharmacyStore = json['pharmacyStore'] as Map<String, dynamic>?;
    final street = json['deliveryStreet']?.toString();
    final city = json['deliveryCity']?.toString();
    final state = json['deliveryState']?.toString();

    final addressParts = <String>[
      if (street != null && street.isNotEmpty) street,
      if (city != null && city.isNotEmpty) city,
      if (state != null && state.isNotEmpty) state,
    ];

    final customerAddress = addressParts.isNotEmpty ? addressParts.join(', ') : '';
    final destinationLat = (json['deliveryLatitude'] as num?)?.toDouble();
    final destinationLng = (json['deliveryLongitude'] as num?)?.toDouble();

    double? pickupLat;
    double? pickupLng;

    if (restaurant != null) {
      pickupLat = (restaurant['latitude'] as num?)?.toDouble();
      pickupLng = (restaurant['longitude'] as num?)?.toDouble();
    } else if (groceryStore != null) {
      pickupLat = (groceryStore['latitude'] as num?)?.toDouble();
      pickupLng = (groceryStore['longitude'] as num?)?.toDouble();
    } else if (pharmacyStore != null) {
      pickupLat = (pharmacyStore['latitude'] as num?)?.toDouble();
      pickupLng = (pharmacyStore['longitude'] as num?)?.toDouble();
    }

    final items = (json['items'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map((item) {
          final name = item['name']?.toString() ?? '';
          final quantity = (item['quantity'] as num?)?.toInt() ?? 0;
          if (name.isEmpty) return null;
          return quantity > 0 ? '$name x$quantity' : name;
        })
        .whereType<String>()
        .toList();

    final customerArea = street?.isNotEmpty == true ? street! : (city ?? state ?? 'Unknown Area');
    DateTime? createdAt;
    if (json['createdAt'] != null) {
      try {
        createdAt = DateTime.parse(json['createdAt'].toString());
      } catch (e) {
        debugPrint('Failed to parse createdAt: $e');
      }
    }

    String storeName = 'Store';
    if (restaurant != null) {
      storeName = restaurant['restaurantName']?.toString() ?? 'Restaurant';
    } else if (groceryStore != null) {
      storeName = groceryStore['storeName']?.toString() ?? 'Grocery Store';
    } else if (pharmacyStore != null) {
      storeName = pharmacyStore['storeName']?.toString() ?? 'Pharmacy';
    }

    return AvailableOrderDto(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      orderNumber: json['orderNumber']?.toString() ?? '',
      customerName: customer != null ? (customer['username']?.toString() ?? 'Customer') : 'Customer',
      customerId: customer != null ? (customer['id']?.toString() ?? customer['_id']?.toString() ?? '') : '',
      customerAddress: customerAddress,
      customerArea: customerArea,
      customerPhone: customer != null ? (customer['phone']?.toString() ?? '') : '',
      customerPhoto: customer != null ? (customer['profilePicture']?.toString()) : null,
      restaurantName: storeName,
      restaurantLogo: restaurant != null ? (restaurant['logo']?.toString()) : null,
      restaurantAddress:
          restaurant?['address']?.toString() ??
          groceryStore?['address']?.toString() ??
          pharmacyStore?['address']?.toString() ??
          '',
      totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0.0,
      orderItems: items,
      itemCount: items.length,
      notes: json['notes']?.toString(),
      orderStatus: json['status']?.toString() ?? 'confirmed',
      paymentMethod: json['paymentMethod']?.toString() ?? 'cash',
      orderType: json['orderType']?.toString() ?? json['type']?.toString(),
      createdAt: createdAt,
      distance: (json['distance'] as num?)?.toDouble(),
      riderEarnings: (json['riderEarnings'] as num?)?.toDouble(),
      distanceToPickup: (json['distanceToPickup'] as num?)?.toDouble(),
      destinationLatitude: destinationLat,
      destinationLongitude: destinationLng,
      pickupLatitude: pickupLat,
      pickupLongitude: pickupLng,
    );
  }
}
