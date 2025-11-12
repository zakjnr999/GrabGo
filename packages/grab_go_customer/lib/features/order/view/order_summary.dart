import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:dotted_line/dotted_line.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_customer/features/cart/service/paystack_box.dart';
import 'package:grab_go_customer/features/cart/view/mtn_momo_payment_dialog.dart';
import 'package:grab_go_customer/features/cart/viewmodel/cart_provider.dart';
import 'package:grab_go_customer/features/order/service/order_service_wrapper.dart';
import 'package:provider/provider.dart';
import 'package:grab_go_shared/grub_go_shared.dart';

class OrderSummaryPage extends StatefulWidget {
  final String selectedAddress;
  final String selectedPaymentMethod;

  const OrderSummaryPage({super.key, required this.selectedAddress, required this.selectedPaymentMethod});

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
      // Handle other payment methods (existing Paystack implementation)
      final paystackService = PaystackService();
      paystackService.makePayment(
        context: context,
        amount: total,
        email: "zakjnr5@gmail.com",
        method: widget.selectedPaymentMethod,
        subTotal: subtotal,
        total: total,
        deliveryFee: deliveryFee,
      );
    }
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

        // Show MTN MOMO payment dialog
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
      final orderId = await orderService.createOrder(
        cartItems: cart.cartItems,
        deliveryAddress: widget.selectedAddress,
        paymentMethod: widget.selectedPaymentMethod,
        subtotal: subtotal,
        deliveryFee: deliveryFee,
        total: total,
        notes: null, // You can add notes field if needed
      );

      return orderId;
    } catch (e) {
      debugPrint("Order creation error: $e");
      throw Exception("Failed to create order: ${e.toString()}");
    }
  }

  void _handlePaymentSuccess(BuildContext context) {
    // Clear cart
    context.read<CartProvider>().clearCart();

    // Navigate to order tracking or success page
    context.go('/payment-complete');
  }

  void _handlePaymentFailure(BuildContext context) {
    _showErrorDialog(context, "Payment failed. Please try again.");
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
    final paystackService = PaystackService();

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        backgroundColor: colors.backgroundSecondary,
        title: Row(
          children: [
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

            const Spacer(),

            Container(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
              decoration: BoxDecoration(
                color: colors.backgroundPrimary,
                borderRadius: BorderRadius.circular(20.r),
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
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: EdgeInsets.all(6.r),
                    decoration: BoxDecoration(color: colors.accentGreen.withValues(alpha: 0.1), shape: BoxShape.circle),
                    child: SvgPicture.asset(
                      Assets.icons.check,
                      package: 'grab_go_shared',
                      height: 16.h,
                      width: 16.w,
                      colorFilter: ColorFilter.mode(colors.accentGreen, BlendMode.srcIn),
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Text(
                    "Order Summary",
                    style: TextStyle(color: colors.textPrimary, fontSize: 17.sp, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),

            const Spacer(),

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
                  onTap: () {
                    AwesomeDialog(
                      context: context,
                      dialogType: DialogType.info,
                      animType: AnimType.scale,
                      dialogBorderRadius: BorderRadius.circular(KBorderSize.border),
                      padding: EdgeInsets.all(KSpacing.md.r),
                      btnCancelColor: colors.error,
                      btnOkText: "Yes",
                      dismissOnBackKeyPress: false,
                      dismissOnTouchOutside: false,
                      customHeader: Container(
                        height: 70.h,
                        width: 70.w,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: colors.error),
                        child: SvgPicture.asset(
                          Assets.icons.infoCircle,
                          package: 'grab_go_shared',
                          colorFilter: ColorFilter.mode(colors.backgroundPrimary, BlendMode.srcIn),
                        ),
                      ),
                      body: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Discard Order?",
                            style: TextStyle(color: colors.textPrimary, fontSize: 20.sp, fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: KSpacing.md.h),
                          Text(
                            "Are you sure you would like to discard this order?",
                            style: TextStyle(color: colors.textPrimary, fontSize: 12.sp, fontWeight: FontWeight.w400),
                          ),
                        ],
                      ),
                      btnCancelOnPress: () {},
                      btnOkOnPress: () {
                        Provider.of<CartProvider>(context, listen: false).clearCart();
                        context.go("/homepage");
                      },
                    ).show();
                  },
                  customBorder: const CircleBorder(),
                  child: Padding(
                    padding: EdgeInsets.all(10.r),
                    child: SvgPicture.asset(
                      Assets.icons.binMinusIn,
                      package: 'grab_go_shared',
                      colorFilter: ColorFilter.mode(colors.error, BlendMode.srcIn),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      backgroundColor: colors.backgroundSecondary,
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
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
                  Row(
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
                          height: 16.h,
                          width: 16.w,
                          colorFilter: ColorFilter.mode(colors.accentOrange, BlendMode.srcIn),
                        ),
                      ),
                      SizedBox(width: 10.w),
                      Text(
                        "Order Items",
                        style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w800, color: colors.textPrimary),
                      ),
                    ],
                  ),
                  SizedBox(height: 16.h),
                  ListView.separated(
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
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                                  decoration: BoxDecoration(
                                    color: colors.accentViolet.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6.r),
                                  ),
                                  child: Text(
                                    "Qty: $quantity",
                                    style: TextStyle(
                                      fontSize: 11.sp,
                                      color: colors.accentViolet,
                                      fontWeight: FontWeight.w700,
                                    ),
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
                ],
              ),
            ),

            SizedBox(height: 16.h),

            Container(
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
                  Row(
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
                          height: 16.h,
                          width: 16.w,
                          colorFilter: ColorFilter.mode(colors.accentOrange, BlendMode.srcIn),
                        ),
                      ),
                      SizedBox(width: 10.w),
                      Text(
                        "Delivery Address",
                        style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w800, color: colors.textPrimary),
                      ),
                    ],
                  ),
                  SizedBox(height: 12.h),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(12.r),
                    decoration: BoxDecoration(
                      color: colors.backgroundSecondary,
                      borderRadius: BorderRadius.circular(10.r),
                      border: Border.all(color: colors.inputBorder.withValues(alpha: 0.3), width: 0.5),
                    ),
                    child: Text(
                      widget.selectedAddress,
                      style: TextStyle(fontSize: 13.sp, color: colors.textPrimary, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 16.h),

            Container(
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
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(8.r),
                        decoration: BoxDecoration(
                          color: colors.accentViolet.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: SvgPicture.asset(
                          Assets.icons.creditCard,
                          package: 'grab_go_shared',
                          height: 16.h,
                          width: 16.w,
                          colorFilter: ColorFilter.mode(colors.accentViolet, BlendMode.srcIn),
                        ),
                      ),
                      SizedBox(width: 10.w),
                      Text(
                        "Payment Method",
                        style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w800, color: colors.textPrimary),
                      ),
                    ],
                  ),
                  SizedBox(height: 12.h),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(12.r),
                    decoration: BoxDecoration(
                      color: colors.backgroundSecondary,
                      borderRadius: BorderRadius.circular(10.r),
                      border: Border.all(color: colors.inputBorder.withValues(alpha: 0.3), width: 0.5),
                    ),
                    child: Row(
                      children: [
                        Text(
                          widget.selectedPaymentMethod,
                          style: TextStyle(fontSize: 13.sp, color: colors.textPrimary, fontWeight: FontWeight.w600),
                        ),
                        if (widget.selectedPaymentMethod == "MTN MOMO") ...[
                          const Spacer(),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFD700).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6.r),
                            ),
                            child: Text(
                              _momoNumber,
                              style: TextStyle(
                                fontSize: 11.sp,
                                color: const Color(0xFFFFD700),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 100.h),
          ],
        ),
      ),

      bottomNavigationBar: Consumer<CartProvider>(
        builder: (context, provider, child) {
          const double deliveryFee = 2.0;
          final double subtotal = provider.totalPrice;
          final double total = subtotal + deliveryFee;

          return Container(
            padding: EdgeInsets.all(20.r),
            decoration: BoxDecoration(
              color: colors.backgroundPrimary,
              borderRadius: BorderRadius.only(topLeft: Radius.circular(24.r), topRight: Radius.circular(24.r)),
              border: Border(top: BorderSide(color: colors.inputBorder.withValues(alpha: 0.3), width: 0.5)),
              boxShadow: [
                BoxShadow(
                  color: isDark ? Colors.black.withAlpha(40) : Colors.black.withAlpha(15),
                  spreadRadius: 0,
                  blurRadius: 20,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: EdgeInsets.all(16.r),
                    decoration: BoxDecoration(
                      color: colors.backgroundSecondary,
                      borderRadius: BorderRadius.circular(KBorderSize.borderRadius15),
                      border: Border.all(color: colors.inputBorder.withValues(alpha: 0.3), width: 0.5),
                    ),
                    child: Column(
                      children: [
                        _buildPriceRow("Subtotal", subtotal, colors, false),
                        SizedBox(height: 10.h),
                        _buildPriceRow("Delivery Fee", deliveryFee, colors, false),
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: 12.h),
                          child: DottedLine(
                            dashLength: 6,
                            dashGapLength: 4,
                            lineThickness: 1.5,
                            dashColor: colors.inputBorder,
                          ),
                        ),
                        _buildPriceRow("Total Amount", total, colors, true),
                      ],
                    ),
                  ),
                  SizedBox(height: 16.h),

                  GestureDetector(
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
                            SvgPicture.asset(
                              Assets.icons.check,
                              package: 'grab_go_shared',
                              height: 20.h,
                              width: 20.w,
                              colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                            ),
                          SizedBox(width: 10.w),
                          Text(
                            _isProcessingPayment
                                ? "Processing Payment..."
                                : "Confirm & Pay GHS ${total.toStringAsFixed(2)}",
                            style: TextStyle(color: Colors.white, fontSize: 15.sp, fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPriceRow(String label, double amount, AppColorsExtension colors, bool isTotal) {
    return Row(
      children: [
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
