import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_customer/features/cart/model/cart_item_interface.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_customer/features/cart/viewmodel/cart_provider.dart';
import 'package:grab_go_customer/shared/models/address_model.dart';
import 'package:grab_go_customer/shared/viewmodels/native_location_provider.dart';
import 'package:grab_go_customer/features/home/model/food_category.dart';
import 'package:grab_go_customer/features/groceries/model/grocery_item.dart';
import 'package:grab_go_customer/features/pharmacy/model/pharmacy_item.dart';
import 'package:provider/provider.dart';
import 'package:grab_go_shared/grub_go_shared.dart';

class Checkout extends StatefulWidget {
  const Checkout({super.key});

  @override
  State<Checkout> createState() => _CheckoutState();
}

class _CheckoutState extends State<Checkout> {
  String _selectedAddress = "Home";
  String _selectedAddressDetails = "Madina, Adenta";
  String _selectedPaymentMethod = "Credit Card";
  double? _selectedLatitude;
  double? _selectedLongitude;
  final List<String> _selectedInstructions = [];
  bool _showCustomInstruction = false;
  final List<String> _selectedDeliveryInstructions = [];
  bool _showCustomDeliveryInstruction = false;
  bool _showCustomTip = false;
  double _tipAmount = 0.0;

  final TextEditingController _restaurantInstructionController = TextEditingController();
  final TextEditingController _deliveryInstructionController = TextEditingController();

