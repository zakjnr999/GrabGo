import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_customer/features/home/model/food_category.dart';
import 'package:grab_go_customer/features/vendors/model/vendor_model.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:url_launcher/url_launcher.dart';

class VendorDetailBottomSheet extends StatefulWidget {
  final VendorModel vendor;
  const VendorDetailBottomSheet({super.key, required this.vendor});
  static void show({required BuildContext context, required VendorModel vendor}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => VendorDetailBottomSheet(vendor: vendor),
    );
  }

  @override
  State<VendorDetailBottomSheet> createState() => _VendorDetailBottomSheetState();
}

class _VendorDetailBottomSheetState extends State<VendorDetailBottomSheet> {
  List<FoodItem> _latestItems = [];
  bool _isLoadingItems = true;
  @override
  void initState() {
    super.initState();
    _loadLatestItems();
  }

  Future<void> _loadLatestItems() async {
    // TODO: Fetch latest items from vendor
    // For now, using mock data
    await Future.delayed(const Duration(milliseconds: 500));

    setState(() {
      _latestItems = []; // Replace with actual items
      _isLoadingItems = false;
    });
  }

  void _openDirections() async {
    final vendor = widget.vendor;
    if (vendor.location == null) return;
    final url = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=${vendor.location!.lat},${vendor.location!.lng}',
    );
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  void _viewFullMenu() {
    Navigator.pop(context);
    // Navigate to vendor page
    context.push('/vendor/${widget.vendor.id}');
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final vendor = widget.vendor;
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: colors.backgroundPrimary,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
            boxShadow: [
              BoxShadow(
                color: isDark ? Colors.black.withAlpha(50) : Colors.black.withAlpha(20),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            children: [
              // Drag handle
              Container(
                margin: EdgeInsets.only(top: 12.h),
                width: 40.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: colors.textSecondary.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
                  children: [
                    // Vendor header
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Vendor logo
                        Container(
                          width: 80.w,
                          height: 80.w,
                          decoration: BoxDecoration(
                            color: colors.backgroundSecondary,
                            borderRadius: BorderRadius.circular(12.r),
                            border: Border.all(color: colors.border.withOpacity(0.1), width: 1),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12.r),
                            child: vendor.logo != null && vendor.logo!.isNotEmpty
                                ? Image.network(
                                    vendor.logo!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Icon(Icons.store_rounded, size: 40.sp, color: colors.textSecondary);
                                    },
                                  )
                                : Icon(Icons.store_rounded, size: 40.sp, color: colors.textSecondary),
                          ),
                        ),
                        SizedBox(width: 12.w),
                        // Vendor info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                vendor.displayName,
                                style: TextStyle(
                                  color: colors.textPrimary,
                                  fontSize: 20.sp,
                                  fontWeight: FontWeight.w700,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              SizedBox(height: 4.h),
                              // Rating and reviews
                              Row(
                                children: [
                                  Icon(Icons.star_rounded, size: 16.sp, color: const Color(0xFFFBBF24)),
                                  SizedBox(width: 4.w),
                                  Text(
                                    '${vendor.rating.toStringAsFixed(1)} (${vendor.totalReviews})',
                                    style: TextStyle(
                                      color: colors.textSecondary,
                                      fontSize: 14.sp,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 4.h),
                              // Distance
                              if (vendor.distance != null)
                                Row(
                                  children: [
                                    Icon(Icons.location_on_rounded, size: 16.sp, color: colors.textSecondary),
                                    SizedBox(width: 4.w),
                                    Text(
                                      vendor.distanceText,
                                      style: TextStyle(
                                        color: colors.textSecondary,
                                        fontSize: 14.sp,
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16.h),
                    // Status badges
                    Row(
                      children: [
                        // Open/Closed status
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                          decoration: BoxDecoration(
                            color: vendor.isOpen ? colors.accentGreen.withOpacity(0.1) : colors.error.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20.r),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6.w,
                                height: 6.w,
                                decoration: BoxDecoration(
                                  color: vendor.isOpen ? colors.accentGreen : colors.error,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              SizedBox(width: 6.w),
                              Text(
                                vendor.isOpen ? 'Open Now' : 'Closed',
                                style: TextStyle(
                                  color: vendor.isOpen ? colors.accentGreen : colors.error,
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: 8.w),
                        // Accepting orders
                        if (vendor.isAcceptingOrders)
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                            decoration: BoxDecoration(
                              color: colors.accentGreen.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20.r),
                            ),
                            child: Text(
                              'Accepting Orders',
                              style: TextStyle(color: colors.accentGreen, fontSize: 12.sp, fontWeight: FontWeight.w600),
                            ),
                          ),
                      ],
                    ),
                    SizedBox(height: 16.h),
                    // Delivery info
                    Row(
                      children: [
                        Expanded(
                          child: _buildInfoCard(
                            icon: Assets.icons.clock,
                            label: 'Delivery Time',
                            value: vendor.deliveryTimeText,
                            colors: colors,
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: _buildInfoCard(
                            icon: Assets.icons.deliveryTruck,
                            label: 'Delivery Fee',
                            value: vendor.deliveryFeeText,
                            colors: colors,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16.h),
                    // Min order
                    _buildInfoCard(
                      icon: Assets.icons.cash,
                      label: 'Minimum Order',
                      value: vendor.minOrderText,
                      colors: colors,
                    ),
                    SizedBox(height: 24.h),
                    // Latest items section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Popular Items',
                          style: TextStyle(color: colors.textPrimary, fontSize: 18.sp, fontWeight: FontWeight.w700),
                        ),
                        TextButton(
                          onPressed: _viewFullMenu,
                          child: Text(
                            'View All',
                            style: TextStyle(color: colors.accentGreen, fontSize: 14.sp, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12.h),
                    // Items horizontal list
                    if (_isLoadingItems)
                      SizedBox(
                        height: 200.h,
                        child: Center(child: CircularProgressIndicator(color: colors.accentGreen)),
                      )
                    else if (_latestItems.isEmpty)
                      SizedBox(
                        height: 200.h,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.restaurant_menu_rounded,
                                size: 48.sp,
                                color: colors.textSecondary.withOpacity(0.5),
                              ),
                              SizedBox(height: 12.h),
                              Text(
                                'No items available',
                                style: TextStyle(color: colors.textSecondary, fontSize: 14.sp),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      SizedBox(
                        height: 220.h,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _latestItems.length,
                          itemBuilder: (context, index) {
                            final item = _latestItems[index];
                            return _buildItemCard(item, colors);
                          },
                        ),
                      ),
                    SizedBox(height: 24.h),
                    // Action buttons
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _openDirections,
                            icon: Icon(Icons.directions_rounded, size: 20.sp),
                            label: Text('Directions'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: colors.backgroundSecondary,
                              foregroundColor: colors.textPrimary,
                              padding: EdgeInsets.symmetric(vertical: 14.h),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                            ),
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _viewFullMenu,
                            icon: Icon(Icons.restaurant_menu_rounded, size: 20.sp),
                            label: Text('View Menu'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: colors.accentGreen,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(vertical: 14.h),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16.h),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoCard({
    required String icon,
    required String label,
    required String value,
    required AppColorsExtension colors,
  }) {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(color: colors.backgroundSecondary, borderRadius: BorderRadius.circular(12.r)),
      child: Row(
        children: [
          SvgPicture.asset(
            icon,
            package: 'grab_go_shared',
            width: 20.w,
            height: 20.w,
            colorFilter: ColorFilter.mode(colors.accentGreen, BlendMode.srcIn),
          ),
          SizedBox(width: 8.w),
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
                  style: TextStyle(color: colors.textPrimary, fontSize: 13.sp, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemCard(FoodItem item, AppColorsExtension colors) {
    return Container(
      width: 160.w,
      margin: EdgeInsets.only(right: 12.w),
      decoration: BoxDecoration(color: colors.backgroundSecondary, borderRadius: BorderRadius.circular(12.r)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Item image
          ClipRRect(
            borderRadius: BorderRadius.vertical(top: Radius.circular(12.r)),
            child: Container(
              height: 120.h,
              width: double.infinity,
              color: colors.backgroundTertiary,
              child: item.image.isNotEmpty
                  ? Image.network(
                      item.image,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Icon(Icons.restaurant_rounded, size: 40.sp, color: colors.textSecondary);
                      },
                    )
                  : Icon(Icons.restaurant_rounded, size: 40.sp, color: colors.textSecondary),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(8.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: TextStyle(color: colors.textPrimary, fontSize: 14.sp, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 4.h),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'GHS ${item.price.toStringAsFixed(2)}',
                      style: TextStyle(color: colors.accentGreen, fontSize: 14.sp, fontWeight: FontWeight.w700),
                    ),
                    Row(
                      children: [
                        Icon(Icons.star_rounded, size: 14.sp, color: const Color(0xFFFBBF24)),
                        SizedBox(width: 2.w),
                        Text(
                          item.rating.toStringAsFixed(1),
                          style: TextStyle(color: colors.textSecondary, fontSize: 12.sp),
                        ),
                      ],
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
}
