import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:grab_go_customer/features/cart/service/payment_service.dart';
import 'package:grab_go_customer/core/api/api_client.dart';

class MtnMomoServiceChopper {
  final PaymentService _paymentService;

  MtnMomoServiceChopper() : _paymentService = chopperClient.getService<PaymentService>();

  // Initialize MTN MOMO payment
  Future<MtnMomoInitiateResponse> initiateMtnMomoPayment({
    required String orderId,
    required String phoneNumber,
  }) async {
    try {
      final request = MtnMomoInitiateRequest(
        orderId: orderId,
        phoneNumber: phoneNumber,
      );

      final response = await _paymentService.initiateMtnMomoPayment(request);

      if (response.isSuccessful && response.body != null) {
        final responseData = response.body!;
        if (responseData['success'] == true) {
          return MtnMomoInitiateResponse.fromJson(responseData['data']);
        } else {
          throw Exception(responseData['message'] ?? 'Payment initiation failed');
        }
      } else {
        throw Exception('Payment initiation failed: ${response.error}');
      }
    } catch (e) {
      debugPrint('MTN MOMO initiation error: $e');
      throw Exception('Failed to initiate payment: $e');
    }
  }

  // Check payment status
  Future<MtnMomoStatusResponse> checkPaymentStatus(String paymentId) async {
    try {
      final response = await _paymentService.checkPaymentStatus(paymentId);

      if (response.isSuccessful && response.body != null) {
        final responseData = response.body!;
        if (responseData['success'] == true) {
          return MtnMomoStatusResponse.fromJson(responseData['data']);
        } else {
          throw Exception(responseData['message'] ?? 'Status check failed');
        }
      } else {
        throw Exception('Status check failed: ${response.error}');
      }
    } catch (e) {
      debugPrint('MTN MOMO status check error: $e');
      throw Exception('Failed to check payment status: $e');
    }
  }

  // Cancel payment
  Future<bool> cancelPayment(String paymentId) async {
    try {
      final response = await _paymentService.cancelPayment(paymentId);

      if (response.isSuccessful && response.body != null) {
        final responseData = response.body!;
        return responseData['success'] == true;
      }
      return false;
    } catch (e) {
      debugPrint('MTN MOMO cancellation error: $e');
      return false;
    }
  }

  // Get user payments
  Future<List<Map<String, dynamic>>> getUserPayments({
    int page = 1,
    int limit = 10,
  }) async {
    try {
      final response = await _paymentService.getUserPayments(page, limit);

      if (response.isSuccessful && response.body != null) {
        final responseData = response.body!;
        if (responseData['success'] == true) {
          return List<Map<String, dynamic>>.from(responseData['data']);
        }
      }
      return [];
    } catch (e) {
      debugPrint('Get payments error: $e');
      return [];
    }
  }
}