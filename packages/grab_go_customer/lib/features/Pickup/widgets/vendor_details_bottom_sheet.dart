import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_customer/features/grabmart/repository/grabmart_repository.dart';
import 'package:grab_go_customer/features/groceries/repository/grocery_repository.dart';
import 'package:grab_go_customer/features/cart/viewmodel/cart_provider.dart';
import 'package:grab_go_customer/features/home/model/food_category.dart';
import 'package:grab_go_customer/features/home/repository/food_repository.dart';
import 'package:grab_go_customer/features/pharmacy/repository/pharmacy_repository.dart';
import 'package:grab_go_customer/features/vendors/model/vendor_model.dart';
import 'package:grab_go_customer/features/vendors/model/vendor_type.dart';
import 'package:grab_go_customer/shared/services/auth_guard.dart';
import 'package:grab_go_customer/shared/viewmodels/favorites_provider.dart';
import 'package:grab_go_customer/shared/widgets/section_header.dart';
import 'package:grab_go_customer/shared/widgets/vertical_zigzag_tag.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart' hide FoodRepository, FoodService;
import 'package:provider/provider.dart';

class VendorDetailBottomSheet extends StatefulWidget {
  final VendorModel vendor;
  const VendorDetailBottomSheet({super.key, required this.vendor});
  static PersistentBottomSheetController show({required BuildContext context, required VendorModel vendor}) {
    return Scaffold.of(context).showBottomSheet(
      (context) => VendorDetailBottomSheet(vendor: vendor),
      backgroundColor: Colors.transparent,
      elevation: 0,
    );
  }

  @override
  State<VendorDetailBottomSheet> createState() => _VendorDetailBottomSheetState();
}

class _VendorDetailBottomSheetState extends State<VendorDetailBottomSheet> {
  List<FoodItem> _popularItems = [];
  List<FoodItem> _quickPickupItems = [];
  bool _isLoadingItems = true;

  @override
  void initState() {
    super.initState();
    _fetchVendorItems();
  }

