import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:grab_go_customer/features/groceries/model/grocery_item.dart';
import 'package:grab_go_customer/shared/widgets/popular_item_card.dart';
import 'package:grab_go_customer/shared/widgets/horizontal_card_skeleton.dart';
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        SectionHeader(
          title: 'Fresh Arrivals',
          sectionTotal: items.length,
          accentColor: colors.accentOrange,
          onSeeAll: onSeeAll,
        ),
        SizedBox(height: 16.h),
        if (isLoading)
          HorizontalCardSkeleton(colors: colors, isDark: isDark, height: 260.h)
        else if (items.isEmpty)
          _buildEmptyState(colors)
        else
          _buildItemsList(),
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

  Widget _buildEmptyState(AppColorsExtension colors) {
    return Container(
      height: 200.h,
      margin: EdgeInsets.symmetric(horizontal: 20.w),
      decoration: BoxDecoration(
        color: colors.backgroundSecondary,
        borderRadius: BorderRadius.circular(KBorderSize.borderMedium),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 48.sp, color: colors.textTertiary),
            SizedBox(height: 12.h),
            Text(
              'No new arrivals yet',
              style: TextStyle(color: colors.textSecondary, fontSize: 14.sp, fontWeight: FontWeight.w500),
            ),
            SizedBox(height: 4.h),
            Text(
              'Check back soon for new items!',
              style: TextStyle(color: colors.textTertiary, fontSize: 12.sp),
            ),
          ],
        ),
      ),
    );
  }
}
