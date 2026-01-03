import 'package:flutter/material.dart';
import 'package:grab_go_customer/shared/services/paystack_webview_screen.dart';

class PaystackPaymentResult {
  final bool success;
  final String? reference;
  final String? message;

  PaystackPaymentResult({required this.success, this.reference, this.message});
}

class PaystackService {
  PaystackService._();
  static final PaystackService instance = PaystackService._();

  Future<PaystackPaymentResult> launchPayment({
    required BuildContext context,
    required String authorizationUrl,
    required String reference,
    String? callbackUrl,
  }) async {
    final result = await Navigator.of(context).push<PaystackPaymentResult>(
      MaterialPageRoute(
        builder: (context) => PaystackWebViewScreen(
          authorizationUrl: authorizationUrl,
          reference: reference,
          callbackUrl: callbackUrl ?? 'https://standard.paystack.co/close',
        ),
      ),
    );

    return result ?? PaystackPaymentResult(success: false, message: 'Payment was cancelled');
  }
}
