import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';

class OrderConfirmationPage extends StatefulWidget {
  final String orderId;
  final String? orderNumber;
  final String? orderStatus;
  final String orderInstructions;
  final String customerName;
  final String customerAddress;
  final String customerPhone;
  final String? customerPhoto;
  final double riderEarnings;
  final String restaurantName;
  final String restaurantAddress;
  final String? restaurantLogo;
  final String orderTotal;
  final List<String> orderItems;
  final String? specialInstructions;
  final String? customerId;
  final String? riderId;
  final double? pickupLatitude;
  final double? pickupLongitude;
  final double? destinationLatitude;
  final double? destinationLongitude;

  const OrderConfirmationPage({
    super.key,
    this.orderId = "",
    this.orderNumber,
    required this.customerName,
    required this.customerAddress,
    required this.customerPhone,
    required this.restaurantName,
    required this.restaurantAddress,
    required this.orderTotal,
    required this.orderItems,
    this.specialInstructions,
    this.customerId,
    this.riderId,
    this.pickupLatitude,
    this.pickupLongitude,
    this.destinationLatitude,
    this.destinationLongitude,
    this.orderStatus,
    required this.riderEarnings,
    required this.orderInstructions,
    this.customerPhoto,
    this.restaurantLogo,
  });

  String get displayOrderId => orderNumber ?? orderId;

  @override
  State<OrderConfirmationPage> createState() => _OrderConfirmationPageState();
}

