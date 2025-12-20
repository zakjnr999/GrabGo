import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_customer/features/cart/viewmodel/cart_provider.dart';
import 'package:grab_go_customer/features/home/viewmodel/food_provider.dart';
import 'package:grab_go_customer/features/restaurant/viewmodel/restaurant_provider.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_customer/features/restaurant/model/restaurants_model.dart';
import 'package:grab_go_customer/features/home/model/food_category.dart';
import 'package:grab_go_customer/shared/widgets/restaurant_details_appbar.dart';
import 'package:grab_go_customer/shared/widgets/restaurant_details_banner.dart';
import 'package:grab_go_customer/shared/widgets/restaurant_details_info_box.dart';
import 'package:provider/provider.dart';
import 'package:readmore/readmore.dart';
import 'package:shimmer/shimmer.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:grab_go_customer/shared/widgets/food_item_card.dart';

class RestaurantDetails extends StatefulWidget {
  const RestaurantDetails({super.key, required this.restaurant});
  final RestaurantModel restaurant;

  @override
  State<RestaurantDetails> createState() => _RestaurantDetailsState();
}

class _RestaurantDetailsState extends State<RestaurantDetails> with TickerProviderStateMixin {
  late RestaurantModel selectedCategory;
  int selectedTabIndex = 0;
  int _restaurantItemsToShow = 3;
  final int _itemsPerPage = 3;
  bool _isLoadingMore = false;
  late ScrollController _scrollController;

  late AnimationController _animationController;
  late AnimationController _bounceController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;

  List<FoodItem> get filteredFoodItems {
    final foodProvider = Provider.of<FoodProvider>(context, listen: false);

    if (widget.restaurant.foods.isNotEmpty) {
      final restaurantFoodItems = <FoodItem>[];

      for (final food in widget.restaurant.foods) {
        FoodItem? foundItem;
        for (final category in foodProvider.categories) {
          try {
            foundItem = category.items.firstWhere(
              (item) =>
                  item.name.toLowerCase() == food.name.toLowerCase() &&
                  item.sellerName.toLowerCase() == food.sellerName.toLowerCase(),
            );
            break;
          } catch (e) {
            continue;
          }
        }

        if (foundItem != null) {
          restaurantFoodItems.add(foundItem);
        } else {
          restaurantFoodItems.add(
            FoodItem(
              id: food.backendId.isNotEmpty ? food.backendId : food.id.toString(),
              name: food.name,
              image: food.imageUrl,
              description: food.description,
              sellerName: food.sellerName,
              sellerId: food.sellerId,
              restaurantId: widget.restaurant.backendId.isNotEmpty ? widget.restaurant.backendId : '',
              price: food.price,
              restaurantImage: widget.restaurant.imageUrl,
            ),
          );
        }
      }

      if (restaurantFoodItems.isNotEmpty) {
        return restaurantFoodItems;
      }
    }

    final allFoodItems = foodProvider.categories.expand((category) => category.items).where((item) {
      final itemSellerName = item.sellerName.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
      final restaurantName = widget.restaurant.name.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
      final matchesByName = itemSellerName == restaurantName;
      final matchesById = item.sellerId != 0 && widget.restaurant.id != 0 && item.sellerId == widget.restaurant.id;
      final matchesByContains = itemSellerName.contains(restaurantName) || restaurantName.contains(itemSellerName);

      return matchesByName ||
          matchesById ||
          (matchesByContains && itemSellerName.length > 3 && restaurantName.length > 3);
    }).toList();

    return allFoodItems;
  }

  List<String> get foodCategories {
    final categories = filteredFoodItems.map((food) => _getCategoryNameForFood(food)).toSet().toList();

    categories.sort();
    return ['All', ...categories];
  }

  String _getCategoryNameForFood(FoodItem foodItem) {
    final foodProvider = Provider.of<FoodProvider>(context, listen: false);
    for (final category in foodProvider.categories) {
      if (category.items.contains(foodItem)) {
        return category.name;
      }
    }
    return 'Other';
  }

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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<FoodProvider>(context, listen: false).fetchCategories();
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

