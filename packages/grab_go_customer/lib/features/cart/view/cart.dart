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

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        systemNavigationBarColor: colors.backgroundSecondary,
        systemNavigationBarDividerColor: Colors.transparent,
      ),
      child: Scaffold(
        appBar: AppBar(
          elevation: 0,
          scrolledUnderElevation: 0,
          automaticallyImplyLeading: false,
          backgroundColor: colors.backgroundSecondary,
          title: Padding(
            padding: EdgeInsets.symmetric(horizontal: 8.w),
            child: Row(
              children: [
                Container(
                  height: 44.h,
                  width: 44.w,
                  decoration: BoxDecoration(
                    color: colors.backgroundPrimary,
                    shape: BoxShape.circle,
                    border: Border.all(color: colors.inputBorder.withOpacity(0.3), width: 0.5),
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
                    border: Border.all(color: colors.inputBorder.withOpacity(0.3), width: 0.5),
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
                        decoration: BoxDecoration(color: colors.accentOrange.withOpacity(0.1), shape: BoxShape.circle),
                        child: SvgPicture.asset(
                          Assets.icons.cart,
                          package: 'grab_go_shared',
                          height: 16.h,
                          width: 16.w,
                          colorFilter: ColorFilter.mode(colors.accentOrange, BlendMode.srcIn),
                        ),
                      ),
                      SizedBox(width: 8.w),
                      Text(
                        AppStrings.cartMyCart,
                        style: TextStyle(
                          fontFamily: "Lato",
                          package: 'grab_go_shared',
                          color: colors.textPrimary,
                          fontSize: 17.sp,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                AppPopupMenu(
                  items: [
                    AppPopupMenuItem(
                      value: 'clear_all',
                      label: AppStrings.cartClearCart,
                      icon: Assets.icons.binMinusIn,
                      isDanger: true,
                    ),
                  ],
                  onSelected: (value) {
                    switch (value) {
                      case "clear_all":
                        _showClearAllDialog(context, colors);
                    }
                  },
                  child: Container(
                    height: 44.h,
                    width: 44.w,
                    decoration: BoxDecoration(
                      color: colors.backgroundPrimary,
                      shape: BoxShape.circle,
                      border: Border.all(color: colors.inputBorder.withOpacity(0.3), width: 0.5),
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
                        customBorder: const CircleBorder(),
                        child: Padding(
                          padding: EdgeInsets.all(10.r),
                          child: Icon(Icons.more_vert, size: 20, color: colors.textPrimary),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        backgroundColor: colors.backgroundSecondary,
        body: AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle(
            statusBarColor: colors.backgroundSecondary,
            statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
            systemNavigationBarColor: colors.backgroundPrimary,
            systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          ),
          child: const CartItem(),
        ),

        bottomNavigationBar: Consumer<CartProvider>(
          builder: (context, provider, child) {
            const double deliveryFee = 2.0;
            final double subtotal = provider.totalPrice;
            final double total = subtotal + deliveryFee;

            return Container(
              padding: EdgeInsets.only(left: 20.w, right: 20.w, top: 20.h, bottom: padding.bottom + 16.h),
              decoration: BoxDecoration(
                color: colors.backgroundPrimary,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(KBorderSize.border),
                  topRight: Radius.circular(KBorderSize.border),
                ),
                boxShadow: [
                  BoxShadow(
                    color: isDark ? Colors.black.withAlpha(40) : Colors.black.withAlpha(15),
                    spreadRadius: 0,
                    blurRadius: 20,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () async {
                      final promoCode = await PromoCodeDialog.show(
                        context: context,
                        onApply: (code) {
                          AppToastMessage.show(
                            context: context,
                            icon: Icons.check_circle,
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
                          colors: [colors.accentViolet.withOpacity(0.1), colors.accentOrange.withOpacity(0.1)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12.r),
                        border: Border.all(color: colors.accentViolet.withOpacity(0.2), width: 1),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(8.r),
                            decoration: BoxDecoration(
                              color: colors.accentViolet.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8.r),
                            ),
                            child: Assets.icons.discount.image(
                              height: 20.h,
                              width: 20.w,
                              color: colors.accentViolet,
                              package: 'grab_go_shared',
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

                  Container(
                    padding: EdgeInsets.all(14.r),
                    decoration: BoxDecoration(
                      color: colors.backgroundSecondary,
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(color: colors.inputBorder.withOpacity(0.3), width: 0.5),
                    ),
                    child: Column(
                      children: [
                        _buildPriceRow(AppStrings.cartSubtotal, subtotal, colors, false),
                        SizedBox(height: 10.h),
                        _buildPriceRow(AppStrings.cartDeliveryFee, deliveryFee, colors, false),
                        SizedBox(height: 12.h),
                        DottedLine(
                          direction: Axis.horizontal,
                          lineLength: double.infinity,
                          lineThickness: 1.5,
                          dashLength: 6,
                          dashColor: colors.inputBorder.withOpacity(0.5),
                          dashGapLength: 4,
                        ),
                        SizedBox(height: 12.h),
                        _buildPriceRow(AppStrings.cartTotalAmount, total, colors, true),
                      ],
                    ),
                  ),
                  SizedBox(height: 16.h),

                  GestureDetector(
                    onTap: () {
                      if (provider.cartItems.isEmpty) {
                        AppToastMessage.show(
                          context: context,
                          icon: Icons.close,
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
                        splashColor: Colors.white.withValues(alpha: 2),
                        child: Container(
                          padding: EdgeInsets.symmetric(vertical: 16.h),
                          decoration: BoxDecoration(
                            color: provider.cartItems.isEmpty ? colors.inputBorder : colors.accentOrange,
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                AppStrings.cartProceedToCheckout,
                                style: TextStyle(
                                  color: provider.cartItems.isEmpty ? colors.textSecondary : Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15.sp,
                                ),
                              ),
                              SizedBox(width: 8.w),
                              SvgPicture.asset(
                                Assets.icons.navArrowRight,
                                package: 'grab_go_shared',
                                height: 18.h,
                                width: 18.w,
                                colorFilter: ColorFilter.mode(
                                  provider.cartItems.isEmpty ? colors.textSecondary : Colors.white,
                                  BlendMode.srcIn,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
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
          "${AppStrings.currencySymbol} ${amount.toStringAsFixed(2)}",
          style: TextStyle(
            color: isTotal ? colors.accentOrange : colors.textPrimary,
            fontSize: isTotal ? 16.sp : 13.sp,
            fontWeight: FontWeight.w800,
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
