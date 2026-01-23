import 'package:dotted_line/dotted_line.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_customer/features/cart/viewmodel/cart_provider.dart';
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
            const double deliveryFee = 2.0;
            final double subtotal = provider.totalPrice;
            final double total = subtotal + deliveryFee + _tipAmount;

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
                          child: Row(
                            children: [
                              SvgPicture.asset(
                                Assets.icons.mapPin,
                                package: 'grab_go_shared',
                                height: 18.h,
                                width: 18.w,
                                colorFilter: ColorFilter.mode(colors.accentOrange, BlendMode.srcIn),
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
                        SizedBox(height: 10.h),

                        _buildAddressTile(
                          id: "Home",
                          title: "Home",
                          phone: "(233) 55 250 1805",
                          address: "Madina, Adenta",
                          context: context,
                        ),
                        _buildAddressTile(
                          id: "Office",
                          title: "Office",
                          phone: "(233) 55 250 1805",
                          address: "Kasoa, Millennium City",
                          context: context,
                        ),
                        _buildCurrentLocationTile(context),

                        SizedBox(height: 8.h),

                        // Payment Method Section
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
                          child: Row(
                            children: [
                              SvgPicture.asset(
                                Assets.icons.cash,
                                package: 'grab_go_shared',
                                height: 18.h,
                                width: 18.w,
                                colorFilter: ColorFilter.mode(colors.accentOrange, BlendMode.srcIn),
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

                        _buildPaymentOption(
                          title: "MTN MOMO",
                          methodValue: "MTN MOMO",
                          assetPath: Assets.icons.mom.path,
                          context: context,
                        ),
                        _buildPaymentOption(
                          title: "Vodafone Cash",
                          methodValue: "Vodafone Cash",
                          assetPath: Assets.icons.vodafoneCash.path,
                          context: context,
                        ),

                        _buildPaymentOption(
                          title: "Credit Card",
                          methodValue: "Credit Card",
                          assetPath: Assets.icons.cc.path,
                          context: context,
                        ),

                        _buildPaymentOption(
                          title: "Payment on Delivery",
                          methodValue: "Payment on Delivery",
                          icon: Assets.icons.deliveryTruck,
                          context: context,
                        ),

                        SizedBox(height: 8.h),

                        // Special Instructions Section
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
                          child: Row(
                            children: [
                              SvgPicture.asset(
                                Assets.icons.squareMenu,
                                package: 'grab_go_shared',
                                height: 18.h,
                                width: 18.w,
                                colorFilter: ColorFilter.mode(colors.accentOrange, BlendMode.srcIn),
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
                          child: Row(
                            children: [
                              SvgPicture.asset(
                                Assets.icons.deliveryTruck,
                                package: 'grab_go_shared',
                                height: 18.h,
                                width: 18.w,
                                colorFilter: ColorFilter.mode(colors.accentOrange, BlendMode.srcIn),
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
                          child: Row(
                            children: [
                              SvgPicture.asset(
                                Assets.icons.handCash,
                                package: 'grab_go_shared',
                                height: 18.h,
                                width: 18.w,
                                colorFilter: ColorFilter.mode(colors.accentOrange, BlendMode.srcIn),
                              ),
                              SizedBox(width: 12.w),
                              Text(
                                "Tip Delivery Driver",
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
                          child: Row(
                            children: [
                              SvgPicture.asset(
                                Assets.icons.squareMenu,
                                package: 'grab_go_shared',
                                height: 18.h,
                                width: 18.w,
                                colorFilter: ColorFilter.mode(colors.accentOrange, BlendMode.srcIn),
                              ),
                              SizedBox(width: 12.w),
                              Text(
                                "Order Summary",
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

                        // Pricing breakdown
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
                                _buildPriceRowWithIcon("Subtotal", subtotal, colors, Assets.icons.cash, false),
                                SizedBox(height: 10.h),
                                _buildPriceRowWithIcon(
                                  "Delivery Fee",
                                  deliveryFee,
                                  colors,
                                  Assets.icons.deliveryTruck,
                                  false,
                                ),
                                if (_tipAmount > 0) ...[
                                  SizedBox(height: 10.h),
                                  _buildPriceRowWithIcon("Tip", _tipAmount, colors, Assets.icons.handCash, false),
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
                                    color: colors.accentOrange.withValues(alpha: 0.1),
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
                                          color: colors.accentOrange,
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
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 8.h),
                          child: Text(
                            "Est. Delivery: 30-45 mins",
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
                      context.push(
                        "/orderSummary",
                        extra: {
                          'address': _selectedAddress,
                          'addressDetails': _selectedAddressDetails,
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

  Widget _buildPriceRowWithIcon(String label, double amount, AppColorsExtension colors, String icon, bool isTotal) {
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
        SizedBox(width: 8.w),
        Text(
          label,
          style: TextStyle(color: colors.textSecondary, fontSize: 13.sp, fontWeight: FontWeight.w500),
        ),
        const Spacer(),
        Text(
          "GHS ${amount.toStringAsFixed(2)}",
          style: TextStyle(color: colors.textPrimary, fontSize: 13.sp, fontWeight: FontWeight.w800),
        ),
      ],
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
    required BuildContext context,
  }) {
    final colors = context.appColors;
    final bool isSelected = _selectedAddress == id;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedAddress = id;
          _selectedAddressDetails = address;
        });
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

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedAddress = "Current Location";
          _selectedAddressDetails = "Tap to use your current GPS location";
        });
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
              // child: Center(child: Icon(Icons.my_location, color: colors.accentOrange, size: 24)),
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

  Widget _buildPaymentOption({
    required String title,
    String? assetPath,
    String? icon,
    required String methodValue,
    required BuildContext context,
  }) {
    final colors = context.appColors;
    final bool isSelected = _selectedPaymentMethod == methodValue;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedPaymentMethod = methodValue;
        });
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
            // Payment Logo or Icon
            Container(
              height: 50.h,
              width: 60.w,
              decoration: BoxDecoration(
                color: icon != null ? colors.accentOrange.withValues(alpha: 0.1) : colors.backgroundSecondary,
                borderRadius: BorderRadius.circular(10.r),
                border: icon == null ? Border.all(color: colors.inputBorder.withValues(alpha: 0.3), width: 0.5) : null,
              ),
              child: icon != null
                  ? Center(
                      child: SvgPicture.asset(
                        icon,
                        package: 'grab_go_shared',
                        height: 28.h,
                        width: 28.w,
                        colorFilter: ColorFilter.mode(colors.accentOrange, BlendMode.srcIn),
                      ),
                    )
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(10.r),
                      child: Image.asset(assetPath!, package: 'grab_go_shared', fit: BoxFit.cover),
                    ),
            ),
            SizedBox(width: 14.w),
            Expanded(
              child: Text(
                title,
                style: TextStyle(fontSize: 14.sp, color: colors.textPrimary, fontWeight: FontWeight.w700),
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
}
