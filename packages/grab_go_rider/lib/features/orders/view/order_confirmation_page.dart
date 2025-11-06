import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';

class OrderConfirmationPage extends StatefulWidget {
  final String orderId;
  final String customerName;
  final String customerAddress;
  final String customerPhone;
  final String restaurantName;
  final String restaurantAddress;
  final String orderTotal;
  final List<String> orderItems;
  final String? specialInstructions;

  const OrderConfirmationPage({
    super.key,
    this.orderId = "ORD-12345",
    this.customerName = "John Doe",
    this.customerAddress = "123 Main Street, Accra, Ghana",
    this.customerPhone = "+233 123 456 789",
    this.restaurantName = "Pizza Palace",
    this.restaurantAddress = "456 Food Street, Accra, Ghana",
    this.orderTotal = "GHS 45.00",
    this.orderItems = const ["Pizza Margherita x1", "Coca Cola x2"],
    this.specialInstructions,
  });

  @override
  State<OrderConfirmationPage> createState() => _OrderConfirmationPageState();
}

class _OrderConfirmationPageState extends State<OrderConfirmationPage> {
  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarColor: colors.backgroundPrimary,
        systemNavigationBarDividerColor: Colors.transparent,
        systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: colors.backgroundSecondary,
        appBar: AppBar(
          backgroundColor: colors.backgroundPrimary,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            icon: SvgPicture.asset(
              Assets.icons.navArrowLeft,
              package: 'grab_go_shared',
              width: 24.w,
              height: 24.w,
              colorFilter: ColorFilter.mode(colors.textPrimary, BlendMode.srcIn),
            ),
            onPressed: () => context.pop(),
          ),
          title: Text(
            "Order Confirmation",
            style: TextStyle(
              fontFamily: "Lato",
              package: "grab_go_shared",
              color: colors.textPrimary,
              fontSize: 18.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
          centerTitle: true,
          actions: [
            Container(
              margin: EdgeInsets.all(8.w),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    _showCallOptions(context, colors);
                  },
                  customBorder: const CircleBorder(),
                  child: Padding(
                    padding: EdgeInsets.all(10.r),
                    child: Icon(Icons.more_vert, size: 20.r, color: colors.textPrimary),
                  ),
                ),
              ),
            ),
          ],
        ),
        body: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 20.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Order ID",
                          style: TextStyle(color: colors.textSecondary, fontSize: 12.sp, fontWeight: FontWeight.w400),
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          widget.orderId,
                          style: TextStyle(color: colors.textPrimary, fontSize: 18.sp, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                      decoration: BoxDecoration(
                        color: colors.accentOrange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
                      ),
                      child: Text(
                        "Pickup",
                        style: TextStyle(color: colors.accentOrange, fontSize: 12.sp, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 24.h),

                _buildRestaurantInfo(colors),

                SizedBox(height: 20.h),

                _buildOrderDetails(colors),

                SizedBox(height: 20.h),

                _buildCustomerInfo(colors),

                SizedBox(height: 32.h),

                _buildActionButtons(colors),

                SizedBox(height: 20.h),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRestaurantInfo(AppColorsExtension colors) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: colors.backgroundPrimary,
        borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
        border: Border.all(color: colors.border, width: 1),
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
                  borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
                ),
                child: SvgPicture.asset(
                  Assets.icons.chefHat,
                  package: 'grab_go_shared',
                  width: 20.w,
                  height: 20.w,
                  colorFilter: ColorFilter.mode(colors.accentOrange, BlendMode.srcIn),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Restaurant",
                      style: TextStyle(color: colors.textSecondary, fontSize: 11.sp, fontWeight: FontWeight.w400),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      widget.restaurantName,
                      style: TextStyle(color: colors.textPrimary, fontSize: 16.sp, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: SvgPicture.asset(
                  Assets.icons.phone,
                  package: 'grab_go_shared',
                  width: 20.w,
                  height: 20.w,
                  colorFilter: ColorFilter.mode(colors.accentGreen, BlendMode.srcIn),
                ),
                onPressed: () {
                  // Call restaurant
                },
              ),
            ],
          ),
          SizedBox(height: 16.h),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SvgPicture.asset(
                Assets.icons.mapPin,
                package: 'grab_go_shared',
                width: 16.w,
                height: 16.w,
                colorFilter: ColorFilter.mode(colors.textSecondary, BlendMode.srcIn),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(
                  widget.restaurantAddress,
                  style: TextStyle(color: colors.textPrimary, fontSize: 14.sp, fontWeight: FontWeight.w400),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerInfo(AppColorsExtension colors) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: colors.backgroundPrimary,
        borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
        border: Border.all(color: colors.border, width: 1),
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
                  borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
                ),
                child: SvgPicture.asset(
                  Assets.icons.user,
                  package: 'grab_go_shared',
                  width: 20.w,
                  height: 20.w,
                  colorFilter: ColorFilter.mode(colors.accentViolet, BlendMode.srcIn),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Customer",
                      style: TextStyle(color: colors.textSecondary, fontSize: 11.sp, fontWeight: FontWeight.w400),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      widget.customerName,
                      style: TextStyle(color: colors.textPrimary, fontSize: 16.sp, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: SvgPicture.asset(
                  Assets.icons.phone,
                  package: 'grab_go_shared',
                  width: 20.w,
                  height: 20.w,
                  colorFilter: ColorFilter.mode(colors.accentGreen, BlendMode.srcIn),
                ),
                onPressed: () {
                  // Call customer
                },
              ),
            ],
          ),
          SizedBox(height: 16.h),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SvgPicture.asset(
                Assets.icons.mapPin,
                package: 'grab_go_shared',
                width: 16.w,
                height: 16.w,
                colorFilter: ColorFilter.mode(colors.textSecondary, BlendMode.srcIn),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(
                  widget.customerAddress,
                  style: TextStyle(color: colors.textPrimary, fontSize: 14.sp, fontWeight: FontWeight.w400),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOrderDetails(AppColorsExtension colors) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: colors.backgroundPrimary,
        borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
        border: Border.all(color: colors.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Order Details",
                style: TextStyle(color: colors.textPrimary, fontSize: 16.sp, fontWeight: FontWeight.w700),
              ),
              Text(
                widget.orderTotal,
                style: TextStyle(color: colors.accentOrange, fontSize: 18.sp, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          ...widget.orderItems.map(
            (item) => Padding(
              padding: EdgeInsets.only(bottom: 8.h),
              child: Row(
                children: [
                  Container(
                    width: 6.w,
                    height: 6.w,
                    decoration: BoxDecoration(color: colors.textSecondary, shape: BoxShape.circle),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Text(
                      item,
                      style: TextStyle(color: colors.textPrimary, fontSize: 14.sp, fontWeight: FontWeight.w400),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (widget.specialInstructions != null) ...[
            SizedBox(height: 12.h),
            Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: colors.accentBlue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SvgPicture.asset(
                    Assets.icons.infoCircle,
                    package: 'grab_go_shared',
                    width: 16.w,
                    height: 16.w,
                    colorFilter: ColorFilter.mode(colors.accentBlue, BlendMode.srcIn),
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(
                      widget.specialInstructions!,
                      style: TextStyle(color: colors.textPrimary, fontSize: 12.sp, fontWeight: FontWeight.w400),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButtons(AppColorsExtension colors) {
    return Column(
      children: [
        _buildActionButton(
          icon: Assets.icons.deliveryTruck,
          label: "Navigate to Restaurant",
          onPressed: () {
            _navigateToTracking(phase: "pickup");
          },
          backgroundColor: colors.accentOrange,
          colors: colors,
        ),
        SizedBox(height: 12.h),
        _buildActionButton(
          icon: Assets.icons.check,
          label: "Confirm Pickup",
          onPressed: () {
            _showPickupConfirmDialog(colors);
          },
          backgroundColor: colors.accentGreen,
          colors: colors,
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required String icon,
    required String label,
    required VoidCallback onPressed,
    required Color backgroundColor,
    required AppColorsExtension colors,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 14.h),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SvgPicture.asset(
                icon,
                package: 'grab_go_shared',
                width: 18.w,
                height: 18.w,
                colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
              ),
              SizedBox(width: 8.w),
              Text(
                label,
                style: TextStyle(color: Colors.white, fontSize: 14.sp, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToTracking({required String phase}) {
    context.push(
      "/delivery-tracking",
      extra: {
        'orderId': widget.orderId,
        'customerName': widget.customerName,
        'customerAddress': widget.customerAddress,
        'customerPhone': widget.customerPhone,
        'restaurantName': widget.restaurantName,
        'restaurantAddress': widget.restaurantAddress,
        'orderTotal': widget.orderTotal,
        'orderItems': widget.orderItems,
        'specialInstructions': widget.specialInstructions,
        'phase': phase,
        'hasPickedUp': phase == "delivery",
      },
    );
  }

  void _showPickupConfirmDialog(AppColorsExtension colors) {
    AppDialog.show(
      context: context,
      title: "Confirm Pickup?",
      message: "Have you picked up the order from the restaurant?",
      type: AppDialogType.question,
      primaryButtonText: "Confirm",
      secondaryButtonText: "Cancel",
      primaryButtonColor: colors.accentGreen,
      borderRadius: KBorderSize.borderRadius4,
      buttonBorderRadius: KBorderSize.borderRadius4,
      onPrimaryPressed: () {
        Navigator.pop(context);
        _navigateToTracking(phase: "delivery");
      },
      onSecondaryPressed: () => Navigator.pop(context),
    );
  }

  void _showCallOptions(BuildContext context, AppColorsExtension colors) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: colors.backgroundPrimary,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(KBorderSize.borderRadius20),
            topRight: Radius.circular(KBorderSize.borderRadius20),
          ),
        ),
        padding: EdgeInsets.all(20.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40.w,
              height: 4.h,
              margin: EdgeInsets.only(bottom: 20.h),
              decoration: BoxDecoration(
                color: colors.textSecondary.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
            ListTile(
              leading: Container(
                padding: EdgeInsets.all(10.r),
                decoration: BoxDecoration(
                  color: colors.accentOrange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
                ),
                child: SvgPicture.asset(
                  Assets.icons.chefHat,
                  package: 'grab_go_shared',
                  width: 20.w,
                  height: 20.w,
                  colorFilter: ColorFilter.mode(colors.accentOrange, BlendMode.srcIn),
                ),
              ),
              title: Text(
                "Call Restaurant",
                style: TextStyle(color: colors.textPrimary, fontSize: 16.sp, fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                "Contact restaurant for order details",
                style: TextStyle(color: colors.textSecondary, fontSize: 12.sp),
              ),
              onTap: () {
                Navigator.pop(context);
                // Call restaurant
              },
            ),
            Divider(color: colors.border),
            ListTile(
              leading: Container(
                padding: EdgeInsets.all(10.r),
                decoration: BoxDecoration(
                  color: colors.accentViolet.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
                ),
                child: SvgPicture.asset(
                  Assets.icons.user,
                  package: 'grab_go_shared',
                  width: 20.w,
                  height: 20.w,
                  colorFilter: ColorFilter.mode(colors.accentViolet, BlendMode.srcIn),
                ),
              ),
              title: Text(
                "Call Customer",
                style: TextStyle(color: colors.textPrimary, fontSize: 16.sp, fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                widget.customerPhone,
                style: TextStyle(color: colors.textSecondary, fontSize: 12.sp),
              ),
              onTap: () {
                Navigator.pop(context);
                // Call customer
              },
            ),
            SizedBox(height: 20.h),
          ],
        ),
      ),
    );
  }
}
