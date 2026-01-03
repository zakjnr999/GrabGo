import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:grab_go_customer/features/order/service/order_service_chopper.dart';
import 'package:grab_go_customer/features/home/model/food_category.dart';
import 'package:grab_go_customer/features/cart/model/cart_item_interface.dart';
import 'package:grab_go_customer/core/api/api_client.dart';

class OrderServiceWrapper {
  final OrderServiceChopper _orderService;

  OrderServiceWrapper() : _orderService = chopperClient.getService<OrderServiceChopper>();

  // Create a new order
  Future<String> createOrder({
    required Map<CartItem, int> cartItems,
    required String deliveryAddress,
    required String paymentMethod,
    required double subtotal,
    required double deliveryFee,
    required double total,
    String? notes,
  }) async {
    try {
      if (cartItems.isEmpty) {
        throw Exception('Cart is empty');
      }

      final restaurantIds = cartItems.keys.map((item) => item.providerId).where((id) => id.isNotEmpty).toSet();

      if (restaurantIds.isEmpty) {
        throw Exception('Unable to determine restaurant for order');
      }

      if (restaurantIds.length > 1) {
        throw Exception('Orders can only contain items from one restaurant');
      }

      final restaurantId = restaurantIds.first;

      // Convert cart items to the format expected by the backend
      final items = cartItems.entries.map((entry) {
        final foodId = entry.key.id;

        if (foodId.isEmpty) {
          throw Exception('Missing identifier for item ${entry.key.name}. Please refresh your menu data.');
        }

        return OrderItem(food: foodId, quantity: entry.value, price: entry.key.price, itemType: 'food');
      }).toList();

      final request = CreateOrderRequest(
        orderNumber: _generateOrderNumber(),
        restaurant: restaurantId,
        items: items,
        deliveryAddress: _resolveDeliveryAddress(deliveryAddress),
        paymentMethod: paymentMethod.toLowerCase().replaceAll(' ', '_'), // Convert "MTN MOMO" to "mtn_momo"
        notes: notes,
        pricing: OrderPricing(subtotal: subtotal, deliveryFee: deliveryFee, total: total),
      );

      // Debug: Print the request JSON to verify itemType is included
      debugPrint('📦 Order Request JSON: ${request.toJson()}');

      final response = await _orderService.createOrder(request);

      if (response.isSuccessful && response.body != null) {
        final responseData = response.body!;
        if (responseData['success'] == true) {
          return responseData['data']['_id']; // Return the order ID
        } else {
          throw Exception(responseData['message'] ?? 'Order creation failed');
        }
      } else {
        throw Exception('Order creation failed: ${response.error}');
      }
    } catch (e) {
      // Handle specific food not found errors
      final errorMessage = e.toString();
      if (errorMessage.contains('Food item') && errorMessage.contains('not found')) {
        throw Exception(
          'Some items in your cart are no longer available. Please refresh the menu and add items again.',
        );
      }

      throw Exception('Failed to create order: $e');
    }
  }

  // Get order details
  Future<Map<String, dynamic>> getOrder(String orderId) async {
    try {
      final response = await _orderService.getOrder(orderId);

      if (response.isSuccessful && response.body != null) {
        final responseData = response.body!;
        if (responseData['success'] == true) {
          return responseData['data'];
        } else {
          throw Exception(responseData['message'] ?? 'Failed to get order');
        }
      } else {
        throw Exception('Failed to get order: ${response.error}');
      }
    } catch (e) {
      throw Exception('Failed to get order: $e');
    }
  }

  // Get user orders
  Future<List<Map<String, dynamic>>> getUserOrders() async {
    try {
      final response = await _orderService.getUserOrders();

      if (response.isSuccessful && response.body != null) {
        final responseData = response.body!;

        if (responseData['success'] == true) {
          final orders = responseData['data'];
          if (orders is List) {
            return List<Map<String, dynamic>>.from(orders);
          } else {
            return [];
          }
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  String _generateOrderNumber() {
    final random = Random();
    final suffix = random.nextInt(9000) + 1000;
    return 'ORD-${DateTime.now().millisecondsSinceEpoch}-$suffix';
  }

  DeliveryAddress _resolveDeliveryAddress(String selectedAddress) {
    final normalized = selectedAddress.trim().toLowerCase();

    switch (normalized) {
      case 'home':
        return DeliveryAddress(
          street: 'Cocoyam Street',
          city: 'Madina - Adenta',
          state: 'Greater Accra',
          zipCode: null,
          latitude: null,
          longitude: null,
        );
      case 'office':
        return DeliveryAddress(
          street: 'Millennium City Road',
          city: 'Kasoa',
          state: 'Central Region',
          zipCode: null,
          latitude: null,
          longitude: null,
        );
      default:
        return DeliveryAddress(
          street: selectedAddress,
          city: 'Accra',
          state: 'Greater Accra',
          zipCode: null,
          latitude: null,
          longitude: null,
        );
    }
  }
}
