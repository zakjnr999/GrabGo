import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:grab_go_customer/features/groceries/model/grocery_item.dart';
import 'package:grab_go_customer/shared/widgets/popular_item_card.dart';
import 'package:grab_go_customer/shared/widgets/section_header.dart';
import 'package:grab_go_shared/grub_go_shared.dart';

class FreshArrivalsSection extends StatelessWidget {
  final List<GroceryItem> items;
  final VoidCallback onSeeAll;
  final Function(GroceryItem) onItemTap;
  final bool isLoading;

  const FreshArrivalsSection({
    super.key,
    required this.items,
    required this.onSeeAll,
    required this.onItemTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Column(
      children: [
        SectionHeader(
          title: 'Fresh Arrivals',
          sectionTotal: items.length,
          accentColor: colors.accentOrange,
          onSeeAll: onSeeAll,
        ),
        SizedBox(height: 16.h),
        if (items.isNotEmpty) _buildItemsList(),
      ],
    );
  }

  Widget _buildItemsList() {
    return SizedBox(
      height: 220.h,
      child: ListView.builder(
        padding: EdgeInsets.only(left: 20.w),
        scrollDirection: Axis.horizontal,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          final foodItem = item.toFoodItem();

          return Padding(
            padding: EdgeInsets.only(right: 15.w),
            child: PopularItemCard(
              item: foodItem,
              cartItem: item,
              orderCount: item.orderCount,
              onTap: () => onItemTap(item),
            ),
          );
        },
      ),
    );
  }
}
