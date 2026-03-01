import 'package:cached_network_image/cached_network_image.dart';
import 'package:dotted_line/dotted_line.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:flutter_swipe_action_cell/core/cell.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_customer/features/cart/model/cart_item_interface.dart' as cart_model;
import 'package:grab_go_customer/features/cart/viewmodel/cart_provider.dart';
import 'package:grab_go_customer/features/home/model/food_category.dart';
import 'package:grab_go_customer/shared/widgets/food_customization_editor_sheet.dart';
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
    final double imageSize = (size.width * 0.24).clamp(74.0, 88.0);

    return Consumer<CartProvider>(
      builder: (context, provider, child) {
        if (provider.cartItems.isEmpty) {
          return const SizedBox.shrink();
        }

        final groupedEntries = _groupCartEntries(provider.cartItems);

        return Column(
          children: [
            for (int groupIndex = 0; groupIndex < groupedEntries.length; groupIndex++) ...[
              _buildGroupHeader(colors: colors, group: groupedEntries[groupIndex]),
              for (int itemIndex = 0; itemIndex < groupedEntries[groupIndex].entries.length; itemIndex++)
                _buildCartEntry(
                  context: context,
                  provider: provider,
                  cartEntry: groupedEntries[groupIndex].entries[itemIndex],
                  imageSize: imageSize,
                  colors: colors,
                  showItemDivider: itemIndex < groupedEntries[groupIndex].entries.length - 1,
                ),
              if (groupIndex < groupedEntries.length - 1) SizedBox(height: 10.h),
            ],
          ],
        );
      },
    );
  }

  List<_CartVendorGroup> _groupCartEntries(Map<cart_model.CartItem, int> cartItems) {
    final grouped = <String, List<MapEntry<cart_model.CartItem, int>>>{};
    final groupNames = <String, String>{};

    for (final entry in cartItems.entries) {
      final item = entry.key;
      final providerId = item.providerId.trim();
      final providerName = item.providerName.trim().isNotEmpty ? item.providerName.trim() : 'Vendor';
      final providerKey = providerId.isNotEmpty ? providerId : '${item.itemType}:${providerName.toLowerCase()}';
      final groupKey = '${item.itemType}:$providerKey';

      grouped.putIfAbsent(groupKey, () => <MapEntry<cart_model.CartItem, int>>[]);
      grouped[groupKey]!.add(entry);
      groupNames[groupKey] = providerName;
    }

    return grouped.entries
        .map(
          (entry) =>
              _CartVendorGroup(key: entry.key, providerName: groupNames[entry.key] ?? 'Vendor', entries: entry.value),
        )
        .toList(growable: false);
  }

  Widget _buildGroupHeader({required AppColorsExtension colors, required _CartVendorGroup group}) {
    final subtitle = '${group.entries.length} ${group.entries.length == 1 ? 'item' : 'items'}';

    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 4.h, 20.w, 2.h),
      child: Row(
        children: [
          Text(
            group.providerName,
            style: TextStyle(color: colors.textPrimary, fontSize: 14.sp, fontWeight: FontWeight.w800),
          ),
          const Spacer(),
          Text(
            subtitle,
            style: TextStyle(color: colors.textSecondary, fontSize: 12.sp, fontWeight: FontWeight.w600),
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
    final bool isRestaurantClosed = cartItem is FoodItem ? !cartItem.isRestaurantOpen : false;
    final bool isItemPending = provider.isItemOperationPending(cartItem);
    final etaLabelFromProvider = provider.etaLabelForVendor(
      itemType: cartItem.itemType,
      providerId: cartItem.providerId,
      providerName: cartItem.providerName,
    );
    final etaLabel = (etaLabelFromProvider != null && etaLabelFromProvider.trim().isNotEmpty)
        ? etaLabelFromProvider
        : (cartItem is FoodItem ? cartItem.estimatedDeliveryTime : null);

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
                  height: imageSize + 14.h,
                  width: 80.w,
                  margin: EdgeInsets.only(right: 10.w, top: 4.h, bottom: 4.h),
                  decoration: BoxDecoration(
                    color: colors.error,
                    borderRadius: BorderRadius.circular(KBorderSize.borderRadius15),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        isItemPending ? 'Removing' : AppStrings.cartDelete,
                        textAlign: TextAlign.center,
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
              margin: EdgeInsets.symmetric(horizontal: 20.w, vertical: 4.h),
              padding: EdgeInsets.zero,
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
                                style: TextStyle(color: Colors.white, fontSize: 12.sp, fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10.r, vertical: 4.h),
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
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w700,
                                  color: colors.textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              SizedBox(height: 4.h),
                              if (etaLabel != null && etaLabel.trim().isNotEmpty) ...[
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SvgPicture.asset(
                                      Assets.icons.timer,
                                      package: 'grab_go_shared',
                                      height: 10.h,
                                      width: 10.w,
                                      colorFilter: ColorFilter.mode(colors.textSecondary, BlendMode.srcIn),
                                    ),
                                    SizedBox(width: 4.w),
                                    Text(
                                      etaLabel,
                                      style: TextStyle(
                                        fontSize: 10.sp,
                                        fontWeight: FontWeight.w500,
                                        color: colors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 5.h),
                              ],
                              if (cartItem is FoodItem) ...[
                                _buildFoodCustomizationMeta(
                                  context: context,
                                  provider: provider,
                                  item: cartItem,
                                  isItemPending: isItemPending,
                                  colors: colors,
                                ),
                              ],
                            ],
                          ),
                          SizedBox(height: 6.h),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                                decoration: BoxDecoration(
                                  color: colors.accentOrange.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8.r),
                                ),
                                child: Text(
                                  "GHS ${cartItem.price.toStringAsFixed(2)}",
                                  style: TextStyle(
                                    fontSize: 12.sp,
                                    fontWeight: FontWeight.w800,
                                    color: colors.accentOrange,
                                  ),
                                ),
                              ),
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 2.h),
                                decoration: BoxDecoration(
                                  color: colors.backgroundSecondary,
                                  borderRadius: BorderRadius.circular(9.r),
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
                                                width: 16.w,
                                                height: 16.w,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  valueColor: AlwaysStoppedAnimation<Color>(colors.textSecondary),
                                                ),
                                              )
                                            : Icon(Icons.remove, color: colors.textSecondary, size: 16),
                                      ),
                                    ),
                                    Container(
                                      padding: EdgeInsets.symmetric(horizontal: 10.w),
                                      child: Text(
                                        isItemPending ? '...' : quantity.toString(),
                                        style: TextStyle(
                                          fontSize: 13.sp,
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
                                                width: 16.w,
                                                height: 16.w,
                                                child: const CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                                ),
                                              )
                                            : const Icon(Icons.add, color: Colors.white, size: 16),
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

  Widget _buildFoodCustomizationMeta({
    required BuildContext context,
    required CartProvider provider,
    required FoodItem item,
    required bool isItemPending,
    required AppColorsExtension colors,
  }) {
    final summaryLines = FoodCustomizationChips.buildFoodCustomizationSummaryLines(
      item,
      maxPreferenceLabels: 2,
      maxNoteLength: 28,
    );
    final hasCustomizations = summaryLines.isNotEmpty;
    final hasCustomizationOptions = item.portionOptions.isNotEmpty || item.preferenceGroups.isNotEmpty;

    if (!hasCustomizations && !hasCustomizationOptions) {
      return const SizedBox.shrink();
    }

    final compactSummary = _buildCompactCustomizationSummary(item, fallbackLines: summaryLines);

    return Row(
      children: [
        if (compactSummary != null)
          Expanded(
            child: Text(
              compactSummary,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 10.sp, fontWeight: FontWeight.w600, color: colors.textSecondary),
            ),
          ),
        if (hasCustomizationOptions) ...[
          if (compactSummary != null) SizedBox(width: 8.w),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () async {
                if (isItemPending) return;
                await _customizeFoodItem(context: context, provider: provider, currentItem: item);
              },
              customBorder: const CircleBorder(),
              child: Tooltip(
                message: 'Customize',
                child: Container(
                  padding: EdgeInsets.all(5.r),
                  decoration: BoxDecoration(color: colors.backgroundSecondary, shape: BoxShape.circle),
                  child: SvgPicture.asset(
                    Assets.icons.edit,
                    package: 'grab_go_shared',
                    height: 12.h,
                    width: 12.w,
                    colorFilter: ColorFilter.mode(colors.textSecondary, BlendMode.srcIn),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  String? _buildCompactCustomizationSummary(FoodItem item, {required List<String> fallbackLines}) {
    final pieces = <String>[];
    final portionLabel = item.selectedPortion?['label']?.toString().trim();
    if (portionLabel != null && portionLabel.isNotEmpty) {
      pieces.add('Portion: $portionLabel');
    }

    final preferenceCount = item.selectedPreferences.length;
    if (preferenceCount > 0) {
      if (preferenceCount == 1) {
        final prefLabel = item.selectedPreferences.first['optionLabel']?.toString().trim();
        if (prefLabel != null && prefLabel.isNotEmpty) {
          pieces.add(prefLabel);
        } else {
          pieces.add('1 pref');
        }
      } else {
        pieces.add('$preferenceCount prefs');
      }
    }

    final note = item.itemNote?.trim();
    if (note != null && note.isNotEmpty) {
      pieces.add('Note');
    }

    if (pieces.isEmpty) {
      if (fallbackLines.isEmpty) return null;
      return fallbackLines.first;
    }

    return pieces.join(' • ');
  }

  Future<void> _customizeFoodItem({
    required BuildContext context,
    required CartProvider provider,
    required FoodItem currentItem,
  }) async {
    final updatedItem = await FoodCustomizationEditorSheet.show(context: context, item: currentItem);
    if (updatedItem == null) return;

    final error = await provider.replaceFoodCustomizationInCart(currentItem: currentItem, updatedItem: updatedItem);
    if (!context.mounted) return;
    if (error != null && error.trim().isNotEmpty) {
      AppToastMessage.show(context: context, backgroundColor: context.appColors.error, message: error, maxLines: 2);
    }
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

  const _CartVendorGroup({required this.key, required this.providerName, required this.entries});
}