  void _loadMoreRestaurantItems() {
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

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final size = MediaQuery.sizeOf(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        systemNavigationBarColor: colors.backgroundPrimary,
        systemNavigationBarIconBrightness: Brightness.dark,
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
      child: SafeArea(
        top: false,
        bottom: false,
        child: Scaffold(
          backgroundColor: colors.backgroundSecondary,
          body: AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return CustomScrollView(
                controller: _scrollController,
                physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                slivers: <Widget>[
                  RestaurantDetailsAppBar(restaurant: widget.restaurant),
                  SliverToBoxAdapter(
                    child: Transform.translate(
                      offset: Offset(0, _slideAnimation.value),
                      child: FadeTransition(
                        opacity: _fadeAnimation,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: RestaurantDetailsInfoBox(
                                      size: size,
                                      colors: colors,
                                      widget: widget,
                                      assetImg: Assets.icons.clock,
                                      text: widget.restaurant.averageDeliveryTime,
                                      subText: "Delivery time",
                                    ),
                                  ),
                                  SizedBox(width: KSpacing.md.w),
                                  Expanded(
                                    child: RestaurantDetailsInfoBox(
                                      size: size,
                                      colors: colors,
                                      widget: widget,
                                      assetImg: Assets.icons.creditCard,
                                      text: "GHC ${widget.restaurant.deliveryFee.toStringAsFixed(2)}",
                                      subText: "Delivery fee",
                                    ),
                                  ),
                                  SizedBox(width: KSpacing.md.w),
                                  Expanded(
                                    child: RestaurantDetailsInfoBox(
                                      size: size,
                                      colors: colors,
                                      widget: widget,
                                      assetImg: Assets.icons.deliveryTruck,
                                      text: "GHC ${widget.restaurant.minOrder.toStringAsFixed(2)}",
                                      subText: "Minimum order",
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            SizedBox(height: KSpacing.lg.h),

                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 20.0.w),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ReadMoreText(
                                    widget.restaurant.description,
                                    trimMode: TrimMode.Line,
                                    trimLines: 3,
                                    colorClickableText: colors.accentViolet,
                                    trimCollapsedText: "Show more",
                                    trimExpandedText: " Show less",
                                    moreStyle: TextStyle(
                                      fontSize: 12.sp,
                                      fontWeight: FontWeight.w900,
                                      color: colors.textPrimary,
                                    ),
                                    lessStyle: TextStyle(
                                      fontSize: 12.sp,
                                      fontWeight: FontWeight.w900,
                                      color: colors.textPrimary,
                                    ),
                                  ),
                                  SizedBox(height: 20.h),
                                  Container(
                                    decoration: BoxDecoration(
                                      color: colors.backgroundSecondary,
                                      borderRadius: BorderRadius.circular(12.r),
                                      border: Border.all(color: colors.inputBorder.withValues(alpha: 0.3), width: 0.5),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "Contact Information",
                                          style: TextStyle(
                                            fontSize: 17.sp,
                                            fontWeight: FontWeight.w600,
                                            color: colors.textPrimary,
                                          ),
                                        ),
                                        SizedBox(height: 16.h),
                                        _buildContactRow(
                                          icon: Assets.icons.mapPin,
                                          iconColor: colors.accentOrange,
                                          label: "Address",
                                          value: widget.restaurant.address,
                                          colors: colors,
                                          onTap: null,
                                        ),
                                        SizedBox(height: 6.h),
                                        _buildContactRow(
                                          icon: Assets.icons.phone,
                                          iconColor: colors.accentGreen,
                                          label: "Phone",
                                          value: widget.restaurant.phone,
                                          colors: colors,
                                          onTap: () => _makePhoneCall(widget.restaurant.phone),
                                        ),
                                        SizedBox(height: 6.h),
                                        _buildContactRow(
                                          icon: Assets.icons.mail,
                                          iconColor: colors.accentViolet,
                                          label: "Email",
                                          value: widget.restaurant.email,
                                          colors: colors,
                                          onTap: () => _sendEmail(widget.restaurant.email),
                                        ),
                                        if (widget.restaurant.openingHours.isNotEmpty) ...[
                                          SizedBox(height: 6.h),
                                          Padding(
                                            padding: EdgeInsets.only(top: 4.h),
                                            child: Row(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Container(
                                                  padding: EdgeInsets.all(6.w),
                                                  decoration: BoxDecoration(
                                                    color: colors.accentOrange.withValues(alpha: 0.1),
                                                    borderRadius: BorderRadius.circular(8.r),
                                                  ),
                                                  child: SvgPicture.asset(
                                                    Assets.icons.clock,
                                                    package: 'grab_go_shared',
                                                    height: 16.h,
                                                    width: 16.w,
                                                    colorFilter: ColorFilter.mode(colors.accentOrange, BlendMode.srcIn),
                                                  ),
                                                ),
                                                SizedBox(width: 12.w),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        "Opening Hours",
                                                        style: TextStyle(
                                                          fontSize: 12.sp,
                                                          fontWeight: FontWeight.w500,
                                                          color: colors.textSecondary,
                                                        ),
                                                      ),
                                                      SizedBox(height: 4.h),
                                                      Text(
                                                        widget.restaurant.openingHours,
                                                        style: TextStyle(
                                                          fontSize: 14.sp,
                                                          fontWeight: FontWeight.w400,
                                                          color: colors.textPrimary,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                        if (widget.restaurant.paymentMethods.isNotEmpty) ...[
                                          SizedBox(height: 12.h),
                                          Padding(
                                            padding: EdgeInsets.only(top: 4.h),
                                            child: Row(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Container(
                                                  padding: EdgeInsets.all(6.w),
                                                  decoration: BoxDecoration(
                                                    color: colors.accentViolet.withValues(alpha: 0.1),
                                                    borderRadius: BorderRadius.circular(8.r),
                                                  ),
                                                  child: SvgPicture.asset(
                                                    Assets.icons.creditCard,
                                                    package: 'grab_go_shared',
                                                    height: 16.h,
                                                    width: 16.w,
                                                    colorFilter: ColorFilter.mode(colors.accentViolet, BlendMode.srcIn),
                                                  ),
                                                ),
                                                SizedBox(width: 12.w),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        "Payment Methods",
                                                        style: TextStyle(
                                                          fontSize: 12.sp,
                                                          fontWeight: FontWeight.w500,
                                                          color: colors.textSecondary,
                                                        ),
                                                      ),
                                                      SizedBox(height: 4.h),
                                                      Wrap(
                                                        spacing: 8.w,
                                                        runSpacing: 8.h,
                                                        children: widget.restaurant.paymentMethods.map((method) {
                                                          return Container(
                                                            padding: EdgeInsets.symmetric(
                                                              horizontal: 12.w,
                                                              vertical: 8.h,
                                                            ),
                                                            decoration: BoxDecoration(
                                                              color: Colors.transparent,
                                                              borderRadius: BorderRadius.circular(8.r),
                                                              border: Border.all(color: colors.inputBorder, width: 1),
                                                            ),
                                                            child: Text(
                                                              method,
                                                              style: TextStyle(
                                                                fontSize: 12.sp,
                                                                fontWeight: FontWeight.w500,
                                                                color: colors.textPrimary,
                                                              ),
                                                            ),
                                                          );
                                                        }).toList(),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: KSpacing.lg.h),

                            Consumer<RestaurantProvider>(
                              builder: (context, provider, _) {
                                return RestaurantDetailsBanner(
                                  restaurant: widget.restaurant,
                                  isLoading: provider.isLoading,
                                );
                              },
                            ),

                            SizedBox(height: KSpacing.lg.h),

                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 20.w),
                              child: Row(
                                children: [
                                  Container(
                                    padding: EdgeInsets.all(8.r),
                                    decoration: BoxDecoration(
                                      color: colors.accentViolet.withValues(alpha: 0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: SvgPicture.asset(
                                      Assets.icons.star,
                                      package: 'grab_go_shared',
                                      height: 18.h,
                                      width: 18.w,
                                      colorFilter: ColorFilter.mode(colors.accentViolet, BlendMode.srcIn),
                                    ),
                                  ),
                                  SizedBox(width: 10.w),
                                  Text(
                                    "Customer Reviews",
                                    style: TextStyle(
                                      fontSize: 17.sp,
                                      fontWeight: FontWeight.w800,
                                      color: colors.textPrimary,
                                    ),
                                  ),
                                  const Spacer(),
                                  Container(
                                    padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                                    decoration: BoxDecoration(
                                      color: colors.accentViolet.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(12.r),
                                    ),
                                    child: Text(
                                      "${widget.restaurant.totalReviews > 0 ? widget.restaurant.totalReviews : 8} ${(widget.restaurant.totalReviews > 0 ? widget.restaurant.totalReviews : 8) == 1 ? 'review' : 'reviews'}",
                                      style: TextStyle(
                                        fontSize: 12.sp,
                                        fontWeight: FontWeight.w600,
                                        color: colors.accentViolet,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            SizedBox(height: 16.h),

                            _buildReviewsSection(colors, size),

                            SizedBox(height: KSpacing.lg.h),

                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 20.w),
                              child: Row(
                                children: [
                                  Container(
                                    padding: EdgeInsets.all(8.r),
                                    decoration: BoxDecoration(
                                      color: colors.accentOrange.withValues(alpha: 0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: SvgPicture.asset(
                                      Assets.icons.utensilsCrossed,
                                      package: 'grab_go_shared',
                                      height: 18.h,
                                      width: 18.w,
                                      colorFilter: ColorFilter.mode(colors.accentOrange, BlendMode.srcIn),
                                    ),
                                  ),
                                  SizedBox(width: 10.w),
                                  Text(
                                    "Available Meals",
                                    style: TextStyle(
                                      fontSize: 17.sp,
                                      fontWeight: FontWeight.w800,
                                      color: colors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            SizedBox(height: 16.h),
                            Consumer<RestaurantProvider>(
                              builder: (context, provider, _) {
                                if (provider.isLoading) {
                                  return Shimmer.fromColors(
                                    baseColor: Theme.of(context).brightness == Brightness.dark
                                        ? Colors.grey.shade800
                                        : Colors.grey.shade300,
                                    highlightColor: Theme.of(context).brightness == Brightness.dark
                                        ? Colors.grey.shade700
                                        : Colors.grey.shade100,
                                    child: Container(
                                      height: 50.h,
                                      margin: EdgeInsets.symmetric(horizontal: 20.w),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).brightness == Brightness.dark
                                            ? Colors.grey.shade800
                                            : Colors.grey.shade300,
                                        borderRadius: BorderRadius.circular(KBorderSize.borderRadius8),
                                      ),
                                    ),
                                  );
                                }

                                return AnimatedTabBar(
                                  tabs: foodCategories,
                                  selectedIndex: selectedTabIndex,
                                  onTabChanged: (index) {
                                    setState(() {
                                      selectedTabIndex = index;
                                    });
                                  },
                                );
                              },
                            ),
                            SizedBox(height: KSpacing.lg.h),
                            Consumer<FoodProvider>(
                              builder: (context, foodProvider, _) {
                                if (foodProvider.isLoading) {
                                  return Shimmer.fromColors(
                                    baseColor: Theme.of(context).brightness == Brightness.dark
                                        ? Colors.grey.shade800
                                        : Colors.grey.shade300,
                                    highlightColor: Theme.of(context).brightness == Brightness.dark
                                        ? Colors.grey.shade700
                                        : Colors.grey.shade100,
                                    child: Column(
                                      children: List.generate(3, (index) {
                                        return Container(
                                          height: size.height * 0.15,
                                          margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
                                          decoration: BoxDecoration(
                                            color: Theme.of(context).brightness == Brightness.dark
                                                ? Colors.grey.shade800
                                                : Colors.grey.shade300,
                                            borderRadius: BorderRadius.circular(KBorderSize.borderMedium),
                                          ),
                                        );
                                      }),
                                    ),
                                  );
                                }

                                if (foodProvider.error != null) {
                                  return Container(
                                    height: size.height * 0.2,
                                    margin: EdgeInsets.symmetric(horizontal: 16.w),
                                    child: Center(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            'Error loading food items',
                                            style: TextStyle(color: colors.textSecondary, fontSize: 14.sp),
                                          ),
                                          SizedBox(height: KSpacing.sm.h),
                                          Text(
                                            foodProvider.error!,
                                            style: TextStyle(color: colors.textTertiary, fontSize: 12.sp),
                                            textAlign: TextAlign.center,
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }

                                final filteredFoods = selectedTabIndex == 0
                                    ? filteredFoodItems
                                    : filteredFoodItems
                                          .where(
                                            (food) => _getCategoryNameForFood(food) == foodCategories[selectedTabIndex],
                                          )
                                          .toList();

                                if (filteredFoods.isEmpty) {
                                  return Container(
                                    height: size.height * 0.2,
                                    margin: EdgeInsets.symmetric(horizontal: 16.w),
                                    child: Center(
                                      child: Column(
                                        mainAxisAlignment: .center,
                                        children: [
                                          Text(
                                            'No food items found',
                                            style: TextStyle(
                                              color: colors.textSecondary,
                                              fontSize: 14.sp,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          SizedBox(height: KSpacing.sm.h),
                                          Text(
                                            'This restaurant has no items in the selected category',
                                            style: TextStyle(color: colors.textTertiary, fontSize: 12.sp),
                                            textAlign: TextAlign.center,
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }

                                final displayedItems = filteredFoods.take(_restaurantItemsToShow).toList();
                                final hasMoreItems = filteredFoods.length > _restaurantItemsToShow;

                                return Column(
                                  children: [
                                    ListView.builder(
                                      physics: const NeverScrollableScrollPhysics(),
                                      shrinkWrap: true,
                                      itemCount: displayedItems.length + (hasMoreItems && _isLoadingMore ? 1 : 0),
                                      padding: EdgeInsets.symmetric(horizontal: 16.w),
                                      itemBuilder: (context, index) {
                                        // Show loading indicator at the end
                                        if (index >= displayedItems.length) {
                                          LoadingMore(
                                            colors: colors,
                                            spinnerColor: colors.accentOrange,
                                            borderColor: colors.accentOrange,
                                          );
                                        }
                                        final food = displayedItems[index];

                                        return Consumer<CartProvider>(
                                          builder: (context, cartProvider, _) {
                                            final bool isInCart = cartProvider.cartItems.containsKey(food);

                                            return FoodItemCard(
                                              item: food,
                                              margin: EdgeInsets.symmetric(vertical: 6.h),
                                              onTap: () {
                                                context.push('/foodDetails', extra: food);
                                              },
                                              trailing: GestureDetector(
                                                onTap: () {
                                                  if (isInCart) {
                                                    cartProvider.removeItemCompletely(food);
                                                  } else {
                                                    cartProvider.addToCart(food, context: context);
                                                  }
                                                },
                                                child: Container(
                                                  padding: EdgeInsets.all(8.r),
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
                                              ),
                                            );
                                          },
                                        );
                                      },
                                    ),
                                  ],
                                );
                              },
                            ),

                            SizedBox(height: KSpacing.lg.h),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),

          bottomNavigationBar: SafeArea(
            child: Container(
              height: size.height * 0.08,
              decoration: BoxDecoration(
                color: colors.backgroundPrimary,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(KBorderSize.border),
                  topRight: Radius.circular(KBorderSize.border),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(10),
                    spreadRadius: 1,
                    blurRadius: 20,
                    offset: const Offset(0, -3),
                  ),
                ],
              ),
              padding: EdgeInsets.all(14.r),
              child: Consumer<CartProvider>(
                builder: (context, provider, _) {
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                        child: Row(
                          children: [
                            SvgPicture.asset(
                              Assets.icons.cart,
                              package: 'grab_go_shared',
                              height: 20.h,
                              width: 20.w,
                              colorFilter: ColorFilter.mode(colors.textPrimary, BlendMode.srcIn),
                            ),
                            SizedBox(width: 5.w),
                            Text(
                              provider.totalQuantity == 0
                                  ? "Empty cart"
                                  : provider.totalQuantity > 1
                                  ? "${provider.totalQuantity} items"
                                  : "${provider.totalQuantity} item",
                              style: TextStyle(fontSize: 14.sp, color: colors.textPrimary, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        "GHC ${provider.totalPrice.toStringAsFixed(2)}",
                        style: TextStyle(fontSize: 14.sp, color: colors.textPrimary, fontWeight: FontWeight.w600),
                      ),

                      Row(
                        children: [
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                context.push("/cart");
                              },
                              borderRadius: BorderRadius.circular(KBorderSize.border),
                              splashColor: colors.accentOrange.withValues(alpha: 0.05),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                                child: Row(
                                  children: [
                                    Text(
                                      "View Cart",
                                      style: TextStyle(
                                        fontSize: 14.sp,
                                        color: colors.textPrimary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    SizedBox(width: 5.w),
                                    SvgPicture.asset(
                                      Assets.icons.navArrowRight,
                                      package: 'grab_go_shared',
                                      height: 20.h,
                                      width: 20.w,
                                      colorFilter: ColorFilter.mode(colors.textPrimary, BlendMode.srcIn),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContactRow({
    required String icon,
    required Color iconColor,
    required String label,
    required String value,
    required AppColorsExtension colors,
    VoidCallback? onTap,
  }) {
    final content = Padding(
      padding: EdgeInsets.symmetric(vertical: 8.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(6.w),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: SvgPicture.asset(
              icon,
              package: 'grab_go_shared',
              height: 16.h,
              width: 16.w,
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
                  style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w500, color: colors.textSecondary),
                ),
                SizedBox(height: 4.h),
                Text(
                  value,
                  style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w400, color: colors.textPrimary),
                ),
              ],
            ),
          ),
          if (onTap != null)
            SvgPicture.asset(
              Assets.icons.navArrowRight,
              package: 'grab_go_shared',
              height: 16.h,
              width: 16.w,
              colorFilter: ColorFilter.mode(colors.textSecondary.withValues(alpha: 0.5), BlendMode.srcIn),
            ),
        ],
      ),
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(8.r), child: content),
      );
    }

    return content;
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    try {
      final Uri phoneUri = Uri(scheme: 'tel', path: phoneNumber);
      if (await canLaunchUrl(phoneUri)) {
        await launchUrl(phoneUri);
      } else {
        if (mounted) {
          AppToastMessage.show(
            context: context,
            icon: Icons.error_outline,
            message: 'Unable to open phone dialer. Please try again.',
            backgroundColor: context.appColors.error,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        AppToastMessage.show(
          context: context,
          icon: Icons.error_outline,
          message: 'Error opening phone dialer: $e',
          backgroundColor: context.appColors.error,
        );
      }
    }
  }

  Future<void> _sendEmail(String email) async {
    try {
      final Uri emailUri = Uri(
        scheme: 'mailto',
        path: email,
        query: 'subject=${Uri.encodeComponent('Inquiry about ${widget.restaurant.name}')}',
      );
      if (await canLaunchUrl(emailUri)) {
        await launchUrl(emailUri);
      } else {
        if (mounted) {
          await Clipboard.setData(ClipboardData(text: email));
          AppToastMessage.show(
            context: context,
            icon: Icons.check_circle,
            message: 'Email copied to clipboard: $email',
            backgroundColor: context.appColors.accentOrange,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        AppToastMessage.show(
          context: context,
          icon: Icons.error_outline,
          message: 'Error opening email client: $e',
          backgroundColor: context.appColors.error,
        );
      }
    }
  }

  Widget _buildReviewsSection(AppColorsExtension colors, Size size) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final reviews = [
      {
        'name': 'John Doe',
        'rating': 5.0,
        'date': '2 days ago',
        'comment':
            'Amazing food and fast delivery! The quality is excellent and the portions are generous. Highly recommend!',
      },
      {
        'name': 'Sarah Williams',
        'rating': 4.5,
        'date': '1 week ago',
        'comment':
            'Great restaurant with delicious meals. The delivery was on time and the food was still hot. Will order again!',
      },
      {
        'name': 'Michael Chen',
        'rating': 4.0,
        'date': '2 weeks ago',
        'comment':
            'Good food quality and reasonable prices. The only downside was a slight delay in delivery, but overall satisfied.',
      },
      {
        'name': 'Emily Rodriguez',
        'rating': 5.0,
        'date': '3 days ago',
        'comment':
            'Absolutely loved everything! The food arrived hot and fresh. The portions are huge and the taste is incredible. This is now my go-to restaurant!',
      },
      {
        'name': 'David Thompson',
        'rating': 4.5,
        'date': '5 days ago',
        'comment':
            'Excellent service and delicious food. The packaging was great and everything arrived intact. Will definitely order from here again.',
      },
      {
        'name': 'Lisa Anderson',
        'rating': 4.0,
        'date': '1 week ago',
        'comment':
            'Really good food at reasonable prices. The delivery was a bit late but the food quality made up for it. Satisfied customer!',
      },
      {
        'name': 'James Wilson',
        'rating': 5.0,
        'date': '4 days ago',
        'comment':
            'Best restaurant in town! The food is always fresh, tasty, and well-prepared. Customer service is top-notch. Highly recommended!',
      },
      {
        'name': 'Maria Garcia',
        'rating': 4.5,
        'date': '6 days ago',
        'comment':
            'Great variety of dishes and everything tastes amazing. The delivery time is usually accurate. Very happy with my orders!',
      },
    ];

    // Show reviews if we have reviews data, regardless of totalReviews count
    if (reviews.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: 20.w),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.all(24.r),
          decoration: BoxDecoration(
            color: colors.backgroundPrimary,
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: colors.inputBorder.withValues(alpha: 0.3), width: 0.5),
          ),
          child: Column(
            children: [
              Container(
                padding: EdgeInsets.all(16.r),
                decoration: BoxDecoration(color: colors.accentViolet.withValues(alpha: 0.1), shape: BoxShape.circle),
                child: SvgPicture.asset(
                  Assets.icons.starSolid,
                  package: 'grab_go_shared',
                  height: 32.h,
                  width: 32.w,
                  colorFilter: ColorFilter.mode(colors.accentViolet, BlendMode.srcIn),
                ),
              ),
              SizedBox(height: 16.h),
              Text(
                'No reviews yet',
                style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600, color: colors.textPrimary),
              ),
              SizedBox(height: 8.h),
              Text(
                'Be the first to review this restaurant!',
                style: TextStyle(fontSize: 14.sp, color: colors.textSecondary),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: Column(
        children: [
          // Show first 3 reviews, add "View All" if more exist
          ...reviews.take(3).map<Widget>((review) {
            return Container(
              margin: EdgeInsets.only(bottom: 12.h),
              padding: EdgeInsets.all(16.r),
              decoration: BoxDecoration(
                color: colors.backgroundPrimary,
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: colors.inputBorder.withValues(alpha: 0.3), width: 0.5),
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
                  Row(
                    children: [
                      Container(
                        width: 40.w,
                        height: 40.h,
                        decoration: BoxDecoration(
                          color: colors.accentViolet.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            (review['name'] as String).substring(0, 1).toUpperCase(),
                            style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w700, color: colors.accentViolet),
                          ),
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              review['name'] as String,
                              style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w700, color: colors.textPrimary),
                            ),
                            SizedBox(height: 4.h),
                            Row(
                              children: [
                                ...List.generate(5, (index) {
                                  final rating = review['rating'] as double;
                                  final isFilled = index < rating.floor();
                                  final isHalf = index == rating.floor() && rating % 1 >= 0.5;
                                  return Padding(
                                    padding: EdgeInsets.only(right: 2.w),
                                    child: SvgPicture.asset(
                                      Assets.icons.starSolid,
                                      package: 'grab_go_shared',
                                      height: 14.h,
                                      width: 14.w,
                                      colorFilter: ColorFilter.mode(
                                        isFilled || isHalf ? colors.accentOrange : colors.inputBorder,
                                        BlendMode.srcIn,
                                      ),
                                    ),
                                  );
                                }),
                                SizedBox(width: 6.w),
                                Text(
                                  (review['rating'] as double).toStringAsFixed(1),
                                  style: TextStyle(
                                    fontSize: 12.sp,
                                    fontWeight: FontWeight.w600,
                                    color: colors.textPrimary,
                                  ),
                                ),
                                SizedBox(width: 8.w),
                                Container(
                                  width: 3.w,
                                  height: 3.h,
                                  decoration: BoxDecoration(shape: BoxShape.circle, color: colors.textSecondary),
                                ),
                                SizedBox(width: 8.w),
                                Text(
                                  review['date'] as String,
                                  style: TextStyle(
                                    fontSize: 12.sp,
                                    color: colors.textSecondary,
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
                  SizedBox(height: 12.h),
                  Text(
                    review['comment'] as String,
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w400,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            );
          }),

          // "View All Reviews" button if there are more reviews
          if (reviews.length > 3)
            Padding(
              padding: EdgeInsets.only(top: 8.h),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    // Navigate to full reviews page
                    // context.push('/restaurantReviews', extra: widget.restaurant);
                  },
                  borderRadius: BorderRadius.circular(12.r),
                  child: Container(
                    padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 16.w),
                    decoration: BoxDecoration(
                      color: colors.accentViolet.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(color: colors.accentViolet.withValues(alpha: 0.3), width: 1),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'View All ${reviews.length} Reviews',
                          style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600, color: colors.accentViolet),
                        ),
                        SizedBox(width: 8.w),
                        SvgPicture.asset(
                          Assets.icons.navArrowRight,
                          package: 'grab_go_shared',
                          height: 16.h,
                          width: 16.w,
                          colorFilter: ColorFilter.mode(colors.accentViolet, BlendMode.srcIn),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
