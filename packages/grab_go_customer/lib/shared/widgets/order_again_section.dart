import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:grab_go_customer/features/cart/viewmodel/cart_provider.dart';
import 'package:grab_go_customer/features/home/model/food_category.dart';
import 'package:grab_go_customer/shared/widgets/horizontal_card_skeleton.dart';
import 'package:grab_go_customer/shared/widgets/quick_reorder_card.dart';
import 'package:grab_go_customer/shared/widgets/section_header.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:provider/provider.dart';

class OrderAgainSection extends StatelessWidget {
  final List<FoodItem> recentOrders;
  final List<dynamic>? originalItems; // Original GroceryItem list for cart operations
  final VoidCallback onSeeAll;
  final Function(FoodItem) onItemTap;
  final bool isLoading;

  const OrderAgainSection({
    super.key,
    required this.recentOrders,
    this.originalItems,
    required this.onSeeAll,
    required this.onItemTap,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        SectionHeader(
          title: "Order Again",
          icon: Assets.icons.history,
          accentColor: colors.accentViolet,
          onSeeAll: onSeeAll,
        ),
        SizedBox(height: 16.h),
        if (isLoading)
          HorizontalCardSkeleton(colors: colors, isDark: isDark, height: 230.h)
        else if (recentOrders.isEmpty)
          _buildEmptyState(colors)
        else
          SizedBox(
            height: 230.h,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.only(left: 20.w),
              physics: const BouncingScrollPhysics(),
              itemCount: recentOrders.length,
              itemBuilder: (context, index) {
                final item = recentOrders[index];
                final originalItem = originalItems != null && index < originalItems!.length
                    ? originalItems![index]
                    : null;
                // Calculate real days ago from lastOrderedAt
                final daysAgo = item.lastOrderedAt != null ? DateTime.now().difference(item.lastOrderedAt!).inDays : 0;

                return Consumer<CartProvider>(
                  builder: (context, cartProvider, child) {
                    final itemForCart = originalItem ?? item;
                    final bool isInCart = cartProvider.cartItems.containsKey(itemForCart);
                    return Padding(
                      padding: EdgeInsets.only(right: 15.w),
                      child: QuickReorderCard(
                        item: item,
                        daysAgo: daysAgo,
                        onTap: () => onItemTap(item),
                        isInCart: isInCart,
                        onAddToCart: () {
                          if (isInCart) {
                            cartProvider.removeItemCompletely(itemForCart);
                          } else {
                            cartProvider.addToCart(itemForCart, context: context);
                          }
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildEmptyState(AppColorsExtension colors) {
    return Container(
      height: 200.h,
      padding: EdgeInsets.symmetric(horizontal: 40.w, vertical: 32.h),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history, size: 48.sp, color: colors.textSecondary.withValues(alpha: 0.5)),
          SizedBox(height: 16.h),
          Text(
            'No previous orders yet',
            style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600, color: colors.textPrimary),
          ),
          SizedBox(height: 8.h),
          Text(
            'Items you order will appear here for quick reordering',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13.sp, color: colors.textSecondary),
          ),
        ],
      ),
    );
  }
}
