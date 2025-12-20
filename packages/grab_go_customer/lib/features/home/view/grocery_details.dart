import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_customer/features/cart/viewmodel/cart_provider.dart';
import 'package:grab_go_customer/features/groceries/model/grocery_item.dart';
import 'package:grab_go_customer/features/groceries/viewmodel/grocery_provider.dart';
import 'package:grab_go_customer/features/home/model/food_category.dart';
import 'package:grab_go_customer/shared/widgets/grocery_details_appbar.dart';
import 'package:grab_go_customer/shared/widgets/grocery_item_card.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:provider/provider.dart';
import 'package:readmore/readmore.dart';

extension GroceryItemToFood on GroceryItem {
  FoodItem toFoodItem() {
    return FoodItem(
      id: id,
      name: name,
      image: image,
      description: description,
      sellerName: storeName ?? brand,
      sellerId: storeId.hashCode, // Temporary int conversion
      restaurantId: storeId,
      restaurantImage: storeLogo ?? '',
      price: price,
      rating: rating,
      discountPercentage: discountPercentage,
      discountEndDate: discountEndDate,
      isAvailable: isAvailable,
    );
  }
}

class GroceryDetails extends StatefulWidget {
  const GroceryDetails({super.key, required this.groceryItem});

  final GroceryItem groceryItem;

  @override
  State<GroceryDetails> createState() => _GroceryDetailsState();
}

