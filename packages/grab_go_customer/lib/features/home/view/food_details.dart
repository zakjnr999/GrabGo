// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_customer/features/home/viewmodel/food_provider.dart';
import 'package:grab_go_customer/features/groceries/model/grocery_item.dart';
import 'package:grab_go_customer/features/groceries/viewmodel/grocery_provider.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_customer/features/pharmacy/model/pharmacy_item.dart';
import 'package:grab_go_customer/features/grabmart/model/grabmart_item.dart';
import 'package:grab_go_customer/features/home/model/food_category.dart';
import 'package:grab_go_customer/features/cart/viewmodel/cart_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:grab_go_customer/shared/utils/image_optimizer.dart';
import 'package:provider/provider.dart';
import 'package:readmore/readmore.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:grab_go_customer/shared/widgets/food_item_card.dart';
import 'package:grab_go_customer/shared/widgets/food_details_appbar.dart';
import 'package:grab_go_customer/shared/widgets/grocery_item_card.dart';

class FoodDetails extends StatefulWidget {
  const FoodDetails({super.key, this.foodItem, this.groceryItem, this.pharmacyItem, this.grabMartItem})
    : assert(
        foodItem != null || groceryItem != null || pharmacyItem != null || grabMartItem != null,
        'At least one item type must be provided',
      );

  final FoodItem? foodItem;
  final GroceryItem? groceryItem;
  final PharmacyItem? pharmacyItem;
  final GrabMartItem? grabMartItem;

  bool get isGrocery => groceryItem != null;
  bool get isPharmacy => pharmacyItem != null;
  bool get isGrabMart => grabMartItem != null;
  bool get isStoreItem => isGrocery || isPharmacy || isGrabMart;

  @override
  State<FoodDetails> createState() => _FoodDetailsState();
}

