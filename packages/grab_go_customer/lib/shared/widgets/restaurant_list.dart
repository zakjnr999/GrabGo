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

    return SizedBox(
      height: size.height * 0.35,
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
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(KBorderSize.borderMedium),
                      topRight: Radius.circular(KBorderSize.borderMedium),
                    ),
                    child: Stack(
                      children: [
                        CachedImageWidget(
                          imageUrl: restaurant.imageUrl,
                          height: size.height * 0.22,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          placeholder: Container(
                            height: size.height * 0.22,
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
                            height: size.height * 0.22,
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
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                          margin: EdgeInsets.all(KSpacing.md.r),
                          decoration: BoxDecoration(
                            color: colors.accentOrange,
                            borderRadius: BorderRadius.circular(KBorderSize.border),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.star, color: colors.backgroundPrimary, size: 12.r),
                              SizedBox(width: KBorderWidth.extraThick.w),
                              Text(
                                restaurant.rating.toStringAsFixed(1),
                                style: TextStyle(fontSize: 12.sp, color: colors.backgroundPrimary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.all(KSpacing.md.r),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            restaurant.name,
                            style: TextStyle(color: colors.textPrimary, fontSize: 14.sp, fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 2.h),
                          Text(
                            restaurant.foodType,
                            style: TextStyle(color: colors.textSecondary, fontSize: 12.sp, fontWeight: FontWeight.w400),
                          ),
                          const Spacer(),
                          Row(
                            children: [
                              SvgPicture.asset(
                                Assets.icons.mapPin,
                                package: 'grab_go_shared',
                                height: 15.h,
                                width: 15.w,
                                colorFilter: ColorFilter.mode(colors.accentBlue, BlendMode.srcIn),
                              ),
                              SizedBox(width: 5.w),
                              Text(
                                restaurant.city,
                                style: TextStyle(color: Colors.grey.shade600, fontSize: 12.sp),
                              ),
                              SizedBox(width: KSpacing.md.w),
                              SvgPicture.asset(
                                Assets.icons.sendDiagonal,
                                package: 'grab_go_shared',
                                height: 15.h,
                                width: 15.w,
                                colorFilter: ColorFilter.mode(colors.accentOrange, BlendMode.srcIn),
                              ),
                              SizedBox(width: 5.w),
                              Text(
                                "${restaurant.distance} km",
                                style: TextStyle(fontSize: 12.sp, color: Colors.grey.shade600),
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
      ),
    );
  }
}