class _OrderConfirmationPageState extends State<OrderConfirmationPage> {
  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final size = MediaQuery.sizeOf(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        systemNavigationBarColor: colors.backgroundPrimary,
        systemNavigationBarDividerColor: Colors.transparent,
        systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: colors.backgroundSecondary,
        body: Column(
          children: [
            Expanded(
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverAppBar(
                    expandedHeight: size.height * 0.20,
                    floating: false,
                    pinned: true,
                    elevation: 0,
                    backgroundColor: colors.backgroundPrimary,
                    systemOverlayStyle: SystemUiOverlayStyle(
                      statusBarColor: Colors.transparent,
                      statusBarIconBrightness: Brightness.light,
                    ),
                    leading: IconButton(
                      icon: SvgPicture.asset(
                        Assets.icons.navArrowLeft,
                        package: 'grab_go_shared',
                        width: 24.w,
                        height: 24.w,
                        colorFilter: ColorFilter.mode(Colors.white, BlendMode.srcIn),
                      ),
                      onPressed: () => context.pop(),
                    ),
                    actions: [
                      IconButton(
                        icon: SvgPicture.asset(
                          Assets.icons.infoCircle,
                          package: 'grab_go_shared',
                          width: 20.w,
                          height: 20.w,
                          colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                        ),

                        onPressed: () => _showCallOptions(context, colors),
                      ),
                    ],

                    flexibleSpace: FlexibleSpaceBar(
                      background: Container(
                        color: colors.accentGreen,
                        child: SafeArea(
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 16.h),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(KBorderSize.borderRadius20),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 6.w,
                                        height: 6.w,
                                        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                                      ),
                                      SizedBox(width: 6.w),
                                      Text(
                                        widget.orderStatus ?? "Order Confirmed",
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 12.sp,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(height: 8.h),
                                Row(
                                  children: [
                                    Text(
                                      "ORDER NO. : ",
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.9),
                                        fontSize: 12.sp,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Text(
                                      widget.displayOrderId,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 20.sp,
                                        fontWeight: FontWeight.w700,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                                SizedBox(height: 4.h),
                                Row(
                                  children: [
                                    Text(
                                      "EARNINGS : ",
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.9),
                                        fontSize: 12.sp,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Text(
                                      "GHS ${widget.riderEarnings.toString()}",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 18.sp,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Low Battery Warning
                        _buildLowBatteryWarning(colors),

                        SizedBox(height: 20.h),

                        // Pickup & Delivery Timeline
                        _buildDeliveryTimeline(colors),

                        SizedBox(height: 20.h),

                        // Order Items
                        _buildOrderItems(colors),

                        SizedBox(height: 20.h),

                        // Special Instructions (if any)
                        if (widget.specialInstructions != null) ...[
                          _buildSpecialInstructions(colors),
                          SizedBox(height: 20.h),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Container(
              color: colors.backgroundPrimary,
              padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 20.h),
              child: SafeArea(top: false, child: _buildActionButtons(colors)),
            ),
          ],
        ),
      ),
    );
  }

  Container _buildLowBatteryWarning(AppColorsExtension colors) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      color: colors.warning,
      child: Row(
        children: [
          SvgPicture.asset(
            Assets.icons.battery25,
            package: 'grab_go_shared',
            width: 16.w,
            height: 16.w,
            colorFilter: ColorFilter.mode(Colors.white, BlendMode.srcIn),
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Low battery. Consider charging before starting your journey.',
              style: TextStyle(fontSize: 11.sp, color: Colors.white, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveryTimeline(AppColorsExtension colors) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20.w),
      decoration: BoxDecoration(
        color: colors.backgroundPrimary,
        borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
      ),
      child: Column(
        children: [
          // Pickup Location
          _buildTimelineItem(
            colors: colors,
            icon: Assets.icons.chefHat,
            iconColor: colors.accentOrange,
            iconBgColor: colors.accentOrange.withValues(alpha: 0.1),
            title: "Pickup from",
            name: widget.restaurantName,
            address: widget.restaurantAddress,
            size: MediaQuery.of(context).size,
            imageUrl: widget.restaurantLogo,
            showPhone: true,
            isFirst: true,
            isLast: false,
          ),

          Padding(
            padding: EdgeInsets.only(left: 48.w),
            child: Row(
              children: [
                Container(width: 2.w, height: 24.h, color: colors.accentGreen.withValues(alpha: 0.3)),
                Expanded(
                  child: Container(
                    height: 1.h,
                    margin: EdgeInsets.symmetric(horizontal: 16.w),
                    color: colors.border.withValues(alpha: 0.3),
                  ),
                ),
              ],
            ),
          ),

          // Delivery Location
          _buildTimelineItem(
            colors: colors,
            icon: Assets.icons.user,
            iconColor: colors.accentViolet,
            iconBgColor: colors.accentViolet.withValues(alpha: 0.1),
            title: "Deliver to",
            name: widget.customerName,
            address: widget.customerAddress,
            size: MediaQuery.of(context).size,
            imageUrl: widget.customerPhoto,
            showPhone: true,
            isFirst: false,
            isLast: true,
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineItem({
    required AppColorsExtension colors,
    required String icon,
    required Color iconColor,
    required Color iconBgColor,
    required String title,
    required String name,
    required String address,
    required Size size,
    required String? imageUrl,
    required bool showPhone,
    required bool isFirst,
    required bool isLast,
  }) {
    return Padding(
      padding: EdgeInsets.all(16.w),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
            child: CachedNetworkImage(
              height: size.width * 0.15,
              width: size.width * 0.15,
              fit: BoxFit.cover,
              imageUrl: ImageOptimizer.getPreviewUrl(imageUrl ?? '', width: 200),
              memCacheWidth: 200,
              maxHeightDiskCache: 200,
              placeholder: (context, url) => Container(
                height: size.width * 0.15,
                width: size.width * 0.15,
                padding: EdgeInsets.all(12.r),
                decoration: BoxDecoration(
                  color: colors.accentGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
                ),
                child: SvgPicture.asset(
                  icon,
                  package: 'grab_go_shared',
                  width: 24.w,
                  height: 24.w,
                  colorFilter: ColorFilter.mode(colors.accentGreen, BlendMode.srcIn),
                ),
              ),
              errorWidget: (context, url, error) => Container(
                height: size.width * 0.15,
                width: size.width * 0.15,
                padding: EdgeInsets.all(12.r),
                decoration: BoxDecoration(
                  color: colors.accentGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
                ),
                child: SvgPicture.asset(
                  icon,
                  package: 'grab_go_shared',
                  width: 24.w,
                  height: 24.w,
                  colorFilter: ColorFilter.mode(colors.accentGreen, BlendMode.srcIn),
                ),
              ),
            ),
          ),
          SizedBox(width: 16.w),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(color: colors.textSecondary, fontSize: 12.sp, fontWeight: FontWeight.w500),
                ),
                SizedBox(height: 4.h),
                Text(
                  name,
                  style: TextStyle(color: colors.textPrimary, fontSize: 14.sp, fontWeight: FontWeight.w600),
                ),
                SizedBox(height: 4.h),
                Text(
                  address,
                  style: TextStyle(color: colors.textSecondary, fontSize: 12.sp, fontWeight: FontWeight.w400),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderItems(AppColorsExtension colors) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20.w),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: colors.backgroundPrimary,
        borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                "Order Items",
                style: TextStyle(color: colors.textPrimary, fontSize: 16.sp, fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              Text(
                "${widget.orderItems.length} items",
                style: TextStyle(color: colors.textSecondary, fontSize: 11.sp, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          if (widget.orderItems.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 8.h),
              child: Text(
                "No items available",
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w400,
                  fontStyle: FontStyle.italic,
                ),
              ),
            )
          else
            ...widget.orderItems.asMap().entries.map(
              (entry) => Padding(
                padding: EdgeInsets.only(bottom: entry.key == widget.orderItems.length - 1 ? 0 : 12.h),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: EdgeInsets.only(top: 6.h),
                      width: 6.w,
                      height: 6.w,
                      decoration: BoxDecoration(
                        color: colors.accentGreen.withValues(alpha: 0.6),
                        shape: BoxShape.circle,
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Text(
                        entry.value,
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w400,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSpecialInstructions(AppColorsExtension colors) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20.w),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: colors.backgroundPrimary,
        borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Special Instructions",
                  style: TextStyle(color: colors.textPrimary, fontSize: 16.sp, fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 16.h),
                Row(
                  children: [
                    Container(
                      margin: EdgeInsets.only(top: 6.h),
                      width: 6.w,
                      height: 6.w,
                      decoration: BoxDecoration(
                        color: colors.accentGreen.withValues(alpha: 0.6),
                        shape: BoxShape.circle,
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Text(
                      widget.specialInstructions!,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w400,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(AppColorsExtension colors) {
    return _buildPrimaryButton(
      colors: colors,
      label: "Navigate to Restaurant",
      color: colors.accentGreen,
      onPressed: () {
        _navigateToTracking(phase: "pickup");
      },
    );
  }

  Widget _buildPrimaryButton({
    required AppColorsExtension colors,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(vertical: 16.h),
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(KBorderSize.borderRadius4)),
          child: Center(
            child: Text(
              label,
              style: TextStyle(color: Colors.white, fontSize: 15.sp, fontWeight: FontWeight.w600),
            ),
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
        // Tracking data
        'customerId': widget.customerId,
        'riderId': widget.riderId,
        'pickupLatitude': widget.pickupLatitude,
        'pickupLongitude': widget.pickupLongitude,
        'destinationLatitude': widget.destinationLatitude,
        'destinationLongitude': widget.destinationLongitude,
      },
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