  @override
  void dispose() {
    _restaurantInstructionController.dispose();
    _deliveryInstructionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final padding = MediaQuery.of(context).padding;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final locationProvider = context.watch<NativeLocationProvider>();
    final cartProvider = context.read<CartProvider>();
    final confirmedAddress = locationProvider.confirmedAddress;

    final bool hasInitialCoords = _selectedLatitude != null && _selectedLongitude != null;
    final double? fallbackLat = confirmedAddress?.latitude ?? locationProvider.latitude;
    final double? fallbackLng = confirmedAddress?.longitude ?? locationProvider.longitude;
    if (!hasInitialCoords && fallbackLat != null && fallbackLng != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _selectedLatitude = fallbackLat;
          _selectedLongitude = fallbackLng;
        });
        cartProvider.updateDeliveryLocation(latitude: fallbackLat, longitude: fallbackLng);
      });
    }

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
            final double total = provider.total + _tipAmount;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
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
                        "Checkout",
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
                Divider(color: colors.backgroundSecondary, height: 1.h, thickness: 1),
                // Scrollable content
                Expanded(
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Shipping Address Section
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
                          child: Text(
                            "Delivery Address",
                            style: TextStyle(
                              fontFamily: "Lato",
                              package: 'grab_go_shared',
                              color: colors.textPrimary,
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        SizedBox(height: 10.h),

                        _buildAddressTile(
                          id: "Home",
                          title: "Home",
                          phone: "(233) 55 250 1805",
                          address: confirmedAddress?.label == AddressLabel.home
                              ? confirmedAddress!.formattedAddress
                              : "Madina, Adenta",
                          latitude: confirmedAddress?.label == AddressLabel.home ? confirmedAddress!.latitude : null,
                          longitude: confirmedAddress?.label == AddressLabel.home ? confirmedAddress!.longitude : null,
                          context: context,
                        ),
                        _buildAddressTile(
                          id: "Office",
                          title: "Office",
                          phone: "(233) 55 250 1805",
                          address: confirmedAddress?.label == AddressLabel.work
                              ? confirmedAddress!.formattedAddress
                              : "Kasoa, Millennium City",
                          latitude: confirmedAddress?.label == AddressLabel.work ? confirmedAddress!.latitude : null,
                          longitude: confirmedAddress?.label == AddressLabel.work ? confirmedAddress!.longitude : null,
                          context: context,
                        ),
                        _buildCurrentLocationTile(context),

                        SizedBox(height: 8.h),

                        // Special Instructions Section
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
                          child: Text(
                            "Special Instructions",
                            style: TextStyle(
                              fontFamily: "Lato",
                              package: 'grab_go_shared',
                              color: colors.textPrimary,
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),

                        // Quick-select instruction chips
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 20.w),
                          child: Wrap(
                            spacing: 8.w,
                            runSpacing: 8.h,
                            children: [
                              _buildInstructionChip("No onions", colors),
                              _buildInstructionChip("Extra sauce", colors),
                              _buildInstructionChip("Less spicy", colors),
                              _buildInstructionChip("No ice", colors),
                              _buildInstructionChip("Cutlery included", colors),
                              _buildInstructionChip("Extra napkins", colors),
                              _buildCustomInstructionChip(colors),
                            ],
                          ),
                        ),

                        // Show custom text field only when Custom is selected
                        if (_showCustomInstruction) ...[
                          SizedBox(height: 12.h),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 20.w),
                            child: Container(
                              padding: EdgeInsets.all(16.r),
                              decoration: BoxDecoration(
                                color: colors.backgroundPrimary,
                                borderRadius: BorderRadius.circular(12.r),
                                border: Border.all(color: colors.inputBorder.withValues(alpha: 0.3), width: 0.5),
                              ),
                              child: TextField(
                                controller: _restaurantInstructionController,
                                maxLines: 3,
                                style: TextStyle(
                                  color: colors.textPrimary,
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w500,
                                ),
                                decoration: InputDecoration(
                                  hintText: "Add notes for the restaurant (e.g., no onions, extra sauce)",
                                  hintStyle: TextStyle(
                                    color: colors.textSecondary,
                                    fontSize: 13.sp,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ),
                            ),
                          ),
                        ],

                        SizedBox(height: 16.h),

                        // Delivery Instructions Section
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
                          child: Text(
                            "Delivery Instructions",
                            style: TextStyle(
                              fontFamily: "Lato",
                              package: 'grab_go_shared',
                              color: colors.textPrimary,
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),

                        // Delivery instruction chips
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 20.w),
                          child: Wrap(
                            spacing: 8.w,
                            runSpacing: 8.h,
                            children: [
                              _buildDeliveryInstructionChip("Leave at door", colors),
                              _buildDeliveryInstructionChip("Ring doorbell", colors),
                              _buildDeliveryInstructionChip("Text on arrival", colors),
                              _buildDeliveryInstructionChip("Call on arrival", colors),
                              _buildCustomDeliveryInstructionChip(colors),
                            ],
                          ),
                        ),

                        // Show custom delivery instruction field only when Custom is selected
                        if (_showCustomDeliveryInstruction) ...[
                          SizedBox(height: 12.h),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 20.w),
                            child: Container(
                              padding: EdgeInsets.all(16.r),
                              decoration: BoxDecoration(
                                color: colors.backgroundPrimary,
                                borderRadius: BorderRadius.circular(12.r),
                                border: Border.all(color: colors.inputBorder.withValues(alpha: 0.3), width: 0.5),
                              ),
                              child: TextField(
                                controller: _deliveryInstructionController,
                                maxLines: 2,
                                style: TextStyle(
                                  color: colors.textPrimary,
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w500,
                                ),
                                decoration: InputDecoration(
                                  hintText: "Enter custom delivery instructions",
                                  hintStyle: TextStyle(
                                    color: colors.textSecondary,
                                    fontSize: 13.sp,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ),
                            ),
                          ),
                        ],

                        SizedBox(height: 16.h),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
                          child: Text(
                            "Tip Delivery Driver",
                            style: TextStyle(
                              fontFamily: "Lato",
                              package: 'grab_go_shared',
                              color: colors.textPrimary,
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),

                        // Tip amount chips
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 20.w),
                          child: Wrap(
                            spacing: 8.w,
                            runSpacing: 8.h,
                            children: [
                              _buildTipChip(0.0, "No tip", colors),
                              _buildTipChip(2.0, "GHS 2", colors),
                              _buildTipChip(5.0, "GHS 5", colors),
                              _buildTipChip(10.0, "GHS 10", colors),
                              _buildCustomTipChip(colors),
                            ],
                          ),
                        ),

                        // Show custom tip field only when Custom is selected
                        if (_showCustomTip) ...[
                          SizedBox(height: 12.h),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 20.w),
                            child: Container(
                              padding: EdgeInsets.all(16.r),
                              decoration: BoxDecoration(
                                color: colors.backgroundPrimary,
                                borderRadius: BorderRadius.circular(12.r),
                                border: Border.all(color: colors.inputBorder.withValues(alpha: 0.3), width: 0.5),
                              ),
                              child: TextField(
                                keyboardType: TextInputType.number,
                                onChanged: (value) {
                                  final amount = double.tryParse(value);
                                  if (amount != null && amount >= 0) {
                                    setState(() {
                                      _tipAmount = amount;
                                    });
                                  }
                                },
                                style: TextStyle(
                                  color: colors.textPrimary,
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w500,
                                ),
                                decoration: InputDecoration(
                                  hintText: "Enter custom tip amount (GHS)",
                                  prefixText: "GHS ",
                                  hintStyle: TextStyle(
                                    color: colors.textSecondary,
                                    fontSize: 13.sp,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ),
                            ),
                          ),
                        ],
                        SizedBox(height: 16.h),

                        // Order Summary Section
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
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

                        // Pricing breakdown (matches cart page)
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 20.w),
                          child: Column(
                            children: [
                              _buildPriceRow(context, "Subtotal", subtotal, colors, false, false),
                              SizedBox(height: 6.h),
                              _buildPriceRow(
                                context,
                                "Delivery Fee",
                                deliveryFee,
                                colors,
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
                                  false,
                                  true,
                                  infoType: _FeeInfoType.rain,
                                ),
                              ],
                              // Tax removed (kept in pricing for backend compatibility)
                              if (_tipAmount > 0) ...[
                                SizedBox(height: 6.h),
                                _buildPriceRow(context, "Tip", _tipAmount, colors, false, false),
                              ],
                              SizedBox(height: 6.h),
                              _buildPriceRow(context, "Total Amount", total, colors, true, false),
                            ],
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 8.h),
                          child: Text(
                            _formatEstimatedDelivery(
                              provider.cartItems,
                              minMinutes: provider.estimatedDeliveryMin,
                              maxMinutes: provider.estimatedDeliveryMax,
                            ),
                            style: TextStyle(color: colors.textSecondary, fontSize: 12.sp, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                Container(
                  padding: EdgeInsets.only(left: 20.w, right: 20.w, top: 16.h, bottom: padding.bottom + 16.h),
                  decoration: BoxDecoration(
                    color: colors.backgroundPrimary,
                    border: Border(top: BorderSide(color: colors.textPrimary.withValues(alpha: 0.1), width: 0.5)),
                  ),
                  child: GestureDetector(
                    onTap: () {
                      if (_selectedLatitude != null && _selectedLongitude != null) {
                        cartProvider.updateDeliveryLocation(latitude: _selectedLatitude, longitude: _selectedLongitude);
                      }
                      context.push(
                        "/orderSummary",
                        extra: {
                          'address': _selectedAddress,
                          'addressDetails': _selectedAddressDetails,
                          'latitude': _selectedLatitude,
                          'longitude': _selectedLongitude,
                          'payment': _selectedPaymentMethod,
                          'selectedInstructions': _selectedInstructions,
                          'customRestaurantInstruction': _restaurantInstructionController.text,
                          'selectedDeliveryInstructions': _selectedDeliveryInstructions,
                          'customDeliveryInstruction': _deliveryInstructionController.text,
                          'tipAmount': _tipAmount,
                        },
                      );
                    },
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        splashColor: Colors.white.withValues(alpha: 0.2),
                        child: Container(
                          width: double.infinity,
                          padding: EdgeInsets.symmetric(vertical: 16.h),
                          decoration: BoxDecoration(
                            color: colors.accentOrange,
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                          child: Center(
                            child: Text(
                              "Proceed to Order Summary",
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15.sp),
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

  Widget _buildPriceRow(
    BuildContext context,
    String label,
    double amount,
    AppColorsExtension colors,
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
          "GHS ${amount.toStringAsFixed(2)}",
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: 13.sp,
            fontWeight: isTotal ? FontWeight.w600 : FontWeight.w400,
          ),
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
              Text(
                title,
                style: TextStyle(color: colors.textPrimary, fontSize: 16.sp, fontWeight: FontWeight.w800),
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

  Widget _buildInstructionChip(String label, AppColorsExtension colors) {
    final bool isSelected = _selectedInstructions.contains(label);

    return GestureDetector(
      onTap: () {
        setState(() {
          if (isSelected) {
            _selectedInstructions.remove(label);
          } else {
            _selectedInstructions.add(label);
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: isSelected ? colors.accentOrange : colors.backgroundSecondary,
          borderRadius: BorderRadius.circular(20.r),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : colors.textPrimary,
            fontSize: 13.sp,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildCustomInstructionChip(AppColorsExtension colors) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _showCustomInstruction = !_showCustomInstruction;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: _showCustomInstruction ? colors.accentOrange : colors.backgroundSecondary,
          borderRadius: BorderRadius.circular(20.r),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Custom",
              style: TextStyle(
                color: _showCustomInstruction ? Colors.white : colors.textPrimary,
                fontSize: 13.sp,
                fontWeight: _showCustomInstruction ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
            SizedBox(width: 4.w),
            SvgPicture.asset(
              _showCustomInstruction ? Assets.icons.navArrowUp : Assets.icons.navArrowDown,
              package: 'grab_go_shared',
              height: 16.h,
              width: 16.w,
              colorFilter: ColorFilter.mode(
                _showCustomInstruction ? Colors.white : colors.textPrimary,
                BlendMode.srcIn,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeliveryInstructionChip(String label, AppColorsExtension colors) {
    final bool isSelected = _selectedDeliveryInstructions.contains(label);

    return GestureDetector(
      onTap: () {
        setState(() {
          if (isSelected) {
            _selectedDeliveryInstructions.remove(label);
          } else {
            _selectedDeliveryInstructions.add(label);
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: isSelected ? colors.accentOrange : colors.backgroundSecondary,
          borderRadius: BorderRadius.circular(20.r),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : colors.textPrimary,
            fontSize: 13.sp,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildCustomDeliveryInstructionChip(AppColorsExtension colors) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _showCustomDeliveryInstruction = !_showCustomDeliveryInstruction;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: _showCustomDeliveryInstruction ? colors.accentOrange : colors.backgroundSecondary,
          borderRadius: BorderRadius.circular(20.r),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Custom",
              style: TextStyle(
                color: _showCustomDeliveryInstruction ? Colors.white : colors.textPrimary,
                fontSize: 13.sp,
                fontWeight: _showCustomDeliveryInstruction ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
            SizedBox(width: 4.w),
            SvgPicture.asset(
              _showCustomDeliveryInstruction ? Assets.icons.navArrowUp : Assets.icons.navArrowDown,
              package: 'grab_go_shared',
              height: 16.h,
              width: 16.w,
              colorFilter: ColorFilter.mode(
                _showCustomDeliveryInstruction ? Colors.white : colors.textPrimary,
                BlendMode.srcIn,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTipChip(double amount, String label, AppColorsExtension colors) {
    final bool isSelected = _tipAmount == amount;

    return GestureDetector(
      onTap: () {
        setState(() {
          _tipAmount = amount;
          _showCustomTip = false;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: isSelected ? colors.accentOrange : colors.backgroundSecondary,
          borderRadius: BorderRadius.circular(20.r),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : colors.textPrimary,
            fontSize: 13.sp,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildCustomTipChip(AppColorsExtension colors) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _showCustomTip = !_showCustomTip;
          if (!_showCustomTip) {
            _tipAmount = 0.0;
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: _showCustomTip ? colors.accentOrange : colors.backgroundSecondary,
          borderRadius: BorderRadius.circular(20.r),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Custom",
              style: TextStyle(
                color: _showCustomTip ? Colors.white : colors.textPrimary,
                fontSize: 13.sp,
                fontWeight: _showCustomTip ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
            SizedBox(width: 4.w),
            SvgPicture.asset(
              _showCustomTip ? Assets.icons.navArrowUp : Assets.icons.navArrowDown,
              package: 'grab_go_shared',
              height: 16.h,
              width: 16.w,
              colorFilter: ColorFilter.mode(_showCustomTip ? Colors.white : colors.textPrimary, BlendMode.srcIn),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddressTile({
    required String id,
    required String title,
    required String phone,
    required String address,
    double? latitude,
    double? longitude,
    required BuildContext context,
  }) {
    final colors = context.appColors;
    final bool isSelected = _selectedAddress == id;
    final cartProvider = context.read<CartProvider>();

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedAddress = id;
          _selectedAddressDetails = address;
          _selectedLatitude = latitude;
          _selectedLongitude = longitude;
        });
        if (latitude != null && longitude != null) {
          cartProvider.updateDeliveryLocation(latitude: latitude, longitude: longitude);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: EdgeInsets.symmetric(horizontal: 20.w, vertical: 6.h),
        padding: EdgeInsets.all(16.r),
        decoration: BoxDecoration(
          color: colors.backgroundPrimary,
          borderRadius: BorderRadius.circular(KBorderSize.borderRadius15),
          border: Border.all(color: colors.inputBorder.withValues(alpha: 0.5), width: 1),
        ),
        child: Row(
          children: [
            Container(
              height: 24.h,
              width: 24.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? colors.accentOrange.withValues(alpha: 0.1) : Colors.transparent,
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        height: 10.h,
                        width: 10.w,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: colors.accentOrange),
                      ),
                    )
                  : null,
            ),
            SizedBox(width: 14.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                        decoration: BoxDecoration(
                          color: isSelected ? colors.accentOrange.withValues(alpha: 0.15) : colors.backgroundSecondary,
                          borderRadius: BorderRadius.circular(6.r),
                        ),
                        child: Text(
                          title,
                          style: TextStyle(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w700,
                            color: isSelected ? colors.accentOrange : colors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8.h),
                  Row(
                    children: [
                      SvgPicture.asset(
                        Assets.icons.phone,
                        package: 'grab_go_shared',
                        height: 12.h,
                        width: 12.w,
                        colorFilter: ColorFilter.mode(colors.textSecondary, BlendMode.srcIn),
                      ),
                      SizedBox(width: 6.w),
                      Text(
                        phone,
                        style: TextStyle(fontSize: 12.sp, color: colors.textSecondary, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                  SizedBox(height: 4.h),
                  Row(
                    children: [
                      SvgPicture.asset(
                        Assets.icons.mapPin,
                        package: 'grab_go_shared',
                        height: 12.h,
                        width: 12.w,
                        colorFilter: ColorFilter.mode(colors.textSecondary, BlendMode.srcIn),
                      ),
                      SizedBox(width: 6.w),
                      Expanded(
                        child: Text(
                          address,
                          style: TextStyle(fontSize: 12.sp, color: colors.textSecondary, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(width: 8.w),
            Container(
              padding: EdgeInsets.all(8.r),
              decoration: BoxDecoration(color: colors.backgroundSecondary, shape: BoxShape.circle),
              child: SvgPicture.asset(
                Assets.icons.edit,
                package: 'grab_go_shared',
                height: 16.h,
                width: 16.w,
                colorFilter: ColorFilter.mode(colors.textPrimary, BlendMode.srcIn),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentLocationTile(BuildContext context) {
    final colors = context.appColors;
    final bool isSelected = _selectedAddress == "Current Location";
    final locationProvider = context.read<NativeLocationProvider>();
    final cartProvider = context.read<CartProvider>();
    final double? latitude = locationProvider.latitude;
    final double? longitude = locationProvider.longitude;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedAddress = "Current Location";
          _selectedAddressDetails = "Tap to use your current GPS location";
          _selectedLatitude = latitude;
          _selectedLongitude = longitude;
        });
        if (latitude != null && longitude != null) {
          cartProvider.updateDeliveryLocation(latitude: latitude, longitude: longitude);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: EdgeInsets.symmetric(horizontal: 20.w, vertical: 6.h),
        padding: EdgeInsets.all(16.r),
        decoration: BoxDecoration(
          color: colors.backgroundPrimary,
          borderRadius: BorderRadius.circular(KBorderSize.borderRadius15),
          border: Border.all(color: colors.inputBorder.withValues(alpha: 0.5), width: 1),
        ),
        child: Row(
          children: [
            // Location Pin Icon
            Container(
              height: 50.h,
              width: 50.w,
              decoration: BoxDecoration(
                color: colors.accentOrange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: Center(
                child: SvgPicture.asset(
                  Assets.icons.mapPin,
                  package: 'grab_go_shared',
                  height: 28.h,
                  width: 28.w,
                  colorFilter: ColorFilter.mode(colors.accentOrange, BlendMode.srcIn),
                ),
              ),
            ),
            SizedBox(width: 14.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                        decoration: BoxDecoration(
                          color: isSelected ? colors.accentOrange.withValues(alpha: 0.15) : colors.backgroundSecondary,
                          borderRadius: BorderRadius.circular(6.r),
                        ),
                        child: Text(
                          "Use Current Location",
                          style: TextStyle(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w700,
                            color: isSelected ? colors.accentOrange : colors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    "Tap to use your current GPS location",
                    style: TextStyle(fontSize: 12.sp, color: colors.textSecondary, fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Container(
              height: 24.h,
              width: 24.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? colors.accentOrange.withValues(alpha: 0.1) : Colors.transparent,
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        height: 10.h,
                        width: 10.w,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: colors.accentOrange),
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  String _formatEstimatedDelivery(
    Map<CartItem, int> cartItems, {
    int? minMinutes,
    int? maxMinutes,
  }) {
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
