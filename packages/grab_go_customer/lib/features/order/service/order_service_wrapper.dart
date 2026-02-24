import 'dart:convert';
import 'dart:math';

import 'package:chopper/chopper.dart';
import 'package:flutter/foundation.dart';
import 'package:grab_go_customer/features/order/service/order_service_chopper.dart';
import 'package:grab_go_customer/features/cart/model/cart_item_interface.dart';
import 'package:grab_go_customer/core/api/api_client.dart';

class CreateOrderResult {
  final String orderId;
  final String? orderNumber;
  final String? giftDeliveryCode;
  final String? paymentMethod;
  final double? codUpfrontAmount;
  final double? codRemainingCashOnDelivery;

  const CreateOrderResult({
    required this.orderId,
    this.orderNumber,
    this.giftDeliveryCode,
    this.paymentMethod,
    this.codUpfrontAmount,
    this.codRemainingCashOnDelivery,
  });
}

class DeliveryCodeResendResult {
  final bool success;
  final String message;
  final String? giftDeliveryCode;
  final int? retryAfterSeconds;
  final String? code;

  const DeliveryCodeResendResult({
    required this.success,
    required this.message,
    this.giftDeliveryCode,
    this.retryAfterSeconds,
    this.code,
  });
}

class ConfirmPaymentResult {
  final bool success;
  final String? paymentScope;
  final double? externalPaymentAmount;
  final double? codRemainingCashAmount;

  const ConfirmPaymentResult({
    required this.success,
    this.paymentScope,
    this.externalPaymentAmount,
    this.codRemainingCashAmount,
  });
}

class InitializePaymentResult {
  final String authorizationUrl;
  final String reference;
  final double? paymentAmount;
  final String? paymentScope;
  final double? codRemainingCashAmount;

  const InitializePaymentResult({
    required this.authorizationUrl,
    required this.reference,
    this.paymentAmount,
    this.paymentScope,
    this.codRemainingCashAmount,
  });
}

class CodEligibilityResult {
  final bool eligible;
  final String code;
  final String message;
  final int? deliveredPrepaidOrders;
  final int? minPrepaidDeliveredOrders;
  final int? confirmedNoShows;
  final int? noShowDisableThreshold;
  final int? activeCodOrders;
  final int? maxConcurrentCodOrders;

  const CodEligibilityResult({
    required this.eligible,
    required this.code,
    required this.message,
    this.deliveredPrepaidOrders,
    this.minPrepaidDeliveredOrders,
    this.confirmedNoShows,
    this.noShowDisableThreshold,
    this.activeCodOrders,
    this.maxConcurrentCodOrders,
  });
}

class OrderServiceWrapper {
  final OrderServiceChopper _orderService;

  OrderServiceWrapper()
    : _orderService = chopperClient.getService<OrderServiceChopper>();

