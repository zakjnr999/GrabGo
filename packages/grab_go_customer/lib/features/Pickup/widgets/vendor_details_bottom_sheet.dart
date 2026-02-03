import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_customer/features/grabmart/repository/grabmart_repository.dart';
import 'package:grab_go_customer/features/groceries/repository/grocery_repository.dart';
import 'package:grab_go_customer/features/home/model/food_category.dart';
import 'package:grab_go_customer/features/home/repository/food_repository.dart';
import 'package:grab_go_customer/features/pharmacy/repository/pharmacy_repository.dart';
import 'package:grab_go_customer/features/vendors/model/vendor_model.dart';
import 'package:grab_go_customer/features/vendors/model/vendor_type.dart';
import 'package:grab_go_customer/shared/viewmodels/favorites_provider.dart';
import 'package:grab_go_customer/shared/widgets/section_header.dart';
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

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final size = MediaQuery.of(context).size;
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
                                  height: 80.w,
                                  width: 80.w,
                                  fit: BoxFit.cover,
                                  imageUrl: ImageOptimizer.getPreviewUrl(vendor.logo ?? '', width: 200),
                                  memCacheWidth: 200,
                                  maxHeightDiskCache: 200,
                                  placeholder: (context, url) => Container(
                                    height: 80.w,
                                    width: 80.w,
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
                                    height: 80.w,
                                    width: 80.w,
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
                                      height: 80.w,
                                      width: 80.w,
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
                                      vendor.deliveryTimeText,
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
                                      vendor.isOpen ? 'Open' : 'Closed',
                                      style: TextStyle(
                                        color: vendor.isOpen ? colors.accentGreen : colors.error,
                                        fontSize: 14.sp,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 6.w),
                                      child: Text('•', style: TextStyle(color: colors.textSecondary)),
                                    ),
                                    Text(
                                      vendor.isOpen ? 'Closes at 11:00 PM' : 'Opens at 9:00 AM', // Dummy schedule
                                      style: TextStyle(color: colors.textSecondary, fontSize: 13.sp),
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
                          height: 200.h,
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
                          height: 220.h,
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
    return Row(
      children: List.generate(
        3,
        (index) => Container(
          height: 200.h,
          width: size.width * 0.4,
          margin: EdgeInsets.only(right: 6.w, left: index == 0 ? 20.w : 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 120.h,
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
    return GestureDetector(
      onTap: () {
        context.push('/foodDetails', extra: item);
      },
      child: Container(
        width: size.width * 0.4,
        padding: EdgeInsets.all(2.r),
        decoration: BoxDecoration(
          color: colors.backgroundPrimary,
          borderRadius: BorderRadius.circular(KBorderSize.borderMedium),
          border: Border.all(color: colors.inputBorder.withValues(alpha: 0.5), width: 1),
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
                    height: 120.h,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    memCacheWidth: 400,
                    maxHeightDiskCache: 800,
                    placeholder: (context, url) => Container(
                      height: 120.h,
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
                      height: 120.h,
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
                        onTap: () {
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

                isPopular
                    ? Positioned(
                        top: 0.h,
                        left: 0.w,
                        child: item.orderCount > 0
                            ? Container(
                                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [colors.error, colors.accentOrange],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: const BorderRadius.only(
                                    bottomRight: Radius.circular(KBorderSize.borderMedium),
                                    topLeft: Radius.circular(KBorderSize.borderMedium),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SvgPicture.asset(
                                      Assets.icons.flame,
                                      package: 'grab_go_shared',
                                      height: 13.h,
                                      width: 13.w,
                                      colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                                    ),
                                    SizedBox(width: 4.w),
                                    Text(
                                      item.orderCount.toString(),
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12.sp,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : const SizedBox.shrink(),
                      )
                    : const SizedBox.shrink(),
              ],
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(10.r, 10.r, 10.r, 6.r),
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
                        SizedBox(height: isPopular ? 0.h : 8.h),
                        if (!isPopular)
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
                                "Pickup in ${'${item.deliveryTimeMinutes} mins'}",
                                style: TextStyle(
                                  fontSize: 11.sp,
                                  fontWeight: FontWeight.w500,
                                  color: colors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        SizedBox(height: 8.h),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
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
