// ignore_for_file: deprecated_member_use

import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_image_slideshow/flutter_image_slideshow.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_customer/features/cart/viewmodel/cart_provider.dart';
import 'package:grab_go_customer/features/home/viewmodel/food_provider.dart';
import 'package:grab_go_customer/shared/viewmodels/favorites_provider.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

import 'cached_image_widget.dart';

class HomeBanner extends StatefulWidget {
  const HomeBanner({super.key, required this.size});

  final Size size;

  @override
  State<HomeBanner> createState() => _HomeBannerState();
}

class _HomeBannerState extends State<HomeBanner> {
  int currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final itemsProvider = Provider.of<FoodProvider>(context);

    if (itemsProvider.isLoading) {
      return Shimmer.fromColors(
        baseColor: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
        highlightColor: isDark ? Colors.grey.shade700 : Colors.grey.shade100,
        child: Container(
          height: widget.size.height * 0.28,
          margin: EdgeInsets.symmetric(horizontal: 20.w),
          decoration: BoxDecoration(
            color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
            borderRadius: BorderRadius.circular(KBorderSize.borderMedium),
          ),
        ),
      );
    }

    if (itemsProvider.error != null) {
      return Shimmer.fromColors(
        baseColor: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
        highlightColor: isDark ? Colors.grey.shade700 : Colors.grey.shade100,
        child: Container(
          height: widget.size.height * 0.28,
          margin: EdgeInsets.symmetric(horizontal: 20.w),
          decoration: BoxDecoration(
            color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
            borderRadius: BorderRadius.circular(KBorderSize.borderMedium),
          ),
        ),
      );
    }

    final allFoods = itemsProvider.categories.expand((cat) => cat.items).toList();

    if (allFoods.isEmpty) {
      return Container(
        margin: EdgeInsets.symmetric(horizontal: 20.w),
        height: widget.size.height * 0.28,
        width: double.infinity,
        decoration: BoxDecoration(
          color: colors.backgroundPrimary,
          borderRadius: BorderRadius.circular(KBorderSize.borderMedium),
        ),
        child: Center(
          child: Text(
            "Banner is empty...",
            style: TextStyle(color: colors.textSecondary, fontSize: 16.sp, fontWeight: FontWeight.w500),
          ),
        ),
      );
    }

    final random = Random();
    final Set<int> selectedIndexes = {};
    while (selectedIndexes.length < 3 && selectedIndexes.length < allFoods.length) {
      selectedIndexes.add(random.nextInt(allFoods.length));
    }
    final bannerFoods = selectedIndexes.map((i) => allFoods[i]).toList();

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20.w),
      decoration: BoxDecoration(
        color: colors.backgroundPrimary,
        borderRadius: BorderRadius.circular(KBorderSize.borderMedium),
        boxShadow: [
          BoxShadow(color: Colors.black.withAlpha(10), spreadRadius: 1, blurRadius: 12, offset: const Offset(0, 4)),
          BoxShadow(color: Colors.black.withAlpha(5), spreadRadius: -1, blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(KBorderSize.borderMedium),
        child: Stack(
          children: [
            ImageSlideshow(
              height: widget.size.height * 0.28,
              width: widget.size.width,
              initialPage: 0,
              indicatorColor: Colors.transparent,
              indicatorBackgroundColor: Colors.transparent,
              disableUserScrolling: false,
              autoPlayInterval: 5000,
              isLoop: true,
              onPageChanged: (value) {
                setState(() {
                  currentIndex = value;
                });
              },
              children: bannerFoods
                  .map(
                    (food) => GestureDetector(
                      onTap: () => context.push("/foodDetails", extra: food),
                      child: CachedImageWidget(
                        imageUrl: food.image,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        placeholder: Container(
                          width: double.infinity,
                          height: widget.size.height * 0.26,
                          color: colors.inputBorder,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),

            Container(
              height: widget.size.height * 0.28,
              width: widget.size.width,
              padding: EdgeInsets.all(10.r),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(KBorderSize.borderMedium),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                          child: Container(
                            color: Colors.black.withOpacity(0.2),
                            child: Padding(
                              padding: EdgeInsets.all(6.r),
                              child: Text(
                                bannerFoods[currentIndex].name.toString(),
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600, color: Colors.white),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Consumer<FavoritesProvider>(
                        builder: (context, favoriteProvider, child) {
                          final bool isFavorite = favoriteProvider.isFavorite(bannerFoods[currentIndex]);
                          return GestureDetector(
                            onTap: () {
                              if (isFavorite) {
                                favoriteProvider.removeFromFavorites(bannerFoods[currentIndex]);
                              } else {
                                favoriteProvider.addToFavorites(bannerFoods[currentIndex]);
                              }
                            },
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(KBorderSize.borderMedium),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                                child: Container(
                                  color: Colors.black.withOpacity(0.2),
                                  child: Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: SvgPicture.asset(
                                      isFavorite ? Assets.icons.heartSolid : Assets.icons.heart,
                                      height: 22.h,
                                      width: 22.w,
                                      colorFilter: ColorFilter.mode(
                                        isFavorite ? Colors.red : Colors.white,
                                        BlendMode.srcIn,
                                      ),
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
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(KBorderSize.borderMedium),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                        child: Container(
                          color: Colors.black.withOpacity(0.2),
                          child: Padding(
                            padding: const EdgeInsets.all(6.0),
                            child: Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.all(10.r),
                                  decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.black),
                                  child: SvgPicture.asset(
                                    Assets.icons.cart,
                                    package: 'grab_go_shared',
                                    height: 18.h,
                                    width: 18.w,
                                    colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                                  ),
                                ),
                                SizedBox(width: 10.w),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "GHC ${bannerFoods[currentIndex].price.toStringAsFixed(2)}",
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 12.sp,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Row(
                                        children: [
                                          SvgPicture.asset(
                                            Assets.icons.starSolid,
                                            package: 'grab_go_shared',
                                            height: 14.h,
                                            width: 14.w,
                                            colorFilter: ColorFilter.mode(colors.accentOrange, BlendMode.srcIn),
                                          ),
                                          SizedBox(width: 4.w),
                                          Text(
                                            "${bannerFoods[currentIndex].rating}(120+)",
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 12.sp,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                Consumer<CartProvider>(
                                  builder: (context, cartProvider, child) {
                                    final bool isInCart = cartProvider.cartItems.containsKey(bannerFoods[currentIndex]);
                                    return AppButton(
                                      height: 38.h,
                                      onPressed: () {
                                        if (isInCart) {
                                          cartProvider.removeFromCart(bannerFoods[currentIndex]);
                                        } else {
                                          cartProvider.addToCart(bannerFoods[currentIndex]);
                                        }
                                      },
                                      textColor: isDark ? Colors.black : Colors.white,
                                      buttonText: isInCart ? "Remove from Cart" : "Add to Cart",
                                      borderRadius: KBorderSize.borderMedium,
                                      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
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
