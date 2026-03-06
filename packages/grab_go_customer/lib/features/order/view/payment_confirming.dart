import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_customer/features/order/service/order_service_wrapper.dart';
import 'package:grab_go_customer/shared/services/subscription_service.dart';
import 'package:grab_go_shared/grub_go_shared.dart';

class PaymentConfirming extends StatefulWidget {
  final String? orderId;
  final String? sessionId;
  final String reference;
  final Map<String, dynamic> paymentData;
  final String flow;

  const PaymentConfirming({
    super.key,
    this.orderId,
    this.sessionId,
    required this.reference,
    required this.paymentData,
    this.flow = 'order',
  });

  @override
  State<PaymentConfirming> createState() => _PaymentConfirmingState();
}

class _PaymentConfirmingState extends State<PaymentConfirming> {
  bool _isConfirming = true;

  @override
  void initState() {
    super.initState();
    _confirmPayment();
  }

  Future<void> _confirmPayment() async {
    setState(() {
      _isConfirming = true;
    });

    if (widget.flow == 'subscription') {
      try {
        if (widget.reference.isEmpty) {
          if (!mounted) return;
          Navigator.of(context).pop(false);
          return;
        }
        final confirmation = await SubscriptionService().confirmPayment(widget.reference);
        if (!mounted) return;
        Navigator.of(context).pop(confirmation.confirmed);
        return;
      } catch (e) {
        debugPrint('⚠️ Failed to confirm subscription payment: $e');
        if (!mounted) return;
        Navigator.of(context).pop(false);
        return;
      }
    }

    final orderService = OrderServiceWrapper();
    ConfirmPaymentResult confirmationResult = const ConfirmPaymentResult(
      success: false,
    );
    try {
      if (widget.sessionId != null && widget.sessionId!.isNotEmpty) {
        confirmationResult = await orderService.confirmCheckoutSessionPayment(
          sessionId: widget.sessionId!,
          reference: widget.reference,
        );
      } else if (widget.orderId != null && widget.orderId!.isNotEmpty) {
        confirmationResult = await orderService.confirmPayment(
          orderId: widget.orderId!,
          reference: widget.reference,
        );
      }
    } catch (e) {
      debugPrint('⚠️ Failed to confirm payment: $e');
    }

    if (!mounted) return;

    if (confirmationResult.success) {
      final mergedPaymentData = <String, dynamic>{
        ...widget.paymentData,
        'paymentScope':
            confirmationResult.paymentScope ??
            widget.paymentData['paymentScope'],
        'total':
            confirmationResult.externalPaymentAmount ??
            widget.paymentData['total'],
        'codRemainingCashAmount':
            confirmationResult.codRemainingCashAmount ??
            widget.paymentData['codRemainingCashAmount'],
      };
      context.go('/paymentComplete', extra: mergedPaymentData);
      return;
    }
    context.go('/paymentFailed', extra: widget.paymentData);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Scaffold(
      backgroundColor: colors.backgroundPrimary,
      body: Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24.w),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isConfirming) ...[
                SpinKitCubeGrid(color: colors.accentOrange, size: 35),
                SizedBox(height: 16.h),
                Text(
                  'Confirming payment...',
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 6.h),
                Text(
                  'Please wait a moment',
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
