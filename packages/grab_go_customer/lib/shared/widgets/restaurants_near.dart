import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_customer/features/restaurant/model/restaurants_model.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:shimmer/shimmer.dart';

class RestaurantsNear extends StatefulWidget {
  final List<RestaurantModel> restaurants;
  final bool isLoading;

  const RestaurantsNear({super.key, required this.restaurants, this.isLoading = false});

  @override
  State<RestaurantsNear> createState() => _RestaurantListState();
}

class _RestaurantListState extends State<RestaurantsNear> {
  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Size size = MediaQuery.sizeOf(context);

    if (widget.isLoading) {
      return SizedBox(
        height: 120.h,
        child: Shimmer.fromColors(
          baseColor: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
          highlightColor: isDark ? Colors.grey.shade700 : Colors.grey.shade100,
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: Column(
              children: List.generate(4, (index) {
                return Container(
                  margin: EdgeInsets.only(left: 20.w, right: 20.w, bottom: 12.h),
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(KBorderSize.borderRadius15)),
                  child: Row(
                    children: [
                      // Image placeholder
                      Container(
                        height: size.height * 0.14,
                        width: size.width * 0.32,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.grey.shade700 : Colors.grey.shade200,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(KBorderSize.borderRadius15),
                            bottomLeft: Radius.circular(KBorderSize.borderRadius15),
                          ),
                        ),
                      ),

                      // Itemname placeholder
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12.r, vertical: 8.h),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 140.w,
                                height: 16.h,
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.grey.shade700 : Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(4.r),
                                ),
                              ),
                              SizedBox(height: 6.h),
                              // Rating and delivery time placeholder
                              Container(
                                width: 120.w,
                                height: 16.h,
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.grey.shade700 : Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(4.r),
                                ),
                              ),
                              SizedBox(height: 10.h),
                              // Price placeholder
                              Container(
                                width: 100.w,
                                height: 16.h,
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.grey.shade700 : Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(4.r),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
        ),
      );
    }

    if (widget.restaurants.isEmpty) {
      return SizedBox(
        height: 120.h,
        child: Shimmer.fromColors(
          baseColor: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
          highlightColor: isDark ? Colors.grey.shade700 : Colors.grey.shade100,
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: Column(
              children: List.generate(4, (index) {
                return Container(
                  margin: EdgeInsets.only(left: 20.w, right: 20.w, bottom: 12.h),
                  decoration: BoxDecoration(
                    border: Border.all(color: isDark ? Colors.grey.shade800 : Colors.grey.shade300, width: 0.5),
                    borderRadius: BorderRadius.circular(KBorderSize.borderRadius15),
                  ),
                  child: Row(
                    children: [
                      // Image placeholder
                      Container(
                        height: size.height * 0.14,
                        width: size.width * 0.32,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.grey.shade700 : Colors.grey.shade200,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(KBorderSize.borderRadius15),
                            bottomLeft: Radius.circular(KBorderSize.borderRadius15),
                          ),
                        ),
                      ),

                      // Itemname placeholder
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12.r, vertical: 8.h),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 140.w,
                                height: 16.h,
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.grey.shade700 : Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(4.r),
                                ),
                              ),
                              SizedBox(height: 6.h),
                              // Rating and delivery time placeholder
                              Container(
                                width: 120.w,
                                height: 16.h,
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.grey.shade700 : Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(4.r),
                                ),
                              ),
                              SizedBox(height: 10.h),
                              // Price placeholder
                              Container(
                                width: 100.w,
                                height: 16.h,
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.grey.shade700 : Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(4.r),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      child: ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        itemCount: widget.restaurants.length,
        padding: EdgeInsets.symmetric(horizontal: 20.w),
        itemBuilder: (context, index) {
          final restaurant = widget.restaurants[index];

          return GestureDetector(
            onTap: () {
              context.push("/restaurantDetails", extra: restaurant);
            },
            child: Container(
              margin: EdgeInsets.symmetric(vertical: 4.h),
              decoration: BoxDecoration(
                color: colors.backgroundPrimary,
                borderRadius: BorderRadius.circular(KBorderSize.borderRadius15),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(KBorderSize.borderRadius15),
                      bottomLeft: Radius.circular(KBorderSize.borderRadius15),
                    ),
                    child: CachedNetworkImage(
                      imageUrl: ImageOptimizer.getPreviewUrl(restaurant.imageUrl, width: 400),
                      height: size.height * 0.14,
                      width: size.width * 0.32,
                      fit: BoxFit.cover,
                      memCacheWidth: 400,
                      maxHeightDiskCache: 600,
                      placeholder: (context, url) => Container(
                        height: size.height * 0.14,
                        width: size.width * 0.32,
                        color: colors.inputBorder,
                        padding: const EdgeInsets.all(30),
                        child: SvgPicture.asset(
                          Assets.icons.chefHat,
                          package: 'grab_go_shared',
                          colorFilter: ColorFilter.mode(colors.textSecondary, BlendMode.srcIn),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        height: size.height * 0.14,
                        width: size.width * 0.32,
                        color: colors.inputBorder,
                        padding: const EdgeInsets.all(30),
                        child: SvgPicture.asset(
                          Assets.icons.chefHat,
                          package: 'grab_go_shared',
                          colorFilter: ColorFilter.mode(colors.textSecondary, BlendMode.srcIn),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          restaurant.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold, color: colors.textPrimary),
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          restaurant.foodType,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: colors.textSecondary, fontSize: 12.sp, fontWeight: FontWeight.w400),
                        ),
                        SizedBox(height: KSpacing.sm.h),
                        Row(
                          children: [
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                              decoration: BoxDecoration(
                                color: colors.accentOrange.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8.r),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SvgPicture.asset(
                                    Assets.icons.starSolid,
                                    package: 'grab_go_shared',
                                    height: 12.h,
                                    width: 12.w,
                                    colorFilter: ColorFilter.mode(colors.accentOrange, BlendMode.srcIn),
                                  ),
                                  SizedBox(width: 3.w),
                                  Text(
                                    restaurant.rating.toStringAsFixed(1),
                                    style: TextStyle(
                                      fontSize: 11.sp,
                                      color: colors.accentOrange,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(width: 6.w),

                            if (restaurant.isOpen)
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                                decoration: BoxDecoration(
                                  color: colors.accentGreen.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8.r),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 5.w,
                                      height: 5.h,
                                      decoration: BoxDecoration(color: colors.accentGreen, shape: BoxShape.circle),
                                    ),
                                    SizedBox(width: 4.w),
                                    Text(
                                      "Open",
                                      style: TextStyle(
                                        fontSize: 11.sp,
                                        color: colors.accentGreen,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        // Row(
                        //   children: [
                        //     Icon(Icons.star, color: colors.accentOrange, size: 14.r),
                        //     const SizedBox(width: KBorderWidth.extraThick),
                        //     Text(
                        //       restaurant.rating.toStringAsFixed(1),
                        //       style: TextStyle(fontSize: 12.sp, color: colors.textSecondary),
                        //     ),
                        //     SizedBox(width: KSpacing.md.w),
                        //     SvgPicture.asset(
                        //       Assets.icons.sendDiagonal,
                        //       package: 'grab_go_shared',
                        //       height: 12.h,
                        //       width: 12.w,
                        //       colorFilter: ColorFilter.mode(colors.accentOrange, BlendMode.srcIn),
                        //     ),
                        //     SizedBox(width: 5.w),
                        //     Text(
                        //       "${restaurant.distance} km",
                        //       style: TextStyle(fontSize: 12.sp, color: Colors.grey.shade600),
                        //     ),
                        //   ],
                        // ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
