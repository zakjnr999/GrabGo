import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_customer/features/home/model/food_category.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:grab_go_customer/shared/viewmodels/favorites_provider.dart';
import 'package:grab_go_customer/shared/widgets/cached_image_widget.dart';
import 'package:provider/provider.dart';

class FoodDetailsAppBar extends StatelessWidget {
  const FoodDetailsAppBar({super.key, required this.foodItem});
  final FoodItem foodItem;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    Size size = MediaQuery.sizeOf(context);

    return SliverAppBar(
      expandedHeight: size.height * 0.40,
      backgroundColor: colors.backgroundPrimary,
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
        background: CachedImageWidget(
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
        ),
        stretchModes: const [StretchMode.blurBackground, StretchMode.zoomBackground],
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
            width: 40.w,
            height: 5.h,
            decoration: BoxDecoration(
              color: colors.textSecondary.withAlpha(50),
              borderRadius: BorderRadius.circular(KBorderSize.border),
            ),
          ),
        ),
      ),
      actionsPadding: EdgeInsets.symmetric(horizontal: 20.h),
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

        Consumer<FavoritesProvider>(
          builder: (context, favoritesProvider, child) {
            final isFavorite = favoritesProvider.isFavorite(foodItem);
            return BlurCircleButton(
              onTap: () {
                favoritesProvider.toggleFavorite(foodItem);
              },
              icon: SvgPicture.asset(
                isFavorite ? Assets.icons.heartSolid : Assets.icons.heart,
                colorFilter: ColorFilter.mode(isFavorite ? Colors.red : Colors.white, BlendMode.srcIn),
              ),
            );
          },
        ),
      ],
    );
  }
}
