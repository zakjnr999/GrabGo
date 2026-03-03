import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:grab_go_customer/features/cart/model/cart_item.dart' as cart_widgets;
import 'package:grab_go_customer/features/cart/model/cart_item_interface.dart';
import 'package:grab_go_customer/features/home/model/food_category.dart';
import 'package:grab_go_customer/features/groceries/model/grocery_item.dart';
import 'package:grab_go_customer/features/pharmacy/model/pharmacy_item.dart';
import 'package:grab_go_customer/shared/viewmodels/navigation_provider.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_customer/features/cart/viewmodel/cart_provider.dart';
import 'package:provider/provider.dart';
import 'package:grab_go_shared/grub_go_shared.dart';

class Cart extends StatelessWidget {
  const Cart({super.key});
  static final Uri _supportUrl = Uri.parse('https://grabgo.app/support');

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final padding = MediaQuery.of(context).padding;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final systemUiOverlayStyle = SystemUiOverlayStyle(
      statusBarColor: colors.backgroundPrimary,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      systemNavigationBarColor: colors.backgroundPrimary,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
    );

    SystemChrome.setSystemUIOverlayStyle(systemUiOverlayStyle);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: systemUiOverlayStyle,
      child: Scaffold(
        backgroundColor: colors.backgroundPrimary,
        body: Consumer<CartProvider>(
          builder: (context, provider, child) {
            final bool isPickupTab = context.watch<NavigationProvider>().selectedIndex == 1;
            if (isPickupTab && provider.fulfillmentMode != 'pickup') {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!context.mounted) return;
                context.read<CartProvider>().setFulfillmentMode('pickup');
              });
            }
            final double subtotal = provider.subtotal;
            final double deliveryFee = provider.deliveryFee;
            final double serviceFee = provider.serviceFee;
            final double rainFee = provider.rainFee;
            final double creditsApplied = provider.creditsApplied;
            final double total = provider.total;
            final bool isPricingLoading = provider.isPricingLoading;
            final bool hasCredits = provider.availableCredits > 0;
            final bool useCredits = hasCredits && provider.useCredits;
            final bool isPickupMode = provider.fulfillmentMode == 'pickup' || isPickupTab;
            final int itemCount = provider.cartItems.values.fold(0, (sum, quantity) => sum + quantity);
            final List<String> providerNames = provider.cartItems.keys
                .map((item) => item.providerName.trim())
                .where((name) => name.isNotEmpty)
                .toSet()
                .toList();
            final String providerLabel = providerNames.isEmpty
                ? 'Unknown vendor'
                : providerNames.length == 1
                ? providerNames.first
                : '${providerNames.length} vendors';
            return Column(
              children: [
                Padding(
                  padding: EdgeInsets.only(top: padding.top + 10, left: 20.w, right: 20.w, bottom: 16.h),
                  child: Row(
                    children: [
                      Container(
                        height: 44,
                        width: 44,
                        decoration: BoxDecoration(color: colors.backgroundSecondary, shape: BoxShape.circle),
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
                      const Spacer(),
                      _buildHeaderMenuButton(context, provider, colors),
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
                          Padding(
                            padding: EdgeInsets.fromLTRB(20.w, 10.h, 20.w, 6.h),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      "$itemCount ${itemCount == 1 ? 'item' : 'items'}",
                                      style: TextStyle(
                                        fontFamily: "Lato",
                                        package: 'grab_go_shared',
                                        color: colors.textSecondary,
                                        fontSize: 13.sp,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    SizedBox(width: 8.w),
                                    Container(
                                      width: 3.w,
                                      height: 3,
                                      decoration: BoxDecoration(shape: BoxShape.circle, color: colors.textSecondary),
                                    ),
                                    SizedBox(width: 8.w),
                                    Text(
                                      providerLabel,
                                      style: TextStyle(
                                        fontFamily: "Lato",
                                        package: 'grab_go_shared',
                                        color: colors.textSecondary,
                                        fontSize: 13.sp,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
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
                                          borderRadius: BorderRadius.circular(KBorderSize.borderMedium),
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
                                if (!isPickupMode && provider.providerCount <= 1) ...[
                                  SizedBox(height: 12.h),
                                  _buildGiftEntry(provider, colors),
                                ],
                                SizedBox(height: 20.h),
                                Row(
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
                                          hasCredits
                                              ? "Apply your GrabGo credits to this order"
                                              : "No GrabGo credits available yet. Earn credits from \nreferrals.",
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
                                      value: useCredits,
                                      onChanged: (value) {
                                        if (!hasCredits) return;
                                        provider.setUseCredits(value);
                                      },
                                      activeColor: colors.accentOrange,
                                    ),
                                  ],
                                ),
                                SizedBox(height: 16.h),

                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Padding(
                                      padding: EdgeInsets.fromLTRB(0.w, 0.h, 20.w, 16.h),
                                      child: Text(
                                        "Order Summary",
                                        style: TextStyle(
                                          fontFamily: "Lato",
                                          package: 'grab_go_shared',
                                          color: colors.textPrimary,
                                          fontSize: 16.sp,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
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
                                    if (!isPickupMode)
                                      _buildPriceRow(
                                        context,
                                        AppStrings.cartDeliveryFee,
                                        deliveryFee,
                                        colors,
                                        Assets.icons.deliveryTruck,
                                        false,
                                        true,
                                        infoType: _FeeInfoType.delivery,
                                        isLoading: isPricingLoading,
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
                                      isLoading: isPricingLoading,
                                    ),
                                    if (!isPickupMode && rainFee > 0) ...[
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
                                    _buildTotalRow(context, total, creditsApplied, colors, isLoading: isPricingLoading),
                                  ],
                                ),
                                SizedBox(height: 12.h),
                                Padding(
                                  padding: EdgeInsets.only(bottom: 8.h),
                                  child: Text(
                                    _formatEstimatedDelivery(
                                      provider.cartItems,
                                      providerCount: provider.providerCount,
                                      minMinutes: provider.estimatedDeliveryMin,
                                      maxMinutes: provider.estimatedDeliveryMax,
                                      completionMinMinutes: provider.estimatedDeliveryCompletionMin,
                                      completionMaxMinutes: provider.estimatedDeliveryCompletionMax,
                                      isPickupMode: isPickupMode,
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
                      onPressed: () async {
                        if (provider.hasPendingCartOperations) return;
                        if (provider.cartItems.isEmpty) {
                          AppToastMessage.show(
                            context: context,
                            message: AppStrings.cartEmpty,
                            backgroundColor: colors.error,
                          );
                        } else {
                          final navigationProvider = context.read<NavigationProvider>();
                          final targetMode = navigationProvider.selectedIndex == 1
                              ? 'pickup'
                              : provider.fulfillmentMode;
                          if (provider.fulfillmentMode != targetMode) {
                            await provider.setFulfillmentMode(targetMode);
                          }
                          if (!context.mounted) return;
                          context.push("/checkout");
                        }
                      },
                      buttonText: provider.hasPendingCartOperations
                          ? "Updating cart..."
                          : (isPickupMode ? "Proceed to Pickup Checkout" : "Proceed to Checkout"),
                      textStyle: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w800),
                      textColor: provider.cartItems.isEmpty || provider.hasPendingCartOperations
                          ? colors.textSecondary
                          : Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 16.h),
                      backgroundColor: provider.hasPendingCartOperations
                          ? colors.accentOrange.withValues(alpha: 0.6)
                          : colors.accentOrange,
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
            SvgPicture.asset(Assets.icons.emptyCart, package: 'grab_go_shared', width: 180.w, height: 180.w),

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
    bool isLoading = false,
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
        isLoading
            ? Text(
                "...",
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: 13.sp,
                  fontWeight: isTotal ? FontWeight.w600 : FontWeight.w400,
                ),
              )
            : Text(
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

  Widget _buildHeaderMenuButton(BuildContext context, CartProvider provider, AppColorsExtension colors) {
    return CustomPopupMenu(
      menuWidth: 220.w,
      showArrow: false,
      items: [
        CustomPopupMenuItem(
          value: 'clear_cart',
          label: 'Clear Cart',
          icon: Assets.icons.brushCleaning,
          iconColor: colors.textSecondary,
          isDestructive: true,
        ),
        CustomPopupMenuItem(
          value: 'refresh_prices',
          label: 'Refresh Prices',
          icon: Assets.icons.refresh,
          iconColor: colors.textSecondary,
        ),
        CustomPopupMenuItem(
          value: 'need_help',
          label: 'Need Help?',
          icon: Assets.icons.headsetHelp,
          iconColor: colors.textSecondary,
        ),
      ],
      onSelected: (value) => _onHeaderMenuSelected(context: context, provider: provider, value: value),
      child: _buildHeaderCircleButton(icon: Assets.icons.moreVertical, colors: colors),
    );
  }

  Widget _buildHeaderCircleButton({required String icon, required AppColorsExtension colors}) {
    return Container(
      height: 44,
      width: 44,
      decoration: BoxDecoration(color: colors.backgroundSecondary, shape: BoxShape.circle),
      child: Padding(
        padding: EdgeInsets.all(10.r),
        child: SvgPicture.asset(
          icon,
          package: 'grab_go_shared',
          colorFilter: ColorFilter.mode(colors.textPrimary, BlendMode.srcIn),
        ),
      ),
    );
  }

  Future<void> _onHeaderMenuSelected({
    required BuildContext context,
    required CartProvider provider,
    required String value,
  }) async {
    switch (value) {
      case 'clear_cart':
        await _confirmClearCart(context, provider);
        return;
      case 'refresh_prices':
        await _refreshCartPricing(context, provider);
        return;
      case 'need_help':
        await _openSupport(context);
        return;
    }
  }

  Future<void> _confirmClearCart(BuildContext context, CartProvider provider) async {
    if (provider.cartItems.isEmpty) {
      AppToastMessage.show(
        context: context,
        message: 'Cart is already empty.',
        backgroundColor: context.appColors.error,
      );
      return;
    }

    final shouldClear = await AppDialog.show(
      context: context,
      title: 'Clear Cart',
      message: 'Remove all items from your cart?',
      type: AppDialogType.warning,
      primaryButtonText: 'Clear Cart',
      secondaryButtonText: 'Cancel',
      primaryButtonColor: Colors.red,
      onPrimaryPressed: () => Navigator.of(context).pop(true),
      onSecondaryPressed: () => Navigator.of(context).pop(false),
    );

    if (shouldClear == true) {
      await provider.clearCart();
    }
  }

  Future<void> _refreshCartPricing(BuildContext context, CartProvider provider) async {
    try {
      await provider.syncFromBackend();
      if (!context.mounted) return;
      AppToastMessage.show(context: context, message: 'Prices refreshed.');
    } catch (_) {
      if (!context.mounted) return;
      AppToastMessage.show(
        context: context,
        backgroundColor: context.appColors.error,
        message: 'Unable to refresh prices right now.',
      );
    }
  }

  Future<void> _openSupport(BuildContext context) async {
    try {
      final launched = await launchUrl(_supportUrl, mode: LaunchMode.externalApplication);
      if (launched || !context.mounted) return;
      AppToastMessage.show(
        context: context,
        backgroundColor: context.appColors.error,
        message: 'Unable to open support right now. Please try again.',
      );
    } catch (_) {
      if (!context.mounted) return;
      AppToastMessage.show(
        context: context,
        backgroundColor: context.appColors.error,
        message: 'Unable to open support right now. Please try again.',
      );
    }
  }

  Widget _buildGiftEntry(CartProvider provider, AppColorsExtension colors) {
    final isGiftEnabled = provider.isGiftOrderDraftEnabled;
    final recipientName = provider.giftRecipientNameDraft.trim();
    final giftSummary = !isGiftEnabled
        ? "Recipient details are completed in checkout."
        : recipientName.isNotEmpty
        ? "Recipient: $recipientName"
        : "Recipient details are completed in checkout.";

    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(8.r),
          decoration: BoxDecoration(
            color: colors.accentOrange.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(KBorderSize.borderMedium),
          ),
          child: SvgPicture.asset(
            Assets.icons.gift,
            package: 'grab_go_shared',
            height: 20.h,
            width: 20.w,
            colorFilter: ColorFilter.mode(colors.accentOrange, BlendMode.srcIn),
          ),
        ),
        SizedBox(width: 10.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Send as a gift",
                style: TextStyle(color: colors.textPrimary, fontSize: 13.sp, fontWeight: FontWeight.w700),
              ),
              SizedBox(height: 2.h),
              Text(
                giftSummary,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: colors.textSecondary, fontSize: 11.sp, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
        CustomSwitch(
          value: provider.isGiftOrderDraftEnabled,
          onChanged: provider.setGiftOrderDraftEnabled,
          activeColor: colors.accentOrange,
        ),
      ],
    );
  }

  Widget _buildTotalRow(
    BuildContext context,
    double total,
    double creditsApplied,
    AppColorsExtension colors, {
    bool isLoading = false,
  }) {
    if (isLoading) {
      return Row(
        children: [
          Text(
            "Total Amount",
            style: TextStyle(color: colors.textPrimary, fontSize: 16.sp, fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          Text(
            "...",
            style: TextStyle(color: colors.textPrimary, fontSize: 16.sp, fontWeight: FontWeight.w600),
          ),
        ],
      );
    }

    final double? originalTotal = creditsApplied > 0 ? total + creditsApplied : null;

    return Row(
      children: [
        Text(
          "Total Amount",
          style: TextStyle(color: colors.textPrimary, fontSize: 16.sp, fontWeight: FontWeight.w600),
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
                  style: TextStyle(color: colors.textPrimary, fontSize: 16.sp, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          )
        else
          Text(
            "${AppStrings.currencySymbol} ${total.toStringAsFixed(2)}",
            style: TextStyle(color: colors.textPrimary, fontSize: 16.sp, fontWeight: FontWeight.w600),
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
        return SafeArea(
          child: Container(
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

  String _formatEstimatedDelivery(
    Map<CartItem, int> cartItems, {
    int providerCount = 1,
    int? minMinutes,
    int? maxMinutes,
    int? completionMinMinutes,
    int? completionMaxMinutes,
    bool isPickupMode = false,
  }) {
    final prefix = isPickupMode ? "Est. Pickup" : "Est. Delivery";
    String formatWindow(int start, int end) {
      if (start == end) {
        const padding = 5;
        start = math.max(5, start - padding);
        end = end + padding;
      }
      return "$start-$end mins";
    }

    if (!isPickupMode &&
        providerCount > 1 &&
        completionMinMinutes != null &&
        completionMaxMinutes != null &&
        completionMinMinutes > 0 &&
        completionMaxMinutes > 0) {
      final completionWindow = formatWindow(completionMinMinutes, completionMaxMinutes);
      return "All deliveries by: $completionWindow";
    }

    if (!isPickupMode &&
        providerCount > 1 &&
        minMinutes != null &&
        maxMinutes != null &&
        minMinutes > 0 &&
        maxMinutes > 0) {
      return "All deliveries by: ${formatWindow(minMinutes, maxMinutes)}";
    }

    if (minMinutes != null && maxMinutes != null && minMinutes > 0 && maxMinutes > 0) {
      return "$prefix: ${formatWindow(minMinutes, maxMinutes)}";
    }

    if (cartItems.isEmpty) {
      return "$prefix: --";
    }

    final times = cartItems.keys
        .map(_deliveryMinutesForItem)
        .where((minutes) => minutes != null && minutes > 0)
        .cast<int>()
        .toList();

    if (times.isEmpty) {
      return "$prefix: --";
    }

    var minTime = times.reduce((a, b) => a < b ? a : b);
    var maxTime = times.reduce((a, b) => a > b ? a : b);

    if (minTime == maxTime) {
      const padding = 5;
      minTime = math.max(5, minTime - padding);
      maxTime = maxTime + padding;
    }
    return "$prefix: $minTime-$maxTime mins";
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
