import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:grab_go_customer/features/cart/viewmodel/cart_provider.dart';
import 'package:grab_go_customer/features/home/model/food_category.dart';
import 'package:grab_go_customer/shared/widgets/quick_reorder_card.dart';
import 'package:grab_go_customer/shared/widgets/section_header.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:provider/provider.dart';

class OrderAgainSection extends StatelessWidget {
  final List<FoodItem> recentOrders;
  final VoidCallback onSeeAll;
  final Function(FoodItem) onItemTap;

  const OrderAgainSection({super.key, required this.recentOrders, required this.onSeeAll, required this.onItemTap});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    // Don't show if no order history
    if (recentOrders.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        SectionHeader(
          title: "Order Again",
          icon: Assets.icons.history,
          accentColor: colors.accentViolet,
          onSeeAll: onSeeAll,
        ),
        SizedBox(height: 16.h),
        SizedBox(
          height: 260.h,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.only(left: 20.w),
            physics: const BouncingScrollPhysics(),
            itemCount: recentOrders.length,
            itemBuilder: (context, index) {
              final item = recentOrders[index];
              // Mock days ago (0-7)
              final daysAgo = index;

              return Consumer<CartProvider>(
                builder: (context, cartProvider, child) {
                  final bool isInCart = cartProvider.cartItems.containsKey(item);
                  return Padding(
                    padding: EdgeInsets.only(right: 15.w),
                    child: QuickReorderCard(
                      item: item,
                      daysAgo: daysAgo,
                      onTap: () => onItemTap(item),
                      isInCart: isInCart,
                      onAddToCart: () {
                        if (isInCart) {
                          cartProvider.removeItemCompletely(item);
                        } else {
                          cartProvider.addToCart(item);
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
