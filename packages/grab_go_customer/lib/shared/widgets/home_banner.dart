// ignore_for_file: deprecated_member_use

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_image_slideshow/flutter_image_slideshow.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_customer/features/cart/viewmodel/cart_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:grab_go_customer/features/home/viewmodel/food_provider.dart';
import 'package:grab_go_customer/features/groceries/viewmodel/grocery_provider.dart';
import 'package:grab_go_customer/shared/viewmodels/service_provider.dart';
import 'package:grab_go_customer/shared/viewmodels/favorites_provider.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:grab_go_customer/shared/utils/image_optimizer.dart';

class HomeBanner extends StatefulWidget {
  const HomeBanner({super.key, required this.size});

  final Size size;

  @override
  State<HomeBanner> createState() => _HomeBannerState();
}

class _HomeBannerState extends State<HomeBanner> {
  int currentIndex = 0;
  bool _autoPlayEnabled = true;

  // Stabilized banner foods and signature of categories
  List<dynamic> _bannerFoods = [];
  String _lastCategoriesSignature = '';

  final Set<String> _preloadedImageUrls = <String>{};

  Future<void> _precacheBannerImages(BuildContext context, List<dynamic> foods) async {
    for (final food in foods) {
      final String url = food.image;
      if (url.isEmpty || _preloadedImageUrls.contains(url)) continue;
      try {
        await precacheImage(CachedNetworkImageProvider(url), context);
        _preloadedImageUrls.add(url);
      } catch (_) {
        // Ignore
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final itemsProvider = Provider.of<FoodProvider>(context);
    final groceryProvider = Provider.of<GroceryProvider>(context);
    final serviceProvider = Provider.of<ServiceProvider>(context);

    // Determine loading state and error state based on service
    bool isLoading = false;
    bool hasError = false;

    if (serviceProvider.isGroceryService) {
      isLoading = groceryProvider.isLoadingItems || groceryProvider.isLoadingCategories;
      // Grocery provider doesn't strictly have an error field yet, defaulting to false or checking empty logic later
    } else {
      isLoading = itemsProvider.isLoading;
      hasError = itemsProvider.error != null;
    }

    // Determine items to show early to check for empty state
    List<dynamic> allFoods = [];
    if (serviceProvider.isGroceryService) {
      if (groceryProvider.items.isNotEmpty) {
        allFoods = groceryProvider.items.map((e) => e.toFoodItem()).toList();
      } else if (groceryProvider.deals.isNotEmpty) {
        allFoods = groceryProvider.deals.map((e) => e.toFoodItem()).toList();
      }
    } else {
      allFoods = itemsProvider.categories.expand((cat) => cat.items).toList();
    }

    if (isLoading && allFoods.isEmpty) {
      return Shimmer.fromColors(
        baseColor: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
        highlightColor: isDark ? Colors.grey.shade700 : Colors.grey.shade100,
        child: Container(
          height: widget.size.height * 0.28,
          padding: EdgeInsets.all(14.r),
          margin: EdgeInsets.symmetric(horizontal: 20.w),
          decoration: BoxDecoration(
            color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
            borderRadius: BorderRadius.circular(KBorderSize.borderMedium),
          ),
        ),
      );
    }

    // We already determined allFoods above for the loading check

    if (allFoods.isEmpty) {
      return Shimmer.fromColors(
        baseColor: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
        highlightColor: isDark ? Colors.grey.shade700 : Colors.grey.shade100,
        child: Container(
          height: widget.size.height * 0.28,
          padding: EdgeInsets.all(14.r),
          margin: EdgeInsets.symmetric(horizontal: 20.w),
          decoration: BoxDecoration(
            color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
            borderRadius: BorderRadius.circular(KBorderSize.borderMedium),
          ),
        ),
      );
    }

    // Stabilize banner foods across rebuilds using a categories signature
    final String imagesSig = allFoods.map((f) => f.image).join('|');
    if (_lastCategoriesSignature != imagesSig) {
      final random = Random();
      final Set<int> selectedIndexes = {};
      final int target = allFoods.length < 3 ? allFoods.length : 3;
      while (selectedIndexes.length < target) {
        selectedIndexes.add(random.nextInt(allFoods.length));
      }
      final newFoods = selectedIndexes.map((i) => allFoods[i]).toList();
      final clampedIndex = newFoods.isEmpty ? 0 : currentIndex.clamp(0, newFoods.length - 1);

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _lastCategoriesSignature = imagesSig;
          _bannerFoods = newFoods;
          currentIndex = clampedIndex;
        });
        _precacheBannerImages(context, newFoods);
      });
    }

    // Effective foods and safe index for rendering
    final List<dynamic> effectiveFoods = _bannerFoods.isNotEmpty
        ? _bannerFoods
        : (allFoods.length <= 3 ? allFoods : allFoods.take(3).toList());
    final int safeIndex = effectiveFoods.isEmpty ? 0 : currentIndex.clamp(0, effectiveFoods.length - 1);

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20.w),
      decoration: BoxDecoration(
        color: colors.backgroundPrimary,
        borderRadius: BorderRadius.circular(KBorderSize.borderMedium),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withAlpha(50) : Colors.black.withAlpha(10),
            spreadRadius: 1,
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: isDark ? Colors.black.withAlpha(30) : Colors.black.withAlpha(5),
            spreadRadius: -1,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(KBorderSize.borderMedium),
        child: Stack(
          children: [
            VisibilityDetector(
              key: const Key('home_banner_visibility'),
              onVisibilityChanged: (info) {
                if (!mounted) return;
                final shouldEnable = info.visibleFraction > 0.2;
                if (shouldEnable != _autoPlayEnabled) {
                  setState(() => _autoPlayEnabled = shouldEnable);
                }
              },
              child: ImageSlideshow(
                height: widget.size.height * 0.28,
                width: widget.size.width,
                initialPage: 0,
                indicatorColor: Colors.transparent,
                indicatorBackgroundColor: Colors.transparent,
                disableUserScrolling: false,
                autoPlayInterval: _autoPlayEnabled ? 5000 : 0,
                isLoop: true,
                onPageChanged: (value) {
                  if (!mounted) return;
                  setState(() {
                    currentIndex = value;
                  });
                },
                children: effectiveFoods
                    .map(
                      (food) => GestureDetector(
                        onTap: () {
                          // Conditional Navigation
                          if (serviceProvider.isGroceryService) {
                            // Find original grocery item
                            final original = groceryProvider.items.firstWhere(
                              (g) => g.id == food.id,
                              orElse: () => groceryProvider.deals.firstWhere(
                                (d) => d.id == food.id,
                                orElse: () => groceryProvider.items.first,
                              ),
                            );
                            context.push("/foodDetails", extra: original);
                          } else {
                            context.push("/foodDetails", extra: food);
                          }
                        },
                        child: Stack(
                          children: [
                            CachedNetworkImage(
                              imageUrl: ImageOptimizer.getFullUrl(food.image, width: 1200),
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: widget.size.height * 0.28,
                              memCacheWidth: 800,
                              maxHeightDiskCache: 600,
                              placeholder: (context, url) => Shimmer.fromColors(
                                baseColor: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                                highlightColor: isDark ? Colors.grey.shade700 : Colors.grey.shade100,
                                child: Container(
                                  width: double.infinity,
                                  height: widget.size.height * 0.28,
                                  decoration: BoxDecoration(
                                    color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                                    borderRadius: BorderRadius.circular(KBorderSize.borderMedium),
                                  ),
                                ),
                              ),
                              errorWidget: (context, url, error) => Container(
                                width: double.infinity,
                                height: widget.size.height * 0.28,
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.grey.shade800 : Colors.grey.shade600,
                                  borderRadius: BorderRadius.circular(KBorderSize.borderMedium),
                                ),
                                child: Center(
                                  child: SvgPicture.asset(
                                    Assets.icons.utensilsCrossed,
                                    package: 'grab_go_shared',
                                    colorFilter: ColorFilter.mode(Colors.white.withOpacity(0.5), BlendMode.srcIn),
                                    width: 40.w,
                                    height: 40.h,
                                  ),
                                ),
                              ),
                            ),
                            // Gradient overlay for text readability
                            Container(
                              width: double.infinity,
                              height: widget.size.height * 0.28,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.black.withOpacity(0.4),
                                    Colors.transparent,
                                    Colors.transparent,
                                    Colors.black.withOpacity(0.7),
                                  ],
                                  stops: const [0.0, 0.25, 0.6, 1.0],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),

            Container(
              height: widget.size.height * 0.28,
              width: widget.size.width,
              padding: EdgeInsets.all(14.r),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Consumer<FavoritesProvider>(
                        builder: (context, favoriteProvider, child) {
                          // Using normalized food item for favorites
                          final bool isFavorite = favoriteProvider.isFavorite(effectiveFoods[safeIndex]);
                          return GestureDetector(
                            onTap: () {
                              if (isFavorite) {
                                favoriteProvider.removeFromFavorites(effectiveFoods[safeIndex]);
                              } else {
                                favoriteProvider.addToFavorites(effectiveFoods[safeIndex]);
                              }
                            },
                            child: SvgPicture.asset(
                              isFavorite ? Assets.icons.heartSolid : Assets.icons.heart,
                              package: 'grab_go_shared',
                              height: 24.h,
                              width: 24.w,
                              colorFilter: ColorFilter.mode(
                                isFavorite ? AppColors.errorRed : Colors.white,
                                BlendMode.srcIn,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            effectiveFoods[safeIndex].name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.w700, color: Colors.white),
                          ),
                          SizedBox(height: 4.h),
                          Row(
                            children: [
                              Text(
                                "GHS ${effectiveFoods[safeIndex].price.toStringAsFixed(2)}",
                                style: TextStyle(color: Colors.white, fontSize: 14.sp, fontWeight: FontWeight.w800),
                              ),
                              SizedBox(width: 12.w),
                              // Rating
                              SvgPicture.asset(
                                Assets.icons.starSolid,
                                package: 'grab_go_shared',
                                height: 16.h,
                                width: 16.w,
                                colorFilter: ColorFilter.mode(colors.accentOrange, BlendMode.srcIn),
                              ),
                              SizedBox(width: 4.w),
                              Text(
                                effectiveFoods[safeIndex].rating.toStringAsFixed(1),
                                style: TextStyle(color: Colors.white, fontSize: 14.sp, fontWeight: FontWeight.w600),
                              ),
                              SizedBox(width: 4.w),
                              Text(
                                "(120+)",
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.8),
                                  fontSize: 13.sp,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      const Spacer(),
                      // Cart button
                      Consumer<CartProvider>(
                        builder: (context, cartProvider, child) {
                          // Find original item for cart operations
                          dynamic itemForCart = effectiveFoods[safeIndex];
                          if (serviceProvider.isGroceryService) {
                            // Find original grocery item
                            try {
                              itemForCart = groceryProvider.items.firstWhere(
                                (g) => g.id == effectiveFoods[safeIndex].id,
                                orElse: () =>
                                    groceryProvider.deals.firstWhere((d) => d.id == effectiveFoods[safeIndex].id),
                              );
                            } catch (_) {
                              // Fallback to converted item if not found
                            }
                          }

                          final bool isInCart = cartProvider.cartItems.containsKey(itemForCart);
                          return GestureDetector(
                            onTap: () {
                              if (isInCart) {
                                cartProvider.removeItemCompletely(itemForCart);
                              } else {
                                cartProvider.addToCart(itemForCart, context: context);
                              }
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeOut,
                              padding: EdgeInsets.all(10.r),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isInCart ? colors.accentOrange : colors.backgroundSecondary,
                              ),
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 200),
                                transitionBuilder: (child, animation) {
                                  return ScaleTransition(scale: animation, child: child);
                                },
                                child: SvgPicture.asset(
                                  isInCart ? Assets.icons.check : Assets.icons.cart,
                                  key: ValueKey(isInCart),
                                  package: 'grab_go_shared',
                                  height: 18.h,
                                  width: 18.w,
                                  colorFilter: ColorFilter.mode(
                                    isInCart ? Colors.white : colors.textPrimary,
                                    BlendMode.srcIn,
                                  ),
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
}
