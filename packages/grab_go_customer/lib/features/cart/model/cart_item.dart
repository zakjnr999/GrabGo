import 'package:cached_network_image/cached_network_image.dart';
import 'package:dotted_line/dotted_line.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:flutter_swipe_action_cell/core/cell.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_customer/features/cart/model/cart_item_interface.dart'
    as cart_model;
import 'package:grab_go_customer/features/cart/viewmodel/cart_provider.dart';
import 'package:grab_go_customer/features/home/model/food_category.dart';
import 'package:grab_go_customer/shared/widgets/food_customization_chips.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:provider/provider.dart';

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

        final groupedEntries = _groupCartEntries(provider.cartItems);

        return Column(
          children: [
            for (
              int groupIndex = 0;
              groupIndex < groupedEntries.length;
              groupIndex++
            ) ...[
              _buildGroupHeader(
                colors: colors,
                group: groupedEntries[groupIndex],
              ),
              for (
                int itemIndex = 0;
                itemIndex < groupedEntries[groupIndex].entries.length;
                itemIndex++
              )
                _buildCartEntry(
                  context: context,
                  provider: provider,
                  cartEntry: groupedEntries[groupIndex].entries[itemIndex],
                  imageSize: imageSize,
                  colors: colors,
                  showItemDivider:
                      itemIndex < groupedEntries[groupIndex].entries.length - 1,
                ),
              if (groupIndex < groupedEntries.length - 1)
                SizedBox(height: 10.h),
            ],
          ],
        );
      },
    );
  }

  List<_CartVendorGroup> _groupCartEntries(
    Map<cart_model.CartItem, int> cartItems,
  ) {
    final grouped = <String, List<MapEntry<cart_model.CartItem, int>>>{};
    final groupNames = <String, String>{};

    for (final entry in cartItems.entries) {
      final item = entry.key;
      final providerId = item.providerId.trim();
      final providerName = item.providerName.trim().isNotEmpty
          ? item.providerName.trim()
          : 'Vendor';
      final providerKey = providerId.isNotEmpty
          ? providerId
          : '${item.itemType}:${providerName.toLowerCase()}';
      final groupKey = '${item.itemType}:$providerKey';

      grouped.putIfAbsent(
        groupKey,
        () => <MapEntry<cart_model.CartItem, int>>[],
      );
      grouped[groupKey]!.add(entry);
      groupNames[groupKey] = providerName;
    }

    return grouped.entries
        .map(
          (entry) => _CartVendorGroup(
            key: entry.key,
            providerName: groupNames[entry.key] ?? 'Vendor',
            entries: entry.value,
          ),
        )
        .toList(growable: false);
  }

  Widget _buildGroupHeader({
    required AppColorsExtension colors,
    required _CartVendorGroup group,
  }) {
    final subtitle =
        '${group.entries.length} ${group.entries.length == 1 ? 'item' : 'items'}';

    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 6.h, 20.w, 4.h),
      child: Row(
        children: [
          Text(
            group.providerName,
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 14.sp,
              fontWeight: FontWeight.w800,
            ),
          ),
          const Spacer(),
          Text(
            subtitle,
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 12.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartEntry({
    required BuildContext context,
    required CartProvider provider,
    required MapEntry<cart_model.CartItem, int> cartEntry,
    required double imageSize,
    required AppColorsExtension colors,
    required bool showItemDivider,
  }) {
    final cartItem = cartEntry.key;
    final quantity = cartEntry.value;
    final bool isRestaurantClosed = cartItem is FoodItem
        ? !cartItem.isRestaurantOpen
        : false;
    final bool isItemPending = provider.isItemOperationPending(cartItem);

    return Column(
      children: [
        GestureDetector(
          onTap: () => _openItemDetails(context, cartItem),
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
                    borderRadius: BorderRadius.circular(
                      KBorderSize.borderRadius15,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        isItemPending ? 'Removing' : AppStrings.cartDelete,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w700,
                        ),
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
                          imageUrl: ImageOptimizer.getPreviewUrl(
                            cartItem.image,
                            width: 300,
                          ),
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
                                colorFilter: ColorFilter.mode(
                                  colors.textSecondary,
                                  BlendMode.srcIn,
                                ),
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
                                colorFilter: ColorFilter.mode(
                                  colors.textSecondary,
                                  BlendMode.srcIn,
                                ),
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
                      padding: EdgeInsets.symmetric(
                        horizontal: 12.r,
                        vertical: 8.h,
                      ),
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
                                    colorFilter: ColorFilter.mode(
                                      colors.accentOrange,
                                      BlendMode.srcIn,
                                    ),
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
                                ],
                              ),
                              if (cartItem is FoodItem) ...[
                                SizedBox(height: 8.h),
                                FoodCustomizationChips(
                                  item: cartItem,
                                  colors: colors,
                                ),
                              ],
                            ],
                          ),
                          SizedBox(height: 10.h),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 10.w,
                                  vertical: 6.h,
                                ),
                                decoration: BoxDecoration(
                                  color: colors.accentOrange.withValues(
                                    alpha: 0.15,
                                  ),
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
                                padding: EdgeInsets.symmetric(
                                  horizontal: 4.w,
                                  vertical: 4.h,
                                ),
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
                                                  valueColor:
                                                      AlwaysStoppedAnimation<
                                                        Color
                                                      >(colors.textSecondary),
                                                ),
                                              )
                                            : Icon(
                                                Icons.remove,
                                                color: colors.textSecondary,
                                                size: 18,
                                              ),
                                      ),
                                    ),
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 12.w,
                                      ),
                                      child: Text(
                                        isItemPending
                                            ? '...'
                                            : quantity.toString(),
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
                                        provider.addToCart(
                                          cartItem,
                                          context: context,
                                        );
                                      },
                                      child: Container(
                                        padding: EdgeInsets.all(4.r),
                                        decoration: BoxDecoration(
                                          color: isItemPending
                                              ? colors.accentOrange.withValues(
                                                  alpha: 0.45,
                                                )
                                              : colors.accentOrange,
                                          shape: BoxShape.circle,
                                        ),
                                        child: isItemPending
                                            ? SizedBox(
                                                width: 18.w,
                                                height: 18.w,
                                                child:
                                                    const CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      valueColor:
                                                          AlwaysStoppedAnimation<
                                                            Color
                                                          >(Colors.white),
                                                    ),
                                              )
                                            : const Icon(
                                                Icons.add,
                                                color: Colors.white,
                                                size: 18,
                                              ),
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
        if (showItemDivider)
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
  }

  void _openItemDetails(BuildContext context, cart_model.CartItem cartItem) {
    if (cartItem.itemType == 'Food') {
      context.push("/foodDetails", extra: cartItem);
      return;
    }
    if (cartItem.itemType == 'GroceryItem') {
      context.push("/groceryDetails", extra: cartItem);
    }
  }
}

class _CartVendorGroup {
  final String key;
  final String providerName;
  final List<MapEntry<cart_model.CartItem, int>> entries;

  const _CartVendorGroup({
    required this.key,
    required this.providerName,
    required this.entries,
  });
}
