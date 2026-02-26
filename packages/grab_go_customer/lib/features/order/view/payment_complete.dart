import 'package:dotted_line/dotted_line.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_customer/features/cart/viewmodel/cart_provider.dart';
import 'package:grab_go_customer/features/order/service/order_service_wrapper.dart';
import 'package:grab_go_customer/shared/widgets/umbrella_header.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:grab_go_shared/grub_go_shared.dart';

class PaymentComplete extends StatefulWidget {
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
  final String? orderId;
  final String? checkoutSessionId;
  final bool isGroupedOrder;
  final bool isGiftOrder;
  final String? giftRecipientName;
  final String? giftRecipientPhone;
  final String? giftDeliveryCode;
  final double? codRemainingCashAmount;
  final double? orderGrandTotal;

  const PaymentComplete({
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
    this.orderId,
    this.checkoutSessionId,
    this.isGroupedOrder = false,
    this.isGiftOrder = false,
    this.giftRecipientName,
    this.giftRecipientPhone,
    this.giftDeliveryCode,
    this.codRemainingCashAmount,
    this.orderGrandTotal,
  });

  @override
  State<PaymentComplete> createState() => _PaymentCompleteState();
}

class _PaymentCompleteState extends State<PaymentComplete>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _bounceController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _bounceAnimation;
  bool _isResendingDeliveryCode = false;
  String? _currentGiftDeliveryCode;

  @override
  void initState() {
    super.initState();
    _currentGiftDeliveryCode = widget.giftDeliveryCode;

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _bounceController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

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

    _bounceAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _bounceController, curve: Curves.elasticOut),
    );

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
      backgroundColor: colors.backgroundPrimary,
      body: SafeArea(
        bottom: false,
        child: AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            return Column(
              children: [
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) => SingleChildScrollView(
                      padding: EdgeInsets.symmetric(horizontal: 20.w),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight,
                        ),
                        child: Transform.translate(
                          offset: Offset(0, _slideAnimation.value),
                          child: FadeTransition(
                            opacity: _fadeAnimation,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(height: 16.h),
                                ScaleTransition(
                                  scale: _scaleAnimation,
                                  child: Container(
                                    width: 120.w,
                                    height: 120.h,
                                    margin: EdgeInsets.only(bottom: 32.h),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: colors.accentGreen,
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
                                              colorFilter:
                                                  const ColorFilter.mode(
                                                    Colors.white,
                                                    BlendMode.srcIn,
                                                  ),
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
                                  widget.isGroupedOrder
                                      ? "Your multi-vendor order has been placed successfully.\nYou'll receive confirmation for each vendor once accepted."
                                      : "Your order has been placed successfully.\nYou'll receive a confirmation once the vendor accepts it.",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 14.sp,
                                    color: colors.textSecondary,
                                    fontWeight: FontWeight.w500,
                                    height: 1.5,
                                  ),
                                ),

                                SizedBox(height: 40.h),

                                _buildPaymentDetailsCard(colors),
                                if (widget.isGiftOrder) ...[
                                  SizedBox(height: 14.h),
                                  _buildGiftCodeCard(colors),
                                ],
                                SizedBox(height: 16.h),
                              ],
                            ),
                          ),
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
      ),
    );
  }

  Widget _buildPaymentDetailsCard(AppColorsExtension colors) {
    final formattedTimestamp = _formatReceiptTimestamp(widget.timestamp);
    final codRemainingCashAmount = widget.codRemainingCashAmount ?? 0.0;
    final hasCodSplit = codRemainingCashAmount > 0;
    final orderGrandTotal =
        widget.orderGrandTotal ?? (widget.total + codRemainingCashAmount);
    final receiptBackgroundColor = colors.backgroundSecondary.withValues(
      alpha: 0.6,
    );

    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: UmbrellaHeader(
            backgroundColor: receiptBackgroundColor,
            curveDepth: 10,
            numberOfCurves: 24,
            curvesOnTop: true,
            child: SizedBox(height: 20.h),
          ),
        ),
        Container(
          width: double.infinity,
          color: receiptBackgroundColor,
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    "Payment Receipt",
                    style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w800,
                      color: colors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  if (widget.orderNumber != null &&
                      widget.orderNumber!.trim().isNotEmpty)
                    Text(
                      "#${widget.orderNumber}",
                      style: TextStyle(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w700,
                        color: colors.textSecondary,
                      ),
                    ),
                ],
              ),
              SizedBox(height: 8.h),
              Text(
                widget.method,
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
              ),
              if (formattedTimestamp.isNotEmpty) ...[
                SizedBox(height: 2.h),
                Text(
                  formattedTimestamp,
                  style: TextStyle(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w500,
                    color: colors.textSecondary,
                  ),
                ),
              ],

              SizedBox(height: 16.h),
              _buildReceiptDivider(colors),
              SizedBox(height: 16.h),

              _buildEnhancedDetailRow(
                "Subtotal",
                "GHC ${widget.subTotal.toStringAsFixed(2)}",
                colors,
                false,
              ),
              SizedBox(height: 8.h),
              _buildEnhancedDetailRow(
                "Delivery Fee",
                "GHC ${widget.deliveryFee.toStringAsFixed(2)}",
                colors,
                false,
              ),
              if (widget.serviceFee > 0) ...[
                SizedBox(height: 8.h),
                _buildEnhancedDetailRow(
                  "Service Fee",
                  " GHC ${widget.serviceFee.toStringAsFixed(2)}",
                  colors,
                  false,
                ),
              ],
              if (widget.rainFee > 0) ...[
                SizedBox(height: 8.h),
                _buildEnhancedDetailRow(
                  "Rain Fee",
                  "GHC ${widget.rainFee.toStringAsFixed(2)}",
                  colors,
                  false,
                ),
              ],
              if (widget.tip > 0) ...[
                SizedBox(height: 8.h),
                _buildEnhancedDetailRow(
                  "Driver Tip",
                  "GHC ${widget.tip.toStringAsFixed(2)}",
                  colors,
                  false,
                ),
              ],
              SizedBox(height: 12.h),
              DottedLine(
                dashLength: 4,
                dashGapLength: 3,
                lineThickness: 1,
                dashColor: colors.textSecondary.withValues(alpha: 0.35),
              ),
              SizedBox(height: 12.h),

              if (hasCodSplit) ...[
                _buildEnhancedDetailRow(
                  "Paid Online",
                  "GHC ${widget.total.toStringAsFixed(2)}",
                  colors,
                  false,
                ),
                SizedBox(height: 8.h),
                _buildEnhancedDetailRow(
                  "Cash at Delivery",
                  "GHC ${codRemainingCashAmount.toStringAsFixed(2)}",
                  colors,
                  false,
                ),
                SizedBox(height: 12.h),
                DottedLine(
                  dashLength: 4,
                  dashGapLength: 3,
                  lineThickness: 1,
                  dashColor: colors.textSecondary.withValues(alpha: 0.35),
                ),
                SizedBox(height: 12.h),
                _buildEnhancedDetailRow(
                  "Order Total",
                  "GHC ${orderGrandTotal.toStringAsFixed(2)}",
                  colors,
                  true,
                ),
              ] else
                _buildEnhancedDetailRow(
                  "Total Paid",
                  "GHC ${widget.total.toStringAsFixed(2)}",
                  colors,
                  true,
                ),
            ],
          ),
        ),
        SizedBox(
          width: double.infinity,
          child: UmbrellaHeader(
            backgroundColor: receiptBackgroundColor,
            curveDepth: 10,
            numberOfCurves: 24,
            child: SizedBox(height: 20.h),
          ),
        ),
      ],
    );
  }

  Widget _buildReceiptDivider(AppColorsExtension colors) {
    return SizedBox(
      height: 16.h,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          DottedLine(
            dashLength: 6,
            dashGapLength: 4,
            lineThickness: 1,
            dashColor: colors.textSecondary.withValues(alpha: 0.35),
          ),
          Positioned(left: -26.w, child: _buildReceiptCutout(colors)),
          Positioned(right: -26.w, child: _buildReceiptCutout(colors)),
        ],
      ),
    );
  }

  Widget _buildReceiptCutout(AppColorsExtension colors) {
    return Container(
      width: 20.w,
      height: 20.w,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: colors.backgroundPrimary,
        border: Border.all(color: colors.inputBorder.withValues(alpha: 0.2)),
      ),
    );
  }

  String _formatReceiptTimestamp(String? value) {
    if (value == null || value.trim().isEmpty) return "";

    final parsed = DateTime.tryParse(value.trim());
    if (parsed == null) return value;

    const months = <String>[
      "Jan",
      "Feb",
      "Mar",
      "Apr",
      "May",
      "Jun",
      "Jul",
      "Aug",
      "Sep",
      "Oct",
      "Nov",
      "Dec",
    ];

    final local = parsed.toLocal();
    final hour12 = local.hour == 0
        ? 12
        : (local.hour > 12 ? local.hour - 12 : local.hour);
    final minute = local.minute.toString().padLeft(2, "0");
    final period = local.hour >= 12 ? "PM" : "AM";

    return "${local.day} ${months[local.month - 1]} ${local.year}, $hour12:$minute $period";
  }

  Widget _buildGiftCodeCard(AppColorsExtension colors) {
    final hasCode =
        _currentGiftDeliveryCode != null &&
        _currentGiftDeliveryCode!.trim().isNotEmpty;
    final canResendToRecipient =
        widget.giftRecipientPhone != null &&
        widget.giftRecipientPhone!.trim().isNotEmpty;
    final recipientName = widget.giftRecipientName?.trim();

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(14.r),
      decoration: BoxDecoration(
        color: colors.backgroundSecondary.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(KBorderSize.borderMedium),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Gift Delivery Code",
            style: TextStyle(
              fontSize: 15.sp,
              fontWeight: FontWeight.w800,
              color: colors.textPrimary,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            hasCode
                ? "Share this code with the recipient for delivery verification."
                : "Delivery code unavailable. Use resend below.",
            style: TextStyle(
              fontSize: 12.sp,
              fontWeight: FontWeight.w500,
              color: colors.textSecondary,
            ),
          ),
          if (recipientName != null && recipientName.isNotEmpty) ...[
            SizedBox(height: 8.h),
            Text(
              "Recipient: $recipientName",
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              ),
            ),
          ],
          SizedBox(height: 10.h),
          if (hasCode)
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
              decoration: BoxDecoration(
                color: colors.backgroundPrimary,
                borderRadius: BorderRadius.circular(KBorderSize.borderMedium),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _currentGiftDeliveryCode!,
                    style: TextStyle(
                      fontSize: 26.sp,
                      fontWeight: FontWeight.w800,
                      color: colors.textPrimary,
                      letterSpacing: 2,
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      Clipboard.setData(
                        ClipboardData(text: _currentGiftDeliveryCode!),
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Delivery code copied")),
                      );
                    },
                    icon: SvgPicture.asset(
                      Assets.icons.copy,
                      package: 'grab_go_shared',
                      height: 18,
                      width: 18,
                      colorFilter: ColorFilter.mode(
                        colors.textPrimary,
                        BlendMode.srcIn,
                      ),
                    ),
                    tooltip: "Copy code",
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
          SizedBox(height: 10.h),
          if (canResendToRecipient) ...[
            SizedBox(height: 8.h),
            AppButton(
              width: double.infinity,
              onPressed: () {
                if (_isResendingDeliveryCode) return;
                _resendDeliveryCode(target: "recipient");
              },
              buttonText: _isResendingDeliveryCode
                  ? "Sending..."
                  : "Resend to recipient",
              textStyle: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
              ),
              backgroundColor: colors.backgroundPrimary,
              padding: EdgeInsets.symmetric(vertical: 10.h),
              borderRadius: KBorderSize.borderMedium,
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _resendDeliveryCode({required String target}) async {
    if (widget.orderId == null || widget.orderId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Order reference missing; cannot resend code."),
        ),
      );
      return;
    }

    setState(() {
      _isResendingDeliveryCode = true;
    });

    final result = await OrderServiceWrapper().resendDeliveryCode(
      orderId: widget.orderId!,
      target: target,
    );
    if (!mounted) return;

    setState(() {
      _isResendingDeliveryCode = false;
      if (result.success &&
          target == "customer" &&
          result.giftDeliveryCode != null) {
        _currentGiftDeliveryCode = result.giftDeliveryCode;
      }
    });

    final retryMessage = result.retryAfterSeconds != null
        ? " Try again in ${result.retryAfterSeconds}s."
        : "";
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.success ? result.message : "${result.message}$retryMessage",
        ),
        backgroundColor: result.success ? Colors.green : Colors.red,
      ),
    );
  }

  Widget _buildBottomActionBar(AppColorsExtension colors) {
    return Container(
      decoration: BoxDecoration(
        color: colors.backgroundPrimary,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24.r),
          topRight: Radius.circular(24.r),
        ),
        border: Border(
          top: BorderSide(color: colors.backgroundSecondary, width: 1),
        ),
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
              onPressed: () async {
                final status = await Permission.notification.status;
                if (!mounted) return;
                if (status.isGranted) {
                  context.go('/homepage');
                  return;
                }
                context.go(
                  '/notificationPermission',
                  extra: {'nextRoute': '/homepage'},
                );
              },
              buttonText: "Continue",
              textStyle: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
              backgroundColor: colors.accentGreen,
              padding: EdgeInsets.symmetric(vertical: 16.h),
              borderRadius: KBorderSize.borderMedium,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnhancedDetailRow(
    String label,
    String value,
    AppColorsExtension colors,
    bool isTotal,
  ) {
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
            color: colors.textPrimary,
            fontWeight: isTotal ? FontWeight.w800 : FontWeight.w500,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}
