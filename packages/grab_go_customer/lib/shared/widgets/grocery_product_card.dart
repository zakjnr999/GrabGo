import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:grab_go_customer/features/cart/viewmodel/cart_provider.dart';
import 'package:grab_go_customer/features/groceries/model/grocery_item.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:provider/provider.dart';

class GroceryProductCard extends StatelessWidget {
  final GroceryItem item;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final bool showStoreName;
  final bool showDiscountBadge;

  const GroceryProductCard({
    super.key,
    required this.item,
    this.onTap,
    this.margin,
    this.width,
    this.showStoreName = true,
    this.showDiscountBadge = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final accentColor = colors.serviceGrocery;
    final displayPrice = item.discountedPrice;
    final hasDiscount = item.hasDiscount;
    final storeName = (item.storeName ?? '').trim();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        margin: margin,
        padding: EdgeInsets.all(10.r),
        decoration: BoxDecoration(color: colors.backgroundPrimary, borderRadius: BorderRadius.circular(18.r)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(10.r),
                  decoration: BoxDecoration(
                    color: colors.backgroundSecondary,
                    borderRadius: BorderRadius.circular(KBorderSize.borderMedium),
                  ),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12.r),
                      child: CachedNetworkImage(
                        imageUrl: ImageOptimizer.getPreviewUrl(item.catalogImage, width: 320),
                        fit: BoxFit.contain,
                        memCacheWidth: 320,
                        maxHeightDiskCache: 640,
                        placeholder: (context, url) => Container(
                          color: colors.backgroundSecondary,
                          alignment: Alignment.center,
                          child: Icon(Icons.local_grocery_store_outlined, size: 28.sp, color: colors.textSecondary),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: colors.backgroundSecondary,
                          alignment: Alignment.center,
                          child: Icon(Icons.broken_image_outlined, size: 28.sp, color: colors.textSecondary),
                        ),
                      ),
                    ),
                  ),
                ),
                if (showDiscountBadge && hasDiscount)
                  Positioned(
                    left: 8.w,
                    top: 8.h,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                      decoration: BoxDecoration(color: accentColor, borderRadius: BorderRadius.circular(999.r)),
                      child: Text(
                        '-${item.discountPercentage.toInt()}%',
                        style: TextStyle(color: Colors.white, fontSize: 10.sp, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                Positioned(
                  right: 8.w,
                  bottom: 8.h,
                  child: _GroceryCardActionButton(item: item, color: accentColor),
                ),
              ],
            ),
            SizedBox(height: 10.h),
            Text(
              item.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700, color: colors.textPrimary, height: 1.2),
            ),
            SizedBox(height: 4.h),
            if (showStoreName && storeName.isNotEmpty) ...[
              Text(
                storeName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w500, color: colors.textSecondary),
              ),
              SizedBox(height: 4.h),
            ],
            RichText(
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              text: TextSpan(
                children: [
                  TextSpan(
                    text: 'GHS ${displayPrice.toStringAsFixed(2)}',
                    style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w800, color: accentColor),
                  ),
                  TextSpan(
                    text: ' / ${item.unit}',
                    style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w500, color: colors.textSecondary),
                  ),
                ],
              ),
            ),
            if (hasDiscount) ...[
              SizedBox(height: 2.h),
              Text(
                'GHS ${item.price.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w500,
                  color: colors.textSecondary,
                  decoration: TextDecoration.lineThrough,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _GroceryCardActionButton extends StatelessWidget {
  final GroceryItem item;
  final Color color;

  const _GroceryCardActionButton({required this.item, required this.color});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Consumer<CartProvider>(
      builder: (context, cartProvider, _) {
        final isInCart = cartProvider.hasItemInCart(item);
        final isPending = cartProvider.isItemOperationPendingForDisplay(item);
        final actionItem = cartProvider.resolveItemForCartAction(item);
        const animationDuration = Duration(milliseconds: 250);

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
              width: 32.w,
              height: 32.w,
              decoration: BoxDecoration(
                color: isInCart ? color : colors.backgroundPrimary.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(KBorderSize.borderMedium),
              ),
              child: Center(
                child: AnimatedSwitcher(
                  duration: animationDuration,
                  switchInCurve: Curves.easeOutBack,
                  switchOutCurve: Curves.easeIn,
                  transitionBuilder: (child, animation) {
                    return ScaleTransition(
                      scale: animation,
                      child: FadeTransition(opacity: animation, child: child),
                    );
                  },
                  child: isPending
                      ? SizedBox(
                          key: const ValueKey('pending'),
                          width: 17.w,
                          height: 17.w,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(isInCart ? Colors.white : color),
                          ),
                        )
                      : SvgPicture.asset(
                          key: ValueKey(isInCart ? 'in-cart' : 'add'),
                          isInCart ? Assets.icons.check : Assets.icons.plus,
                          package: 'grab_go_shared',
                          height: 17.h,
                          width: 17.w,
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
