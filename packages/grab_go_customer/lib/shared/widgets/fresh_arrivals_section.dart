import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:grab_go_customer/features/groceries/model/grocery_item.dart';
import 'package:grab_go_customer/shared/widgets/grocery_item_card.dart';
import 'package:grab_go_customer/shared/widgets/horizontal_card_skeleton.dart';
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(context, colors),
        SizedBox(height: KSpacing.md.h),
        if (isLoading)
          HorizontalCardSkeleton(colors: colors, isDark: isDark, height: 240.h)
        else if (items.isEmpty)
          _buildEmptyState(colors)
        else
          _buildItemsList(),
      ],
    );
  }

  Widget _buildHeader(BuildContext context, AppColorsExtension colors) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8.r),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF4CAF50), Color(0xFF66BB6A)]),
                  borderRadius: BorderRadius.circular(KBorderSize.border),
                ),
                child: Icon(Icons.fiber_new, size: 20.sp, color: Colors.white),
              ),
              SizedBox(width: 10.w),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Fresh Arrivals',
                    style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w700, color: colors.textPrimary),
                  ),
                  Text(
                    'New this week',
                    style: TextStyle(fontSize: 12.sp, color: colors.textTertiary),
                  ),
                ],
              ),
            ],
          ),
          if (items.isNotEmpty)
            TextButton(
              onPressed: onSeeAll,
              child: Text(
                'See All',
                style: TextStyle(color: colors.accentOrange, fontSize: 14.sp, fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildItemsList() {
    return SizedBox(
      height: 240.h,
      child: ListView.builder(
        padding: EdgeInsets.symmetric(horizontal: 20.w),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          return Padding(
            padding: EdgeInsets.only(right: 16.w),
            child: Stack(
              children: [
                SizedBox(
                  width: 160.w,
                  child: GroceryItemCard(item: item, onTap: () => onItemTap(item)),
                ),
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
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF4CAF50), Color(0xFF66BB6A)]),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.green.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.fiber_new, size: 12.sp, color: Colors.white),
          SizedBox(width: 4.w),
          Text(
            'NEW',
            style: TextStyle(color: Colors.white, fontSize: 10.sp, fontWeight: FontWeight.bold, letterSpacing: 0.5),
          ),
        ],
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
