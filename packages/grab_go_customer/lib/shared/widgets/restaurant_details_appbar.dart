import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_customer/features/restaurant/model/restaurants_model.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:grab_go_customer/shared/utils/image_optimizer.dart';

class RestaurantDetailsAppBar extends StatelessWidget {
  const RestaurantDetailsAppBar({super.key, required this.restaurant});
  final RestaurantModel restaurant;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Size size = MediaQuery.sizeOf(context);

    return SliverAppBar(
      expandedHeight: size.height * 0.40,
      backgroundColor: const Color(0xFF121212),
      surfaceTintColor: colors.backgroundPrimary,
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
          fit: StackFit.expand,
          children: [
            CachedNetworkImage(
              imageUrl: ImageOptimizer.getFullUrl(restaurant.imageUrl, width: 1200),
              fit: BoxFit.cover,
              memCacheWidth: 800,
              maxHeightDiskCache: 600,
              placeholder: (context, url) => Container(
                height: size.height * 0.40,
                width: double.infinity,
                color: colors.inputBorder,
                padding: EdgeInsets.all(45.r),
                child: SvgPicture.asset(
                  Assets.icons.chefHat,
                  package: 'grab_go_shared',
                  colorFilter: ColorFilter.mode(colors.textSecondary, BlendMode.srcIn),
                ),
              ),
              errorWidget: (context, url, error) => Container(
                height: size.height * 0.40,
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
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.5),
                    Colors.black.withValues(alpha: 0.2),
                    Colors.transparent,
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.7),
                  ],
                  stops: const [0.0, 0.15, 0.4, 0.7, 1.0],
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 24.h),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black.withValues(alpha: 0.6)],
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      restaurant.name,
                      style: TextStyle(color: Colors.white, fontSize: 30.sp, fontWeight: FontWeight.w800, height: 1.2),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 10.h),
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                          decoration: BoxDecoration(
                            color: Colors.grey.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10.r),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
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
                                restaurant.rating.toStringAsFixed(1),
                                style: TextStyle(color: Colors.white, fontSize: 13.sp, fontWeight: FontWeight.w700),
                              ),
                              if (restaurant.totalReviews > 0) ...[
                                SizedBox(width: 4.w),
                                Text(
                                  "(${restaurant.totalReviews})",
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.8),
                                    fontSize: 12.sp,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        SizedBox(width: 10.w),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                          decoration: BoxDecoration(
                            color: Colors.grey.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10.r),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SvgPicture.asset(
                                Assets.icons.mapPin,
                                package: 'grab_go_shared',
                                height: 14.h,
                                width: 14.w,
                                colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                              ),
                              SizedBox(width: 4.w),
                              Flexible(
                                child: Text(
                                  restaurant.city,
                                  style: TextStyle(color: Colors.white, fontSize: 13.sp, fontWeight: FontWeight.w600),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (restaurant.isOpen) ...[
                          SizedBox(width: 10.w),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                            decoration: BoxDecoration(
                              color: colors.accentGreen.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(10.r),
                              border: Border.all(color: colors.accentGreen.withValues(alpha: 0.5), width: 1),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6.w,
                                  height: 6.h,
                                  decoration: BoxDecoration(color: colors.accentGreen, shape: BoxShape.circle),
                                ),
                                SizedBox(width: 6.w),
                                Text(
                                  "Open",
                                  style: TextStyle(color: Colors.white, fontSize: 13.sp, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    SizedBox(height: 10.h),
                  ],
                ),
              ),
            ),
          ],
        ),
        stretchModes: const [StretchMode.blurBackground, StretchMode.zoomBackground],
      ),
      bottom: PreferredSize(
        preferredSize: Size.fromHeight(24.h),
        child: Container(
          height: 24.h,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: colors.backgroundSecondary,
            borderRadius: BorderRadius.only(topLeft: Radius.circular(20.r), topRight: Radius.circular(20.r)),
            boxShadow: [
              BoxShadow(
                color: isDark ? Colors.black.withAlpha(50) : Colors.black.withAlpha(10),
                blurRadius: 10,
                spreadRadius: 0,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Container(
            margin: EdgeInsets.only(top: 8.h),
            width: 50.w,
            height: 5.h,
            decoration: BoxDecoration(
              color: colors.textSecondary.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(10.r),
            ),
          ),
        ),
      ),
      actionsPadding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 2.h),
      actions: [
        _buildActionButton(
          context: context,
          onTap: () => context.pop(),
          icon: SvgPicture.asset(
            Assets.icons.navArrowLeft,
            package: 'grab_go_shared',
            height: 20.h,
            width: 20.w,
            colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
          ),
        ),
        const Spacer(),
        _buildActionButton(
          context: context,
          onTap: () => context.pop(),
          icon: SvgPicture.asset(
            Assets.icons.shareAndroid,
            package: 'grab_go_shared',
            height: 20.h,
            width: 20.w,
            colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
          ),
        ),
        SizedBox(width: 10.w),
        _buildActionButton(
          context: context,
          onTap: () {},
          icon: SvgPicture.asset(
            Assets.icons.heart,
            package: 'grab_go_shared',
            height: 20.h,
            width: 20.w,
            colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required BuildContext context,
    required VoidCallback onTap,
    required Widget icon,
    bool isFavorite = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44.w,
        height: 44.h,
        decoration: const BoxDecoration(shape: BoxShape.circle),
        child: ClipOval(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              decoration: BoxDecoration(
                color: isFavorite ? Colors.red.withValues(alpha: 0.3) : Colors.grey.withValues(alpha: 0.2),
                shape: BoxShape.circle,
                border: Border.all(
                  color: isFavorite ? Colors.red.withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.2),
                  width: 1.5,
                ),
              ),
              child: Center(child: icon),
            ),
          ),
        ),
      ),
    );
  }
}
