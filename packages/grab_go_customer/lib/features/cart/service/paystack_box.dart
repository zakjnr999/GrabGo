import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pay_with_paystack/pay_with_paystack.dart';
import 'package:grab_go_shared/grub_go_shared.dart';

class PaystackService {
  final PayWithPayStack _paystack = PayWithPayStack();

  String get publicKey => AppConfig.paystackPublicKey;
  String get secretKey => AppConfig.paystackSecretKey;
  String get currency => AppConfig.currency;

  Future<void> makePayment({
    required BuildContext context,
    required double amount,
    required String email,
    required String method,
    required double total,
    required double subTotal,
    required double deliveryFee,
    double serviceFee = 0.0,
    double tax = 0.0,
    double tip = 0.0,
  }) async {
    final String reference = _paystack.generateUuidV4();

    _paystack.now(
      context: context,
      secretKey: secretKey,
      customerEmail: email.trim(),
      reference: reference,
      currency: currency,
      amount: amount * 100, // Convert to pesewas (kobo) - Paystack requires smallest currency unit
      callbackUrl: "https://google.com",
      transactionCompleted: (paymentData) {
        debugPrint("✅ Transaction completed: $paymentData");
        context.go(
          "/paymentComplete",
          extra: {
            "method": method,
            "total": total,
            "subTotal": subTotal,
            "deliveryFee": deliveryFee,
            "serviceFee": serviceFee,
            "tax": tax,
            "tip": tip
          },
        );
      },
      transactionNotCompleted: (reason) {
        debugPrint("Transaction failed: $reason");
        // context.pushReplacement("/paymentComplete", extra: amount);
      },
    );
  }
}
