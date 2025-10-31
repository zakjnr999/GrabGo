import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_customer/features/restaurant/model/restaurants_model.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:grab_go_customer/shared/widgets/restaurant_details_helper.dart';

class RestaurantDetailsAppBar extends StatelessWidget {
  const RestaurantDetailsAppBar({super.key, required this.restaurant});
  final RestaurantModel restaurant;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    Size size = MediaQuery.sizeOf(context);

    return SliverAppBar(
      expandedHeight: size.height * 0.40,
      backgroundColor: colors.backgroundSecondary,
      surfaceTintColor: colors.backgroundSecondary,
      systemOverlayStyle: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      elevation: 0,
      pinned: true,
      stretch: true,
      automaticallyImplyLeading: false,
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          children: [
            Positioned.fill(
              child: Image.network(
                restaurant.imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: size.height * 0.40,
                    color: colors.inputBorder,
                    padding: const EdgeInsets.all(40),
                    child: SvgPicture.asset(
                      Assets.icons.cookingPot,
                            package: 'grab_go_shared',
                      colorFilter: ColorFilter.mode(
                        colors.textSecondary,
                        BlendMode.srcIn,
                      ),
                    ),
                  );
                },
              ),
            ),
            Container(
              height: size.height * 0.40,
              width: double.infinity,
              padding: EdgeInsets.only(top: 20.r, left: 20.r),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    restaurant.name,
                    style: TextStyle(
                      fontSize: 30.sp,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          offset: const Offset(0, 0),
                          blurRadius: 4,
                          color: Colors.black.withAlpha(100),
                        ),
                      ],
                    ),
                  ),

                  Text(
                    restaurant.foodType,
                    style: TextStyle(
                      fontSize: KTextSize.small.sp,
                      fontWeight: FontWeight.w400,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          offset: const Offset(0, 0),
                          blurRadius: 4,
                          color: Colors.black.withAlpha(100),
                        ),
                      ],
                    ),
                  ),

                  Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            BuildRestaurantDetails(
                              text: restaurant.rating.toString(),
                              colors: colors,
                              restaurant: restaurant,
                              icon: Assets.icons.star,
                              color: colors.accentOrange,
                            ),
                            SizedBox(width: 10.w),
                            BuildRestaurantDetails(
                              text: restaurant.city,
                              colors: colors,
                              restaurant: restaurant,
                              icon: Assets.icons.mapPin,
                              color: colors.accentBlue,
                            ),
                            SizedBox(width: 10.w),
                            BuildRestaurantDetails(
                              text: "Opened",
                              colors: colors,
                              restaurant: restaurant,
                              icon: Assets.icons.logIn,
                              color: colors.accentViolet,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        stretchModes: const [
          StretchMode.blurBackground,
          StretchMode.zoomBackground,
        ],
      ),

      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(0.0),
        child: Container(
          height: 20.h,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: colors.backgroundSecondary,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(KBorderSize.border),
              topRight: Radius.circular(KBorderSize.border),
            ),
          ),
          child: Container(
            width: 40,
            height: 5,
            decoration: BoxDecoration(
              color: colors.textSecondary.withAlpha(50),
              borderRadius: BorderRadius.circular(KBorderSize.border),
            ),
          ),
        ),
      ),
      actionsPadding: EdgeInsets.symmetric(horizontal: 8.h),
      actions: [
        BlurCircleButton(
          onTap: () => context.pop(),
          icon: SvgPicture.asset(
            Assets.icons.navArrowLeft,
                            package: 'grab_go_shared',
            colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
          ),
        ),
        const Spacer(),

        BlurCircleButton(
          onTap: () {},
          icon: Padding(
            padding: const EdgeInsets.all(4),
            child: SvgPicture.asset(
              Assets.icons.heart,
                            package: 'grab_go_shared',
              colorFilter: const ColorFilter.mode(
                Colors.white,
                BlendMode.srcIn,
              ),
            ),
          ),
        ),
      ],
    );
  }
}



