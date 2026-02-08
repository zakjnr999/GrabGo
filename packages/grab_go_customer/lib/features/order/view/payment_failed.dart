import 'package:dotted_line/dotted_line.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';

class PaymentFailed extends StatefulWidget {
  final String method;
  final double total;
  final double subTotal;
  final double deliveryFee;
  final double serviceFee;
  final double rainFee;
  final double tax;
  final double tip;
  final String? orderNumber;
  final String? timestamp;

  const PaymentFailed({
    super.key,
    required this.method,
    required this.total,
    required this.subTotal,
    required this.deliveryFee,
    this.serviceFee = 0.0,
    this.rainFee = 0.0,
    this.tax = 0.0,
    this.tip = 0.0,
    this.orderNumber,
    this.timestamp,
  });

  @override
  State<PaymentFailed> createState() => _PaymentFailedState();
}

class _PaymentFailedState extends State<PaymentFailed> with TickerProviderStateMixin {
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
    HapticFeedback.mediumImpact();

    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) _bounceController.forward();
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
      backgroundColor: colors.backgroundPrimary,
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
                              decoration: BoxDecoration(shape: BoxShape.circle, color: colors.error),
                              child: AnimatedBuilder(
                                animation: _bounceController,
                                builder: (context, child) {
                                  return Transform.scale(
                                    scale: _bounceAnimation.value,
                                    child: Center(
                                      child: SvgPicture.asset(
                                        Assets.icons.xmark,
                                        package: 'grab_go_shared',
                                        height: 52.h,
                                        width: 52.h,
                                        colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),

                          Text(
                            "Payment Failed",
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
                            "We couldn't complete your payment.\nYour order is still pending. You can retry from Orders.",
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
      decoration: BoxDecoration(color: colors.backgroundPrimary, borderRadius: BorderRadius.circular(20.r)),
      child: Column(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                widget.method,
                style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w700, color: colors.textPrimary),
              ),
              SizedBox(height: 4.h),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                decoration: BoxDecoration(
                  color: colors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Text(
                  "Payment not completed",
                  style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w600, color: colors.error),
                ),
              ),
            ],
          ),

          SizedBox(height: 24.h),

          DottedLine(dashLength: 6, dashGapLength: 4, lineThickness: 1, dashColor: colors.textSecondary.withAlpha(50)),

          SizedBox(height: 24.h),

          _buildEnhancedDetailRow("Subtotal", "GHC ${widget.subTotal.toStringAsFixed(2)}", colors, false),
          SizedBox(height: 8.h),
          _buildEnhancedDetailRow("Delivery Fee", "GHC ${widget.deliveryFee.toStringAsFixed(2)}", colors, false),
          if (widget.serviceFee > 0) ...[
            SizedBox(height: 8.h),
            _buildEnhancedDetailRow("Service Fee", " GHC ${widget.serviceFee.toStringAsFixed(2)}", colors, false),
          ],
          if (widget.rainFee > 0) ...[
            SizedBox(height: 8.h),
            _buildEnhancedDetailRow("Rain Fee", "GHC ${widget.rainFee.toStringAsFixed(2)}", colors, false),
          ],
          if (widget.tip > 0) ...[
            SizedBox(height: 8.h),
            _buildEnhancedDetailRow("Driver Tip", "GHC ${widget.tip.toStringAsFixed(2)}", colors, false),
          ],
          SizedBox(height: 8.h),

          _buildEnhancedDetailRow("Total Due", "GHC ${widget.total.toStringAsFixed(2)}", colors, true),
        ],
      ),
    );
  }

  Widget _buildBottomActionBar(AppColorsExtension colors) {
    return Container(
      decoration: BoxDecoration(
        color: colors.backgroundPrimary,
        borderRadius: BorderRadius.only(topLeft: Radius.circular(24.r), topRight: Radius.circular(24.r)),
        border: Border(top: BorderSide(color: colors.backgroundSecondary, width: 1)),
      ),
      child: Padding(
        padding: EdgeInsets.only(
          left: 20.w,
          right: 20.w,
          top: 12.h,
          bottom: MediaQuery.of(context).padding.bottom + 20.h,
        ),
        child: Column(
          children: [
            AppButton(
              width: double.infinity,
              onPressed: () => context.go('/orders'),
              buttonText: "Go to Orders",
              textStyle: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w800, color: Colors.white),
              backgroundColor: colors.accentOrange,
              padding: EdgeInsets.symmetric(vertical: 16.h),
              borderRadius: KBorderSize.borderMedium,
            ),
            SizedBox(height: 10.h),
            AppButton(
              width: double.infinity,
              onPressed: () => context.go('/homepage'),
              buttonText: "Back Home",
              textStyle: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w800, color: colors.textPrimary),
              backgroundColor: colors.backgroundSecondary,
              padding: EdgeInsets.symmetric(vertical: 16.h),
              borderRadius: KBorderSize.borderMedium,
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
            color: colors.textSecondary,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.2,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isTotal ? 16.sp : 14.sp,
            color: isTotal ? colors.error : colors.textPrimary,
            fontWeight: isTotal ? FontWeight.w800 : FontWeight.w500,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}
