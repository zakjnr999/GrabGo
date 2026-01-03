import 'package:dotted_line/dotted_line.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_customer/features/order/service/order_service_wrapper.dart';
import 'package:grab_go_customer/shared/services/paystack_service.dart' as paystack;
import 'package:grab_go_customer/shared/services/user_service.dart';
import 'package:grab_go_customer/features/cart/view/mtn_momo_payment_dialog.dart';
import 'package:grab_go_customer/features/cart/viewmodel/cart_provider.dart';
import 'package:pay_with_paystack/pay_with_paystack.dart';
import 'package:provider/provider.dart';
import 'package:grab_go_shared/grub_go_shared.dart';

class OrderSummaryPage extends StatefulWidget {
  final String selectedAddress;
  final String selectedAddressDetails;
  final String selectedPaymentMethod;
  final List<String> selectedInstructions;
  final String customRestaurantInstruction;
  final List<String> selectedDeliveryInstructions;
  final String customDeliveryInstruction;
  final double tipAmount;

  const OrderSummaryPage({
    super.key,
    required this.selectedAddress,
    this.selectedAddressDetails = "",
    required this.selectedPaymentMethod,
    this.selectedInstructions = const [],
    this.customRestaurantInstruction = "",
    this.selectedDeliveryInstructions = const [],
    this.customDeliveryInstruction = "",
    this.tipAmount = 0.0,
  });

  @override
  State<OrderSummaryPage> createState() => _OrderSummaryPageState();
}

class _OrderSummaryPageState extends State<OrderSummaryPage> {
  bool _isProcessingPayment = false;
  final String _momoNumber = "0536997662"; // User's saved MOMO number

  void _handlePayment(BuildContext context, double total, double subtotal, double deliveryFee) async {
    if (widget.selectedPaymentMethod == "MTN MOMO") {
      await _handleMtnMomoPayment(context, total, subtotal, deliveryFee);
    } else {
      // Handle Paystack payment with webview
      await _handlePaystackPayment(context, total, subtotal, deliveryFee);
    }
  }

  Future<void> _handlePaystackPayment(BuildContext context, double total, double subtotal, double deliveryFee) async {
    setState(() {
      _isProcessingPayment = true;
    });

    try {
      // 1. Create order first
      final orderId = await _createOrder(context, total, subtotal, deliveryFee);
      if (orderId == null) {
        throw Exception('Failed to create order');
      }

      // 2. Get user email
      final user = await UserService().getCurrentUser();
      final email = user?.email ?? 'customer@grabgo.com';

      // 3. Generate reference using pay_with_paystack
      final paystackHelper = PayWithPayStack();
      final reference = paystackHelper.generateUuidV4();

      // 4. Generate authorization URL using Paystack inline
      final authUrl = await _generatePaystackUrl(amount: total, email: email, reference: reference);

      setState(() {
        _isProcessingPayment = false;
      });

      // 5. Launch payment webview
      final result = await paystack.PaystackService.instance.launchPayment(
        context: context,
        authorizationUrl: authUrl,
        reference: reference,
      );

      // 6. Handle payment result
      if (result.success) {
        _handlePaymentSuccess(context);
      } else {
        _handlePaymentFailure(context);
      }
    } catch (e) {
      setState(() {
        _isProcessingPayment = false;
      });
      _showErrorDialog(context, 'Payment failed: ${e.toString()}');
    }
  }

  Future<String> _generatePaystackUrl({
    required double amount,
    required String email,
    required String reference,
  }) async {
    // Use Paystack's inline checkout URL
    final amountInKobo = (amount * 100).toInt();
    final publicKey = AppConfig.paystackPublicKey;

    // Generate Paystack inline URL
    return 'https://checkout.paystack.com/$publicKey?amount=$amountInKobo&email=$email&reference=$reference&currency=${AppConfig.currency}';
  }

  Future<void> _handleMtnMomoPayment(BuildContext context, double total, double subtotal, double deliveryFee) async {
    setState(() {
      _isProcessingPayment = true;
    });

    try {
      // First create the order
      final orderId = await _createOrder(context, total, subtotal, deliveryFee);

      if (orderId != null) {
        setState(() {
          _isProcessingPayment = false;
        });

        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => MtnMomoPaymentDialog(
              orderId: orderId,
              totalAmount: total,
              phoneNumber: _momoNumber,
              onPaymentSuccess: () {
                _handlePaymentSuccess(context);
              },
              onPaymentFailed: () {
                _handlePaymentFailure(context);
              },
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isProcessingPayment = false;
      });

      if (mounted) {
        _showErrorDialog(context, "Failed to create order: ${e.toString()}");
      }
    }
  }

