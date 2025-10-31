import 'package:flutter/material.dart';
import 'package:flutter_image_slideshow/flutter_image_slideshow.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:grab_go_customer/features/restaurant/model/restaurants_model.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:shimmer/shimmer.dart';

class RestaurantDetailsBanner extends StatefulWidget {
  final RestaurantModel restaurant;
  final bool isLoading;

  const RestaurantDetailsBanner({
    super.key,
    required this.restaurant,
    this.isLoading = false,
  });

  @override
  State<RestaurantDetailsBanner> createState() =>
      _RestaurantDetailsBannerState();
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
          height: size.height * 0.15,
          margin: EdgeInsets.symmetric(horizontal: 20.w),
          decoration: BoxDecoration(
            color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
            borderRadius: BorderRadius.circular(KBorderSize.borderMedium),
          ),
        ),
      );
    }

    // Use restaurant banner images if available, otherwise use the main image
    List<String> bannerImages = widget.restaurant.bannerImages.isNotEmpty
        ? widget.restaurant.bannerImages
        : [widget.restaurant.imageUrl];

    // Remove any empty or null images
    bannerImages = bannerImages.where((image) => image.isNotEmpty).toList();

    if (bannerImages.isEmpty) {
      return Container(
        height: size.height * 0.15,
        margin: EdgeInsets.symmetric(horizontal: 20.w),
        decoration: BoxDecoration(
          color: colors.backgroundTertiary,
          borderRadius: BorderRadius.circular(KBorderSize.borderMedium),
        ),
        child: Center(
          child: Text(
            'No banner images available',
            style: TextStyle(color: colors.textSecondary, fontSize: 14.sp),
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
          BoxShadow(
            color: Colors.black.withAlpha(10),
            spreadRadius: 1,
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withAlpha(5),
            spreadRadius: -1,
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(KBorderSize.borderMedium),
        child: Column(
          children: [
            ImageSlideshow(
              height: size.height * 0.15,
              width: size.width,
              initialPage: 0,
              indicatorColor: colors.accentOrange,
              indicatorBackgroundColor: Colors.white,
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
                    (imageUrl) => Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: double.infinity,
                          height: size.height * 0.15,
                          color: colors.backgroundTertiary,
                          child: Icon(
                            Icons.restaurant,
                            size: 48.sp,
                            color: colors.textTertiary,
                          ),
                        );
                      },
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Shimmer.fromColors(
                          baseColor: isDark
                              ? Colors.grey.shade800
                              : Colors.grey.shade300,
                          highlightColor: isDark
                              ? Colors.grey.shade700
                              : Colors.grey.shade100,
                          child: Container(
                            width: double.infinity,
                            height: size.height * 0.15,
                            color: isDark
                                ? Colors.grey.shade800
                                : Colors.grey.shade300,
                          ),
                        );
                      },
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