class _FoodDetailsState extends State<FoodDetails> with TickerProviderStateMixin {
  late FoodCategoryModel selectedCategory;
  int _restaurantItemsToShow = 3;
  final int _itemsPerPage = 3;
  bool _isLoadingMore = false;
  late ScrollController _scrollController;
  late AnimationController _animationController;
  late AnimationController _bounceController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);

    _animationController = AnimationController(duration: const Duration(milliseconds: 800), vsync: this);

    _bounceController = AnimationController(duration: const Duration(milliseconds: 500), vsync: this);

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    _slideAnimation = Tween<double>(begin: 50.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.1, 0.7, curve: Curves.easeOutCubic),
      ),
    );

    _animationController.forward();

    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) _bounceController.forward();
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _animationController.dispose();
    _bounceController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent * 0.9) {
      if (!_isLoadingMore) {
        _loadMoreRestaurantItems();
      }
    }
  }

  List<FoodItem> _getSimilarFoods(List<FoodCategoryModel> categories) {
    List<FoodItem> similarFoods = [];

    for (var category in categories) {
      for (var item in category.items) {
        if (item.sellerId == widget.foodItem!.sellerId && item.name != widget.foodItem!.name) {
          similarFoods.add(item);
        }
      }
    }

    return similarFoods.take(5).toList();
  }

  List<FoodItem> _getMoreFromRestaurant(List<FoodCategoryModel> categories) {
    List<FoodItem> restaurantFoods = [];

    for (var category in categories) {
      for (var item in category.items) {
        if (item.sellerId == widget.foodItem!.sellerId && item.name != widget.foodItem!.name) {
          restaurantFoods.add(item);
        }
      }
    }

    return restaurantFoods;
  }

  bool get isPharmacy => widget.isPharmacy;
  bool get isGrabMart => widget.isGrabMart;
  bool get isStoreItem => widget.isStoreItem;

  void _loadMoreRestaurantItems() {
    if (widget.foodItem == null) return;
    setState(() {
      _isLoadingMore = true;
    });

    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _restaurantItemsToShow += _itemsPerPage;
          _isLoadingMore = false;
        });
      }
    });
  }

  String get itemName {
    if (widget.isGrocery) return widget.groceryItem!.name;
    if (isPharmacy) return widget.pharmacyItem!.name;
    if (isGrabMart) return widget.grabMartItem!.name;
    return widget.foodItem!.name;
  }

  String get itemDescription {
    if (widget.isGrocery) return widget.groceryItem!.description;
    if (isPharmacy) return widget.pharmacyItem!.description;
    if (isGrabMart) return widget.grabMartItem!.description;
    return widget.foodItem!.description;
  }

  String get itemImage {
    if (widget.isGrocery) return widget.groceryItem!.image;
    if (isPharmacy) return widget.pharmacyItem!.image;
    if (isGrabMart) return widget.grabMartItem!.image;
    return widget.foodItem!.image;
  }

  double get itemPrice {
    if (widget.isGrocery) return widget.groceryItem!.discountedPrice;
    if (isPharmacy) return widget.pharmacyItem!.discountedPrice;
    if (isGrabMart) return widget.grabMartItem!.discountedPrice;
    return widget.foodItem!.price;
  }

  double get itemRating {
    if (widget.isGrocery) return widget.groceryItem!.rating;
    if (isPharmacy) return widget.pharmacyItem!.rating;
    if (isGrabMart) return widget.grabMartItem!.rating;
    return widget.foodItem!.rating;
  }

  // Get CartItem for cart operations (use original type)
  dynamic get cartItem {
    if (widget.isGrocery) return widget.groceryItem!;
    if (isPharmacy) return widget.pharmacyItem!;
    if (isGrabMart) return widget.grabMartItem!;
    return widget.foodItem!;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final padding = MediaQuery.paddingOf(context);
    Size size = MediaQuery.sizeOf(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        systemNavigationBarColor: colors.backgroundPrimary,
        systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      ),
      child: PopScope(
        canPop: false,
        onPopInvoked: (didPop) async {
          if (didPop) return;

          // Check if we can pop (i.e., there's a navigation stack)
          final router = GoRouter.of(context);
          if (router.canPop()) {
            // Normal back navigation - just pop
            router.pop();
          } else {
            // No navigation stack - navigate to home instead of closing app
            if (context.mounted) {
              context.go("/homepage");
            }
          }
        },
        child: Scaffold(
          backgroundColor: colors.backgroundSecondary,
          body: AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return CustomScrollView(
                controller: _scrollController,
                physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                slivers: <Widget>[
                  FoodDetailsAppBar(foodItem: cartItem),
                  SliverToBoxAdapter(
                    child: Transform.translate(
                      offset: Offset(0, _slideAnimation.value),
                      child: FadeTransition(
                        opacity: _fadeAnimation,
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 10.h),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 20.w),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          // Show brand for store items
                                          if (isStoreItem) ...[
                                            Builder(
                                              builder: (context) {
                                                String brand = "";
                                                if (widget.isGrocery) brand = widget.groceryItem!.brand;
                                                if (isPharmacy) brand = widget.pharmacyItem!.brand;
                                                if (isGrabMart) brand = widget.grabMartItem!.brand;

                                                if (brand.isEmpty) return const SizedBox.shrink();
                                                return Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      brand.toUpperCase(),
                                                      style: TextStyle(
                                                        color: colors.textSecondary,
                                                        fontSize: 12.sp,
                                                        fontWeight: FontWeight.w600,
                                                        letterSpacing: 1.0,
                                                      ),
                                                    ),
                                                    SizedBox(height: 4.h),
                                                  ],
                                                );
                                              },
                                            ),
                                          ],
                                          // Item name
                                          Text(
                                            itemName,
                                            style: TextStyle(
                                              color: colors.textPrimary,
                                              fontSize: 22.sp,
                                              fontWeight: FontWeight.w800,
                                              height: 1.2,
                                            ),
                                          ),
                                          SizedBox(height: 6.h),
                                          // Show unit for store items or seller for food
                                          if (isStoreItem)
                                            Builder(
                                              builder: (context) {
                                                String unit = "";
                                                if (widget.isGrocery) unit = widget.groceryItem!.unit;
                                                if (isPharmacy) unit = widget.pharmacyItem!.unit;
                                                if (isGrabMart) unit = widget.grabMartItem!.unit;

                                                return Container(
                                                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                                                  decoration: BoxDecoration(
                                                    color: colors.inputBackground,
                                                    borderRadius: BorderRadius.circular(6.r),
                                                  ),
                                                  child: Text(
                                                    unit,
                                                    style: TextStyle(
                                                      color: colors.textSecondary,
                                                      fontSize: 12.sp,
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                  ),
                                                );
                                              },
                                            )
                                          else
                                            Text(
                                              "By ${widget.foodItem!.sellerName}",
                                              style: TextStyle(
                                                color: colors.textSecondary,
                                                fontSize: 13.sp,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          if (isPharmacy && widget.pharmacyItem!.requiresPrescription) ...[
                                            SizedBox(height: 8.h),
                                            Container(
                                              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                                              decoration: BoxDecoration(
                                                color: Colors.red.withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(6.r),
                                                border: Border.all(color: Colors.red.withOpacity(0.3)),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(Icons.description_outlined, size: 14.sp, color: Colors.red),
                                                  SizedBox(width: 4.w),
                                                  Text(
                                                    "Prescription Required",
                                                    style: TextStyle(
                                                      color: Colors.red,
                                                      fontSize: 11.sp,
                                                      fontWeight: FontWeight.w700,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    SizedBox(width: 12.w),
                                    Container(
                                      decoration: BoxDecoration(
                                        color: colors.accentOrange.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(12.r),
                                      ),
                                      child: Column(
                                        children: [
                                          Text(
                                            "GHS",
                                            style: TextStyle(
                                              color: colors.accentOrange,
                                              fontSize: 10.sp,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          Text(
                                            itemPrice.toStringAsFixed(2),
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
                              SizedBox(height: 16.h),

                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 20.w),
                                child: Row(
                                  children: [
                                    // Rating chip (common for both)
                                    _buildInfoChip(
                                      icon: Assets.icons.star,
                                      text: itemRating.toStringAsFixed(1),
                                      colors: colors,
                                      isDark: isDark,
                                    ),
                                    if (isStoreItem) ...[SizedBox(width: 12.w), _buildStockChip(colors, isDark)],
                                    SizedBox(width: 8.w),

                                    // Conditional chips based on item type
                                    if (widget.isGrocery) ...[
                                      // Stock status for groceries
                                      if (widget.groceryItem!.stock < 10 && widget.groceryItem!.isAvailable)
                                        _buildInfoChip(
                                          icon: Assets.icons.infoCircle,
                                          text: "Only ${widget.groceryItem!.stock} left",
                                          colors: colors,
                                          isDark: isDark,
                                        )
                                      else if (widget.groceryItem!.isAvailable)
                                        _buildInfoChip(
                                          icon: Assets.icons.check,
                                          text: "In Stock",
                                          colors: colors,
                                          isDark: isDark,
                                        )
                                      else
                                        _buildInfoChip(
                                          icon: Assets.icons.alarm,
                                          text: "Out of Stock",
                                          colors: colors,
                                          isDark: isDark,
                                        ),
                                    ] else ...[
                                      // Prep time and delivery for food
                                      _buildInfoChip(
                                        icon: Assets.icons.timer,
                                        text: "25-30 min",
                                        colors: colors,
                                        isDark: isDark,
                                      ),
                                      SizedBox(width: 8.w),
                                      _buildInfoChip(
                                        icon: Assets.icons.deliveryTruck,
                                        text: "Free Delivery",
                                        colors: colors,
                                        isDark: isDark,
                                      ),
                                    ],
                                  ],
                                ),
                              ),

                              SizedBox(height: KSpacing.lg.h),

                              // Restaurant info section (Food only)
                              if (!widget.isGrocery)
                                Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 20.w),
                                  child: Container(
                                    padding: EdgeInsets.all(14.r),
                                    decoration: BoxDecoration(
                                      color: colors.backgroundPrimary,
                                      borderRadius: BorderRadius.circular(KBorderSize.borderRadius15),
                                      border: Border.all(color: colors.inputBorder.withOpacity(0.3), width: 0.5),
                                      boxShadow: [
                                        BoxShadow(
                                          color: isDark ? Colors.black.withAlpha(30) : Colors.black.withAlpha(5),
                                          spreadRadius: 0,
                                          blurRadius: 12,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: size.width * 0.14,
                                          height: size.width * 0.14,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            border: Border.all(color: colors.inputBorder.withOpacity(0.3), width: 2),
                                          ),
                                          child: ClipOval(
                                            child: CachedNetworkImage(
                                              imageUrl: ImageOptimizer.getPreviewUrl(
                                                widget.foodItem!.restaurantImage,
                                                width: 200,
                                              ),
                                              width: size.width * 0.14,
                                              height: size.width * 0.14,
                                              fit: BoxFit.cover,
                                              memCacheWidth: 200,
                                              maxHeightDiskCache: 200,
                                              placeholder: (context, url) => Container(
                                                width: size.width * 0.14,
                                                height: size.width * 0.14,
                                                decoration: BoxDecoration(
                                                  color: colors.inputBorder,
                                                  shape: BoxShape.circle,
                                                ),
                                                child: Center(
                                                  child: SvgPicture.asset(
                                                    Assets.icons.chefHat,
                                                    package: 'grab_go_shared',
                                                    colorFilter: ColorFilter.mode(
                                                      colors.textSecondary,
                                                      BlendMode.srcIn,
                                                    ),
                                                    width: size.width * 0.08,
                                                    height: size.width * 0.08,
                                                  ),
                                                ),
                                              ),
                                              errorWidget: (context, url, error) => Container(
                                                width: size.width * 0.14,
                                                height: size.width * 0.14,
                                                decoration: BoxDecoration(
                                                  color: colors.inputBorder,
                                                  shape: BoxShape.circle,
                                                ),
                                                child: Center(
                                                  child: SvgPicture.asset(
                                                    Assets.icons.chefHat,
                                                    package: 'grab_go_shared',
                                                    colorFilter: ColorFilter.mode(
                                                      colors.textSecondary,
                                                      BlendMode.srcIn,
                                                    ),
                                                    width: size.width * 0.08,
                                                    height: size.width * 0.08,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        SizedBox(width: 14.w),

                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                widget.foodItem!.sellerName,
                                                style: TextStyle(
                                                  color: colors.textPrimary,
                                                  fontSize: 15.sp,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              SizedBox(height: 4.h),
                                              Row(
                                                children: [
                                                  SvgPicture.asset(
                                                    Assets.icons.starSolid,
                                                    package: 'grab_go_shared',
                                                    height: 12.h,
                                                    width: 12.w,
                                                    colorFilter: ColorFilter.mode(colors.accentOrange, BlendMode.srcIn),
                                                  ),
                                                  SizedBox(width: 4.w),
                                                  Text(
                                                    "4.8 (120+ reviews)",
                                                    style: TextStyle(
                                                      color: colors.textSecondary,
                                                      fontSize: 11.sp,
                                                      fontWeight: FontWeight.w500,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        Row(
                                          children: [
                                            _buildActionButton(
                                              icon: Assets.icons.chatBubbleSolid,
                                              colors: colors,
                                              onTap: () {},
                                            ),
                                            SizedBox(width: 8.w),
                                            _buildActionButton(
                                              icon: Assets.icons.phoneSolid,
                                              colors: colors,
                                              onTap: () {},
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                              SizedBox(height: KSpacing.lg.h),

                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 20.w),
                                child: Container(
                                  padding: EdgeInsets.all(16.r),
                                  decoration: BoxDecoration(
                                    color: colors.backgroundPrimary,
                                    borderRadius: BorderRadius.circular(KBorderSize.borderRadius15),
                                    border: Border.all(color: colors.inputBorder.withOpacity(0.3), width: 0.5),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: EdgeInsets.all(8.r),
                                            decoration: BoxDecoration(
                                              color: colors.accentOrange.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(8.r),
                                            ),
                                            child: SvgPicture.asset(
                                              Assets.icons.infoCircle,
                                              package: 'grab_go_shared',
                                              height: 18.h,
                                              width: 18.w,
                                              colorFilter: ColorFilter.mode(colors.accentOrange, BlendMode.srcIn),
                                            ),
                                          ),
                                          SizedBox(width: 10.w),
                                          Text(
                                            "Description",
                                            style: TextStyle(
                                              fontSize: 18.sp,
                                              fontWeight: FontWeight.w800,
                                              color: colors.textPrimary,
                                            ),
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: 12.h),
                                      ReadMoreText(
                                        itemDescription,
                                        trimMode: TrimMode.Line,
                                        trimLines: 3,
                                        colorClickableText: colors.accentOrange,
                                        trimCollapsedText: " Show more",
                                        trimExpandedText: " Show less",
                                        style: TextStyle(
                                          fontSize: 13.sp,
                                          fontWeight: FontWeight.w400,
                                          color: colors.textSecondary,
                                          height: 1.5,
                                        ),
                                        moreStyle: TextStyle(
                                          fontSize: 13.sp,
                                          fontWeight: FontWeight.w700,
                                          color: colors.accentOrange,
                                        ),
                                        lessStyle: TextStyle(
                                          fontSize: 13.sp,
                                          fontWeight: FontWeight.w700,
                                          color: colors.accentOrange,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              SizedBox(height: KSpacing.lg.h),

                              // Similar Foods section (Food only)
                              if (!widget.isGrocery)
                                Consumer<FoodProvider>(
                                  builder: (context, foodProvider, child) {
                                    final similarFoods = _getSimilarFoods(foodProvider.categories);

                                    if (similarFoods.isEmpty) {
                                      return const SizedBox.shrink();
                                    }

                                    return Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Padding(
                                          padding: EdgeInsets.symmetric(horizontal: 20.w),
                                          child: Row(
                                            children: [
                                              Container(
                                                padding: EdgeInsets.all(8.r),
                                                decoration: BoxDecoration(
                                                  color: colors.accentViolet.withOpacity(0.1),
                                                  borderRadius: BorderRadius.circular(8.r),
                                                ),
                                                child: SvgPicture.asset(
                                                  Assets.icons.utensilsCrossed,
                                                  package: 'grab_go_shared',
                                                  height: 18.h,
                                                  width: 18.w,
                                                  colorFilter: ColorFilter.mode(colors.accentViolet, BlendMode.srcIn),
                                                ),
                                              ),
                                              SizedBox(width: 10.w),
                                              Text(
                                                "Similar Foods",
                                                style: TextStyle(
                                                  fontSize: 18.sp,
                                                  fontWeight: FontWeight.w800,
                                                  color: colors.textPrimary,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        SizedBox(height: 12.h),
                                        SizedBox(
                                          height: 210.h,
                                          child: ListView.builder(
                                            padding: EdgeInsets.only(left: 20.w),
                                            scrollDirection: Axis.horizontal,
                                            physics: const BouncingScrollPhysics(),
                                            itemCount: similarFoods.length,
                                            itemBuilder: (context, index) {
                                              return Padding(
                                                padding: EdgeInsets.only(right: 12.w),
                                                child: _buildSimilarFoodItem(colors, similarFoods[index], size, isDark),
                                              );
                                            },
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),

                              SizedBox(height: KSpacing.lg.h),

                              // More From Restaurant (Food only) or Similar Items (Grocery only)
                              if (!widget.isGrocery)
                                Consumer<FoodProvider>(
                                  builder: (context, foodProvider, child) {
                                    final allRestaurantFoods = _getMoreFromRestaurant(foodProvider.categories);

                                    if (allRestaurantFoods.isEmpty) {
                                      return const SizedBox.shrink();
                                    }

                                    final displayedItems = allRestaurantFoods.take(_restaurantItemsToShow).toList();
                                    final hasMoreItems = allRestaurantFoods.length > _restaurantItemsToShow;

                                    return Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Padding(
                                          padding: EdgeInsets.symmetric(horizontal: 20.w),
                                          child: Row(
                                            children: [
                                              Container(
                                                padding: EdgeInsets.all(8.r),
                                                decoration: BoxDecoration(
                                                  color: colors.accentGreen.withOpacity(0.1),
                                                  borderRadius: BorderRadius.circular(8.r),
                                                ),
                                                child: SvgPicture.asset(
                                                  Assets.icons.chefHat,
                                                  package: 'grab_go_shared',
                                                  height: 18.h,
                                                  width: 18.w,
                                                  colorFilter: ColorFilter.mode(colors.accentGreen, BlendMode.srcIn),
                                                ),
                                              ),
                                              SizedBox(width: 10.w),
                                              Text(
                                                "More From Restaurant",
                                                style: TextStyle(
                                                  fontSize: 18.sp,
                                                  fontWeight: FontWeight.w800,
                                                  color: colors.textPrimary,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        SizedBox(height: 12.h),
                                        Padding(
                                          padding: EdgeInsets.symmetric(horizontal: 20.w),
                                          child: Column(
                                            children: displayedItems.map((item) {
                                              return Padding(
                                                padding: EdgeInsets.only(bottom: 12.h),
                                                child: _buildRestaurantFoodItem(item, colors),
                                              );
                                            }).toList(),
                                          ),
                                        ),
                                        if (hasMoreItems && _isLoadingMore) ...[
                                          LoadingMore(
                                            colors: colors,
                                            spinnerColor: colors.accentOrange,
                                            borderColor: colors.accentOrange,
                                          ),
                                          SizedBox(height: 8.h),
                                        ],
                                      ],
                                    );
                                  },
                                )
                              else
                                // Similar Items for Groceries
                                Consumer<GroceryProvider>(
                                  builder: (context, groceryProvider, child) {
                                    final similarItems = groceryProvider.items
                                        .where(
                                          (item) =>
                                              item.categoryId == widget.groceryItem!.categoryId &&
                                              item.id != widget.groceryItem!.id,
                                        )
                                        .take(5)
                                        .toList();

                                    if (similarItems.isEmpty) return const SizedBox.shrink();

                                    return Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Padding(
                                          padding: EdgeInsets.symmetric(horizontal: 20.w),
                                          child: Text(
                                            "Similar Items",
                                            style: TextStyle(
                                              fontSize: 18.sp,
                                              fontWeight: FontWeight.w800,
                                              color: colors.textPrimary,
                                            ),
                                          ),
                                        ),
                                        SizedBox(height: 12.h),
                                        SizedBox(
                                          height: 250.h,
                                          child: ListView.builder(
                                            padding: EdgeInsets.only(left: 20.w),
                                            scrollDirection: Axis.horizontal,
                                            physics: const BouncingScrollPhysics(),
                                            itemCount: similarItems.length,
                                            itemBuilder: (context, index) {
                                              return SizedBox(
                                                width: 160.w,
                                                child: GroceryItemCard(
                                                  item: similarItems[index],
                                                  margin: EdgeInsets.only(right: 12.w, bottom: 10.h),
                                                  onTap: () {
                                                    context.push('/foodDetails', extra: similarItems[index]);
                                                  },
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),

                              SizedBox(height: KSpacing.md.h),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),

          bottomNavigationBar: Container(
            padding: EdgeInsets.only(bottom: padding.bottom),
            decoration: BoxDecoration(
              color: colors.backgroundPrimary,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(KBorderSize.border),
                topRight: Radius.circular(KBorderSize.border),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(20),
                  blurRadius: 20,
                  spreadRadius: 0,
                  offset: const Offset(0, -3),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(KBorderSize.border),
                topRight: Radius.circular(KBorderSize.border),
              ),
              child: Container(
                height: size.height * 0.10,
                padding: EdgeInsets.all(14.r),
                decoration: BoxDecoration(color: colors.backgroundPrimary),
                child: Consumer<CartProvider>(
                  builder: (context, provider, _) {
                    final int qty = provider.cartItems[cartItem] ?? 0;
                    final bool isInCart = qty > 0;

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        isInCart
                            ? Expanded(
                                child: Container(
                                  height: size.height * 0.06,
                                  margin: EdgeInsets.only(right: KSpacing.md.w),
                                  padding: EdgeInsets.symmetric(horizontal: 10.w),
                                  decoration: BoxDecoration(
                                    color: colors.backgroundSecondary,
                                    borderRadius: BorderRadius.circular(KBorderSize.borderRadius15),
                                    border: Border.all(color: colors.inputBorder, width: 1.5),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      InkWell(
                                        onTap: () {
                                          if (isInCart) {
                                            provider.removeFromCart(cartItem);
                                          }
                                        },
                                        child: Icon(Icons.remove, color: colors.textSecondary, size: 20),
                                      ),
                                      Text(
                                        qty.toString(),
                                        style: TextStyle(
                                          fontSize: 12.sp,
                                          fontWeight: FontWeight.w400,
                                          color: colors.textPrimary,
                                        ),
                                      ),
                                      GestureDetector(
                                        onTap: () {
                                          provider.addToCart(cartItem, context: context);
                                        },
                                        child: Container(
                                          padding: EdgeInsets.all(2.r),
                                          decoration: BoxDecoration(color: colors.accentOrange, shape: BoxShape.circle),
                                          child: const Icon(Icons.add, color: Colors.white, size: 20),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : const SizedBox.shrink(),

                        Expanded(
                          flex: 2,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [colors.accentOrange, colors.accentOrange.withOpacity(0.8)],
                              ),
                              borderRadius: BorderRadius.circular(KBorderSize.borderRadius15),
                              boxShadow: [
                                BoxShadow(
                                  color: colors.accentOrange.withOpacity(0.4),
                                  blurRadius: 12,
                                  spreadRadius: 0,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: AppButton(
                              onPressed: () {
                                if (isInCart) {
                                  provider.removeItemCompletely(cartItem);
                                } else {
                                  provider.addToCart(cartItem, context: context);
                                }
                              },
                              backgroundColor: Colors.transparent,
                              borderRadius: KBorderSize.borderRadius50,
                              buttonText: isInCart ? "Remove from Cart" : "Add to Cart",
                              textStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip({
    required String icon,
    required String text,
    required AppColorsExtension colors,
    required bool isDark,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: isDark ? colors.backgroundPrimary.withOpacity(0.5) : colors.backgroundPrimary,
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: colors.inputBorder.withOpacity(0.3), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset(
            icon,
            package: 'grab_go_shared',
            height: 14.h,
            width: 14.w,
            colorFilter: ColorFilter.mode(colors.accentOrange, BlendMode.srcIn),
          ),
          SizedBox(width: 5.w),
          Text(
            text,
            style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w600, color: colors.textPrimary),
          ),
        ],
      ),
    );
  }

  Widget _buildStockChip(AppColorsExtension colors, bool isDark) {
    bool inStock = true;
    if (widget.isGrocery) inStock = widget.groceryItem!.stock > 0 && widget.groceryItem!.isAvailable;
    if (isPharmacy) inStock = widget.pharmacyItem!.stock > 0 && widget.pharmacyItem!.isAvailable;
    if (isGrabMart) inStock = widget.grabMartItem!.stock > 0 && widget.grabMartItem!.isAvailable;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: inStock
            ? (isDark ? colors.accentGreen.withOpacity(0.1) : colors.accentGreen.withOpacity(0.05))
            : colors.inputBackground,
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(
          color: inStock ? colors.accentGreen.withOpacity(0.3) : colors.inputBorder.withOpacity(0.3),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            inStock ? Icons.check_circle_outline : Icons.error_outline,
            size: 14.sp,
            color: inStock ? colors.accentGreen : colors.textSecondary,
          ),
          SizedBox(width: 5.w),
          Text(
            inStock ? "In Stock" : "Out of Stock",
            style: TextStyle(
              fontSize: 11.sp,
              fontWeight: FontWeight.w700,
              color: inStock ? colors.accentGreen : colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({required String icon, required AppColorsExtension colors, required VoidCallback onTap}) {
    return Container(
      height: 40.h,
      width: 40.w,
      decoration: BoxDecoration(color: colors.accentOrange.withOpacity(0.1), shape: BoxShape.circle),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Padding(
            padding: EdgeInsets.all(10.r),
            child: SvgPicture.asset(
              icon,
              package: 'grab_go_shared',
              colorFilter: ColorFilter.mode(colors.accentOrange, BlendMode.srcIn),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSimilarFoodItem(AppColorsExtension colors, FoodItem item, Size size, bool isDark) {
    return GestureDetector(
      onTap: () {
        context.push('/foodDetails', extra: item);
      },
      child: Container(
        width: size.width * 0.6,
        decoration: BoxDecoration(
          color: colors.backgroundPrimary,
          borderRadius: BorderRadius.circular(KBorderSize.borderRadius15),
          border: Border.all(color: colors.inputBorder.withOpacity(0.3), width: 0.5),
          boxShadow: [
            BoxShadow(
              color: isDark ? Colors.black.withAlpha(30) : Colors.black.withAlpha(8),
              spreadRadius: 0,
              blurRadius: 12,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(KBorderSize.borderRadius15),
                topRight: Radius.circular(KBorderSize.borderRadius15),
              ),
              child: SizedBox(
                height: 100.h,
                width: double.infinity,
                child: CachedNetworkImage(
                  imageUrl: ImageOptimizer.getPreviewUrl(item.image, width: 400),
                  height: 100.h,
                  fit: BoxFit.cover,
                  memCacheWidth: 400,
                  maxHeightDiskCache: 400,
                  placeholder: (context, url) => Container(
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
                    color: colors.inputBorder,
                    child: Center(
                      child: Icon(Icons.broken_image, color: colors.textSecondary, size: 30.sp),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(10.r),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700, color: colors.textPrimary),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 4.h),
                  Row(
                    children: [
                      SvgPicture.asset(
                        Assets.icons.starSolid,
                        package: 'grab_go_shared',
                        height: 11.h,
                        width: 11.w,
                        colorFilter: ColorFilter.mode(colors.accentOrange, BlendMode.srcIn),
                      ),
                      SizedBox(width: 4.w),
                      Text(
                        item.rating.toStringAsFixed(1),
                        style: TextStyle(fontSize: 10.sp, color: colors.textPrimary, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  SizedBox(height: 8.h),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                        decoration: BoxDecoration(
                          color: colors.accentOrange.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        child: Text(
                          "GHS ${item.price.toStringAsFixed(2)}",
                          style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w800, color: colors.accentOrange),
                        ),
                      ),
                      Consumer<CartProvider>(
                        builder: (context, provider, _) {
                          final bool isInCart = provider.cartItems.containsKey(item);

                          return GestureDetector(
                            onTap: () {
                              if (isInCart) {
                                provider.removeItemCompletely(item);
                              } else {
                                provider.addToCart(item, context: context);
                              }
                            },
                            child: Container(
                              padding: EdgeInsets.all(6.r),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isInCart ? colors.accentOrange : colors.backgroundSecondary,
                                border: Border.all(
                                  color: isInCart ? colors.accentOrange : colors.inputBorder,
                                  width: 1,
                                ),
                              ),
                              child: SvgPicture.asset(
                                Assets.icons.cart,
                                package: 'grab_go_shared',
                                height: 16.h,
                                width: 16.w,
                                colorFilter: ColorFilter.mode(
                                  isInCart ? Colors.white : colors.textPrimary,
                                  BlendMode.srcIn,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRestaurantFoodItem(FoodItem item, AppColorsExtension colors) {
    return Consumer<CartProvider>(
      builder: (context, cartProvider, child) {
        final bool isInCart = cartProvider.cartItems.containsKey(item);

        return FoodItemCard(
          item: item,
          margin: EdgeInsets.zero,
          onTap: () {
            context.push("/foodDetails", extra: item);
          },
          trailing: GestureDetector(
            onTap: () {
              if (isInCart) {
                cartProvider.removeItemCompletely(item);
              } else {
                cartProvider.addToCart(item, context: context);
              }
            },
            child: Container(
              padding: EdgeInsets.all(8.r),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isInCart ? colors.accentOrange : colors.backgroundSecondary,
                border: Border.all(color: isInCart ? colors.accentOrange : colors.inputBorder, width: 1),
              ),
              child: SvgPicture.asset(
                Assets.icons.cart,
                package: 'grab_go_shared',
                height: 16.h,
                width: 16.w,
                colorFilter: ColorFilter.mode(isInCart ? Colors.white : colors.textPrimary, BlendMode.srcIn),
              ),
            ),
          ),
        );
      },
    );
  }
}
