import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_customer/features/cart/model/cart_item.dart' as cart_widgets;
import 'package:grab_go_customer/features/cart/model/cart_item_interface.dart';
import 'package:grab_go_customer/features/home/model/food_category.dart';
import 'package:grab_go_customer/features/groceries/model/grocery_item.dart';
import 'package:grab_go_customer/features/pharmacy/model/pharmacy_item.dart';
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
            final double rainFee = provider.rainFee;
            final double creditsApplied = provider.creditsApplied;
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
                          border: Border.all(color: colors.inputBorder.withValues(alpha: 0.3), width: 0.5),
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
                    ],
                  ),
                ),
                Divider(color: colors.backgroundSecondary, height: 1.h, thickness: 1),
                if (provider.cartItems.isEmpty)
                  _buildEmptyCart(context, colors)
                else
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const cart_widgets.CartItem(),
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
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: EdgeInsets.all(8.r),
                                        decoration: BoxDecoration(
                                          color: colors.accentOrange.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(8.r),
                                        ),
                                        child: SvgPicture.asset(
                                          Assets.icons.badgePercent,
                                          package: 'grab_go_shared',
                                          height: 20.h,
                                          width: 20.w,
                                          colorFilter: ColorFilter.mode(colors.accentOrange, BlendMode.srcIn),
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
                                        colorFilter: ColorFilter.mode(colors.accentOrange, BlendMode.srcIn),
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(height: 20.h),
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 8.h),
                                  decoration: BoxDecoration(
                                    color: colors.backgroundSecondary.withValues(alpha: 0.6),
                                    borderRadius: BorderRadius.circular(KBorderSize.borderMedium),
                                  ),
                                  child: Row(
                                    children: [
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            "Use Credits",
                                            style: TextStyle(
                                              color: colors.textPrimary,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 13.sp,
                                            ),
                                          ),
                                          SizedBox(height: 2.h),
                                          Text(
                                            "Apply your GrabGo credits to this order",
                                            style: TextStyle(
                                              color: colors.textSecondary,
                                              fontWeight: FontWeight.w500,
                                              fontSize: 11.sp,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const Spacer(),
                                      CustomSwitch(
                                        value: provider.useCredits,
                                        onChanged: (value) => provider.setUseCredits(value),
                                        activeColor: colors.accentOrange,
                                        inactiveColor: colors.backgroundSecondary,
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(height: 16.h),

                                Column(
                                  children: [
                                    _buildPriceRow(
                                      context,
                                      AppStrings.cartSubtotal,
                                      subtotal,
                                      colors,
                                      Assets.icons.cash,
                                      false,
                                      false,
                                    ),
                                    SizedBox(height: 6.h),
                                    _buildPriceRow(
                                      context,
                                      AppStrings.cartDeliveryFee,
                                      deliveryFee,
                                      colors,
                                      Assets.icons.deliveryTruck,
                                      false,
                                      true,
                                      infoType: _FeeInfoType.delivery,
                                    ),
                                    SizedBox(height: 6.h),
                                    _buildPriceRow(
                                      context,
                                      "Service Fee",
                                      serviceFee,
                                      colors,
                                      Assets.icons.deliveryTruck,
                                      false,
                                      true,
                                      infoType: _FeeInfoType.service,
                                    ),
                                    if (rainFee > 0) ...[
                                      SizedBox(height: 6.h),
                                      _buildPriceRow(
                                        context,
                                        "Rain Fee",
                                        rainFee,
                                        colors,
                                        Assets.icons.warningCircle,
                                        false,
                                        true,
                                        infoType: _FeeInfoType.rain,
                                      ),
                                    ],
                                    if (creditsApplied > 0) ...[
                                      SizedBox(height: 6.h),
                                      _buildPriceRow(
                                        context,
                                        "Credits Applied",
                                        -creditsApplied,
                                        colors,
                                        Assets.icons.gift,
                                        false,
                                        false,
                                      ),
                                    ],
                                    SizedBox(height: 6.h),
                                    _buildTotalRow(context, total, creditsApplied, colors),
                                  ],
                                ),
                                SizedBox(height: 12.h),
                                Padding(
                                  padding: EdgeInsets.only(bottom: 8.h),
                                  child: Text(
                                    _formatEstimatedDelivery(
                                      provider.cartItems,
                                      minMinutes: provider.estimatedDeliveryMin,
                                      maxMinutes: provider.estimatedDeliveryMax,
                                    ),
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
                      border: Border(top: BorderSide(color: colors.backgroundSecondary, width: 0.5)),
                    ),
                    child: AppButton(
                      width: double.infinity,
                      onPressed: () {
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
                      buttonText: "Proceed to Checkout",
                      textStyle: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w800),
                      textColor: provider.cartItems.isEmpty ? colors.textSecondary : Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 16.h),
                      borderRadius: KBorderSize.borderMedium,
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
              child: AppButton(
                width: double.infinity,
                onPressed: () => context.pop(),
                buttonText: "Browse",
                textStyle: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w800),
                textColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 16.h),
                borderRadius: KBorderSize.borderMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceRow(
    BuildContext context,
    String label,
    double amount,
    AppColorsExtension colors,
    String icon,
    bool isTotal,
    bool info, {
    _FeeInfoType? infoType,
  }) {
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
            ? Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: infoType == null ? null : () => _showFeeInfoSheet(context, colors, infoType),
                  borderRadius: BorderRadius.circular(999),
                  child: Padding(
                    padding: EdgeInsets.all(8.0.r),
                    child: SvgPicture.asset(
                      Assets.icons.infoCircle,
                      package: "grab_go_shared",
                      height: 10.h,
                      width: 10.w,
                      colorFilter: ColorFilter.mode(colors.textSecondary, BlendMode.srcIn),
                    ),
                  ),
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

  Widget _buildTotalRow(BuildContext context, double total, double creditsApplied, AppColorsExtension colors) {
    final double? originalTotal = creditsApplied > 0 ? total + creditsApplied : null;

    return Row(
      children: [
        Text(
          "Total Amount",
          style: TextStyle(color: colors.textSecondary, fontSize: 13.sp, fontWeight: FontWeight.w600),
        ),
        const Spacer(),
        if (originalTotal != null)
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: "${AppStrings.currencySymbol} ${originalTotal.toStringAsFixed(2)}",
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w400,
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
                TextSpan(
                  text: " / ",
                  style: TextStyle(color: colors.textSecondary, fontSize: 13.sp, fontWeight: FontWeight.w400),
                ),
                TextSpan(
                  text: "${AppStrings.currencySymbol} ${total.toStringAsFixed(2)}",
                  style: TextStyle(color: colors.textPrimary, fontSize: 13.sp, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          )
        else
          Text(
            "${AppStrings.currencySymbol} ${total.toStringAsFixed(2)}",
            style: TextStyle(color: colors.textPrimary, fontSize: 13.sp, fontWeight: FontWeight.w600),
          ),
      ],
    );
  }

  void _showFeeInfoSheet(BuildContext context, AppColorsExtension colors, _FeeInfoType type) {
    final title = type == _FeeInfoType.delivery
        ? "Delivery Fee"
        : type == _FeeInfoType.service
        ? "Service Fee"
        : "Rain Fee";
    final description = type == _FeeInfoType.delivery
        ? "This helps cover the cost of getting your order from the vendor to your door."
        : type == _FeeInfoType.service
        ? "This supports platform operations and keeps the service running smoothly."
        : "This is applied when it's raining to support safe and reliable deliveries.";

    final details = type == _FeeInfoType.delivery
        ? const [
            _FeeInfoDetail(
              title: "Distance-based",
              body: "Calculated using the distance from the vendor to your delivery address.",
            ),
            _FeeInfoDetail(
              title: "Fair limits",
              body: "A minimum and maximum are applied to keep pricing predictable.",
            ),
            _FeeInfoDetail(title: "Courier coverage", body: "Helps cover rider time, fuel, and delivery handling."),
          ]
        : type == _FeeInfoType.service
        ? const [
            _FeeInfoDetail(
              title: "Platform support",
              body: "Keeps the app running, including customer support and order processing.",
            ),
            _FeeInfoDetail(
              title: "Order value based",
              body: "Scales with your subtotal so larger orders contribute slightly more.",
            ),
            _FeeInfoDetail(
              title: "Lower delivery fees",
              body: "Helps reduce delivery charges by spreading costs across orders.",
            ),
          ]
        : const [
            _FeeInfoDetail(
              title: "Weather-based",
              body: "Applied only when active rain is detected for your delivery area.",
            ),
            _FeeInfoDetail(
              title: "Rider safety",
              body: "Helps cover extra time and protective handling in wet conditions.",
            ),
            _FeeInfoDetail(title: "Transparent pricing", body: "The fee is fixed and visible before checkout."),
          ];

    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 24.h),
          decoration: BoxDecoration(
            color: colors.backgroundPrimary,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36.w,
                  height: 4.h,
                  decoration: BoxDecoration(color: colors.divider, borderRadius: BorderRadius.circular(999)),
                ),
              ),
              SizedBox(height: 14.h),
              Row(
                children: [
                  Text(
                    title,
                    style: TextStyle(color: colors.textPrimary, fontSize: 16.sp, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              SizedBox(height: 8.h),
              Text(
                description,
                style: TextStyle(color: colors.textSecondary, fontSize: 12.sp, fontWeight: FontWeight.w500),
              ),
              SizedBox(height: 12.h),
              ...details.map((detail) => _buildInfoDetail(detail, colors)),
              SizedBox(height: 6.h),
              Text(
                "Fees can vary by location, vendor, and promotions.",
                style: TextStyle(color: colors.textSecondary, fontSize: 11.sp, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoDetail(_FeeInfoDetail detail, AppColorsExtension colors) {
    return Padding(
      padding: EdgeInsets.only(bottom: 10.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 6.w,
            height: 6.w,
            margin: EdgeInsets.only(top: 6.h),
            decoration: BoxDecoration(color: colors.accentOrange, shape: BoxShape.circle),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  detail.title,
                  style: TextStyle(color: colors.textPrimary, fontSize: 12.sp, fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 2.h),
                Text(
                  detail.body,
                  style: TextStyle(color: colors.textSecondary, fontSize: 11.sp, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
      ),
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

  String _formatEstimatedDelivery(Map<CartItem, int> cartItems, {int? minMinutes, int? maxMinutes}) {
    if (minMinutes != null && maxMinutes != null && minMinutes > 0 && maxMinutes > 0) {
      if (minMinutes == maxMinutes) {
        const padding = 5;
        minMinutes = math.max(5, minMinutes - padding);
        maxMinutes = maxMinutes + padding;
      }
      return "Est. Delivery: $minMinutes-$maxMinutes mins";
    }

    if (cartItems.isEmpty) {
      return "Est. Delivery: --";
    }

    final times = cartItems.keys
        .map(_deliveryMinutesForItem)
        .where((minutes) => minutes != null && minutes > 0)
        .cast<int>()
        .toList();

    if (times.isEmpty) {
      return "Est. Delivery: --";
    }

    var minTime = times.reduce((a, b) => a < b ? a : b);
    var maxTime = times.reduce((a, b) => a > b ? a : b);

    if (minTime == maxTime) {
      const padding = 5;
      minTime = math.max(5, minTime - padding);
      maxTime = maxTime + padding;
    }
    return "Est. Delivery: $minTime-$maxTime mins";
  }

  int? _deliveryMinutesForItem(CartItem item) {
    if (item is FoodItem) {
      return item.deliveryTimeMinutes;
    }
    if (item is GroceryItem) {
      return 45;
    }
    if (item is PharmacyItem) {
      return 30;
    }
    return 30;
  }
}

enum _FeeInfoType { delivery, service, rain }

class _FeeInfoDetail {
  final String title;
  final String body;

  const _FeeInfoDetail({required this.title, required this.body});
}
