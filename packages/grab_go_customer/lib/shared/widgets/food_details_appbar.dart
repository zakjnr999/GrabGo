import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_customer/features/home/model/food_category.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:grab_go_customer/shared/viewmodels/favorites_provider.dart';
import 'package:grab_go_customer/shared/widgets/cached_image_widget.dart';
import 'package:grab_go_customer/shared/services/food_share_link.dart';
import 'package:provider/provider.dart';

class FoodDetailsAppBar extends StatelessWidget {
  const FoodDetailsAppBar({super.key, required this.foodItem});
  final FoodItem foodItem;

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
            CachedImageWidget(
              imageUrl: foodItem.image,
              fit: BoxFit.cover,
              placeholder: Container(
                height: size.height * 0.40,
                width: double.infinity,
                color: colors.inputBorder,
                padding: EdgeInsets.all(45.r),
                child: SvgPicture.asset(
                  Assets.icons.utensilsCrossed,
                  package: 'grab_go_shared',
                  colorFilter: ColorFilter.mode(colors.textSecondary, BlendMode.srcIn),
                ),
              ),
              errorWidget: Container(
                height: size.height * 0.40,
                width: double.infinity,
                color: colors.inputBorder,
                padding: EdgeInsets.all(45.r),
                child: SvgPicture.asset(
                  Assets.icons.utensilsCrossed,
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
                sellerId: foodItem.sellerId.toString(),
                foodName: foodItem.name,
                sellerName: foodItem.sellerName,
                imageUrl: foodItem.image,
                description: foodItem.description,
              );
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to share: ${e.toString()}'), backgroundColor: colors.error),
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
            final isFavorite = favoritesProvider.isFavorite(foodItem);
            return _buildActionButton(
              context: context,
              onTap: () {
                favoritesProvider.toggleFavorite(foodItem);
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
