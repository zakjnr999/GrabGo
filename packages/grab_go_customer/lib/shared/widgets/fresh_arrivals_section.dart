import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:grab_go_customer/features/groceries/model/grocery_item.dart';
import 'package:grab_go_customer/shared/widgets/popular_item_card.dart';
import 'package:grab_go_customer/shared/widgets/horizontal_card_skeleton.dart';
import 'package:grab_go_customer/shared/widgets/section_header.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';

/// Fresh Arrivals Section
/// Displays newly added grocery items (< 7 days old) with a "NEW" badge
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
          icon: Assets.icons.sparkles,
          accentColor: const Color(0xFF4CAF50),
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
      height: 260.h,
      child: ListView.builder(
        padding: EdgeInsets.only(left: 20.w),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          final foodItem = item.toFoodItem();

          return Padding(
            padding: EdgeInsets.only(right: 15.w),
            child: Stack(
              children: [
                PopularItemCard(item: foodItem, orderCount: item.orderCount, onTap: () => onItemTap(item)),
                // NEW badge
                Positioned(top: 8, right: 8, child: _buildNewBadge(item)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildNewBadge(GroceryItem item) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF4CAF50), Color(0xFF66BB6A)]),
        borderRadius: BorderRadius.circular(KBorderSize.borderMedium),
        boxShadow: [BoxShadow(color: Colors.green.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Text(
        'NEW',
        style: TextStyle(color: Colors.white, fontSize: 12.sp, fontWeight: FontWeight.bold, letterSpacing: 0.5),
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