  // Create a new order
  Future<CreateOrderResult> createOrder({
    required Map<CartItem, int> cartItems,
    required String fulfillmentMode,
    String? deliveryTimeType,
    String? scheduledForAt,
    String? deliveryAddress,
    double? deliveryLatitude,
    double? deliveryLongitude,
    String? pickupContactName,
    String? pickupContactPhone,
    bool? acceptNoShowPolicy,
    String? noShowPolicyVersion,
    required String paymentMethod,
    required double subtotal,
    required double deliveryFee,
    required double total,
    bool? useCredits,
    String? notes,
    bool? isGiftOrder,
    String? giftRecipientName,
    String? giftRecipientPhone,
    String? giftNote,
  }) async {
    try {
      if (cartItems.isEmpty) {
        throw Exception('Cart is empty');
      }

      final restaurantIds = cartItems.keys
          .map((item) => item.providerId)
          .where((id) => id.isNotEmpty)
          .toSet();

      if (restaurantIds.isEmpty) {
        throw Exception('Unable to determine restaurant for order');
      }

      if (restaurantIds.length > 1) {
        throw Exception('Orders can only contain items from one restaurant');
      }

      final restaurantId = restaurantIds.first;

      // Convert cart items to the format expected by the backend
      final items = cartItems.entries.map((entry) {
        final itemId = entry.key.id;
        final itemType = _normalizeOrderItemType(entry.key.itemType);

        if (itemId.isEmpty) {
          throw Exception(
            'Missing identifier for item ${entry.key.name}. Please refresh your menu data.',
          );
        }

        return OrderItem(
          food: itemId,
          quantity: entry.value,
          price: entry.key.price,
          itemType: itemType,
        );
      }).toList();

      final request = CreateOrderRequest(
        orderNumber: _generateOrderNumber(),
        restaurant: restaurantId,
        items: items,
        fulfillmentMode: fulfillmentMode,
        deliveryTimeType: deliveryTimeType,
        scheduledForAt: scheduledForAt,
        deliveryAddress: fulfillmentMode == 'pickup'
            ? null
            : _resolveDeliveryAddress(
                deliveryAddress ?? '',
                latitude: deliveryLatitude,
                longitude: deliveryLongitude,
              ),
        pickupContactName: pickupContactName,
        pickupContactPhone: pickupContactPhone,
        acceptNoShowPolicy: acceptNoShowPolicy,
        noShowPolicyVersion: noShowPolicyVersion,
        paymentMethod: paymentMethod.toLowerCase().replaceAll(' ', '_'),
        useCredits: useCredits,
        notes: notes,
        isGiftOrder: isGiftOrder,
        giftRecipientName: giftRecipientName,
        giftRecipientPhone: giftRecipientPhone,
        giftNote: giftNote,
        pricing: OrderPricing(
          subtotal: subtotal,
          deliveryFee: deliveryFee,
          total: total,
        ),
      );

      // Debug: Print the request JSON to verify itemType is included
      debugPrint('📦 Order Request JSON: ${request.toJson()}');

      final response = await _orderService.createOrder(request);

      if (response.isSuccessful && response.body != null) {
        final responseData = response.body!;
        if (responseData['success'] == true) {
          final orderData = responseData['data'] as Map<String, dynamic>?;
          final orderId = orderData?['id'] ?? orderData?['_id'];
          if (orderId == null) {
            throw Exception('Order created but no id returned');
          }
          return CreateOrderResult(
            orderId: orderId.toString(),
            orderNumber: orderData?['orderNumber']?.toString(),
            giftDeliveryCode: orderData?['giftDeliveryCode']?.toString(),
            paymentMethod: orderData?['paymentMethod']?.toString(),
            codUpfrontAmount: _asDouble(orderData?['cod']?['upfrontAmount']),
            codRemainingCashOnDelivery: _asDouble(
              orderData?['cod']?['remainingCashOnDelivery'],
            ),
          );
        } else {
          throw Exception(responseData['message'] ?? 'Order creation failed');
        }
      } else {
        throw Exception('Order creation failed: ${response.error}');
      }
    } catch (e) {
      // Handle specific food not found errors
      final errorMessage = e.toString();
      if (errorMessage.contains('Food item') &&
          errorMessage.contains('not found')) {
        throw Exception(
          'Some items in your cart are no longer available. Please refresh the menu and add items again.',
        );
      }

      throw Exception('Failed to create order: $e');
    }
  }

  Future<DeliveryCodeResendResult> resendDeliveryCode({
    required String orderId,
    required String target,
  }) async {
    try {
      final response = await _orderService.resendDeliveryCode(orderId, {
        'target': target,
      });
      final body = response.body;

      if (response.isSuccessful && body != null && body['success'] == true) {
        final data = body['data'] as Map<String, dynamic>?;
        return DeliveryCodeResendResult(
          success: true,
          message: body['message']?.toString() ?? 'Delivery code resent',
          giftDeliveryCode: data?['giftDeliveryCode']?.toString(),
        );
      }

      return DeliveryCodeResendResult(
        success: false,
        message:
            body?['message']?.toString() ?? 'Failed to resend delivery code',
        retryAfterSeconds: body?['retryAfterSeconds'] is num
            ? (body?['retryAfterSeconds'] as num).toInt()
            : null,
        code: body?['code']?.toString(),
      );
    } catch (e) {
      return DeliveryCodeResendResult(
        success: false,
        message: 'Failed to resend delivery code: $e',
      );
    }
  }

  Future<ConfirmPaymentResult> confirmPayment({
    required String orderId,
    required String reference,
    String provider = 'paystack',
  }) async {
    try {
      final response = await _orderService.confirmPayment(orderId, {
        'reference': reference,
        'provider': provider,
      });

      if (!response.isSuccessful || response.body == null) {
        return const ConfirmPaymentResult(success: false);
      }

      final body = response.body!;
      final isSuccess = body['success'] == true;
      final data = body['data'] as Map<String, dynamic>?;

      return ConfirmPaymentResult(
        success: isSuccess,
        paymentScope: data?['paymentScope']?.toString(),
        externalPaymentAmount: _asDouble(data?['externalPaymentAmount']),
        codRemainingCashAmount: _asDouble(data?['codRemainingCashAmount']),
      );
    } catch (e) {
      return const ConfirmPaymentResult(success: false);
    }
  }

  Future<void> releaseCreditHold({required String orderId}) async {
    try {
      final response = await _orderService.releaseCreditHold(orderId);
      if (!response.isSuccessful ||
          response.body == null ||
          response.body!['success'] != true) {
        throw Exception(
          response.body?['message'] ?? 'Release credit hold failed',
        );
      }
    } catch (e) {
      throw Exception('Release credit hold failed: $e');
    }
  }

