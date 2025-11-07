import 'package:dotted_line/dotted_line.dart';
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

class RestaurantDetails extends StatefulWidget {
  const RestaurantDetails({super.key, required this.restaurant});
  final RestaurantModel restaurant;

  @override
  State<RestaurantDetails> createState() => _RestaurantDetailsState();
}

class _RestaurantDetailsState extends State<RestaurantDetails> {
  late RestaurantModel selectedCategory;
  int selectedTabIndex = 0;

  List<FoodItem> get filteredFoodItems {
    final foodProvider = Provider.of<FoodProvider>(context, listen: false);
    final allFoodItems = foodProvider.categories.expand((category) => category.items).where((item) {
      final itemSellerName = item.sellerName.trim().toLowerCase();
      final restaurantName = widget.restaurant.name.trim().toLowerCase();
      final matchesByName = itemSellerName == restaurantName;
      final matchesById = item.sellerId == widget.restaurant.id;
      return matchesByName || matchesById;
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<FoodProvider>(context, listen: false).fetchCategories();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final size = MediaQuery.sizeOf(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        systemNavigationBarColor: colors.accentOrange,
        systemNavigationBarIconBrightness: Brightness.light,
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
      child: SafeArea(
        top: false,
        bottom: false,
        child: Scaffold(
          backgroundColor: colors.backgroundSecondary,
          body: CustomScrollView(
            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
            slivers: <Widget>[
              RestaurantDetailsAppBar(restaurant: widget.restaurant),
              SliverToBoxAdapter(
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
                              text: "GHC ${widget.restaurant.minOrder.toStringAsFixed(2)}",
                              subText: "Minimum order",
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: KSpacing.lg.h),

                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20.w),
                      child: DottedLine(
                        dashLength: 6,
                        dashGapLength: 4,
                        lineThickness: 1,
                        dashColor: colors.textSecondary.withAlpha(50),
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
                              fontWeight: FontWeight.w600,
                              color: colors.textPrimary,
                            ),
                            lessStyle: TextStyle(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w600,
                              color: colors.textPrimary,
                            ),
                          ),
                          SizedBox(height: 12.h),
                          Row(
                            children: [
                              SvgPicture.asset(
                                Assets.icons.mapPin,
                                package: 'grab_go_shared',
                                height: 16.h,
                                width: 16.w,
                                colorFilter: ColorFilter.mode(colors.textSecondary, BlendMode.srcIn),
                              ),
                              SizedBox(width: 5.w),
                              Text(
                                " ${widget.restaurant.address}",
                                style: TextStyle(
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w400,
                                  color: colors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 5.h),
                          Row(
                            children: [
                              SvgPicture.asset(
                                Assets.icons.phone,
                                package: 'grab_go_shared',
                                height: 16.h,
                                width: 16.w,
                                colorFilter: ColorFilter.mode(colors.textSecondary, BlendMode.srcIn),
                              ),
                              SizedBox(width: 5.w),
                              Text(
                                " ${widget.restaurant.phone}",
                                style: TextStyle(
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w400,
                                  color: colors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 5.h),
                          Row(
                            children: [
                              SvgPicture.asset(
                                Assets.icons.mail,
                                package: 'grab_go_shared',
                                height: 16.h,
                                width: 16.w,
                                colorFilter: ColorFilter.mode(colors.textSecondary, BlendMode.srcIn),
                              ),
                              SizedBox(width: 5.w),
                              Text(
                                " ${widget.restaurant.email}",
                                style: TextStyle(
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w400,
                                  color: colors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: KSpacing.lg.h),

                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20.w),
                      child: DottedLine(
                        dashLength: 6,
                        dashGapLength: 4,
                        lineThickness: 1,
                        dashColor: colors.textSecondary.withAlpha(50),
                      ),
                    ),

                    SizedBox(height: KSpacing.lg.h),

                    Consumer<RestaurantProvider>(
                      builder: (context, provider, _) {
                        return RestaurantDetailsBanner(restaurant: widget.restaurant, isLoading: provider.isLoading);
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
                              color: colors.accentOrange.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.restaurant_rounded, color: colors.accentOrange, size: 18.sp),
                          ),
                          SizedBox(width: 10.w),
                          Text(
                            "Available Meals",
                            style: TextStyle(fontSize: 17.sp, fontWeight: FontWeight.w800, color: colors.textPrimary),
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
                                  .where((food) => _getCategoryNameForFood(food) == foodCategories[selectedTabIndex])
                                  .toList();

                        if (filteredFoods.isEmpty) {
                          return Container(
                            height: size.height * 0.2,
                            margin: EdgeInsets.symmetric(horizontal: 16.w),
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
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

                        return ListView.builder(
                          physics: const NeverScrollableScrollPhysics(),
                          shrinkWrap: true,
                          itemCount: filteredFoods.length,
                          padding: EdgeInsets.symmetric(horizontal: 16.w),
                          itemBuilder: (context, index) {
                            final food = filteredFoods[index];
                            final isDark = Theme.of(context).brightness == Brightness.dark;

                            return GestureDetector(
                              onTap: () {
                                context.push('/foodDetails', extra: food);
                              },
                              child: Container(
                                margin: EdgeInsets.symmetric(vertical: 6.h),
                                decoration: BoxDecoration(
                                  color: colors.backgroundPrimary,
                                  borderRadius: BorderRadius.circular(KBorderSize.borderRadius15),
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
                                child: Row(
                                  children: [
                                    ClipRRect(
                                      borderRadius: const BorderRadius.only(
                                        topLeft: Radius.circular(KBorderSize.borderRadius15),
                                        bottomLeft: Radius.circular(KBorderSize.borderRadius15),
                                      ),
                                      child: Image.network(
                                        food.image,
                                        height: 110.h,
                                        width: 110.w,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) {
                                          return Container(
                                            height: 110.h,
                                            width: 110.w,
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
                                          );
                                        },
                                      ),
                                    ),

                                    Expanded(
                                      child: Padding(
                                        padding: EdgeInsets.all(12.r),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  food.name,
                                                  style: TextStyle(
                                                    fontSize: 15.sp,
                                                    fontWeight: FontWeight.w700,
                                                    color: colors.textPrimary,
                                                  ),
                                                  maxLines: 2,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                SizedBox(height: 6.h),
                                                Row(
                                                  children: [
                                                    SvgPicture.asset(
                                                      Assets.icons.starSolid,
                                                      package: 'grab_go_shared',
                                                      height: 13.h,
                                                      width: 13.w,
                                                      colorFilter: ColorFilter.mode(
                                                        colors.accentOrange,
                                                        BlendMode.srcIn,
                                                      ),
                                                    ),
                                                    SizedBox(width: 4.w),
                                                    Text(
                                                      food.rating.toStringAsFixed(1),
                                                      style: TextStyle(
                                                        fontSize: 12.sp,
                                                        color: colors.textPrimary,
                                                        fontWeight: FontWeight.w600,
                                                      ),
                                                    ),
                                                    SizedBox(width: 8.w),
                                                    Container(
                                                      width: 3.w,
                                                      height: 3.h,
                                                      decoration: BoxDecoration(
                                                        shape: BoxShape.circle,
                                                        color: colors.textSecondary,
                                                      ),
                                                    ),
                                                    SizedBox(width: 8.w),
                                                    Expanded(
                                                      child: Text(
                                                        _getCategoryNameForFood(food),
                                                        style: TextStyle(
                                                          fontSize: 11.sp,
                                                          fontWeight: FontWeight.w500,
                                                          color: colors.textSecondary,
                                                        ),
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                            SizedBox(height: 10.h),
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Container(
                                                  padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                                                  decoration: BoxDecoration(
                                                    color: colors.accentOrange.withValues(alpha: 0.15),
                                                    borderRadius: BorderRadius.circular(8.r),
                                                  ),
                                                  child: Text(
                                                    "GHS ${food.price.toStringAsFixed(2)}",
                                                    style: TextStyle(
                                                      fontSize: 13.sp,
                                                      fontWeight: FontWeight.w800,
                                                      color: colors.accentOrange,
                                                    ),
                                                  ),
                                                ),
                                                Consumer<CartProvider>(
                                                  builder: (context, cartProvider, _) {
                                                    final bool isInCart = cartProvider.cartItems.containsKey(food);

                                                    return GestureDetector(
                                                      onTap: () {
                                                        if (isInCart) {
                                                          cartProvider.removeItemCompletely(food);
                                                          AppToastMessage.show(
                                                            context: context,
                                                            icon: Icons.close,
                                                            message: AppStrings.cartRemoveItem,
                                                            backgroundColor: colors.error,
                                                          );
                                                        } else {
                                                          cartProvider.addToCart(food);
                                                          AppToastMessage.show(
                                                            context: context,
                                                            icon: Icons.check,
                                                            message: AppStrings.cartAddItem,
                                                            backgroundColor: colors.accentBlue,
                                                          );
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
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),

                    SizedBox(height: KSpacing.lg.h),
                  ],
                ),
              ),
            ],
          ),

          bottomNavigationBar: ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(KBorderSize.border),
              topRight: Radius.circular(KBorderSize.border),
            ),
            child: Container(
              height: size.height * 0.12,
              padding: EdgeInsets.all(14.r),
              decoration: BoxDecoration(
                color: colors.accentOrange,
                boxShadow: [
                  BoxShadow(
                    color: colors.accentOrange.withValues(alpha: 0.1),
                    blurRadius: 20,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
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
                              colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                            ),
                            SizedBox(width: 5.w),
                            Text(
                              provider.totalQuantity == 0
                                  ? "Empty cart"
                                  : provider.totalQuantity > 1
                                  ? "${provider.totalQuantity} items"
                                  : "${provider.totalQuantity} item",
                              style: TextStyle(fontSize: 14.sp, color: Colors.white, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        "GHC ${provider.totalPrice.toStringAsFixed(2)}",
                        style: TextStyle(fontSize: 14.sp, color: Colors.white, fontWeight: FontWeight.w600),
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
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    SizedBox(width: 5.w),
                                    SvgPicture.asset(
                                      Assets.icons.navArrowRight,
                                      package: 'grab_go_shared',
                                      height: 20.h,
                                      width: 20.w,
                                      colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
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
}
