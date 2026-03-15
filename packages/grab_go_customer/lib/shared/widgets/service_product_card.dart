import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:grab_go_customer/features/cart/model/cart_item_interface.dart';
import 'package:grab_go_customer/features/cart/viewmodel/cart_provider.dart';
import 'package:grab_go_customer/shared/widgets/vertical_zigzag_tag.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:provider/provider.dart';

const double kServiceProductGridAspectRatio = 0.70;

class ServiceProductCard<T extends CartItem> extends StatelessWidget {
  final T item;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final bool showStoreName;
  final bool showDiscountBadge;
  final bool showTopRatedBadge;
  final bool compactLayout;
  final Color accentColor;
  final String imageUrl;
  final String unitLabel;
  final String? storeName;
  final double price;
  final double discountedPrice;
  final double discountPercentage;
  final double rating;
  final bool hasDiscount;

  const ServiceProductCard({
    super.key,
    required this.item,
    required this.accentColor,
    required this.imageUrl,
    required this.unitLabel,
    required this.price,
    required this.discountedPrice,
    required this.discountPercentage,
    required this.rating,
    required this.hasDiscount,
    this.onTap,
    this.margin,
    this.width,
    this.storeName,
    this.showStoreName = true,
    this.showDiscountBadge = false,
    this.showTopRatedBadge = false,
    this.compactLayout = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final showExpandedDiscountPricing = showDiscountBadge && hasDiscount;
    final showRatingBadge = !showExpandedDiscountPricing && showTopRatedBadge && rating > 0;
    final resolvedStoreName = (storeName ?? '').trim();
    final outerPadding = compactLayout ? 8.r : 10.r;
    final imagePadding = compactLayout ? 8.r : 10.r;
    final imageCornerRadius = compactLayout ? 10.r : 12.r;
    final titleGap = showExpandedDiscountPricing ? (compactLayout ? 6.h : 8.h) : (compactLayout ? 8.h : 10.h);
    final nameFontSize = compactLayout ? 12.sp : 13.sp;
    final storeFontSize = compactLayout ? 10.sp : 11.sp;
    final priceFontSize = compactLayout ? 13.sp : 14.sp;
    final unitFontSize = compactLayout ? 10.sp : 11.sp;
    final beforePriceFontSize = compactLayout ? 9.sp : 10.sp;
    final afterNameGap = compactLayout ? 3.h : 4.h;
    final afterStoreGap = showExpandedDiscountPricing ? (compactLayout ? 2.h : 2.h) : (compactLayout ? 3.h : 4.h);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        margin: margin,
        padding: EdgeInsets.all(outerPadding),
        decoration: BoxDecoration(color: colors.backgroundPrimary, borderRadius: BorderRadius.circular(18.r)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(imagePadding),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(KBorderSize.borderMedium),
                  ),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(imageCornerRadius),
                      child: CachedNetworkImage(
                        imageUrl: ImageOptimizer.getPreviewUrl(imageUrl, width: 320),
                        fit: BoxFit.contain,
                        memCacheWidth: 320,
                        maxHeightDiskCache: 640,
                        placeholder: (context, url) => _ProductImageFallback(accentColor: accentColor),
                        errorWidget: (context, url, error) => _ProductImageFallback(accentColor: accentColor),
                      ),
                    ),
                  ),
                ),
                if (showDiscountBadge && hasDiscount)
                  Positioned(
                    top: 0,
                    left: 8.w,
                    child: VerticalZigzagTag(
                      primaryText: '${discountPercentage.toInt()}%',
                      secondaryText: 'OFF',
                      color: accentColor,
                    ),
                  ),
                if (showRatingBadge)
                  Positioned(
                    top: 0,
                    left: 8.w,
                    child: VerticalZigzagTag(
                      primaryText: rating.toStringAsFixed(1),
                      secondaryText: 'rated',
                      color: accentColor,
                    ),
                  ),
                Positioned(
                  right: 8.w,
                  bottom: 8.h,
                  child: _ServiceCardActionButton<T>(item: item, color: accentColor, compactLayout: compactLayout),
                ),
              ],
            ),
            SizedBox(height: titleGap),
            Text(
              item.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: nameFontSize,
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
                height: compactLayout ? 1.15 : 1.2,
              ),
            ),
            SizedBox(height: afterNameGap),
            if (showStoreName && resolvedStoreName.isNotEmpty) ...[
              Text(
                resolvedStoreName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: storeFontSize,
                  fontWeight: FontWeight.w500,
                  color: colors.textSecondary,
                  height: 1.1,
                ),
              ),
              SizedBox(height: afterStoreGap),
            ],
            if (showExpandedDiscountPricing) ...[
              RichText(
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: 'GHS ${discountedPrice.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontFamily: 'Lato',
                        package: 'grab_go_shared',
                        fontSize: priceFontSize,
                        fontWeight: FontWeight.w800,
                        color: accentColor,
                        height: 1.0,
                      ),
                    ),
                    TextSpan(
                      text: ' / $unitLabel',
                      style: TextStyle(
                        fontFamily: 'Lato',
                        package: 'grab_go_shared',
                        fontSize: unitFontSize,
                        fontWeight: FontWeight.w500,
                        color: colors.textSecondary,
                        height: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 3.h),
              Text(
                'GHS ${price.toStringAsFixed(2)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Lato',
                  package: 'grab_go_shared',
                  fontSize: beforePriceFontSize,
                  fontWeight: FontWeight.w500,
                  color: colors.textSecondary,
                  decoration: TextDecoration.lineThrough,
                  height: 1.0,
                ),
              ),
            ] else
              RichText(
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: 'GHS ${discountedPrice.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontFamily: 'Lato',
                        package: 'grab_go_shared',
                        fontSize: priceFontSize,
                        fontWeight: FontWeight.w800,
                        color: accentColor,
                        height: 1.0,
                      ),
                    ),
                    TextSpan(
                      text: ' / $unitLabel',
                      style: TextStyle(
                        fontFamily: 'Lato',
                        package: 'grab_go_shared',
                        fontSize: unitFontSize,
                        fontWeight: FontWeight.w500,
                        color: colors.textSecondary,
                        height: 1.0,
                      ),
                    ),
                    if (hasDiscount)
                      TextSpan(
                        text: '  GHS ${price.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontFamily: 'Lato',
                          package: 'grab_go_shared',
                          fontSize: beforePriceFontSize,
                          fontWeight: FontWeight.w500,
                          color: colors.textSecondary,
                          decoration: TextDecoration.lineThrough,
                          height: 1.0,
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ProductImageFallback extends StatelessWidget {
  final Color accentColor;

  const _ProductImageFallback({required this.accentColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: accentColor.withValues(alpha: 0.1),
      alignment: Alignment.center,
      child: SvgPicture.asset(
        Assets.icons.cart,
        package: 'grab_go_shared',
        width: 26.w,
        height: 26.w,
        colorFilter: ColorFilter.mode(accentColor, BlendMode.srcIn),
      ),
    );
  }
}

class _ServiceCardActionButton<T extends CartItem> extends StatelessWidget {
  final T item;
  final Color color;
  final bool compactLayout;

  const _ServiceCardActionButton({required this.item, required this.color, required this.compactLayout});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Consumer<CartProvider>(
      builder: (context, cartProvider, _) {
        final isInCart = cartProvider.hasItemInCart(item);
        final isPending = cartProvider.isItemOperationPendingForDisplay(item);
        final actionItem = cartProvider.resolveItemForCartAction(item);
        const animationDuration = Duration(milliseconds: 250);
        final buttonSize = compactLayout ? 30.w : 32.w;
        final iconSize = compactLayout ? 16.w : 17.w;

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: isPending
                ? null
                : () async {
                    if (isInCart && actionItem != null) {
                      await cartProvider.removeItemCompletely(actionItem);
                    } else {
                      await cartProvider.addToCart(item, context: context);
                    }
                  },
            borderRadius: BorderRadius.circular(KBorderSize.borderMedium),
            child: AnimatedContainer(
              duration: animationDuration,
              width: buttonSize,
              height: buttonSize,
              decoration: BoxDecoration(
                color: isInCart ? color : colors.backgroundPrimary.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(KBorderSize.borderMedium),
              ),
              child: Center(
                child: AnimatedSwitcher(
                  duration: animationDuration,
                  transitionBuilder: (child, animation) => ScaleTransition(
                    scale: animation,
                    child: FadeTransition(opacity: animation, child: child),
                  ),
                  child: isPending
                      ? SizedBox(
                          key: const ValueKey('loading'),
                          width: iconSize,
                          height: iconSize,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(isInCart ? Colors.white : color),
                          ),
                        )
                      : SvgPicture.asset(
                          isInCart ? Assets.icons.check : Assets.icons.plus,
                          key: ValueKey(isInCart ? 'check' : 'plus'),
                          package: 'grab_go_shared',
                          width: iconSize,
                          height: iconSize,
                          colorFilter: ColorFilter.mode(isInCart ? Colors.white : colors.textPrimary, BlendMode.srcIn),
                        ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