  Future<InitializePaymentResult> initializePaystackPayment({
    required String orderId,
  }) async {
    try {
      final response = await _orderService.initializePaystack(orderId);
      if (!response.isSuccessful ||
          response.body == null ||
          response.body!['success'] != true) {
        throw Exception(
          response.body?['message'] ?? 'Payment initialization failed',
        );
      }

      final data = response.body?['data'] as Map<String, dynamic>? ?? {};
      final authorizationUrl = data['authorizationUrl']?.toString();
      final reference = data['reference']?.toString();

      if (authorizationUrl == null || reference == null) {
        throw Exception('Payment initialization missing authorization URL');
      }

      return InitializePaymentResult(
        authorizationUrl: authorizationUrl,
        reference: reference,
        paymentAmount: _asDouble(data['paymentAmount']),
        paymentScope: data['paymentScope']?.toString(),
        codRemainingCashAmount: _asDouble(data['codRemainingCashAmount']),
      );
    } catch (e) {
      throw Exception('Payment initialization failed: $e');
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

  Future<CodEligibilityResult> getCodEligibility() async {
    try {
      final response = await _orderService.getCodEligibility();
      final body = _resolveResponseMap(response);

      if (body == null) {
        return const CodEligibilityResult(
          eligible: false,
          code: 'COD_CHECK_FAILED',
          message: 'Unable to check cash on delivery eligibility right now.',
        );
      }

      final data = body['data'] as Map<String, dynamic>?;
      final isSuccess = body['success'] == true;
      final code =
          body['code']?.toString() ??
          (isSuccess ? 'COD_ELIGIBLE' : 'COD_UNAVAILABLE');
      final message =
          body['message']?.toString() ?? 'Cash on delivery is unavailable.';

      return CodEligibilityResult(
        eligible: isSuccess && code == 'COD_ELIGIBLE',
        code: code,
        message: message,
        deliveredPrepaidOrders: _asInt(data?['deliveredPrepaidOrders']),
        minPrepaidDeliveredOrders: _asInt(data?['minPrepaidDeliveredOrders']),
        confirmedNoShows: _asInt(data?['confirmedNoShows']),
        noShowDisableThreshold: _asInt(data?['noShowDisableThreshold']),
        activeCodOrders: _asInt(data?['activeCodOrders']),
        maxConcurrentCodOrders: _asInt(data?['maxConcurrentCodOrders']),
      );
    } catch (_) {
      return const CodEligibilityResult(
        eligible: false,
        code: 'COD_CHECK_FAILED',
        message: 'Unable to check cash on delivery eligibility right now.',
      );
    }
  }

  Map<String, dynamic>? _resolveResponseMap(
    Response<Map<String, dynamic>> response,
  ) {
    if (response.body != null) return response.body;

    final dynamic errorPayload = response.error;
    if (errorPayload is Map<String, dynamic>) return errorPayload;
    if (errorPayload is Map) return Map<String, dynamic>.from(errorPayload);
    if (errorPayload is String && errorPayload.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(errorPayload);
        if (decoded is Map<String, dynamic>) return decoded;
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  String _generateOrderNumber() {
    final random = Random();
    final suffix = random.nextInt(9000) + 1000;
    return 'ORD-${DateTime.now().millisecondsSinceEpoch}-$suffix';
  }

  DeliveryAddress _resolveDeliveryAddress(
    String selectedAddress, {
    double? latitude,
    double? longitude,
  }) {
    final normalized = selectedAddress.trim().toLowerCase();

    switch (normalized) {
      case 'home':
        return DeliveryAddress(
          street: 'Cocoyam Street',
          city: 'Madina - Adenta',
          state: 'Greater Accra',
          zipCode: null,
          latitude: latitude,
          longitude: longitude,
        );
      case 'office':
        return DeliveryAddress(
          street: 'Millennium City Road',
          city: 'Kasoa',
          state: 'Central Region',
          zipCode: null,
          latitude: latitude,
          longitude: longitude,
        );
      default:
        return DeliveryAddress(
          street: selectedAddress,
          city: 'Accra',
          state: 'Greater Accra',
          zipCode: null,
          latitude: latitude,
          longitude: longitude,
        );
    }
  }

  double? _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  String _normalizeOrderItemType(String itemType) {
    switch (itemType) {
      case 'Food':
        return 'food';
      case 'GroceryItem':
        return 'groceryitem';
      case 'PharmacyItem':
        return 'pharmacyitem';
      case 'GrabMartItem':
        return 'grabmartitem';
      default:
        return itemType.toLowerCase();
    }
  }
}