  Future<void> _fetchVendorItems() async {
    if (!mounted) return;
    setState(() {
      _isLoadingItems = true;
    });

    try {
      final vendorId = widget.vendor.id;
      final vendorType = widget.vendor.vendorTypeEnum;
      List<FoodItem> allVendorItems = [];

      switch (vendorType) {
        case VendorType.food:
          final items = await FoodRepository().fetchFoods(restaurantId: vendorId);
          allVendorItems = items;
          break;
        case VendorType.grocery:
          final items = await GroceryRepository().fetchItems(store: vendorId);
          allVendorItems = items.map((e) => e.toFoodItem()).toList();
          break;
        case VendorType.pharmacy:
          final items = await PharmacyRepository().fetchItems(store: vendorId);
          allVendorItems = items.map((e) => e.toFoodItem()).toList();
          break;
        case VendorType.grabmart:
          final items = await GrabMartRepository().fetchItems(store: vendorId);
          allVendorItems = items.map((e) => e.toFoodItem()).toList();
          break;
      }

      if (mounted) {
        setState(() {
          final sortedByPopularity = List<FoodItem>.from(allVendorItems)
            ..sort((a, b) => b.orderCount.compareTo(a.orderCount));

          _popularItems = sortedByPopularity.take(5).toList();

          _quickPickupItems = sortedByPopularity.skip(5).take(10).toList();

          _isLoadingItems = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching vendor items: $e');
      if (mounted) {
        setState(() {
          _isLoadingItems = false;
        });
      }
    }
  }

  DaySchedule? _todaySchedule(OpeningHours? openingHours) {
    if (openingHours == null) return null;
    switch (DateTime.now().weekday) {
      case DateTime.monday:
        return openingHours.monday;
      case DateTime.tuesday:
        return openingHours.tuesday;
      case DateTime.wednesday:
        return openingHours.wednesday;
      case DateTime.thursday:
        return openingHours.thursday;
      case DateTime.friday:
        return openingHours.friday;
      case DateTime.saturday:
        return openingHours.saturday;
      case DateTime.sunday:
        return openingHours.sunday;
      default:
        return null;
    }
  }

  String _formatOpeningTime(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '--';
    final value = raw.trim();
    final parsed = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(value);
    if (parsed == null) return value;

    final hour24 = int.tryParse(parsed.group(1)!);
    final minute = parsed.group(2)!;
    if (hour24 == null || hour24 < 0 || hour24 > 23) return value;

    final period = hour24 >= 12 ? 'PM' : 'AM';
    final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
    return '$hour12:$minute $period';
  }

  String _vendorAvailabilityText(VendorModel vendor) {
    if (vendor.is24Hours == true) return 'Open 24 hours';

    final schedule = _todaySchedule(vendor.openingHours);
    if (schedule == null) return vendor.isOpen ? 'Open now' : 'Closed for now';
    if (schedule.isClosed) return 'Closed today';

    if (vendor.isOpen) {
      return 'Closes at ${_formatOpeningTime(schedule.close)}';
    }
    return 'Opens at ${_formatOpeningTime(schedule.open)}';
  }

  String _pickupEtaText(FoodItem item) {
    final vendorPrep = widget.vendor.averagePreparationTime ?? 0;
    final baseMinutes = [
      item.prepTimeMinutes,
      vendorPrep,
      item.deliveryTimeMinutes,
    ].firstWhere((value) => value > 0, orElse: () => 20);

    final minMinutes = baseMinutes.clamp(8, 55).toInt();
    final extra = item.prepTimeMinutes > 0 ? 6 : 10;
    final maxMinutes = (minMinutes + extra).clamp(minMinutes + 3, 70).toInt();

    if (maxMinutes - minMinutes <= 2) {
      return '$minMinutes mins';
    }
    return '$minMinutes-$maxMinutes mins';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final size = MediaQuery.of(context).size;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final vendor = widget.vendor;
    final vendorEtaMinutes = vendor.averagePreparationTime ?? vendor.averageDeliveryTime ?? 30;
    final sheetCardWidth = size.width * 0.4;
    final sheetImageHeight = (sheetCardWidth * 0.6).clamp(90.0, 120.0);
    final sheetCardHeight = (sheetImageHeight + 110.0).clamp(190.0, 230.0);
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
              Container(
                margin: EdgeInsets.only(top: 12.h),
                width: 40.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: colors.textSecondary.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: EdgeInsets.symmetric(vertical: 16.h),
                  children: [
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20.w),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12.r),
                                child: CachedNetworkImage(
                                  height: 80,
                                  width: 80,
                                  fit: BoxFit.cover,
                                  imageUrl: ImageOptimizer.getPreviewUrl(vendor.logo ?? '', width: 200),
                                  memCacheWidth: 200,
                                  maxHeightDiskCache: 200,
                                  placeholder: (context, url) => Container(
                                    height: 80,
                                    width: 80,
                                    padding: EdgeInsets.all(20.w),
                                    decoration: BoxDecoration(
                                      color: colors.backgroundSecondary,
                                      borderRadius: BorderRadius.circular(12.r),
                                    ),
                                    child: SvgPicture.asset(
                                      vendor.vendorType == VendorType.food.toString()
                                          ? Assets.icons.chefHat
                                          : vendor.vendorType == VendorType.grocery.toString()
                                          ? Assets.icons.cart
                                          : vendor.vendorType == VendorType.pharmacy.toString()
                                          ? Assets.icons.pharmacyCrossCircle
                                          : Assets.icons.store,
                                      package: "grab_go_shared",
                                      colorFilter: ColorFilter.mode(colors.textSecondary, BlendMode.srcIn),
                                    ),
                                  ),
                                  errorWidget: (context, url, error) => Container(
                                    height: 80,
                                    width: 80,
                                    padding: EdgeInsets.all(20.w),
                                    decoration: BoxDecoration(
                                      color: colors.backgroundSecondary,
                                      borderRadius: BorderRadius.circular(12.r),
                                    ),
                                    child: SvgPicture.asset(
                                      vendor.vendorType == VendorType.food.toString()
                                          ? Assets.icons.chefHat
                                          : vendor.vendorType == VendorType.grocery.toString()
                                          ? Assets.icons.cart
                                          : vendor.vendorType == VendorType.pharmacy.toString()
                                          ? Assets.icons.pharmacyCrossCircle
                                          : Assets.icons.store,
                                      package: "grab_go_shared",

                                      colorFilter: ColorFilter.mode(colors.textSecondary, BlendMode.srcIn),
                                    ),
                                  ),
                                ),
                              ),
                              _popularItems.isEmpty && _quickPickupItems.isEmpty
                                  ? Container(
                                      height: 80,
                                      width: 80,
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(alpha: 0.6),
                                        borderRadius: BorderRadius.circular(12.r),
                                      ),
                                      child: Center(
                                        child: Text(
                                          'Out of Stock',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 14.sp,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    )
                                  : const SizedBox.shrink(),
                            ],
                          ),

                          SizedBox(width: 12.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      vendor.displayName,
                                      style: TextStyle(
                                        color: colors.textPrimary,
                                        fontSize: 18.sp,
                                        fontWeight: FontWeight.w800,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (vendor.isVerified == true) ...[
                                      SizedBox(width: 6.w),
                                      SvgPicture.asset(
                                        Assets.icons.badgeCheck,
                                        package: 'grab_go_shared',
                                        height: 14.sp,
                                        width: 14.sp,
                                        colorFilter: ColorFilter.mode(colors.accentOrange, BlendMode.srcIn),
                                      ),
                                    ],
                                  ],
                                ),
                                SizedBox(height: 4.h),
                                Row(
                                  children: [
                                    SvgPicture.asset(
                                      Assets.icons.starSolid,
                                      package: 'grab_go_shared',
                                      height: 14.sp,
                                      width: 14.sp,
                                      colorFilter: ColorFilter.mode(colors.accentOrange, BlendMode.srcIn),
                                    ),
                                    SizedBox(width: 4.w),
                                    Text(
                                      '${vendor.rating.toStringAsFixed(1)} (${vendor.totalReviews}+ ratings)',
                                      style: TextStyle(
                                        color: colors.textSecondary,
                                        fontSize: 13.sp,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 6.w),
                                      child: Text('•', style: TextStyle(color: colors.textSecondary)),
                                    ),

                                    SvgPicture.asset(
                                      Assets.icons.deliveryTruck,
                                      package: 'grab_go_shared',
                                      height: 14.sp,
                                      width: 14.sp,
                                      colorFilter: ColorFilter.mode(colors.textSecondary, BlendMode.srcIn),
                                    ),

                                    SizedBox(width: 4.w),
                                    Text(
                                      '$vendorEtaMinutes mins',
                                      style: TextStyle(color: colors.textSecondary, fontSize: 13.sp),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 6.h),
                                Row(
                                  children: [
                                    SvgPicture.asset(
                                      Assets.icons.timer,
                                      package: 'grab_go_shared',
                                      height: 14.sp,
                                      width: 14.sp,
                                      colorFilter: ColorFilter.mode(
                                        vendor.isOpen ? colors.accentGreen : colors.error,
                                        BlendMode.srcIn,
                                      ),
                                    ),

                                    SizedBox(width: 6.w),
                                    Text(
                                      _vendorAvailabilityText(vendor),
                                      style: TextStyle(
                                        color: vendor.isOpen ? colors.accentGreen : colors.error,
                                        fontSize: 13.sp,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 16.h),

                    if (_isLoadingItems) ...[
                      _buildHeaderSkeleton(colors),
                      SizedBox(height: 12.h),
                      SingleChildScrollView(scrollDirection: Axis.horizontal, child: _buildItemSkeleton(size, colors)),
                      SizedBox(height: 20.h),
                      _buildHeaderSkeleton(colors),
                      SizedBox(height: 12.h),
                      SingleChildScrollView(scrollDirection: Axis.horizontal, child: _buildItemSkeleton(size, colors)),
                    ] else if (_popularItems.isEmpty && _quickPickupItems.isEmpty) ...[
                      SizedBox(
                        height: 250.h,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Vendor is currently out of stock',
                                style: TextStyle(
                                  color: colors.textSecondary,
                                  fontSize: 15.sp,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              SizedBox(height: 4.h),
                              Text(
                                'Check back later for fresh items',
                                style: TextStyle(color: colors.textSecondary.withValues(alpha: 0.6), fontSize: 13.sp),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ] else ...[
                      if (_popularItems.isNotEmpty) ...[
                        SectionHeader(
                          title: 'Recommended For You',
                          sectionTotal: _popularItems.length,
                          accentColor: colors.accentOrange,
                          showIcon: false,
                          onSeeAll: () {},
                        ),
                        SizedBox(height: 12.h),
                        SizedBox(
                          height: sheetCardHeight,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: _popularItems.length,
                            padding: EdgeInsets.symmetric(horizontal: 20.w),
                            itemBuilder: (context, index) {
                              final item = _popularItems[index];
                              return Padding(
                                padding: EdgeInsets.only(right: index == _popularItems.length - 1 ? 0 : 6.w),
                                child: _buildItemCard(item, colors, size, true),
                              );
                            },
                          ),
                        ),
                        SizedBox(height: 20.h),
                      ],

                      if (_quickPickupItems.isNotEmpty) ...[
                        SectionHeader(
                          title: 'More from Vendor',
                          sectionTotal: _quickPickupItems.length,
                          accentColor: colors.accentOrange,
                          showIcon: false,
                          onSeeAll: () {},
                        ),
                        SizedBox(height: 12.h),
                        SizedBox(
                          height: sheetCardHeight,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: _quickPickupItems.length,
                            padding: EdgeInsets.symmetric(horizontal: 20.w),
                            itemBuilder: (context, index) {
                              final item = _quickPickupItems[index];
                              return Padding(
                                padding: EdgeInsets.only(right: index == _quickPickupItems.length - 1 ? 0 : 6.w),
                                child: _buildItemCard(item, colors, size, false),
                              );
                            },
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeaderSkeleton(AppColorsExtension colors) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            height: 14.h,
            width: 80.w,
            decoration: BoxDecoration(
              color: colors.backgroundSecondary,
              borderRadius: BorderRadius.circular(KBorderSize.border),
            ),
          ),

          Container(
            height: 14.h,
            width: 40.w,
            decoration: BoxDecoration(
              color: colors.backgroundSecondary,
              borderRadius: BorderRadius.circular(KBorderSize.border),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemSkeleton(Size size, AppColorsExtension colors) {
    final cardWidth = size.width * 0.4;
    final imageHeight = (cardWidth * 0.6).clamp(90.0, 120.0);
    final cardHeight = (imageHeight + 110.0).clamp(190.0, 230.0);

    return Row(
      children: List.generate(
        3,
        (index) => Container(
          height: cardHeight,
          width: cardWidth,
          margin: EdgeInsets.only(right: 6.w, left: index == 0 ? 20.w : 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: imageHeight,
                decoration: BoxDecoration(
                  color: colors.backgroundSecondary,
                  borderRadius: BorderRadius.circular(KBorderSize.borderMedium),
                ),
              ),
              SizedBox(height: 10.h),

              Container(
                height: 14.h,
                width: 80.w,
                decoration: BoxDecoration(
                  color: colors.backgroundSecondary,
                  borderRadius: BorderRadius.circular(KBorderSize.border),
                ),
              ),

              SizedBox(height: 10.h),

              Container(
                height: 14.h,
                width: 60.w,
                decoration: BoxDecoration(
                  color: colors.backgroundSecondary,
                  borderRadius: BorderRadius.circular(KBorderSize.border),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildItemCard(FoodItem item, AppColorsExtension colors, Size size, bool isPopular) {
    final cardWidth = size.width * 0.4;
    final imageHeight = (cardWidth * 0.6).clamp(90.0, 120.0);
    final pickupEtaText = _pickupEtaText(item);

    return GestureDetector(
      onTap: () {
        context.push('/foodDetails', extra: item);
      },
      child: Container(
        width: cardWidth,
        padding: EdgeInsets.all(2.r),
        decoration: BoxDecoration(
          color: colors.backgroundPrimary,
          borderRadius: BorderRadius.circular(KBorderSize.borderMedium),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(KBorderSize.borderMedium),
                    topRight: Radius.circular(KBorderSize.borderMedium),
                    bottomLeft: Radius.circular(KBorderSize.borderRadius4),
                    bottomRight: Radius.circular(KBorderSize.borderRadius4),
                  ),
                  child: CachedNetworkImage(
                    imageUrl: ImageOptimizer.getPreviewUrl(item.image, width: 400),
                    height: imageHeight,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    memCacheWidth: 400,
                    maxHeightDiskCache: 800,
                    placeholder: (context, url) => Container(
                      height: imageHeight,
                      color: colors.inputBorder,
                      child: Center(
                        child: SvgPicture.asset(
                          Assets.icons.utensilsCrossed,
                          package: 'grab_go_shared',
                          colorFilter: ColorFilter.mode(colors.textSecondary, BlendMode.srcIn),
                          width: 30.w,
                          height: 30.h,
                        ),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      height: imageHeight,
                      color: colors.inputBorder,
                      child: Center(
                        child: SvgPicture.asset(
                          Assets.icons.utensilsCrossed,
                          package: 'grab_go_shared',
                          colorFilter: ColorFilter.mode(colors.textSecondary, BlendMode.srcIn),
                          width: 30.w,
                          height: 30.h,
                        ),
                      ),
                    ),
                  ),
                ),
                Consumer<FavoritesProvider>(
                  builder: (context, favoriteProvider, child) {
                    final bool isFavorite = favoriteProvider.isFavorite(item);
                    return Positioned(
                      right: 6.r,
                      top: 6.r,
                      child: GestureDetector(
                        onTap: () async {
                          final isAuthenticated = await AuthGuard.ensureAuthenticated(context);
                          if (!isAuthenticated) return;

                          if (isFavorite) {
                            favoriteProvider.removeFromFavorites(item);
                          } else {
                            favoriteProvider.addToFavorites(item);
                          }
                        },
                        child: SvgPicture.asset(
                          isFavorite ? Assets.icons.heartSolid : Assets.icons.heart,
                          package: 'grab_go_shared',
                          height: 24.h,
                          width: 24.w,
                          colorFilter: ColorFilter.mode(isFavorite ? colors.error : Colors.white, BlendMode.srcIn),
                        ),
                      ),
                    );
                  },
                ),

                if (isPopular && item.orderCount > 0)
                  Positioned(
                    top: 0,
                    left: 8.w,
                    child: VerticalZigzagTag(
                      primaryText: item.orderCount.toString(),
                      secondaryText: 'orders',
                      color: colors.accentOrange,
                    ),
                  ),
                Consumer<CartProvider>(
                  builder: (context, cartProvider, _) {
                    final isInCart = cartProvider.hasItemInCart(item, includeFoodCustomizations: true);
                    final isItemPending = cartProvider.isItemOperationPendingForDisplay(
                      item,
                      includeFoodCustomizations: true,
                    );
                    return Positioned(
                      right: 8.w,
                      bottom: 8.h,
                      child: GestureDetector(
                        onTap: () async {
                          if (isItemPending) return;
                          if (cartProvider.fulfillmentMode != 'pickup') {
                            await cartProvider.setFulfillmentMode('pickup');
                          }
                          final refreshedActionItem = cartProvider.resolveItemForCartAction(
                            item,
                            includeFoodCustomizations: true,
                          );
                          if (refreshedActionItem != null) {
                            await cartProvider.removeItemCompletely(refreshedActionItem);
                          } else {
                            await cartProvider.addToCart(item, context: context);
                          }
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          height: 32,
                          width: 32,
                          decoration: BoxDecoration(
                            color: isInCart ? colors.accentOrange : colors.backgroundPrimary.withValues(alpha: 0.95),
                            borderRadius: BorderRadius.circular(KBorderSize.borderMedium),
                          ),
                          child: Center(
                            child: isItemPending
                                ? SizedBox(
                                    width: 17.w,
                                    height: 17.w,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        isInCart ? Colors.white : colors.accentOrange,
                                      ),
                                    ),
                                  )
                                : SvgPicture.asset(
                                    isInCart ? Assets.icons.check : Assets.icons.plus,
                                    package: 'grab_go_shared',
                                    height: 17,
                                    width: 17,
                                    colorFilter: ColorFilter.mode(
                                      isInCart ? Colors.white : colors.textPrimary,
                                      BlendMode.srcIn,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(8.r, 8.r, 8.r, 4.r),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600, color: colors.textPrimary),
                        ),
                        SizedBox(height: 6.h),
                        Row(
                          children: [
                            SvgPicture.asset(
                              Assets.icons.timer,
                              package: 'grab_go_shared',
                              height: 12.h,
                              width: 12.w,
                              colorFilter: ColorFilter.mode(colors.textSecondary, BlendMode.srcIn),
                            ),
                            SizedBox(width: 4.w),
                            Text(
                              "Pickup in $pickupEtaText",
                              style: TextStyle(
                                fontSize: 11.sp,
                                fontWeight: FontWeight.w500,
                                color: colors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 6.h),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                          decoration: BoxDecoration(
                            color: colors.accentOrange.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                          child: Text(
                            "GHS ${item.price.toStringAsFixed(2)}",
                            style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w800, color: colors.accentOrange),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
