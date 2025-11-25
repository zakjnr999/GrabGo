import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_customer/features/restaurant/model/restaurants_model.dart';
import 'package:grab_go_customer/shared/widgets/cached_image_widget.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';

class RestaurantList extends StatefulWidget {
  final List<RestaurantModel> restaurants;

  const RestaurantList({super.key, required this.restaurants});

  @override
  State<RestaurantList> createState() => _RestaurantListState();
}

class _RestaurantListState extends State<RestaurantList> {
  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    Size size = MediaQuery.sizeOf(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      height: 360.h,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: widget.restaurants.length,
        padding: EdgeInsets.symmetric(horizontal: 20.w),
        itemBuilder: (context, index) {
          final restaurant = widget.restaurants[index];

          return GestureDetector(
            onTap: () {
              context.push("/restaurantDetails", extra: restaurant);
            },
            child: Container(
              width: size.width * 0.8,
              margin: EdgeInsets.only(right: 16.w),
              decoration: BoxDecoration(
                color: colors.backgroundPrimary,
                borderRadius: BorderRadius.circular(KBorderSize.borderMedium),
                boxShadow: [
                  BoxShadow(
                    color: isDark ? Colors.black.withAlpha(30) : Colors.black.withAlpha(8),
                    spreadRadius: 0,
                    blurRadius: 12,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(KBorderSize.borderMedium),
                      topRight: Radius.circular(KBorderSize.borderMedium),
                    ),
                    child: CachedImageWidget(
                      imageUrl: restaurant.imageUrl,
                      height: size.height * 0.18,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      placeholder: Container(
                        height: size.height * 0.18,
                        width: double.infinity,
                        color: colors.inputBorder,
                        padding: EdgeInsets.all(45.r),
                        child: SvgPicture.asset(
                          Assets.icons.chefHat,
                          package: 'grab_go_shared',
                          colorFilter: ColorFilter.mode(colors.textSecondary, BlendMode.srcIn),
                        ),
                      ),
                      errorWidget: Container(
                        height: size.height * 0.18,
                        width: double.infinity,
                        color: colors.inputBorder,
                        padding: EdgeInsets.all(45.r),
                        child: SvgPicture.asset(
                          Assets.icons.chefHat,
                          package: 'grab_go_shared',
                          colorFilter: ColorFilter.mode(colors.textSecondary, BlendMode.srcIn),
                        ),
                      ),
                    ),
                  ),

                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.all(KSpacing.md.r),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            restaurant.name,
                            style: TextStyle(
                              color: colors.textPrimary,
                              fontSize: 17.sp,
                              fontWeight: FontWeight.w800,
                              height: 1.2,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),

                          SizedBox(height: KSpacing.sm.h),

                          Wrap(
                            spacing: 4.w,
                            runSpacing: 4.h,
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

                              if (restaurant.foodType.isNotEmpty)
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                                  decoration: BoxDecoration(
                                    color: colors.backgroundSecondary,
                                    borderRadius: BorderRadius.circular(8.r),
                                    border: Border.all(color: colors.inputBorder.withValues(alpha: 0.5), width: 0.5),
                                  ),
                                  child: Text(
                                    restaurant.foodType,
                                    style: TextStyle(
                                      fontSize: 11.sp,
                                      color: colors.textSecondary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),

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

                          SizedBox(height: KSpacing.sm.h),

                          Row(
                            children: [
                              SvgPicture.asset(
                                Assets.icons.mapPin,
                                package: 'grab_go_shared',
                                height: 13.h,
                                width: 13.w,
                                colorFilter: ColorFilter.mode(colors.textSecondary, BlendMode.srcIn),
                              ),
                              SizedBox(width: 4.w),
                              Expanded(
                                child: Text(
                                  restaurant.city.isNotEmpty && restaurant.address.isNotEmpty
                                      ? '${restaurant.city}, ${restaurant.address}'
                                      : restaurant.city.isNotEmpty
                                      ? restaurant.city
                                      : restaurant.address,
                                  style: TextStyle(
                                    color: colors.textSecondary,
                                    fontSize: 12.sp,
                                    fontWeight: FontWeight.w400,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 4.h),

                          Text(
                            restaurant.description,
                            style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w400),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),

                          const Spacer(),

                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
                            decoration: BoxDecoration(
                              color: colors.backgroundSecondary,
                              borderRadius: BorderRadius.circular(10.r),
                              border: Border.all(color: colors.inputBorder.withValues(alpha: 0.3), width: 0.5),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    SvgPicture.asset(
                                      Assets.icons.timer,
                                      package: 'grab_go_shared',
                                      height: 13.h,
                                      width: 13.w,
                                      colorFilter: ColorFilter.mode(colors.textSecondary, BlendMode.srcIn),
                                    ),
                                    SizedBox(width: 5.w),
                                    Text(
                                      restaurant.averageDeliveryTime.isNotEmpty
                                          ? restaurant.averageDeliveryTime
                                          : '25-30 mins',
                                      style: TextStyle(
                                        color: colors.textSecondary,
                                        fontSize: 12.sp,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),

                                Row(
                                  children: [
                                    SvgPicture.asset(
                                      Assets.icons.deliveryTruck,
                                      package: 'grab_go_shared',
                                      height: 18.h,
                                      width: 18.w,
                                      colorFilter: ColorFilter.mode(colors.accentOrange, BlendMode.srcIn),
                                    ),
                                    SizedBox(width: 5.w),
                                    Text(
                                      'GHS ${restaurant.deliveryFee.toStringAsFixed(0)}',
                                      style: TextStyle(
                                        color: colors.accentOrange,
                                        fontSize: 12.sp,
                                        fontWeight: FontWeight.w700,
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
