// ignore_for_file: deprecated_member_use

import 'package:dotted_line/dotted_line.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_customer/features/cart/model/cart_item.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_customer/features/cart/viewmodel/cart_provider.dart';
import 'package:provider/provider.dart';
import 'package:grab_go_shared/grub_go_shared.dart';

class Cart extends StatelessWidget {
  const Cart({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final padding = MediaQuery.of(context).padding;
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
        backgroundColor: colors.backgroundPrimary,
        body: Consumer<CartProvider>(
          builder: (context, provider, child) {
            final double subtotal = provider.subtotal;
            final double deliveryFee = provider.deliveryFee;
            final double serviceFee = provider.serviceFee;
            final double tax = provider.tax;
            final double total = provider.total;

            return Column(
              children: [
                // Header
                Padding(
                  padding: EdgeInsets.only(top: padding.top, left: 20.w, right: 20.w, bottom: 16.h),
                  child: Row(
                    children: [
                      Container(
                        height: 44.h,
                        width: 44.w,
                        decoration: BoxDecoration(
                          color: colors.backgroundSecondary,
                          shape: BoxShape.circle,
                          border: Border.all(color: colors.inputBorder.withOpacity(0.3), width: 0.5),
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
                        "Cart",
                        style: TextStyle(
                          fontFamily: "Lato",
                          package: 'grab_go_shared',
                          color: colors.textPrimary,
                          fontSize: 20.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      // if (provider.cartItems.isNotEmpty) ...[
                      //   SizedBox(width: 8.w),
                      //   Container(
                      //     padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                      //     decoration: BoxDecoration(
                      //       color: colors.accentOrange,
                      //       borderRadius: BorderRadius.circular(12.r),
                      //     ),
                      //     child: Text(
                      //       "${provider.cartItems.length}",
                      //       style: TextStyle(color: Colors.white, fontSize: 12.sp, fontWeight: FontWeight.w700),
                      //     ),
                      //   ),
                      // ],
                    ],
                  ),
                ),
                Divider(color: colors.backgroundSecondary, height: 1.h, thickness: 1),
                if (provider.cartItems.isEmpty)
                  _buildEmptyCart(context, colors)
                else
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const CartItem(),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                GestureDetector(
                                  onTap: () async {
                                    final promoCode = await PromoCodeDialog.show(
                                      context: context,
                                      onApply: (code) {
                                        AppToastMessage.show(
                                          context: context,
                                          message: 'Promo code "$code" applied successfully!',
                                          backgroundColor: colors.accentGreen,
                                        );
                                      },
                                    );

                                    if (promoCode != null) {
                                      debugPrint('Promo code applied: $promoCode');
                                    }
                                  },
                                  child: Container(
                                    padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          colors.accentViolet.withOpacity(0.1),
                                          colors.accentOrange.withOpacity(0.1),
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(12.r),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: EdgeInsets.all(8.r),
                                          decoration: BoxDecoration(
                                            color: colors.accentViolet.withOpacity(0.15),
                                            borderRadius: BorderRadius.circular(8.r),
                                          ),
                                          child: SvgPicture.asset(
                                            Assets.icons.badgePercent,
                                            package: 'grab_go_shared',
                                            height: 20.h,
                                            width: 20.w,
                                            colorFilter: ColorFilter.mode(colors.accentViolet, BlendMode.srcIn),
                                          ),
                                        ),
                                        SizedBox(width: 12.w),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                AppStrings.cartPromoCode,
                                                style: TextStyle(
                                                  color: colors.textPrimary,
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 13.sp,
                                                ),
                                              ),
                                              SizedBox(height: 2.h),
                                              Text(
                                                AppStrings.cartPromoCodeSub,
                                                style: TextStyle(
                                                  color: colors.textSecondary,
                                                  fontWeight: FontWeight.w500,
                                                  fontSize: 11.sp,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        SvgPicture.asset(
                                          Assets.icons.navArrowRight,
                                          package: 'grab_go_shared',
                                          height: 18.h,
                                          width: 18.w,
                                          colorFilter: ColorFilter.mode(colors.accentViolet, BlendMode.srcIn),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                SizedBox(height: 16.h),

                                Column(
                                  children: [
                                    _buildPriceRow(
                                      AppStrings.cartSubtotal,
                                      subtotal,
                                      colors,
                                      Assets.icons.cash,
                                      false,
                                      false,
                                    ),
                                    SizedBox(height: 6.h),
                                    _buildPriceRow(
                                      AppStrings.cartDeliveryFee,
                                      deliveryFee,
                                      colors,
                                      Assets.icons.deliveryTruck,
                                      false,
                                      true,
                                    ),
                                    SizedBox(height: 6.h),
                                    _buildPriceRow(
                                      "Service Fee",
                                      serviceFee,
                                      colors,
                                      Assets.icons.deliveryTruck,
                                      false,
                                      true,
                                    ),
                                    if (tax > 0) ...[
                                      SizedBox(height: 6.h),
                                      _buildPriceRow(
                                        "Tax",
                                        tax,
                                        colors,
                                        Assets.icons.cash,
                                        false,
                                        false,
                                      ),
                                    ],
                                    SizedBox(height: 6.h),
                                    _buildPriceRow(
                                      "Total Amount",
                                      total,
                                      colors,
                                      Assets.icons.deliveryTruck,
                                      true,
                                      false,
                                    ),
                                  ],
                                ),
                                SizedBox(height: 12.h),
                                // Estimated delivery time
                                Padding(
                                  padding: EdgeInsets.only(bottom: 8.h),
                                  child: Text(
                                    "Est. Delivery: 30-45 mins",
                                    style: TextStyle(
                                      color: colors.textSecondary,
                                      fontSize: 12.sp,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                if (provider.cartItems.isEmpty)
                  const SizedBox.shrink()
                else
                  Container(
                    padding: EdgeInsets.only(left: 20.w, right: 20.w, top: 16.h, bottom: padding.bottom + 16.h),
                    decoration: BoxDecoration(
                      color: colors.backgroundPrimary,
                      border: Border(top: BorderSide(color: colors.textPrimary.withOpacity(0.1), width: 0.5)),
                    ),
                    child: GestureDetector(
                      onTap: () {
                        if (provider.cartItems.isEmpty) {
                          AppToastMessage.show(
                            context: context,
                            message: AppStrings.cartEmpty,
                            backgroundColor: colors.error,
                          );
                        } else {
                          context.push("/checkout");
                        }
                      },
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          splashColor: Colors.white.withOpacity(0.2),
                          child: Container(
                            width: double.infinity,
                            padding: EdgeInsets.symmetric(vertical: 16.h),
                            decoration: BoxDecoration(
                              color: provider.cartItems.isEmpty ? colors.inputBorder : colors.accentOrange,
                              borderRadius: BorderRadius.circular(12.r),
                              boxShadow: [
                                BoxShadow(
                                  color: colors.accentOrange.withValues(alpha: 0.3),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                  spreadRadius: 0,
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                AppStrings.cartProceedToCheckout,
                                style: TextStyle(
                                  color: provider.cartItems.isEmpty ? colors.textSecondary : Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15.sp,
                                ),
                              ),
                            ),
                          ),
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

  Widget _buildEmptyCart(BuildContext context, AppColorsExtension colors) {
    return Expanded(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              AppStrings.cartEmpty,
              style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.w800, color: colors.textPrimary),
            ),
            SizedBox(height: 8.h),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 40.w),
              child: Text(
                AppStrings.cartEmptyMessage,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w500, color: colors.textSecondary),
              ),
            ),
            SizedBox(height: KSpacing.xl.h),

            Container(
              padding: EdgeInsets.symmetric(horizontal: 20.w),
              decoration: BoxDecoration(color: colors.backgroundSecondary),
              child: GestureDetector(
                onTap: context.pop,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    splashColor: Colors.white.withOpacity(0.2),
                    child: Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(vertical: 16.h),
                      decoration: BoxDecoration(
                        color: colors.accentOrange,
                        borderRadius: BorderRadius.circular(12.r),
                        boxShadow: [
                          BoxShadow(
                            color: colors.accentOrange.withValues(alpha: 0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                            spreadRadius: 0,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          "Browse offers",
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15.sp),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceRow(String label, double amount, AppColorsExtension colors, String icon, bool isTotal, bool info) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            color: colors.textSecondary,
            fontSize: 13.sp,
            fontWeight: isTotal ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
        info
            ? Padding(
                padding: EdgeInsets.all(8.0.r),
                child: SvgPicture.asset(
                  Assets.icons.infoCircle,
                  package: "grab_go_shared",
                  height: 10.h,
                  width: 10.w,
                  colorFilter: ColorFilter.mode(colors.textSecondary, BlendMode.srcIn),
                ),
              )
            : const SizedBox.shrink(),
        const Spacer(),
        Text(
          "${AppStrings.currencySymbol} ${amount.toStringAsFixed(2)}",
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: 13.sp,
            fontWeight: isTotal ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ],
    );
  }

  void _showClearAllDialog(BuildContext context, colors) async {
    final shouldClear = await AppDialog.show(
      context: context,
      title: AppStrings.cartClearCart,
      message: AppStrings.cartClearCartMessage,
      type: AppDialogType.warning,
      icon: Assets.icons.cart,
      primaryButtonText: AppStrings.cartClearCart,
      secondaryButtonText: AppStrings.cartCancel,
      primaryButtonColor: Colors.red,
      onPrimaryPressed: () => Navigator.of(context).pop(true),
      onSecondaryPressed: () => Navigator.of(context).pop(false),
    );

    if (shouldClear == true) {
      Provider.of<CartProvider>(context, listen: false).clearCart();
      context.go("/homepage");
    }
  }
}
