// ignore_for_file: deprecated_member_use

import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_image_slideshow/flutter_image_slideshow.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_customer/features/cart/viewmodel/cart_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:grab_go_customer/features/home/viewmodel/food_provider.dart';
import 'package:grab_go_customer/shared/viewmodels/favorites_provider.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:visibility_detector/visibility_detector.dart';

import 'cached_image_widget.dart';

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

    if (itemsProvider.isLoading) {
      return Shimmer.fromColors(
        baseColor: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
        highlightColor: isDark ? Colors.grey.shade700 : Colors.grey.shade100,
        child: Container(
          height: widget.size.height * 0.28,
          padding: EdgeInsets.all(8.r),
          margin: EdgeInsets.symmetric(horizontal: 20.w),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(KBorderSize.borderMedium),
            border: BoxBorder.all(color: isDark ? Colors.grey.shade800 : Colors.grey.shade300, width: 0.5),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Food name placeholder
                  Expanded(
                    child: Container(
                      height: 40.h,
                      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey.shade700 : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(KBorderSize.borderMedium),
                      ),
                    ),
                  ),
                  SizedBox(width: 8.w),
                  // Heart icon placeholder
                  Container(
                    height: 40.h,
                    width: 40.w,
                    padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey.shade700 : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(KBorderSize.borderMedium),
                    ),
                  ),
                ],
              ),
              const Spacer(),

              Container(
                padding: EdgeInsets.all(10.r),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey.shade700 : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(KBorderSize.borderMedium),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Price placeholder
                          Container(
                            height: 18.h,
                            width: 80.w,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(4.r),
                            ),
                          ),
                          SizedBox(height: 6.h),
                          // Rating placeholder
                          Row(
                            children: [
                              Container(
                                height: 14.h,
                                width: 14.w,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(2.r),
                                ),
                              ),
                              SizedBox(width: 4.w),
                              Container(
                                height: 13.h,
                                width: 30.w,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(2.r),
                                ),
                              ),
                              SizedBox(width: 4.w),
                              Container(
                                height: 12.h,
                                width: 40.w,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(2.r),
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
            ],
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
          padding: EdgeInsets.all(8.r),
          margin: EdgeInsets.symmetric(horizontal: 20.w),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(KBorderSize.borderMedium),
            border: BoxBorder.all(color: isDark ? Colors.grey.shade800 : Colors.grey.shade300, width: 0.5),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Food name placeholder
                  Expanded(
                    child: Container(
                      height: 40.h,
                      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey.shade700 : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(KBorderSize.borderMedium),
                      ),
                    ),
                  ),
                  SizedBox(width: 8.w),
                  // Heart icon placeholder
                  Container(
                    height: 40.h,
                    width: 40.w,
                    padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey.shade700 : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(KBorderSize.borderMedium),
                    ),
                  ),
                ],
              ),
              const Spacer(),

              Container(
                padding: EdgeInsets.all(10.r),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey.shade700 : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(KBorderSize.borderMedium),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Price placeholder
                          Container(
                            height: 18.h,
                            width: 80.w,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(4.r),
                            ),
                          ),
                          SizedBox(height: 6.h),
                          // Rating placeholder
                          Row(
                            children: [
                              Container(
                                height: 14.h,
                                width: 14.w,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(2.r),
                                ),
                              ),
                              SizedBox(width: 4.w),
                              Container(
                                height: 13.h,
                                width: 30.w,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(2.r),
                                ),
                              ),
                              SizedBox(width: 4.w),
                              Container(
                                height: 12.h,
                                width: 40.w,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(2.r),
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
            ],
          ),
        ),
      );
    }

    final allFoods = itemsProvider.categories.expand((cat) => cat.items).toList();

    if (allFoods.isEmpty) {
      return Shimmer.fromColors(
        baseColor: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
        highlightColor: isDark ? Colors.grey.shade700 : Colors.grey.shade100,
        child: Container(
          height: widget.size.height * 0.28,
          padding: EdgeInsets.all(8.r),
          margin: EdgeInsets.symmetric(horizontal: 20.w),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(KBorderSize.borderMedium),
            border: BoxBorder.all(color: isDark ? Colors.grey.shade800 : Colors.grey.shade300, width: 0.5),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Food name placeholder
                  Expanded(
                    child: Container(
                      height: 40.h,
                      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey.shade700 : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(KBorderSize.borderMedium),
                      ),
                    ),
                  ),
                  SizedBox(width: 8.w),
                  // Heart icon placeholder
                  Container(
                    height: 40.h,
                    width: 40.w,
                    padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey.shade700 : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(KBorderSize.borderMedium),
                    ),
                  ),
                ],
              ),
              const Spacer(),

              Container(
                padding: EdgeInsets.all(10.r),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey.shade700 : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(KBorderSize.borderMedium),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Price placeholder
                          Container(
                            height: 18.h,
                            width: 80.w,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(4.r),
                            ),
                          ),
                          SizedBox(height: 6.h),
                          // Rating placeholder
                          Row(
                            children: [
                              Container(
                                height: 14.h,
                                width: 14.w,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(2.r),
                                ),
                              ),
                              SizedBox(width: 4.w),
                              Container(
                                height: 13.h,
                                width: 30.w,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(2.r),
                                ),
                              ),
                              SizedBox(width: 4.w),
                              Container(
                                height: 12.h,
                                width: 40.w,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(2.r),
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
            ],
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
                  setState(() {
                    currentIndex = value;
                  });
                },
                children: effectiveFoods
                    .map(
                      (food) => GestureDetector(
                        onTap: () => context.push("/foodDetails", extra: food),
                        child: Stack(
                          children: [
                            CachedImageWidget(
                              imageUrl: food.image,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              placeholder: Container(
                                width: double.infinity,
                                height: widget.size.height * 0.28,
                                decoration: BoxDecoration(
                                  color: colors.backgroundPrimary,
                                  borderRadius: BorderRadius.circular(KBorderSize.borderMedium),
                                ),
                                child: Center(
                                  child: SizedBox(
                                    height: 40.h,
                                    width: 40.w,
                                    child: SvgPicture.asset(
                                      Assets.icons.utensilsCrossed,
                                      package: 'grab_go_shared',
                                      colorFilter: ColorFilter.mode(colors.textSecondary, BlendMode.srcIn),
                                    ),
                                  ),
                                ),
                              ),
                              errorWidget: Container(
                                width: double.infinity,
                                height: widget.size.height * 0.28,
                                decoration: BoxDecoration(
                                  color: colors.backgroundPrimary,
                                  borderRadius: BorderRadius.circular(KBorderSize.borderMedium),
                                ),
                                child: Center(
                                  child: SizedBox(
                                    height: 40.h,
                                    width: 40.w,
                                    child: SvgPicture.asset(
                                      Assets.icons.utensilsCrossed,
                                      package: 'grab_go_shared',
                                      colorFilter: ColorFilter.mode(colors.textSecondary, BlendMode.srcIn),
                                    ),
                                  ),
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
              padding: EdgeInsets.all(8.r),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(KBorderSize.borderMedium),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(KBorderSize.borderMedium),
                              ),
                              child: Text(
                                effectiveFoods[safeIndex].name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w700, color: Colors.white),
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 8.w),
                      Consumer<FavoritesProvider>(
                        builder: (context, favoriteProvider, child) {
                          final bool isFavorite = favoriteProvider.isFavorite(effectiveFoods[safeIndex]);
                          return GestureDetector(
                            onTap: () {
                              if (isFavorite) {
                                favoriteProvider.removeFromFavorites(effectiveFoods[safeIndex]);
                              } else {
                                favoriteProvider.addToFavorites(effectiveFoods[safeIndex]);
                              }
                            },
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(KBorderSize.borderMedium),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
                                child: Container(
                                  padding: EdgeInsets.all(10.r),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(KBorderSize.borderMedium),
                                  ),
                                  child: SvgPicture.asset(
                                    isFavorite ? Assets.icons.heartSolid : Assets.icons.heart,
                                    package: 'grab_go_shared',
                                    height: 20.h,
                                    width: 20.w,
                                    colorFilter: ColorFilter.mode(
                                      isFavorite ? Colors.red : Colors.white,
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
                  const Spacer(),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(KBorderSize.borderMedium),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
                      child: Container(
                        padding: EdgeInsets.all(10.r),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(KBorderSize.borderMedium),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    "GHS ${effectiveFoods[safeIndex].price.toStringAsFixed(2)}",
                                    style: TextStyle(color: Colors.white, fontSize: 16.sp, fontWeight: FontWeight.w800),
                                  ),
                                  SizedBox(height: 6.h),
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
                                        effectiveFoods[safeIndex].rating.toStringAsFixed(1),
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 13.sp,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      SizedBox(width: 4.w),
                                      Text(
                                        "(120+)",
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.8),
                                          fontSize: 12.sp,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(width: 12.w),
                            Consumer<CartProvider>(
                              builder: (context, cartProvider, child) {
                                final bool isInCart = cartProvider.cartItems.containsKey(effectiveFoods[safeIndex]);
                                return GestureDetector(
                                  onTap: () {
                                    if (isInCart) {
                                      cartProvider.removeItemCompletely(effectiveFoods[safeIndex]);
                                    } else {
                                      cartProvider.addToCart(effectiveFoods[safeIndex]);
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
                                );
                              },
                            ),
                          ],
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
