// ignore_for_file: deprecated_member_use

import 'package:dotted_line/dotted_line.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_customer/features/cart/viewmodel/cart_provider.dart';
import 'package:provider/provider.dart';
import 'package:grab_go_shared/grub_go_shared.dart';

class PaymentComplete extends StatelessWidget {
  final String method;
  final double total;
  final double subTotal;
  final double deliveryFee;

  const PaymentComplete({
    super.key,
    required this.method,
    required this.total,
    required this.subTotal,
    required this.deliveryFee,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          Provider.of<CartProvider>(context, listen: false).clearCart();
          context.go("/homepage");
        }
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: colors.backgroundSecondary,
          automaticallyImplyLeading: false,
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
        backgroundColor: colors.backgroundSecondary,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 20.w),
            child: Column(
              children: [
                SizedBox(height: 40.h),

                // Success Icon
                Container(
                  height: 120.h,
                  width: 120.w,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [colors.accentGreen, colors.accentGreen.withOpacity(0.8)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: colors.accentGreen.withOpacity(0.3),
                        spreadRadius: 0,
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Center(
                    child: SvgPicture.asset(
                      Assets.icons.checkBig,
                      package: 'grab_go_shared',
                      height: 60.h,
                      width: 60.w,
                      colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                    ),
                  ),
                ),

                SizedBox(height: 32.h),

                // Success Title
                Text(
                  "Payment Successful!",
                  style: TextStyle(fontSize: 24.sp, color: colors.textPrimary, fontWeight: FontWeight.w800),
                  textAlign: TextAlign.center,
                ),

                SizedBox(height: 8.h),

                Text(
                  "Your order has been placed successfully",
                  style: TextStyle(fontSize: 13.sp, color: colors.textSecondary, fontWeight: FontWeight.w500),
                  textAlign: TextAlign.center,
                ),

                SizedBox(height: 32.h),

                // Payment Details Card
                Container(
                  padding: EdgeInsets.all(20.r),
                  decoration: BoxDecoration(
                    color: colors.backgroundPrimary,
                    borderRadius: BorderRadius.circular(KBorderSize.borderRadius15),
                    border: Border.all(color: colors.inputBorder.withOpacity(0.3), width: 0.5),
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
                              color: colors.accentViolet.withOpacity(0.1),
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
                            "Payment Details",
                            style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w800, color: colors.textPrimary),
                          ),
                        ],
                      ),
                      SizedBox(height: 20.h),

                      _buildDetailRow("Payment Method", method, colors, false),
                      SizedBox(height: 12.h),
                      _buildDetailRow("Subtotal", "GHS ${subTotal.toStringAsFixed(2)}", colors, false),
                      SizedBox(height: 12.h),
                      _buildDetailRow("Delivery Fee", "GHS ${deliveryFee.toStringAsFixed(2)}", colors, false),
                      SizedBox(height: 12.h),
                      _buildDetailRow("Date", "Oct 27, 2025", colors, false),

                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 16.h),
                        child: DottedLine(
                          dashLength: 6,
                          dashGapLength: 4,
                          lineThickness: 1.5,
                          dashColor: colors.inputBorder,
                        ),
                      ),

                      _buildDetailRow("Total Paid", "GHS ${total.toStringAsFixed(2)}", colors, true),
                    ],
                  ),
                ),

                SizedBox(height: 120.h),
              ],
            ),
          ),
        ),

        bottomNavigationBar: Container(
          padding: EdgeInsets.all(20.r),
          decoration: BoxDecoration(
            color: colors.backgroundPrimary,
            borderRadius: BorderRadius.only(topLeft: Radius.circular(24.r), topRight: Radius.circular(24.r)),
            border: Border(top: BorderSide(color: colors.inputBorder.withOpacity(0.3), width: 0.5)),
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
            child: GestureDetector(
              onTap: () {
                context.go("/orderTracking");
              },
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: 16.h),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [colors.accentOrange, colors.accentOrange.withOpacity(0.8)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(KBorderSize.borderRadius15),
                  boxShadow: [
                    BoxShadow(
                      color: colors.accentOrange.withOpacity(0.3),
                      spreadRadius: 0,
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Assets.icons.packageDelivered.image(
                      height: 20.h,
                      width: 20.w,
                      color: Colors.white,
                      colorBlendMode: BlendMode.srcIn,
                      package: 'grab_go_shared',
                    ),
                    SizedBox(width: 10.w),
                    Text(
                      "Track Your Order",
                      style: TextStyle(color: Colors.white, fontSize: 15.sp, fontWeight: FontWeight.w800),
                    ),
                    SizedBox(width: 8.w),
                    SvgPicture.asset(
                      Assets.icons.navArrowRight,
                      package: 'grab_go_shared',
                      height: 18.h,
                      width: 18.w,
                      colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, AppColorsExtension colors, bool isTotal) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isTotal ? 14.sp : 13.sp,
            color: isTotal ? colors.textPrimary : colors.textSecondary,
            fontWeight: isTotal ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isTotal ? 16.sp : 13.sp,
            color: isTotal ? colors.accentGreen : colors.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}
