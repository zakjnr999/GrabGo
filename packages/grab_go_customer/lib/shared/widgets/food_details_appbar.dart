import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_customer/features/home/model/food_category.dart';
import 'package:grab_go_customer/features/home/view/item_reviews_page.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:grab_go_customer/shared/viewmodels/favorites_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:grab_go_shared/shared/utils/image_optimizer.dart';
import 'package:grab_go_customer/shared/services/food_share_link.dart';
import 'package:provider/provider.dart';

import 'package:grab_go_customer/features/cart/model/cart_item_interface.dart';

class FoodDetailsAppBar extends StatelessWidget {
  const FoodDetailsAppBar({super.key, required this.foodItem});
  final CartItem foodItem;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    Size size = MediaQuery.sizeOf(context);

    return SliverAppBar(
      expandedHeight: size.height * 0.20,
      backgroundColor: Colors.black,
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
              imageUrl: ImageOptimizer.getFullUrl(foodItem.image, width: 1200),
              fit: BoxFit.cover,
              memCacheWidth: 800,
              maxHeightDiskCache: 600,
              placeholder: (context, url) => Container(
                height: size.height * 0.30,
                width: double.infinity,
                color: colors.inputBorder,
                padding: EdgeInsets.all(80.r),
                child: SvgPicture.asset(
                  foodItem is FoodItem ? Assets.icons.utensilsCrossed : Assets.icons.package,
                  package: 'grab_go_shared',
                  colorFilter: ColorFilter.mode(colors.textSecondary, BlendMode.srcIn),
                ),
              ),
              errorWidget: (context, url, error) => Container(
                height: size.height * 0.30,
                width: double.infinity,
                color: colors.inputBorder,
                padding: EdgeInsets.all(80.r),
                child: SvgPicture.asset(
                  foodItem is FoodItem ? Assets.icons.utensilsCrossed : Assets.icons.package,
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
                    Colors.black.withValues(alpha: 0.4),
                  ],
                  stops: const [0.0, 0.15, 0.4, 0.7, 1.0],
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
            color: colors.backgroundPrimary,
            borderRadius: BorderRadius.only(topLeft: Radius.circular(20.r), topRight: Radius.circular(20.r)),
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
          onTap: () {
            final router = GoRouter.of(context);
            if (router.canPop()) {
              router.pop();
            } else {
              context.go("/homepage");
            }
          },
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
          onTap: () async {
            try {
              await FoodShareLinkService.shareFoodItem(
                sellerId: foodItem.providerId,
                foodName: foodItem.name,
                sellerName: foodItem.providerName,
                imageUrl: foodItem.image,
                description: foodItem.description,
              );
            } catch (e) {
              if (context.mounted) {
                AppToastMessage.show(
                  context: context,
                  message: 'Failed to share ${e.toString()}',
                  backgroundColor: colors.error,
                  maxLines: 2,
                );
              }
            }
          },
          icon: SvgPicture.asset(
            Assets.icons.shareAndroid,
            package: 'grab_go_shared',
            height: 20.h,
            width: 20.w,
            colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
          ),
        ),
        SizedBox(width: 10.w),
        Consumer<FavoritesProvider>(
          builder: (context, favoritesProvider, child) {
            final isFavorite = favoritesProvider.isFavorite(foodItem as dynamic);
            return _buildActionButton(
              context: context,
              onTap: () {
                favoritesProvider.toggleFavorite(foodItem as dynamic);
              },
              icon: SvgPicture.asset(
                isFavorite ? Assets.icons.heartSolid : Assets.icons.heart,
                package: 'grab_go_shared',
                height: 20.h,
                width: 20.w,
                colorFilter: ColorFilter.mode(isFavorite ? Colors.red : Colors.white, BlendMode.srcIn),
              ),
              isFavorite: isFavorite,
            );
          },
        ),
        SizedBox(width: 10.w),
        _buildActionButton(
          context: context,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ItemReviewsPage())),
          icon: SvgPicture.asset(
            Assets.icons.moreVertical,
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
              decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.2), shape: BoxShape.circle),
              child: Center(child: icon),
            ),
          ),
        ),
      ),
    );
  }
}
