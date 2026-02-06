import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:grab_go_customer/features/cart/viewmodel/cart_provider.dart';
import 'package:grab_go_customer/features/home/model/food_category.dart';
import 'package:grab_go_customer/shared/widgets/quick_reorder_card.dart';
import 'package:grab_go_customer/shared/widgets/section_header.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:provider/provider.dart';

class OrderAgainSection extends StatelessWidget {
  final List<FoodItem> recentOrders;
  final List<dynamic>? originalItems;
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

    if (recentOrders.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        SectionHeader(
          title: "Order Again",
          sectionTotal: recentOrders.length,
          accentColor: colors.accentOrange,
          onSeeAll: onSeeAll,
        ),
        SizedBox(height: 10.h),
        SizedBox(
          height: 220.h,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.only(left: 20.w),
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: recentOrders.length,
            itemBuilder: (context, index) {
              final item = recentOrders[index];
              final originalItem = originalItems != null && index < originalItems!.length
                  ? originalItems![index]
                  : null;
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
}
