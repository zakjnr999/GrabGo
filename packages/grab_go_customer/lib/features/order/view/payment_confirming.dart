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
  static const List<Duration> _confirmationRetryDelays = <Duration>[
    Duration.zero,
    Duration(seconds: 2),
    Duration(seconds: 3),
    Duration(seconds: 5),
    Duration(seconds: 8),
  ];
  static const List<Duration> _statusPollDelays = <Duration>[
    Duration(seconds: 2),
    Duration(seconds: 3),
    Duration(seconds: 5),
    Duration(seconds: 5),
    Duration(seconds: 8),
  ];

  bool _isConfirming = true;
  bool _showManualRetry = false;
  String _title = 'Confirming payment...';
  String _subtitle = 'Please wait a moment';

  @override
  void initState() {
    super.initState();
    _confirmPayment();
  }

  Future<void> _confirmPayment() async {
    if (mounted) {
      setState(() {
        _isConfirming = true;
        _showManualRetry = false;
        _title = 'Confirming payment...';
        _subtitle = 'Please wait a moment';
      });
    }

    if (widget.flow == 'subscription') {
      try {
        if (widget.reference.isEmpty) {
          if (!mounted) return;
          Navigator.of(context).pop(false);
          return;
        }
        final confirmation = await SubscriptionService().confirmPayment(
          widget.reference,
        );
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

    final confirmationResult = await _confirmPaymentWithRetry();
    if (!mounted) return;

    if (confirmationResult != null &&
        confirmationResult.success &&
        !confirmationResult.awaitingWebhook) {
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

    if (confirmationResult == null ||
        confirmationResult.awaitingWebhook ||
        confirmationResult.indeterminate) {
      final statusResult = await _pollPaymentStatusWithRetry();
      if (!mounted) return;

      if (statusResult?.isPaid == true) {
        final mergedPaymentData = <String, dynamic>{
          ...widget.paymentData,
          'paymentScope':
              statusResult?.paymentScope ?? widget.paymentData['paymentScope'],
          'total':
              statusResult?.externalPaymentAmount ??
              widget.paymentData['total'],
        };
        context.go('/paymentComplete', extra: mergedPaymentData);
        return;
      }

      if (statusResult?.isTerminal == true) {
        context.go('/paymentFailed', extra: widget.paymentData);
        return;
      }

      setState(() {
        _isConfirming = false;
        _showManualRetry = true;
        _title = 'Still confirming your payment';
        _subtitle =
            'Your payment may already be processing. Keep this screen open and check again.';
      });
      return;
    }

    context.go('/paymentFailed', extra: widget.paymentData);
  }

  Future<ConfirmPaymentResult?> _confirmPaymentWithRetry() async {
    final orderService = OrderServiceWrapper();
    ConfirmPaymentResult? lastResult;

    for (final delay in _confirmationRetryDelays) {
      if (delay > Duration.zero) {
        await Future.delayed(delay);
      }
      if (!mounted) return null;

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

      lastResult = confirmationResult;

      if (confirmationResult.success && !confirmationResult.awaitingWebhook) {
        return confirmationResult;
      }

      if (!confirmationResult.success && !confirmationResult.indeterminate) {
        return confirmationResult;
      }

      if (!mounted) return null;
      setState(() {
        _isConfirming = true;
        _showManualRetry = false;
        _title = confirmationResult.awaitingWebhook
            ? 'Finalizing your payment'
            : 'Still confirming your payment';
        _subtitle = confirmationResult.awaitingWebhook
            ? 'Payment was received. We are waiting for final confirmation.'
            : 'Connection was interrupted. We are safely retrying confirmation.';
      });
    }

    if (lastResult?.success == true && lastResult?.awaitingWebhook == true) {
      return null;
    }

    if (lastResult?.indeterminate == true) {
      return null;
    }

    return lastResult;
  }

  Future<PaymentStatusResult?> _pollPaymentStatusWithRetry() async {
    final orderService = OrderServiceWrapper();
    PaymentStatusResult? lastResult;

    for (final delay in _statusPollDelays) {
      await Future.delayed(delay);
      if (!mounted) return null;

      PaymentStatusResult statusResult;
      if (widget.sessionId != null && widget.sessionId!.isNotEmpty) {
        statusResult = await orderService.getCheckoutSessionPaymentStatus(
          sessionId: widget.sessionId!,
        );
      } else if (widget.orderId != null && widget.orderId!.isNotEmpty) {
        statusResult = await orderService.getOrderPaymentStatus(
          orderId: widget.orderId!,
        );
      } else {
        return null;
      }

      lastResult = statusResult;

      if (!mounted) return null;
      setState(() {
        _isConfirming = true;
        _showManualRetry = false;
        _title = statusResult.awaitingWebhook
            ? 'Finalizing your payment'
            : 'Still confirming your payment';
        _subtitle = statusResult.awaitingWebhook
            ? 'Payment was received. We are waiting for final confirmation.'
            : 'We are checking the latest payment status now.';
      });

      if (statusResult.isPaid || statusResult.isTerminal) {
        return statusResult;
      }
    }

    return lastResult;
  }

  void _retryConfirmation() {
    if (_isConfirming) return;
    _confirmPayment();
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
              ] else ...[
                Container(
                  width: 64.w,
                  height: 64.h,
                  decoration: BoxDecoration(
                    color: colors.accentOrange.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.sync_problem_rounded,
                    color: colors.accentOrange,
                    size: 30.sp,
                  ),
                ),
                SizedBox(height: 16.h),
              ],
              Text(
                _title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 6.h),
              Text(
                _subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (_showManualRetry) ...[
                SizedBox(height: 20.h),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _retryConfirmation,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.accentOrange,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: EdgeInsets.symmetric(vertical: 14.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14.r),
                      ),
                    ),
                    child: Text(
                      'Check Again',
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
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
