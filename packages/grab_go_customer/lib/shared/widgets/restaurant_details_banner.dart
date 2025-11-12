import 'package:flutter/material.dart';
import 'package:flutter_image_slideshow/flutter_image_slideshow.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:grab_go_customer/features/restaurant/model/restaurants_model.dart';
import 'package:grab_go_customer/shared/widgets/cached_image_widget.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:shimmer/shimmer.dart';

class RestaurantDetailsBanner extends StatefulWidget {
  final RestaurantModel restaurant;
  final bool isLoading;

  const RestaurantDetailsBanner({super.key, required this.restaurant, this.isLoading = false});

  @override
  State<RestaurantDetailsBanner> createState() => _RestaurantDetailsBannerState();
}

class _RestaurantDetailsBannerState extends State<RestaurantDetailsBanner> {
  int currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.sizeOf(context);

    if (widget.isLoading) {
      return Shimmer.fromColors(
        baseColor: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
        highlightColor: isDark ? Colors.grey.shade700 : Colors.grey.shade100,
        child: Container(
          height: size.height * 0.18,
          margin: EdgeInsets.symmetric(horizontal: 20.w),
          decoration: BoxDecoration(
            color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
            borderRadius: BorderRadius.circular(KBorderSize.borderMedium),
          ),
        ),
      );
    }

    List<String> bannerImages = widget.restaurant.bannerImages;

    bannerImages = bannerImages.where((image) => image.isNotEmpty).toList();

    if (bannerImages.isEmpty) {
      return Container(
        height: size.height * 0.18,
        margin: EdgeInsets.symmetric(horizontal: 20.w),
        decoration: BoxDecoration(
          color: colors.backgroundPrimary,
          borderRadius: BorderRadius.circular(KBorderSize.borderMedium),
          border: Border.all(color: colors.inputBorder.withValues(alpha: 0.3), width: 0.5),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(16.r),
                decoration: BoxDecoration(color: colors.accentOrange.withValues(alpha: 0.1), shape: BoxShape.circle),
                child: SvgPicture.asset(
                  Assets.icons.chefHat,
                  package: 'grab_go_shared',
                  height: 32.h,
                  width: 32.w,
                  colorFilter: ColorFilter.mode(colors.accentOrange, BlendMode.srcIn),
                ),
              ),
              SizedBox(height: 12.h),
              Text(
                'No banner images available',
                style: TextStyle(color: colors.textSecondary, fontSize: 14.sp, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      );
    }

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
        child: Column(
          children: [
            ImageSlideshow(
              height: size.height * 0.18,
              width: size.width,
              initialPage: 0,
              indicatorColor: colors.accentOrange,
              indicatorBackgroundColor: isDark ? colors.backgroundSecondary : Colors.white,
              disableUserScrolling: false,
              autoPlayInterval: 5000,
              isLoop: bannerImages.length > 1,
              onPageChanged: (value) {
                setState(() {
                  currentIndex = value;
                });
              },
              children: bannerImages
                  .map(
                    (imageUrl) => CachedImageWidget(
                      imageUrl: imageUrl,
                      width: double.infinity,
                      height: size.height * 0.18,
                      fit: BoxFit.cover,
                      placeholder: Shimmer.fromColors(
                        baseColor: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                        highlightColor: isDark ? Colors.grey.shade700 : Colors.grey.shade100,
                        child: Container(
                          width: double.infinity,
                          height: size.height * 0.18,
                          color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                        ),
                      ),
                      errorWidget: Container(
                        width: double.infinity,
                        height: size.height * 0.18,
                        color: colors.backgroundSecondary,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: EdgeInsets.all(12.r),
                                decoration: BoxDecoration(
                                  color: colors.accentOrange.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: SvgPicture.asset(
                                  Assets.icons.chefHat,
                                  package: 'grab_go_shared',
                                  height: 32.h,
                                  width: 32.w,
                                  colorFilter: ColorFilter.mode(colors.accentOrange, BlendMode.srcIn),
                                ),
                              ),
                              SizedBox(height: 8.h),
                              Text(
                                'Failed to load image',
                                style: TextStyle(
                                  color: colors.textSecondary,
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}
