import 'package:dotted_line/dotted_line.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:flutter_swipe_action_cell/core/cell.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_customer/features/home/model/food_category.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_customer/features/cart/viewmodel/cart_provider.dart';
import 'package:provider/provider.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:cached_network_image/cached_network_image.dart';

class CartItem extends StatefulWidget {
  const CartItem({super.key});

  @override
  State<CartItem> createState() => _CartItemState();
}

class _CartItemState extends State<CartItem> {
  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final size = MediaQuery.sizeOf(context);
    final double imageSize = (size.width * 0.28).clamp(96.0, 120.0);

    return Consumer<CartProvider>(
      builder: (context, provider, child) {
        if (provider.cartItems.isEmpty) {
          return const SizedBox.shrink();
        }

        final cartEntries = provider.cartItems.entries.toList();

        return Column(
          children: [
            ...cartEntries.asMap().entries.map((entry) {
              final index = entry.key;
              final cartItem = entry.value.key;
              final quantity = entry.value.value;
              final bool isRestaurantClosed = cartItem is FoodItem ? !(cartItem).isRestaurantOpen : false;
              final bool isItemPending = provider.isItemOperationPending(cartItem);

              return Column(
                children: [
                  GestureDetector(
                    onTap: () {
                      if (cartItem.itemType == 'Food') {
                        context.push("/foodDetails", extra: cartItem);
                      } else if (cartItem.itemType == 'GroceryItem') {
                        context.push("/groceryDetails", extra: cartItem);
                      }
                    },
                    child: SwipeActionCell(
                      backgroundColor: colors.backgroundPrimary,
                      key: ObjectKey(cartItem),
                      trailingActions: [
                        SwipeAction(
                          color: Colors.transparent,
                          content: Container(
                            height: 118.h + 12.h,
                            width: 80.w,
                            margin: EdgeInsets.only(right: 10.w, top: 6.h, bottom: 6.h),
                            decoration: BoxDecoration(
                              color: colors.error,
                              borderRadius: BorderRadius.circular(KBorderSize.borderRadius15),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  AppStrings.cartDelete,
                                  style: TextStyle(color: Colors.white, fontSize: 11.sp, fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                          ),
                          onTap: (handler) async {
                            if (isItemPending) return;
                            await provider.removeItemCompletely(cartItem);
                            if (!context.mounted) return;
                          },
                        ),
                      ],
                      child: Container(
                        margin: EdgeInsets.symmetric(horizontal: 20.w, vertical: 6.h),
                        padding: EdgeInsets.all(2.r),
                        decoration: BoxDecoration(
                          color: colors.backgroundPrimary,
                          borderRadius: BorderRadius.circular(KBorderSize.borderRadius15),
                          border: Border.all(color: colors.inputBorder.withValues(alpha: 0.5), width: 1),
                        ),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(KBorderSize.borderRadius15),
                                bottomLeft: Radius.circular(KBorderSize.borderRadius15),
                                bottomRight: Radius.circular(KBorderSize.borderRadius4),
                                topRight: Radius.circular(KBorderSize.borderRadius4),
                              ),
                              child: Stack(
                                children: [
                                  CachedNetworkImage(
                                    imageUrl: ImageOptimizer.getPreviewUrl(cartItem.image, width: 300),
                                    height: imageSize,
                                    width: imageSize,
                                    fit: BoxFit.cover,
                                    memCacheWidth: 300,
                                    maxHeightDiskCache: 400,
                                    placeholder: (context, url) => Container(
                                      height: imageSize,
                                      width: imageSize,
                                      color: colors.inputBorder,
                                      child: Center(
                                        child: SvgPicture.asset(
                                          Assets.icons.utensilsCrossed,
                                          package: 'grab_go_shared',
                                          colorFilter: ColorFilter.mode(colors.textSecondary, BlendMode.srcIn),
                                          width: 30.w,
                                          height: 30.h,
                                        ),
                                      ),
                                    ),
                                    errorWidget: (context, url, error) => Container(
                                      height: imageSize,
                                      width: imageSize,
                                      color: colors.inputBorder,
                                      child: Center(
                                        child: SvgPicture.asset(
                                          Assets.icons.utensilsCrossed,
                                          package: 'grab_go_shared',
                                          colorFilter: ColorFilter.mode(colors.textSecondary, BlendMode.srcIn),
                                          width: 30.w,
                                          height: 30.h,
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (isRestaurantClosed)
                                    Positioned.fill(
                                      child: Container(
                                        color: Colors.black.withValues(alpha: 0.5),
                                        alignment: Alignment.center,
                                        child: Text(
                                          "We're closed",
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 12.sp,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),

                            Expanded(
                              child: Padding(
                                padding: EdgeInsets.symmetric(horizontal: 12.r, vertical: 8.h),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          cartItem.name,
                                          style: TextStyle(
                                            fontSize: 15.sp,
                                            fontWeight: FontWeight.w700,
                                            color: colors.textPrimary,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        SizedBox(height: 6.h),
                                        Row(
                                          children: [
                                            SvgPicture.asset(
                                              Assets.icons.starSolid,
                                              package: 'grab_go_shared',
                                              height: 13.h,
                                              width: 13.w,
                                              colorFilter: ColorFilter.mode(colors.accentOrange, BlendMode.srcIn),
                                            ),
                                            SizedBox(width: 4.w),
                                            Text(
                                              cartItem.rating.toStringAsFixed(1),
                                              style: TextStyle(
                                                fontSize: 12.sp,
                                                color: colors.textPrimary,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            // SizedBox(width: 8.w),
                                            // Container(
                                            //   width: 3.w,
                                            //   height: 3.h,
                                            //   decoration: BoxDecoration(
                                            //     shape: BoxShape.circle,
                                            //     color: colors.textSecondary,
                                            //   ),
                                            // ),
                                            // SizedBox(width: 8.w),
                                            // Text(
                                            //   "Qty: $quantity",
                                            //   style: TextStyle(
                                            //     fontSize: 11.sp,
                                            //     fontWeight: FontWeight.w600,
                                            //     color: colors.accentViolet,
                                            //   ),
                                            // ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 10.h),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Container(
                                          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                                          decoration: BoxDecoration(
                                            color: colors.accentOrange.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(8.r),
                                          ),
                                          child: Text(
                                            "GHS ${cartItem.price.toStringAsFixed(2)}",
                                            style: TextStyle(
                                              fontSize: 13.sp,
                                              fontWeight: FontWeight.w800,
                                              color: colors.accentOrange,
                                            ),
                                          ),
                                        ),
                                        Container(
                                          padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 4.h),
                                          decoration: BoxDecoration(
                                            color: colors.backgroundSecondary,
                                            borderRadius: BorderRadius.circular(10.r),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              GestureDetector(
                                                onTap: () {
                                                  if (isItemPending) return;
                                                  provider.removeFromCart(cartItem);
                                                },
                                                child: Container(
                                                  padding: EdgeInsets.all(4.r),
                                                  decoration: const BoxDecoration(
                                                    color: Colors.transparent,
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: isItemPending
                                                      ? SizedBox(
                                                          width: 18.w,
                                                          height: 18.w,
                                                          child: CircularProgressIndicator(
                                                            strokeWidth: 2,
                                                            valueColor: AlwaysStoppedAnimation<Color>(
                                                              colors.textSecondary,
                                                            ),
                                                          ),
                                                        )
                                                      : Icon(Icons.remove, color: colors.textSecondary, size: 18),
                                                ),
                                              ),
                                              Container(
                                                padding: EdgeInsets.symmetric(horizontal: 12.w),
                                                child: Text(
                                                  isItemPending ? '...' : quantity.toString(),
                                                  style: TextStyle(
                                                    fontSize: 14.sp,
                                                    fontWeight: FontWeight.w700,
                                                    color: colors.textPrimary,
                                                  ),
                                                ),
                                              ),
                                              GestureDetector(
                                                onTap: () {
                                                  if (isItemPending) return;
                                                  provider.addToCart(cartItem, context: context);
                                                },
                                                child: Container(
                                                  padding: EdgeInsets.all(4.r),
                                                  decoration: BoxDecoration(
                                                    color: isItemPending
                                                        ? colors.accentOrange.withValues(alpha: 0.45)
                                                        : colors.accentOrange,
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: isItemPending
                                                      ? SizedBox(
                                                          width: 18.w,
                                                          height: 18.w,
                                                          child: const CircularProgressIndicator(
                                                            strokeWidth: 2,
                                                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                                          ),
                                                        )
                                                      : const Icon(Icons.add, color: Colors.white, size: 18),
                                                ),
                                              ),
                                            ],
                                          ),
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
                    ),
                  ),
                  if (index < cartEntries.length - 1)
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 5.h),
                      child: DottedLine(
                        dashLength: 6,
                        dashGapLength: 4,
                        lineThickness: 1,
                        dashColor: colors.textSecondary.withAlpha(50),
                      ),
                    ),
                ],
              );
            }),
          ],
        );
      },
    );
  }
}
