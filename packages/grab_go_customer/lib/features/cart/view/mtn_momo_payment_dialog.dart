import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:grab_go_customer/features/cart/service/mtn_momo_service_chopper.dart';

class MtnMomoPaymentDialog extends StatefulWidget {
  final String orderId;
  final double totalAmount;
  final String phoneNumber;
  final VoidCallback onPaymentSuccess;
  final VoidCallback onPaymentFailed;

  const MtnMomoPaymentDialog({
    super.key,
    required this.orderId,
    required this.totalAmount,
    required this.phoneNumber,
    required this.onPaymentSuccess,
    required this.onPaymentFailed,
  });

  @override
  State<MtnMomoPaymentDialog> createState() => _MtnMomoPaymentDialogState();
}

class _MtnMomoPaymentDialogState extends State<MtnMomoPaymentDialog>
    with TickerProviderStateMixin {
  final MtnMomoServiceChopper _mtnMomoService = MtnMomoServiceChopper();
  
  late AnimationController _pulseController;
  late AnimationController _progressController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _progressAnimation;
  
  Timer? _statusTimer;
  Timer? _timeoutTimer;
  
  PaymentStatus _status = PaymentStatus.initiating;
  String? _paymentId;
  int _remainingSeconds = 300; // 5 minutes timeout
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
    
    _progressController = AnimationController(
      duration: const Duration(minutes: 5),
      vsync: this,
    );
    
    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    
    _progressAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(_progressController);
    
    _initializePayment();
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    _timeoutTimer?.cancel();
    _pulseController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  void _initializePayment() async {
    try {
      setState(() {
        _status = PaymentStatus.initiating;
      });

      final response = await _mtnMomoService.initiateMtnMomoPayment(
        orderId: widget.orderId,
        phoneNumber: widget.phoneNumber,
      );

      _paymentId = response.paymentId;
      
      setState(() {
        _status = PaymentStatus.waitingForPin;
      });

      _startProgressTimer();
      _startStatusPolling();
      
    } catch (e) {
      setState(() {
        _status = PaymentStatus.failed;
        _errorMessage = e.toString();
      });
    }
  }

  void _startProgressTimer() {
    _progressController.forward();
    
    _timeoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _remainingSeconds--;
        });
        
        if (_remainingSeconds <= 0) {
          timer.cancel();
          _handleTimeout();
        }
      }
    });
  }

  void _startStatusPolling() {
    _statusTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      if (_paymentId == null) return;
      
      try {
        final statusResponse = await _mtnMomoService.checkPaymentStatus(_paymentId!);
        
        if (statusResponse.isCompleted) {
          timer.cancel();
          _timeoutTimer?.cancel();
          
          setState(() {
            if (statusResponse.isSuccessful) {
              _status = PaymentStatus.successful;
            } else {
              _status = PaymentStatus.failed;
              _errorMessage = statusResponse.errorMessage ?? 'Payment failed';
            }
          });
          
          // Auto close after 2 seconds
          Timer(const Duration(seconds: 2), () {
            if (mounted) {
              if (statusResponse.isSuccessful) {
                widget.onPaymentSuccess();
              } else {
                widget.onPaymentFailed();
              }
              Navigator.of(context).pop();
            }
          });
        }
      } catch (e) {
        // Continue polling on error
        debugPrint('Status check error: $e');
      }
    });
  }

  void _handleTimeout() {
    setState(() {
      _status = PaymentStatus.expired;
    });
    
    _statusTimer?.cancel();
    
    // Auto close after 2 seconds
    Timer(const Duration(seconds: 2), () {
      if (mounted) {
        widget.onPaymentFailed();
        Navigator.of(context).pop();
      }
    });
  }

  void _cancelPayment() async {
    if (_paymentId != null) {
      await _mtnMomoService.cancelPayment(_paymentId!);
    }
    
    _statusTimer?.cancel();
    _timeoutTimer?.cancel();
    
    widget.onPaymentFailed();
    Navigator.of(context).pop();
  }

  String get _formattedTime {
    final minutes = _remainingSeconds ~/ 60;
    final seconds = _remainingSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) {
          _cancelPayment();
        }
      },
      child: Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.all(24.r),
          decoration: BoxDecoration(
            color: colors.backgroundPrimary,
            borderRadius: BorderRadius.circular(20.r),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                spreadRadius: 0,
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8.r),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFD700).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Image.asset(
                      Assets.icons.mom.path,
                      package: 'grab_go_shared',
                      height: 24.h,
                      width: 24.w,
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'MTN Mobile Money',
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w700,
                            color: colors.textPrimary,
                          ),
                        ),
                        Text(
                          widget.phoneNumber,
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_status != PaymentStatus.successful && 
                      _status != PaymentStatus.failed &&
                      _status != PaymentStatus.expired)
                    IconButton(
                      onPressed: _cancelPayment,
                      icon: SvgPicture.asset(
                        Assets.icons.x,
                        package: 'grab_go_shared',
                        colorFilter: ColorFilter.mode(
                          colors.textSecondary,
                          BlendMode.srcIn,
                        ),
                      ),
                    ),
                ],
              ),
              
              SizedBox(height: 32.h),
              
              // Status Icon and Animation
              _buildStatusIcon(colors),
              
              SizedBox(height: 24.h),
              
              // Status Text
              Text(
                _getStatusTitle(),
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              
              SizedBox(height: 8.h),
              
              Text(
                _getStatusMessage(),
                style: TextStyle(
                  fontSize: 14.sp,
                  color: colors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              
              if (_status == PaymentStatus.waitingForPin) ...[
                SizedBox(height: 24.h),
                
                // Progress bar
                Container(
                  height: 6.h,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: colors.backgroundSecondary,
                    borderRadius: BorderRadius.circular(3.r),
                  ),
                  child: AnimatedBuilder(
                    animation: _progressAnimation,
                    builder: (context, child) {
                      return FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: _progressAnimation.value,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFFFFD700),
                                const Color(0xFFFFD700).withOpacity(0.8),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(3.r),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                
                SizedBox(height: 12.h),
                
                Text(
                  'Time remaining: $_formattedTime',
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: colors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
              
              if (_status == PaymentStatus.failed || _status == PaymentStatus.expired) ...[
                SizedBox(height: 16.h),
                
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(12.r),
                  decoration: BoxDecoration(
                    color: colors.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8.r),
                    border: Border.all(
                      color: colors.error.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    _errorMessage ?? 'Payment failed. Please try again.',
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: colors.error,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
              
              SizedBox(height: 24.h),
              
              // Amount
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(16.r),
                decoration: BoxDecoration(
                  color: colors.backgroundSecondary,
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(
                    color: colors.inputBorder.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Amount to Pay',
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: colors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      'GHS ${widget.totalAmount.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 18.sp,
                        color: const Color(0xFFFFD700),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusIcon(AppColorsExtension colors) {
    switch (_status) {
      case PaymentStatus.initiating:
        return Container(
          height: 80.h,
          width: 80.w,
          decoration: BoxDecoration(
            color: colors.backgroundSecondary,
            shape: BoxShape.circle,
          ),
          child: const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFFD700)),
            ),
          ),
        );
        
      case PaymentStatus.waitingForPin:
        return AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _pulseAnimation.value,
              child: Container(
                height: 80.h,
                width: 80.w,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD700).withOpacity(0.1),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFFFFD700),
                    width: 2,
                  ),
                ),
                child: Center(
                  child: SvgPicture.asset(
                    Assets.icons.phone,
                    package: 'grab_go_shared',
                    height: 32.h,
                    width: 32.w,
                    colorFilter: const ColorFilter.mode(
                      Color(0xFFFFD700),
                      BlendMode.srcIn,
                    ),
                  ),
                ),
              ),
            );
          },
        );
        
      case PaymentStatus.successful:
        return Container(
          height: 80.h,
          width: 80.w,
          decoration: BoxDecoration(
            color: colors.accentGreen.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: SvgPicture.asset(
              Assets.icons.checkBig,
              package: 'grab_go_shared',
              height: 40.h,
              width: 40.w,
              colorFilter: ColorFilter.mode(
                colors.accentGreen,
                BlendMode.srcIn,
              ),
            ),
          ),
        );
        
      case PaymentStatus.failed:
      case PaymentStatus.expired:
        return Container(
          height: 80.h,
          width: 80.w,
          decoration: BoxDecoration(
            color: colors.error.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: SvgPicture.asset(
              Assets.icons.x,
              package: 'grab_go_shared',
              height: 32.h,
              width: 32.w,
              colorFilter: ColorFilter.mode(
                colors.error,
                BlendMode.srcIn,
              ),
            ),
          ),
        );
    }
  }

  String _getStatusTitle() {
    switch (_status) {
      case PaymentStatus.initiating:
        return 'Initiating Payment...';
      case PaymentStatus.waitingForPin:
        return 'Enter Your MOMO PIN';
      case PaymentStatus.successful:
        return 'Payment Successful!';
      case PaymentStatus.failed:
        return 'Payment Failed';
      case PaymentStatus.expired:
        return 'Payment Expired';
    }
  }

  String _getStatusMessage() {
    switch (_status) {
      case PaymentStatus.initiating:
        return 'Please wait while we process your payment request...';
      case PaymentStatus.waitingForPin:
        return 'Check your phone for the USSD prompt\nand enter your MTN MOMO PIN to complete the payment.';
      case PaymentStatus.successful:
        return 'Your payment has been processed successfully.\nYou will receive a confirmation message shortly.';
      case PaymentStatus.failed:
        return 'Your payment could not be processed.\nPlease check your balance and try again.';
      case PaymentStatus.expired:
        return 'Payment session has expired.\nPlease try again.';
    }
  }
}

enum PaymentStatus {
  initiating,
  waitingForPin,
  successful,
  failed,
  expired,
}