// ignore_for_file: deprecated_member_use

import 'package:dotted_line/dotted_line.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_customer/features/cart/viewmodel/cart_provider.dart';
import 'package:provider/provider.dart';
import 'package:grab_go_shared/grub_go_shared.dart';

class PaymentComplete extends StatefulWidget {
  final String method;
  final double total;
  final double subTotal;
  final double deliveryFee;
  final String? orderNumber;
  final String? timestamp;

  const PaymentComplete({
    super.key,
    required this.method,
    required this.total,
    required this.subTotal,
    required this.deliveryFee,
    this.orderNumber,
    this.timestamp,
  });

  @override
  State<PaymentComplete> createState() => _PaymentCompleteState();
}

class _PaymentCompleteState extends State<PaymentComplete> with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _bounceController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _bounceAnimation;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(duration: const Duration(milliseconds: 1200), vsync: this);

    _bounceController = AnimationController(duration: const Duration(milliseconds: 600), vsync: this);

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _slideAnimation = Tween<double>(begin: 50.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.2, 0.8, curve: Curves.easeOutCubic),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.elasticOut),
      ),
    );

    _bounceAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _bounceController, curve: Curves.elasticOut));

    _animationController.forward();

    HapticFeedback.lightImpact();

    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) _bounceController.forward();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<CartProvider>(context, listen: false).clearCart();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _bounceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Scaffold(
      backgroundColor: colors.backgroundSecondary,
      body: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return Column(
            children: [
              Expanded(
                child: Transform.translate(
                  offset: Offset(0, _slideAnimation.value),
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20.w),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ScaleTransition(
                            scale: _scaleAnimation,
                            child: Container(
                              width: 120.w,
                              height: 120.h,
                              margin: EdgeInsets.only(bottom: 32.h),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [colors.accentGreen, colors.accentGreen.withOpacity(0.8)],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: colors.accentGreen.withOpacity(0.3),
                                    blurRadius: 25,
                                    spreadRadius: 5,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: AnimatedBuilder(
                                animation: _bounceController,
                                builder: (context, child) {
                                  return Transform.scale(
                                    scale: _bounceAnimation.value,
                                    child: Center(
                                      child: SvgPicture.asset(
                                        Assets.icons.checkBig,
                                        package: 'grab_go_shared',
                                        height: 60.h,
                                        width: 60.h,
                                        colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),

                          Text(
                            "Payment Successful!",
                            style: TextStyle(
                              fontSize: 28.sp,
                              color: colors.textPrimary,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.2,
                              height: 1.5,
                            ),
                          ),
                          SizedBox(height: 8.h),
                          Text(
                            "Your order has been placed successfully.\nYou'll receive a confirmation shortly.",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14.sp,
                              color: colors.textSecondary,
                              fontWeight: FontWeight.w500,
                              height: 1.5,
                            ),
                          ),

                          SizedBox(height: 48.h),

                          _buildPaymentDetailsCard(colors),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              _buildBottomActionBar(colors),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPaymentDetailsCard(AppColorsExtension colors) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(24.r),
      decoration: BoxDecoration(
        color: colors.backgroundPrimary,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: colors.inputBorder.withOpacity(0.15), width: 1),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 4), spreadRadius: 0),
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 40, offset: const Offset(0, 8), spreadRadius: 0),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(KBorderSize.borderRadius8),
                child: Image.asset(
                  _getPaymentMethodIcon(widget.method),
                  package: "grab_go_shared",
                  width: 64.w,
                  height: 45.h,
                  fit: BoxFit.cover,
                ),
              ),
              SizedBox(width: 16.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.method,
                      style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w700, color: colors.textPrimary),
                    ),
                    SizedBox(height: 4.h),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                      decoration: BoxDecoration(
                        color: colors.accentGreen.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: Text(
                        "Payment Complete",
                        style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w600, color: colors.accentGreen),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          SizedBox(height: 24.h),

          DottedLine(dashLength: 6, dashGapLength: 4, lineThickness: 1, dashColor: colors.textSecondary.withAlpha(50)),

          SizedBox(height: 24.h),

          _buildEnhancedDetailRow("Subtotal", "\GHC ${widget.subTotal.toStringAsFixed(2)}", colors, false),
          SizedBox(height: 16.h),
          _buildEnhancedDetailRow("Delivery Fee", "\GHC ${widget.deliveryFee.toStringAsFixed(2)}", colors, false),
          SizedBox(height: 20.h),

          Container(
            padding: EdgeInsets.symmetric(vertical: 16.h, horizontal: 20.w),
            decoration: BoxDecoration(
              color: colors.accentGreen.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: colors.accentGreen.withOpacity(0.2), width: 1),
            ),
            child: _buildEnhancedDetailRow("Total Paid", "\GHC ${widget.total.toStringAsFixed(2)}", colors, true),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActionBar(AppColorsExtension colors) {
    return Container(
      decoration: BoxDecoration(
        color: colors.backgroundPrimary,
        borderRadius: BorderRadius.only(topLeft: Radius.circular(24.r), topRight: Radius.circular(24.r)),
        border: Border(top: BorderSide(color: colors.inputBorder.withOpacity(0.1), width: 1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, -2),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.only(
          left: 20.w,
          right: 20.w,
          top: 30.h,
          bottom: MediaQuery.of(context).padding.bottom + 20.h,
        ),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 56.h,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16.r),
                      border: Border.all(color: colors.inputBorder, width: 1.5),
                      gradient: LinearGradient(
                        colors: [
                          colors.backgroundSecondary.withOpacity(0.08),
                          colors.backgroundSecondary.withOpacity(0.03),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: ElevatedButton(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        context.go('/orders');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.backgroundSecondary,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
                      ),
                      child: Text(
                        "Track Order",
                        style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w700, color: colors.textPrimary),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 16.w),
                Expanded(
                  child: Container(
                    height: 56.h,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16.r),
                      gradient: LinearGradient(
                        colors: [colors.accentGreen, colors.accentGreen.withOpacity(0.8)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: colors.accentGreen.withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        context.go('/homepage');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
                      ),
                      child: Text(
                        "Order More",
                        style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w700, color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnhancedDetailRow(String label, String value, AppColorsExtension colors, bool isTotal) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isTotal ? 16.sp : 14.sp,
            color: isTotal ? colors.textPrimary : colors.textSecondary,
            fontWeight: isTotal ? FontWeight.w700 : FontWeight.w500,
            letterSpacing: 0.2,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isTotal ? 20.sp : 16.sp,
            color: isTotal ? colors.accentGreen : colors.textPrimary,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  String _getPaymentMethodIcon(String method) {
    switch (method.toLowerCase()) {
      case 'mtn momo':
      case 'mtn':
      case 'momo':
        return Assets.icons.mom.path;
      case "vodafone cash":
        return Assets.icons.vodafoneCash.path;
      case 'visa':
      case 'mastercard':
      case 'credit card':
      case 'debit card':
        return Assets.icons.cc.path;
      default:
        return Assets.icons.cc.path;
    }
  }
}