class _GroceryDetailsState extends State<GroceryDetails> with TickerProviderStateMixin {
  late ScrollController _scrollController;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _animationController = AnimationController(duration: const Duration(milliseconds: 800), vsync: this);

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
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Size size = MediaQuery.sizeOf(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        systemNavigationBarColor: colors.backgroundPrimary,
        systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: colors.backgroundSecondary,
        body: CustomScrollView(
          controller: _scrollController,
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          slivers: <Widget>[
            GroceryDetailsAppBar(groceryItem: widget.groceryItem),
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
                        // Header Info
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 20.w),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (widget.groceryItem.brand.isNotEmpty)
                                      Text(
                                        widget.groceryItem.brand.toUpperCase(),
                                        style: TextStyle(
                                          color: colors.textSecondary,
                                          fontSize: 12.sp,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 1.0,
                                        ),
                                      ),
                                    SizedBox(height: 4.h),
                                    Text(
                                      widget.groceryItem.name,
                                      style: TextStyle(
                                        color: colors.textPrimary,
                                        fontSize: 22.sp,
                                        fontWeight: FontWeight.w800,
                                        height: 1.2,
                                      ),
                                    ),
                                    SizedBox(height: 6.h),
                                    Container(
                                      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                                      decoration: BoxDecoration(
                                        color: colors.inputBackground,
                                        borderRadius: BorderRadius.circular(6.r),
                                      ),
                                      child: Text(
                                        widget.groceryItem.unit,
                                        style: TextStyle(
                                          color: colors.textSecondary,
                                          fontSize: 12.sp,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(width: 12.w),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  if (widget.groceryItem.hasDiscount)
                                    Text(
                                      "GHS ${widget.groceryItem.price.toStringAsFixed(2)}",
                                      style: TextStyle(
                                        color: colors.textSecondary,
                                        fontSize: 14.sp,
                                        fontWeight: FontWeight.w500,
                                        decoration: TextDecoration.lineThrough,
                                      ),
                                    ),
                                  Text(
                                    "GHS ${widget.groceryItem.discountedPrice.toStringAsFixed(2)}",
                                    style: TextStyle(
                                      color: colors.accentOrange,
                                      fontSize: 20.sp,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 16.h),

                        // Chips (Rating, Store, Availability)
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 20.w),
                          child: Row(
                            children: [
                              _buildInfoChip(
                                icon: Assets.icons.star,
                                text: widget.groceryItem.rating.toStringAsFixed(1),
                                colors: colors,
                                isDark: isDark,
                              ),
                              SizedBox(width: 8.w),
                              if (widget.groceryItem.stock < 10 && widget.groceryItem.isAvailable) ...[
                                _buildInfoChip(
                                  icon: Assets.icons.infoCircle, // Replace with alert icon if available
                                  text: "Only ${widget.groceryItem.stock} left",
                                  colors: colors,
                                  isDark: isDark,
                                  textColor: Colors.red,
                                ),
                              ] else if (widget.groceryItem.isAvailable) ...[
                                _buildInfoChip(
                                  icon: Assets.icons.check, // Replace with check icon
                                  text: "In Stock",
                                  colors: colors,
                                  isDark: isDark,
                                ),
                              ] else ...[
                                _buildInfoChip(
                                  icon: Assets.icons.alarm, // Replace with close/unavailable icon
                                  text: "Out of Stock",
                                  colors: colors,
                                  isDark: isDark,
                                  textColor: Colors.red,
                                ),
                              ],
                            ],
                          ),
                        ),

                        SizedBox(height: KSpacing.lg.h),

                        // Description
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
                                Text(
                                  "Description",
                                  style: TextStyle(
                                    fontSize: 18.sp,
                                    fontWeight: FontWeight.w800,
                                    color: colors.textPrimary,
                                  ),
                                ),
                                SizedBox(height: 12.h),
                                ReadMoreText(
                                  widget.groceryItem.description,
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

                        // Similar Items (from same category)
                        Consumer<GroceryProvider>(
                          builder: (context, provider, child) {
                            final similarItems = provider.items
                                .where(
                                  (item) =>
                                      item.categoryId == widget.groceryItem.categoryId &&
                                      item.id != widget.groceryItem.id,
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
                                            context.push('/grocery-details', extra: similarItems[index]);
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

                        SizedBox(height: 100.h), // Bottom padding
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          child: Container(
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
                height: 90.h,
                padding: EdgeInsets.all(14.r),
                decoration: BoxDecoration(color: colors.backgroundPrimary),
                child: Consumer<CartProvider>(
                  builder: (context, provider, _) {
                    final int qty = provider.cartItems[widget.groceryItem] ?? 0;
                    final bool isInCart = qty > 0;

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Container(
                            height: 50.h,
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
                                      provider.removeFromCart(widget.groceryItem);
                                    }
                                  },
                                  child: Icon(Icons.remove, color: colors.textSecondary, size: 20.sp),
                                ),
                                Text(
                                  qty.toString(),
                                  style: TextStyle(
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.w600,
                                    color: colors.textPrimary,
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () {
                                    provider.addToCart(widget.groceryItem, context: context);
                                  },
                                  child: Container(
                                    padding: EdgeInsets.all(2.r),
                                    decoration: BoxDecoration(color: colors.accentOrange, shape: BoxShape.circle),
                                    child: Icon(Icons.add, color: Colors.white, size: 20.sp),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        SizedBox(width: KSpacing.md.w),

                        Expanded(
                          flex: 2,
                          child: Container(
                            height: 50.h,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [colors.accentOrange, colors.accentOrange.withOpacity(0.8)],
                              ),
                              borderRadius: BorderRadius.circular(KBorderSize.borderRadius50),
                              boxShadow: [
                                BoxShadow(
                                  color: colors.accentOrange.withOpacity(0.4),
                                  blurRadius: 12,
                                  spreadRadius: 0,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              onPressed: () {
                                if (isInCart) {
                                  provider.removeItemCompletely(widget.groceryItem);
                                } else {
                                  provider.addToCart(widget.groceryItem, context: context);
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(KBorderSize.borderRadius50),
                                ),
                              ),
                              child: Text(
                                isInCart ? "Remove from Cart" : "Add to Cart",
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16.sp),
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

  Widget _buildInfoChip({
    required String icon,
    required String text,
    required AppColorsExtension colors,
    required bool isDark,
    Color? textColor,
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
            style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w600, color: textColor ?? colors.textPrimary),
          ),
        ],
      ),
    );
  }
}
