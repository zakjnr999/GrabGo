import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_customer/features/home/view/item_reviews_page.dart';
import 'package:grab_go_customer/features/home/viewmodel/food_provider.dart';
import 'package:grab_go_customer/features/groceries/model/grocery_item.dart';
import 'package:grab_go_customer/features/groceries/viewmodel/grocery_provider.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_customer/features/pharmacy/model/pharmacy_item.dart';
import 'package:grab_go_customer/features/grabmart/model/grabmart_item.dart';
import 'package:grab_go_customer/features/home/model/food_category.dart';
import 'package:grab_go_customer/features/cart/viewmodel/cart_provider.dart';
import 'package:provider/provider.dart';
import 'package:readmore/readmore.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:grab_go_customer/shared/widgets/food_item_card.dart';
import 'package:grab_go_customer/shared/widgets/food_details_appbar.dart';
import 'package:grab_go_customer/shared/widgets/price_tag_widget.dart';
import 'package:grab_go_customer/shared/widgets/grocery_item_card.dart';
import 'package:grab_go_customer/shared/widgets/deal_card.dart';

class FoodDetails extends StatefulWidget {
  const FoodDetails({
    super.key,
    this.foodItem,
    this.groceryItem,
    this.pharmacyItem,
    this.grabMartItem,
  }) : assert(
         foodItem != null ||
             groceryItem != null ||
             pharmacyItem != null ||
             grabMartItem != null,
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

class _FoodDetailsState extends State<FoodDetails>
    with TickerProviderStateMixin {
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

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _bounceController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

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
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.9) {
      if (!_isLoadingMore) {
        _loadMoreRestaurantItems();
      }
    }
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

  String get itemIngredients {
    try {
      if (widget.isGrocery || isPharmacy || isGrabMart) {
        return '';
      }

      final foodItem = widget.foodItem;
      if (foodItem == null) return '';

      final ingredients = foodItem.ingredients;
      if (ingredients.isNotEmpty) {
        return ingredients.join(', ');
      }
    } catch (e) {
      // Handle any unexpected errors gracefully
      return '';
    }
    return '';
  }

  bool get hasIngredients {
    try {
      if (widget.isGrocery || isPharmacy || isGrabMart) {
        return false;
      }
      final foodItem = widget.foodItem;
      if (foodItem == null) return false;

      return foodItem.ingredients.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

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
        systemNavigationBarIconBrightness: isDark
            ? Brightness.light
            : Brightness.dark,
      ),
      child: PopScope(
        canPop: false,
        onPopInvoked: (didPop) async {
          if (didPop) return;

          final router = GoRouter.of(context);
          if (router.canPop()) {
            router.pop();
          } else {
            if (context.mounted) {
              context.go("/homepage");
            }
          }
        },
        child: Scaffold(
          backgroundColor: colors.backgroundPrimary,
          body: AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return CustomScrollView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
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
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          if (isStoreItem) ...[
                                            Builder(
                                              builder: (context) {
                                                String brand = "";
                                                if (widget.isGrocery)
                                                  brand =
                                                      widget.groceryItem!.brand;
                                                if (isPharmacy)
                                                  brand = widget
                                                      .pharmacyItem!
                                                      .brand;
                                                if (isGrabMart)
                                                  brand = widget
                                                      .grabMartItem!
                                                      .brand;

                                                if (brand.isEmpty)
                                                  return const SizedBox.shrink();
                                                return Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      brand.toUpperCase(),
                                                      style: TextStyle(
                                                        color: colors
                                                            .textSecondary,
                                                        fontSize: 12.sp,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        letterSpacing: 1.0,
                                                      ),
                                                    ),
                                                    SizedBox(height: 4.h),
                                                  ],
                                                );
                                              },
                                            ),
                                          ],
                                          Text(
                                            itemName,
                                            style: TextStyle(
                                              color: colors.textPrimary,
                                              fontSize: 20.sp,
                                              fontWeight: FontWeight.w800,
                                              height: 1.2,
                                            ),
                                          ),
                                          SizedBox(height: 6.h),
                                          if (isStoreItem)
                                            Builder(
                                              builder: (context) {
                                                String unit = "";
                                                if (widget.isGrocery)
                                                  unit =
                                                      widget.groceryItem!.unit;
                                                if (isPharmacy)
                                                  unit =
                                                      widget.pharmacyItem!.unit;
                                                if (isGrabMart)
                                                  unit =
                                                      widget.grabMartItem!.unit;

                                                return Container(
                                                  padding: EdgeInsets.symmetric(
                                                    horizontal: 8.w,
                                                    vertical: 4.h,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color:
                                                        colors.inputBackground,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          6.r,
                                                        ),
                                                  ),
                                                  child: Text(
                                                    unit,
                                                    style: TextStyle(
                                                      color:
                                                          colors.textSecondary,
                                                      fontSize: 12.sp,
                                                      fontWeight:
                                                          FontWeight.w600,
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
                                          if (isPharmacy &&
                                              widget
                                                  .pharmacyItem!
                                                  .requiresPrescription) ...[
                                            SizedBox(height: 8.h),
                                            Container(
                                              padding: EdgeInsets.symmetric(
                                                horizontal: 8.w,
                                                vertical: 4.h,
                                              ),
                                              decoration: BoxDecoration(
                                                color: Colors.red.withValues(
                                                  alpha: 0.1,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(6.r),
                                                border: Border.all(
                                                  color: Colors.red.withValues(
                                                    alpha: 0.3,
                                                  ),
                                                ),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    Icons.description_outlined,
                                                    size: 14.sp,
                                                    color: Colors.red,
                                                  ),
                                                  SizedBox(width: 4.w),
                                                  Text(
                                                    "Prescription Required",
                                                    style: TextStyle(
                                                      color: Colors.red,
                                                      fontSize: 11.sp,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                          SizedBox(height: 6.h),
                                          Row(
                                            children: [
                                              Row(
                                                children: List.generate(
                                                  5,
                                                  (index) => SvgPicture.asset(
                                                    Assets.icons.starSolid,
                                                    package: 'grab_go_shared',
                                                    height: 16,
                                                    width: 16,
                                                    colorFilter:
                                                        ColorFilter.mode(
                                                          colors.accentOrange,
                                                          BlendMode.srcIn,
                                                        ),
                                                  ),
                                                ),
                                              ),
                                              SizedBox(width: 4.w),
                                              Text(
                                                '5.0',
                                                style: TextStyle(
                                                  fontSize: 13.sp,
                                                  color: colors.textPrimary,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              SizedBox(width: 4.w),
                                              Text(
                                                '(142 reviews)',
                                                style: TextStyle(
                                                  fontSize: 13.sp,
                                                  color: colors.textSecondary,
                                                  fontWeight: FontWeight.w400,
                                                ),
                                              ),
                                              SizedBox(width: 4.w),
                                              GestureDetector(
                                                onTap: () => Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) =>
                                                        const ItemReviewsPage(),
                                                  ),
                                                ),
                                                child: SvgPicture.asset(
                                                  Assets.icons.navArrowRight,
                                                  package: 'grab_go_shared',
                                                  height: 12.h,
                                                  width: 12.w,
                                                  colorFilter: ColorFilter.mode(
                                                    colors.textPrimary,
                                                    BlendMode.srcIn,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          SizedBox(height: 8.h),
                                          Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.center,
                                            children: [
                                              SvgPicture.asset(
                                                Assets.icons.timer,
                                                package: 'grab_go_shared',
                                                height: 18.h,
                                                width: 18.w,
                                                colorFilter: ColorFilter.mode(
                                                  colors.textPrimary,
                                                  BlendMode.srcIn,
                                                ),
                                              ),
                                              SizedBox(width: 4.w),
                                              Text(
                                                widget.foodItem != null
                                                    ? widget
                                                          .foodItem!
                                                          .estimatedDeliveryTime
                                                    : "25-30",
                                                style: TextStyle(
                                                  fontFamily: 'Lato',
                                                  package: 'grab_go_shared',
                                                  color: colors.accentOrange,
                                                  fontSize: 14.sp,
                                                ),
                                              ),
                                              SizedBox(width: 10.w),
                                              Container(
                                                height: 4.h,
                                                width: 4.w,
                                                decoration: BoxDecoration(
                                                  color: colors.textSecondary,
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                              SizedBox(width: 8.w),
                                              Text(
                                                '${widget.foodItem?.orderCount.toString()} orders',
                                                style: TextStyle(
                                                  fontFamily: 'Lato',
                                                  package: 'grab_go_shared',
                                                  color: colors.textPrimary,
                                                  fontWeight: FontWeight.w400,
                                                  fontSize: 13.sp,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    PriceTag(
                                      notchPosition: NotchPosition.left,
                                      price: itemPrice,
                                      currency: 'GHS',
                                      priceColor: colors.accentOrange,
                                      size: PriceTagSize.medium,
                                      backgroundColor: colors.accentOrange
                                          .withValues(alpha: 0.2),
                                      borderColor: Colors.transparent,
                                      showShadow: false,
                                    ),
                                  ],
                                ),
                              ),

                              SizedBox(height: KSpacing.lg.h),

                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 20.w),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildSectionHeader(colors, 'Description'),
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

                              if (hasIngredients) ...[
                                SizedBox(height: KSpacing.lg.h),
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 20.w,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _buildSectionHeader(
                                        colors,
                                        'Ingredients',
                                      ),
                                      SizedBox(height: 12.h),
                                      Wrap(
                                        spacing: 8.w,
                                        runSpacing: 8.h,
                                        children: widget.foodItem!.ingredients
                                            .map((ingredient) {
                                              return Container(
                                                padding: EdgeInsets.symmetric(
                                                  horizontal: 8.w,
                                                  vertical: 4.h,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: colors.accentOrange
                                                      .withValues(alpha: 0.1),
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                        20.r,
                                                      ),
                                                ),
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Container(
                                                      width: 6.w,
                                                      height: 6.h,
                                                      decoration: BoxDecoration(
                                                        color:
                                                            colors.accentOrange,
                                                        shape: BoxShape.circle,
                                                      ),
                                                    ),
                                                    SizedBox(width: 6.w),
                                                    Text(
                                                      ingredient,
                                                      style: TextStyle(
                                                        fontSize: 13.sp,
                                                        fontWeight:
                                                            FontWeight.w800,
                                                        color:
                                                            colors.accentOrange,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            })
                                            .toList(),
                                      ),
                                    ],
                                  ),
                                ),
                              ],

                              SizedBox(height: KSpacing.lg.h),

                              if (!widget.isGrocery && widget.foodItem != null)
                                Consumer<FoodProvider>(
                                  builder: (context, foodProvider, child) {
                                    final youMayLikeItems = foodProvider
                                        .getYouMayLikeItems(
                                          widget.foodItem!,
                                          limit: 5,
                                        );

                                    if (youMayLikeItems.isEmpty) {
                                      return const SizedBox.shrink();
                                    }

                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Padding(
                                          padding: EdgeInsets.only(left: 20.w),
                                          child: _buildSectionHeader(
                                            colors,
                                            'You May Like',
                                          ),
                                        ),
                                        SizedBox(height: 12.h),
                                        Builder(
                                          builder: (context) {
                                            final cardWidth =
                                                (size.width * 0.62).clamp(
                                                  200.0,
                                                  260.0,
                                                );
                                            final imageHeight =
                                                (cardWidth * 0.45).clamp(
                                                  90.0,
                                                  125.0,
                                                );
                                            final cardHeight =
                                                (imageHeight + 110.h).clamp(
                                                  208.0,
                                                  250.0,
                                                );
                                            return SizedBox(
                                              height: cardHeight,
                                              child: ListView.builder(
                                                padding: EdgeInsets.only(
                                                  left: 20.w,
                                                ),
                                                scrollDirection:
                                                    Axis.horizontal,
                                                physics:
                                                    const AlwaysScrollableScrollPhysics(),
                                                itemCount:
                                                    youMayLikeItems.length,
                                                itemBuilder: (context, index) {
                                                  final item =
                                                      youMayLikeItems[index];
                                                  return Padding(
                                                    padding: EdgeInsets.only(
                                                      right: 12.w,
                                                    ),
                                                    child: DealCard(
                                                      item: item,
                                                      discountPercent: item
                                                          .discountPercentage
                                                          .toInt(),
                                                      deliveryTime: item
                                                          .estimatedDeliveryTime,
                                                      cardWidth: cardWidth,
                                                      onTap: () {
                                                        context.push(
                                                          '/foodDetails',
                                                          extra: item,
                                                        );
                                                      },
                                                    ),
                                                  );
                                                },
                                              ),
                                            );
                                          },
                                        ),
                                      ],
                                    );
                                  },
                                ),

                              SizedBox(height: KSpacing.lg.h),

                              if (!widget.isGrocery && widget.foodItem != null)
                                Consumer<FoodProvider>(
                                  builder: (context, foodProvider, child) {
                                    final allRestaurantFoods = foodProvider
                                        .getItemsFromSeller(
                                          widget.foodItem!.sellerId,
                                          excludeItemId: widget.foodItem!.id,
                                        );

                                    if (allRestaurantFoods.isEmpty) {
                                      return const SizedBox.shrink();
                                    }

                                    final displayedItems = allRestaurantFoods
                                        .take(_restaurantItemsToShow)
                                        .toList();
                                    final hasMoreItems =
                                        allRestaurantFoods.length >
                                        _restaurantItemsToShow;

                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Padding(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 20.w,
                                          ),
                                          child: _buildSectionHeader(
                                            colors,
                                            'More From Restaurant',
                                          ),
                                        ),
                                        SizedBox(height: 12.h),
                                        Padding(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 20.w,
                                          ),
                                          child: Column(
                                            children: displayedItems.map((
                                              item,
                                            ) {
                                              return Padding(
                                                padding: EdgeInsets.only(
                                                  bottom: 12.h,
                                                ),
                                                child: _buildRestaurantFoodItem(
                                                  item,
                                                  colors,
                                                ),
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
                                              item.categoryId ==
                                                  widget
                                                      .groceryItem!
                                                      .categoryId &&
                                              item.id != widget.groceryItem!.id,
                                        )
                                        .take(5)
                                        .toList();

                                    if (similarItems.isEmpty)
                                      return const SizedBox.shrink();

                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Padding(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 20.w,
                                          ),
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
                                            padding: EdgeInsets.only(
                                              left: 20.w,
                                            ),
                                            scrollDirection: Axis.horizontal,
                                            physics:
                                                const BouncingScrollPhysics(),
                                            itemCount: similarItems.length,
                                            itemBuilder: (context, index) {
                                              return SizedBox(
                                                width: 160.w,
                                                child: GroceryItemCard(
                                                  item: similarItems[index],
                                                  margin: EdgeInsets.only(
                                                    right: 12.w,
                                                    bottom: 10.h,
                                                  ),
                                                  onTap: () {
                                                    context.push(
                                                      '/foodDetails',
                                                      extra:
                                                          similarItems[index],
                                                    );
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
                    final bool isItemPending = provider.isItemOperationPending(
                      cartItem,
                    );

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        isInCart
                            ? Expanded(
                                child: Container(
                                  height: size.height * 0.06,
                                  margin: EdgeInsets.only(right: KSpacing.md.w),
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 10.w,
                                  ),
                                  decoration: BoxDecoration(
                                    color: colors.backgroundSecondary,
                                    borderRadius: BorderRadius.circular(
                                      KBorderSize.borderRadius15,
                                    ),
                                    border: Border.all(
                                      color: colors.inputBorder,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      InkWell(
                                        onTap: () {
                                          if (isItemPending) return;
                                          if (isInCart) {
                                            provider.removeFromCart(cartItem);
                                          }
                                        },
                                        child: isItemPending
                                            ? SizedBox(
                                                width: 20.w,
                                                height: 20.w,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  valueColor:
                                                      AlwaysStoppedAnimation<
                                                        Color
                                                      >(colors.textSecondary),
                                                ),
                                              )
                                            : Icon(
                                                Icons.remove,
                                                color: colors.textSecondary,
                                                size: 20,
                                              ),
                                      ),
                                      Text(
                                        isItemPending ? '...' : qty.toString(),
                                        style: TextStyle(
                                          fontSize: 12.sp,
                                          fontWeight: FontWeight.w400,
                                          color: colors.textPrimary,
                                        ),
                                      ),
                                      GestureDetector(
                                        onTap: () {
                                          if (isItemPending) return;
                                          provider.addToCart(
                                            cartItem,
                                            context: context,
                                          );
                                        },
                                        child: Container(
                                          padding: EdgeInsets.all(2.r),
                                          decoration: BoxDecoration(
                                            color: colors.accentOrange,
                                            shape: BoxShape.circle,
                                          ),
                                          child: isItemPending
                                              ? SizedBox(
                                                  width: 20.w,
                                                  height: 20.w,
                                                  child: const CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    valueColor:
                                                        AlwaysStoppedAnimation<
                                                          Color
                                                        >(Colors.white),
                                                  ),
                                                )
                                              : const Icon(
                                                  Icons.add,
                                                  color: Colors.white,
                                                  size: 20,
                                                ),
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
                              color: colors.accentOrange,
                              borderRadius: BorderRadius.circular(
                                KBorderSize.borderRadius15,
                              ),
                            ),
                            child: AppButton(
                              onPressed: () {
                                if (isItemPending) return;
                                if (isInCart) {
                                  provider.removeItemCompletely(cartItem);
                                } else {
                                  provider.addToCart(
                                    cartItem,
                                    context: context,
                                  );
                                }
                              },
                              backgroundColor: Colors.transparent,
                              borderRadius: KBorderSize.borderRadius50,
                              buttonText: isItemPending
                                  ? "Updating..."
                                  : (isInCart
                                        ? "Remove from Cart"
                                        : "Add to Cart"),
                              textStyle: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
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

  Text _buildSectionHeader(AppColorsExtension colors, String name) {
    return Text(
      name,
      style: TextStyle(
        fontSize: 16.sp,
        fontWeight: FontWeight.w800,
        color: colors.textPrimary,
      ),
    );
  }

  Widget _buildRestaurantFoodItem(FoodItem item, AppColorsExtension colors) {
    return Consumer<CartProvider>(
      builder: (context, cartProvider, child) {
        final bool isInCart = cartProvider.cartItems.containsKey(item);
        final bool isItemPending = cartProvider.isItemOperationPending(item);

        return FoodItemCard(
          item: item,
          margin: EdgeInsets.zero,
          onTap: () {
            context.push("/foodDetails", extra: item);
          },
          trailing: GestureDetector(
            onTap: () {
              if (isItemPending) return;
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
                color: isInCart
                    ? colors.accentOrange
                    : colors.backgroundSecondary,
                border: Border.all(
                  color: isInCart ? colors.accentOrange : colors.inputBorder,
                  width: 1,
                ),
              ),
              child: isItemPending
                  ? SizedBox(
                      width: 16.w,
                      height: 16.w,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isInCart ? Colors.white : colors.accentOrange,
                        ),
                      ),
                    )
                  : SvgPicture.asset(
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
          ),
        );
      },
    );
  }
}
