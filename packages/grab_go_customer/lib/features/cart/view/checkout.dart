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
  String _selectedPaymentMethod = "Credit Card";

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
                  SizedBox(width: 8.w),
                  Text(
                    "Checkout",
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

            SizedBox(width: 44.w),
          ],
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
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: EdgeInsets.only(bottom: 120.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
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
                          "Shipping Address",
                          style: TextStyle(fontSize: 16.sp, color: colors.textPrimary, fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),

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

                  SizedBox(height: 8.h),

                  // Payment Method Section Header
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
                    child: Row(
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
                            height: 18.h,
                            width: 18.w,
                            colorFilter: ColorFilter.mode(colors.accentViolet, BlendMode.srcIn),
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Text(
                          "Payment Method",
                          style: TextStyle(fontSize: 16.sp, color: colors.textPrimary, fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),

                  _buildPaymentOption(
                    title: "Credit Card",
                    methodValue: "Credit Card",
                    assetPath: Assets.icons.cc.path,
                    context: context,
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
                ],
              ),
            ),
          ),
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
                  // Price Breakdown Card
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

                  // Proceed Button
                  GestureDetector(
                    onTap: () {
                      context.push(
                        "/orderSummary",
                        extra: {'address': _selectedAddress, 'payment': _selectedPaymentMethod},
                      );
                    },
                    child: Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(vertical: 16.h),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [colors.accentOrange, colors.accentOrange.withValues(alpha: 0.8)],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(KBorderSize.borderRadius15),
                        boxShadow: [
                          BoxShadow(
                            color: colors.accentOrange.withValues(alpha: 0.3),
                            spreadRadius: 0,
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Proceed to Order Summary",
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
            color: isTotal ? colors.accentOrange : colors.textPrimary,
            fontSize: isTotal ? 16.sp : 13.sp,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bool isSelected = _selectedAddress == id;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedAddress = id;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: EdgeInsets.symmetric(horizontal: 20.w, vertical: 6.h),
        padding: EdgeInsets.all(16.r),
        decoration: BoxDecoration(
          color: colors.backgroundPrimary,
          borderRadius: BorderRadius.circular(KBorderSize.borderRadius15),
          border: Border.all(
            color: isSelected ? colors.accentOrange : colors.inputBorder.withValues(alpha: 0.3),
            width: isSelected ? 1.5 : 0.5,
          ),
          boxShadow: [
            BoxShadow(
              color: isDark ? Colors.black.withAlpha(30) : Colors.black.withAlpha(8),
              spreadRadius: 0,
              blurRadius: isSelected ? 16 : 12,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              height: 24.h,
              width: 24.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: isSelected ? colors.accentOrange : colors.inputBorder, width: 2),
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

  Widget _buildPaymentOption({
    required String title,
    required String assetPath,
    required String methodValue,
    required BuildContext context,
  }) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
          border: Border.all(
            color: isSelected ? colors.accentViolet : colors.inputBorder.withValues(alpha: 0.3),
            width: isSelected ? 1.5 : 0.5,
          ),
          boxShadow: [
            BoxShadow(
              color: isDark ? Colors.black.withAlpha(30) : Colors.black.withAlpha(8),
              spreadRadius: 0,
              blurRadius: isSelected ? 16 : 12,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Payment Logo
            Container(
              height: 50.h,
              width: 60.w,
              decoration: BoxDecoration(
                color: colors.backgroundSecondary,
                borderRadius: BorderRadius.circular(10.r),
                border: Border.all(color: colors.inputBorder.withValues(alpha: 0.3), width: 0.5),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10.r),
                child: Image.asset(assetPath, package: 'grab_go_shared', fit: BoxFit.cover),
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
                border: Border.all(color: isSelected ? colors.accentViolet : colors.inputBorder, width: 2),
                color: isSelected ? colors.accentViolet.withValues(alpha: 0.1) : Colors.transparent,
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        height: 10.h,
                        width: 10.w,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: colors.accentViolet),
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