  Future<String?> _createOrder(BuildContext context, double total, double subtotal, double deliveryFee) async {
    final cart = context.read<CartProvider>();
    final orderService = OrderServiceWrapper();

    try {
      // Map frontend payment method to backend-accepted values
      String backendPaymentMethod;
      if (widget.selectedPaymentMethod == "MTN MOMO") {
        backendPaymentMethod = "mtn_momo";
      } else {
        // For Paystack/Credit Card payments, use 'card'
        backendPaymentMethod = "card";
      }

      final orderId = await orderService.createOrder(
        cartItems: cart.cartItems,
        deliveryAddress: widget.selectedAddress,
        paymentMethod: backendPaymentMethod,
        subtotal: subtotal,
        deliveryFee: deliveryFee,
        total: total,
        notes: _getConcatenatedNotes(),
      );

      return orderId;
    } catch (e) {
      debugPrint("Order creation error: $e");
      throw Exception("Failed to create order: ${e.toString()}");
    }
  }

  void _handlePaymentSuccess(BuildContext context) {
    // Get cart details before clearing
    final cart = context.read<CartProvider>();
    final cartSubtotal = cart.totalPrice;
    const double deliveryFeeAmount = 2.0;
    final double totalAmount = cartSubtotal + deliveryFeeAmount;

    // Clear cart
    cart.clearCart();

    // Navigate to payment success page with actual details
    context.go(
      '/paymentComplete',
      extra: {
        'method': widget.selectedPaymentMethod,
        'total': totalAmount,
        'subTotal': cartSubtotal,
        'deliveryFee': deliveryFeeAmount,
        'orderNumber': _generateOrderNumber(),
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  String _generateOrderNumber() {
    final now = DateTime.now();
    final timestamp = now.millisecondsSinceEpoch.toString();
    return 'ORD${timestamp.substring(timestamp.length - 8)}';
  }

  void _handlePaymentFailure(BuildContext context) {
    _showErrorDialog(context, "Payment failed. Please try again.");
  }

  String _getConcatenatedNotes() {
    List<String> notesParts = [];

    if (widget.selectedInstructions.isNotEmpty || widget.customRestaurantInstruction.isNotEmpty) {
      notesParts.add(
        "Restaurant: ${[...widget.selectedInstructions, if (widget.customRestaurantInstruction.isNotEmpty) widget.customRestaurantInstruction].join(', ')}",
      );
    }

    if (widget.selectedDeliveryInstructions.isNotEmpty || widget.customDeliveryInstruction.isNotEmpty) {
      notesParts.add(
        "Delivery: ${[...widget.selectedDeliveryInstructions, if (widget.customDeliveryInstruction.isNotEmpty) widget.customDeliveryInstruction].join(', ')}",
      );
    }

    return notesParts.join(" | ");
  }

  void _showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Payment Error'),
        content: Text(message),
        actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cart = context.watch<CartProvider>();
    final padding = MediaQuery.of(context).padding;

    final systemUiOverlayStyle = SystemUiOverlayStyle(
      statusBarColor: colors.backgroundSecondary,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      systemNavigationBarColor: colors.backgroundSecondary,
      systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
    );

    SystemChrome.setSystemUIOverlayStyle(systemUiOverlayStyle);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: systemUiOverlayStyle,
      child: Scaffold(
        backgroundColor: colors.backgroundSecondary,
        body: Consumer<CartProvider>(
          builder: (context, provider, child) {
            const double deliveryFee = 2.0;
            final double subtotal = provider.totalPrice;
            final double total = subtotal + deliveryFee + widget.tipAmount;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Section
                Padding(
                  padding: EdgeInsets.only(top: padding.top, left: 20.w, right: 20.w, bottom: 16.h),
                  child: Row(
                    children: [
                      // Back button
                      Container(
                        height: 44.h,
                        width: 44.w,
                        decoration: BoxDecoration(
                          color: colors.backgroundPrimary,
                          shape: BoxShape.circle,
                          border: Border.all(color: colors.inputBorder.withValues(alpha: 0.3), width: 0.5),
                          boxShadow: [
                            BoxShadow(
                              color: isDark ? Colors.black.withAlpha(20) : Colors.black.withAlpha(5),
                              spreadRadius: 0,
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => context.pop(),
                            customBorder: const CircleBorder(),
                            child: Padding(
                              padding: EdgeInsets.all(10.r),
                              child: SvgPicture.asset(
                                Assets.icons.navArrowLeft,
                                package: 'grab_go_shared',
                                colorFilter: ColorFilter.mode(colors.textPrimary, BlendMode.srcIn),
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 16.w),
                      Text(
                        "Summary",
                        style: TextStyle(
                          fontFamily: "Lato",
                          package: 'grab_go_shared',
                          color: colors.textPrimary,
                          fontSize: 24.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                // Scrollable content
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 20.w),
                          child: Row(
                            children: [
                              Container(
                                padding: EdgeInsets.all(8.r),
                                decoration: BoxDecoration(
                                  color: colors.accentOrange.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: SvgPicture.asset(
                                  Assets.icons.cart,
                                  package: 'grab_go_shared',
                                  height: 18.h,
                                  width: 18.w,
                                  colorFilter: ColorFilter.mode(colors.accentOrange, BlendMode.srcIn),
                                ),
                              ),
                              SizedBox(width: 12.w),
                              Text(
                                "Order Items",
                                style: TextStyle(
                                  fontFamily: "Lato",
                                  package: 'grab_go_shared',
                                  color: colors.textPrimary,
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),

                        SizedBox(height: 10.h),

                        // Order Items Section
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 6.h),
                          child: Container(
                            padding: EdgeInsets.all(16.r),
                            decoration: BoxDecoration(
                              color: colors.backgroundPrimary,
                              borderRadius: BorderRadius.circular(KBorderSize.borderRadius15),
                              border: Border.all(color: colors.inputBorder.withValues(alpha: 0.3), width: 0.5),
                              boxShadow: [
                                BoxShadow(
                                  color: isDark ? Colors.black.withAlpha(30) : Colors.black.withAlpha(8),
                                  spreadRadius: 0,
                                  blurRadius: 12,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: cart.cartItems.length,
                              separatorBuilder: (context, index) => Padding(
                                padding: EdgeInsets.symmetric(vertical: 10.h),
                                child: DottedLine(
                                  dashLength: 4,
                                  dashGapLength: 3,
                                  lineThickness: 1,
                                  dashColor: colors.inputBorder.withValues(alpha: 0.5),
                                ),
                              ),
                              itemBuilder: (context, index) {
                                final item = cart.cartItems.keys.elementAt(index);
                                final quantity = cart.cartItems[item]!;
                                return Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.name,
                                            style: TextStyle(
                                              fontSize: 14.sp,
                                              fontWeight: FontWeight.w700,
                                              color: colors.textPrimary,
                                            ),
                                          ),
                                          SizedBox(height: 4.h),
                                          Text(
                                            "Qty: $quantity",
                                            style: TextStyle(
                                              fontSize: 11.sp,
                                              color: colors.textSecondary,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    SizedBox(width: 10.w),
                                    Container(
                                      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                                      decoration: BoxDecoration(
                                        color: colors.accentOrange.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(8.r),
                                      ),
                                      child: Text(
                                        "GHS ${(item.price * quantity).toStringAsFixed(2)}",
                                        style: TextStyle(
                                          fontSize: 13.sp,
                                          color: colors.accentOrange,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ),
                        SizedBox(height: 8.h),

                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
                          child: Row(
                            children: [
                              Container(
                                padding: EdgeInsets.all(8.r),
                                decoration: BoxDecoration(
                                  color: colors.accentOrange.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: SvgPicture.asset(
                                  Assets.icons.mapPin,
                                  package: 'grab_go_shared',
                                  height: 18.h,
                                  width: 18.w,
                                  colorFilter: ColorFilter.mode(colors.accentOrange, BlendMode.srcIn),
                                ),
                              ),
                              SizedBox(width: 12.w),
                              Text(
                                "Delivery Address",
                                style: TextStyle(
                                  fontFamily: "Lato",
                                  package: 'grab_go_shared',
                                  color: colors.textPrimary,
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Delivery Address Section
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 6.h),
                          child: Container(
                            width: double.infinity,
                            padding: EdgeInsets.all(16.r),
                            decoration: BoxDecoration(
                              color: colors.backgroundPrimary,
                              borderRadius: BorderRadius.circular(KBorderSize.borderRadius15),
                              border: Border.all(color: colors.inputBorder.withValues(alpha: 0.3), width: 0.5),
                              boxShadow: [
                                BoxShadow(
                                  color: isDark ? Colors.black.withAlpha(30) : Colors.black.withAlpha(8),
                                  spreadRadius: 0,
                                  blurRadius: 12,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Text(
                              widget.selectedAddressDetails.isNotEmpty
                                  ? widget.selectedAddressDetails
                                  : widget.selectedAddress,
                              style: TextStyle(fontSize: 13.sp, color: colors.textPrimary, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),

                        SizedBox(height: 8.h),

                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
                          child: Row(
                            children: [
                              Container(
                                padding: EdgeInsets.all(8.r),
                                decoration: BoxDecoration(
                                  color: colors.accentOrange.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: SvgPicture.asset(
                                  Assets.icons.cash,
                                  package: 'grab_go_shared',
                                  height: 18.h,
                                  width: 18.w,
                                  colorFilter: ColorFilter.mode(colors.accentOrange, BlendMode.srcIn),
                                ),
                              ),
                              SizedBox(width: 12.w),
                              Text(
                                "Payment Method",
                                style: TextStyle(
                                  fontFamily: "Lato",
                                  package: 'grab_go_shared',
                                  color: colors.textPrimary,
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Payment Method Section
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 6.h),
                          child: Container(
                            width: double.infinity,
                            padding: EdgeInsets.all(16.r),
                            decoration: BoxDecoration(
                              color: colors.backgroundPrimary,
                              borderRadius: BorderRadius.circular(KBorderSize.borderRadius15),
                              border: Border.all(color: colors.inputBorder.withValues(alpha: 0.3), width: 0.5),
                              boxShadow: [
                                BoxShadow(
                                  color: isDark ? Colors.black.withAlpha(30) : Colors.black.withAlpha(8),
                                  spreadRadius: 0,
                                  blurRadius: 12,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.selectedPaymentMethod,
                                  style: TextStyle(
                                    fontSize: 13.sp,
                                    color: colors.textPrimary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        if (widget.selectedInstructions.isNotEmpty ||
                            widget.customRestaurantInstruction.isNotEmpty) ...[
                          SizedBox(height: 8.h),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
                            child: Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.all(8.r),
                                  decoration: BoxDecoration(
                                    color: colors.accentOrange.withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: SvgPicture.asset(
                                    Assets.icons.squareMenu,
                                    package: 'grab_go_shared',
                                    height: 18.h,
                                    width: 18.w,
                                    colorFilter: ColorFilter.mode(colors.accentOrange, BlendMode.srcIn),
                                  ),
                                ),
                                SizedBox(width: 12.w),
                                Text(
                                  "Special Instructions",
                                  style: TextStyle(
                                    fontFamily: "Lato",
                                    package: 'grab_go_shared',
                                    color: colors.textPrimary,
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 6.h),
                            child: Container(
                              width: double.infinity,
                              padding: EdgeInsets.all(16.r),
                              decoration: BoxDecoration(
                                color: colors.backgroundPrimary,
                                borderRadius: BorderRadius.circular(KBorderSize.borderRadius15),
                                border: Border.all(color: colors.inputBorder.withValues(alpha: 0.3), width: 0.5),
                              ),
                              child: Text(
                                [
                                  ...widget.selectedInstructions,
                                  if (widget.customRestaurantInstruction.isNotEmpty) widget.customRestaurantInstruction,
                                ].join(", "),
                                style: TextStyle(
                                  fontSize: 13.sp,
                                  color: colors.textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],

                        if (widget.selectedDeliveryInstructions.isNotEmpty ||
                            widget.customDeliveryInstruction.isNotEmpty) ...[
                          SizedBox(height: 8.h),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
                            child: Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.all(8.r),
                                  decoration: BoxDecoration(
                                    color: colors.accentOrange.withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: SvgPicture.asset(
                                    Assets.icons.deliveryTruck,
                                    package: 'grab_go_shared',
                                    height: 18.h,
                                    width: 18.w,
                                    colorFilter: ColorFilter.mode(colors.accentOrange, BlendMode.srcIn),
                                  ),
                                ),
                                SizedBox(width: 12.w),
                                Text(
                                  "Delivery Instructions",
                                  style: TextStyle(
                                    fontFamily: "Lato",
                                    package: 'grab_go_shared',
                                    color: colors.textPrimary,
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 6.h),
                            child: Container(
                              width: double.infinity,
                              padding: EdgeInsets.all(16.r),
                              decoration: BoxDecoration(
                                color: colors.backgroundPrimary,
                                borderRadius: BorderRadius.circular(KBorderSize.borderRadius15),
                                border: Border.all(color: colors.inputBorder.withValues(alpha: 0.3), width: 0.5),
                              ),
                              child: Text(
                                [
                                  ...widget.selectedDeliveryInstructions,
                                  if (widget.customDeliveryInstruction.isNotEmpty) widget.customDeliveryInstruction,
                                ].join(", "),
                                style: TextStyle(
                                  fontSize: 13.sp,
                                  color: colors.textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],

                        SizedBox(height: 16.h),

                        // Pricing Section
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 20.w),
                          child: Container(
                            padding: EdgeInsets.all(14.r),
                            decoration: BoxDecoration(
                              color: colors.backgroundPrimary,
                              borderRadius: BorderRadius.circular(12.r),
                              border: Border.all(color: colors.inputBorder.withValues(alpha: 0.3), width: 0.5),
                            ),
                            child: Column(
                              children: [
                                _buildPriceRow("Subtotal", subtotal, colors, Assets.icons.cash, false),
                                SizedBox(height: 10.h),
                                _buildPriceRow("Delivery Fee", deliveryFee, colors, Assets.icons.deliveryTruck, false),
                                if (widget.tipAmount > 0) ...[
                                  SizedBox(height: 10.h),
                                  _buildPriceRow("Driver Tip", widget.tipAmount, colors, Assets.icons.handCash, false),
                                ],
                                SizedBox(height: 12.h),
                                DottedLine(
                                  direction: Axis.horizontal,
                                  lineLength: double.infinity,
                                  lineThickness: 1.5,
                                  dashLength: 6,
                                  dashColor: colors.inputBorder.withValues(alpha: 0.5),
                                  dashGapLength: 4,
                                ),
                                SizedBox(height: 12.h),
                                Container(
                                  padding: EdgeInsets.all(12.r),
                                  decoration: BoxDecoration(
                                    color: colors.accentGreen.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8.r),
                                  ),
                                  child: Row(
                                    children: [
                                      Text(
                                        "Total Amount",
                                        style: TextStyle(
                                          color: colors.textPrimary,
                                          fontSize: 14.sp,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const Spacer(),
                                      Text(
                                        "GHS ${total.toStringAsFixed(2)}",
                                        style: TextStyle(
                                          color: colors.accentGreen,
                                          fontSize: 18.sp,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        SizedBox(height: 16.h),
                      ],
                    ),
                  ),
                ),

                // Sticky button at bottom
                Container(
                  padding: EdgeInsets.only(left: 20.w, right: 20.w, top: 16.h, bottom: padding.bottom),
                  decoration: BoxDecoration(
                    color: colors.backgroundSecondary,
                    border: Border(top: BorderSide(color: colors.textPrimary.withValues(alpha: 0.1), width: 0.5)),
                    boxShadow: [
                      BoxShadow(
                        color: isDark ? Colors.black.withAlpha(40) : Colors.black.withAlpha(15),
                        spreadRadius: 0,
                        blurRadius: 20,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: GestureDetector(
                    onTap: _isProcessingPayment ? null : () => _handlePayment(context, total, subtotal, deliveryFee),
                    child: Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(vertical: 16.h),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [colors.accentGreen, colors.accentGreen.withValues(alpha: 0.8)],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(KBorderSize.borderRadius15),
                        boxShadow: [
                          BoxShadow(
                            color: colors.accentGreen.withValues(alpha: 0.3),
                            spreadRadius: 0,
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (_isProcessingPayment)
                            SizedBox(
                              height: 20.h,
                              width: 20.w,
                              child: const CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          else
                            Center(
                              child: Text(
                                _isProcessingPayment ? "Processing Payment..." : "Proceed to Payment",
                                style: TextStyle(color: Colors.white, fontSize: 15.sp, fontWeight: FontWeight.w800),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildPriceRow(String label, double amount, AppColorsExtension colors, String icon, bool isTotal) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(8.r),
          decoration: BoxDecoration(color: colors.backgroundSecondary, borderRadius: BorderRadius.circular(10.r)),
          child: SvgPicture.asset(
            icon,
            package: 'grab_go_shared',
            height: 18.h,
            width: 18.w,
            colorFilter: ColorFilter.mode(colors.textPrimary, BlendMode.srcIn),
          ),
        ),
        SizedBox(width: 10.w),
        Text(
          label,
          style: TextStyle(
            color: isTotal ? colors.textPrimary : colors.textSecondary,
            fontSize: isTotal ? 14.sp : 13.sp,
            fontWeight: isTotal ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        const Spacer(),
        Text(
          "GHS ${amount.toStringAsFixed(2)}",
          style: TextStyle(
            color: isTotal ? colors.accentGreen : colors.textPrimary,
            fontSize: isTotal ? 16.sp : 13.sp,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}
