import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';

class DeliveryTrackingPage extends StatefulWidget {
  final String orderId;
  final String customerName;
  final String customerAddress;
  final String customerPhone;
  final String restaurantName;
  final String restaurantAddress;
  final String orderTotal;
  final List<String> orderItems;
  final String? specialInstructions;
  final String? phase;
  final bool? hasPickedUp;

  const DeliveryTrackingPage({
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
    this.phase,
    this.hasPickedUp,
  });

  @override
  State<DeliveryTrackingPage> createState() => _DeliveryTrackingPageState();
}

class _DeliveryTrackingPageState extends State<DeliveryTrackingPage> {
  late String _currentPhase;
  double _estimatedTime = 12.0;
  double _distance = 4.5;
  bool _isNavigating = false;
  bool _showBottomSheet = true;

  @override
  void initState() {
    super.initState();
    _currentPhase = widget.phase ?? "pickup";
    if (_currentPhase == "delivery") {
      _estimatedTime = 15.0;
      _distance = 5.2;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final size = MediaQuery.of(context).size;
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
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: Container(
            margin: EdgeInsets.all(8.w),
            decoration: BoxDecoration(
              color: colors.backgroundPrimary.withValues(alpha: 0.9),
              shape: BoxShape.circle,
              border: Border.all(color: colors.border.withValues(alpha: 0.3), width: 1),
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
          actions: [
            Container(
              margin: EdgeInsets.all(8.w),
              decoration: BoxDecoration(
                color: colors.backgroundPrimary.withValues(alpha: 0.9),
                shape: BoxShape.circle,
                border: Border.all(color: colors.border.withValues(alpha: 0.3), width: 1),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    _showCallOptions(context, colors);
                  },
                  customBorder: const CircleBorder(),
                  child: Padding(
                    padding: EdgeInsets.all(10.r),
                    child: SvgPicture.asset(
                      Assets.icons.phone,
                      package: 'grab_go_shared',
                      colorFilter: ColorFilter.mode(colors.textPrimary, BlendMode.srcIn),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        body: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _showBottomSheet = false;
                  });
                },
                child: Image.asset(Assets.images.deliveryGuyBicycle.path, package: 'grab_go_shared', fit: BoxFit.cover),
              ),
            ),

            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.black.withValues(alpha: 0.1), Colors.black.withValues(alpha: 0.6)],
                  ),
                ),
              ),
            ),

            if (_showBottomSheet)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  height: size.height * 0.45,
                  decoration: BoxDecoration(
                    color: colors.backgroundPrimary,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(KBorderSize.borderRadius20),
                      topRight: Radius.circular(KBorderSize.borderRadius20),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isDark ? Colors.black.withAlpha(30) : Colors.black.withAlpha(8),
                        spreadRadius: 0,
                        blurRadius: 12,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          margin: EdgeInsets.only(top: 12.h),
                          width: 40.w,
                          height: 4.h,
                          decoration: BoxDecoration(
                            color: colors.textSecondary.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(2.r),
                          ),
                        ),

                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    widget.orderId,
                                    style: TextStyle(
                                      color: colors.textPrimary,
                                      fontSize: 16.sp,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Container(
                                    padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                                    decoration: BoxDecoration(
                                      color: (_currentPhase == "pickup" ? colors.accentOrange : colors.accentGreen)
                                          .withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
                                    ),
                                    child: Text(
                                      _currentPhase == "pickup" ? "Pickup" : "In Transit",
                                      style: TextStyle(
                                        color: _currentPhase == "pickup" ? colors.accentOrange : colors.accentGreen,
                                        fontSize: 12.sp,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              SizedBox(height: 16.h),

                              _buildDestinationInfo(colors),

                              SizedBox(height: 16.h),

                              Container(
                                padding: EdgeInsets.all(16.w),
                                decoration: BoxDecoration(
                                  color: colors.backgroundSecondary,
                                  borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
                                  border: Border.all(color: colors.border.withValues(alpha: 0.3), width: 1),
                                ),
                                child: Row(
                                  children: [
                                    _buildInfoItem(
                                      icon: Assets.icons.timer,
                                      label: "ETA",
                                      value: "${_estimatedTime.toInt()} min",
                                      iconColor: colors.accentOrange,
                                      colors: colors,
                                    ),
                                    Container(
                                      width: 1,
                                      height: 40.h,
                                      color: colors.border,
                                      margin: EdgeInsets.symmetric(horizontal: 16.w),
                                    ),
                                    _buildInfoItem(
                                      icon: Assets.icons.mapPin,
                                      label: "Distance",
                                      value: "${_distance.toStringAsFixed(1)} km",
                                      iconColor: colors.accentBlue,
                                      colors: colors,
                                    ),
                                  ],
                                ),
                              ),

                              SizedBox(height: 20.h),

                              _buildActionButtons(colors),

                              SizedBox(height: 20.h),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            if (!_showBottomSheet)
              Positioned(
                bottom: 20.h,
                left: 0,
                right: 0,
                child: Center(
                  child: FloatingActionButton.extended(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(KBorderSize.borderRadius4)),
                    onPressed: () {
                      setState(() {
                        _showBottomSheet = true;
                      });
                    },
                    backgroundColor: colors.backgroundPrimary,
                    icon: SvgPicture.asset(
                      Assets.icons.mapPin,
                      package: 'grab_go_shared',
                      width: 20.w,
                      height: 20.w,
                      colorFilter: ColorFilter.mode(colors.textPrimary, BlendMode.srcIn),
                    ),
                    label: Text(
                      "Show Details",
                      style: TextStyle(color: colors.textPrimary, fontSize: 14.sp, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDestinationInfo(AppColorsExtension colors) {
    final isPickup = _currentPhase == "pickup";
    final destinationName = isPickup ? widget.restaurantName : widget.customerName;
    final destinationAddress = isPickup ? widget.restaurantAddress : widget.customerAddress;

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: colors.backgroundSecondary,
        borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
        border: Border.all(color: colors.border, width: 1),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8.r),
            decoration: BoxDecoration(
              color: (isPickup ? colors.accentOrange : colors.accentViolet).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
            ),
            child: SvgPicture.asset(
              isPickup ? Assets.icons.chefHat : Assets.icons.user,
              package: 'grab_go_shared',
              width: 20.w,
              height: 20.w,
              colorFilter: ColorFilter.mode(isPickup ? colors.accentOrange : colors.accentViolet, BlendMode.srcIn),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isPickup ? "Restaurant" : "Customer",
                  style: TextStyle(color: colors.textSecondary, fontSize: 11.sp, fontWeight: FontWeight.w400),
                ),
                SizedBox(height: 4.h),
                Text(
                  destinationName,
                  style: TextStyle(color: colors.textPrimary, fontSize: 15.sp, fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 4.h),
                Text(
                  destinationAddress,
                  style: TextStyle(color: colors.textSecondary, fontSize: 12.sp, fontWeight: FontWeight.w400),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
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
            onPressed: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem({
    required String icon,
    required String label,
    required String value,
    required Color iconColor,
    required AppColorsExtension colors,
  }) {
    return Expanded(
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8.r),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
            ),
            child: SvgPicture.asset(
              icon,
              package: 'grab_go_shared',
              width: 20.w,
              height: 20.w,
              colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(color: colors.textSecondary, fontSize: 11.sp, fontWeight: FontWeight.w400),
                ),
                SizedBox(height: 2.h),
                Text(
                  value,
                  style: TextStyle(color: colors.textPrimary, fontSize: 16.sp, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(AppColorsExtension colors) {
    if (_currentPhase == "pickup") {
      return Column(
        children: [
          _buildActionButton(
            icon: Assets.icons.deliveryTruck,
            label: _isNavigating ? "Stop Navigation" : "Navigate to Restaurant",
            onPressed: () {
              setState(() {
                if (!_isNavigating) {
                  _showBottomSheet = false;
                }
                _isNavigating = !_isNavigating;
              });
            },
            backgroundColor: _isNavigating ? colors.textSecondary : colors.accentOrange,
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
    } else {
      return Row(
        children: [
          Expanded(
            child: _buildActionButton(
              icon: Assets.icons.navArrowRight,
              label: _isNavigating ? "Stop Navigation" : "Navigate to Customer",
              onPressed: () {
                setState(() {
                  if (!_isNavigating) {
                    _showBottomSheet = false;
                  }
                  _isNavigating = !_isNavigating;
                });
              },
              backgroundColor: _isNavigating ? colors.textSecondary : colors.accentOrange,
              colors: colors,
            ),
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: _buildActionButton(
              icon: Assets.icons.check,
              label: "Mark Delivered",
              onPressed: () {
                _showDeliveryCompleteDialog(colors);
              },
              backgroundColor: colors.accentGreen,
              colors: colors,
            ),
          ),
        ],
      );
    }
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
        setState(() {
          _currentPhase = "delivery";
          _estimatedTime = 15.0;
          _distance = 5.2;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("Pickup confirmed! You can now navigate to customer."),
            backgroundColor: colors.accentGreen,
          ),
        );
      },
      onSecondaryPressed: () => Navigator.pop(context),
    );
  }

  void _showDeliveryCompleteDialog(AppColorsExtension colors) {
    AppDialog.show(
      context: context,
      title: "Mark as Delivered?",
      message: "Are you sure you have delivered this order to the customer?",
      type: AppDialogType.question,
      primaryButtonText: "Confirm",
      secondaryButtonText: "Cancel",
      primaryButtonColor: colors.accentGreen,
      borderRadius: KBorderSize.borderRadius4,
      buttonBorderRadius: KBorderSize.borderRadius4,
      onPrimaryPressed: () {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: const Text("Order marked as delivered!"), backgroundColor: colors.accentGreen),
        );
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) context.pop();
        });
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
            topLeft: Radius.circular(KBorderSize.borderRadius4),
            topRight: Radius.circular(KBorderSize.borderRadius4),
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
              },
            ),
            SizedBox(height: 20.h),
          ],
        ),
      ),
    );
  }
}
