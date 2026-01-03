import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:grab_go_customer/features/groceries/model/grocery_item.dart';
import 'package:grab_go_customer/features/groceries/model/grocery_store.dart';
import 'package:grab_go_customer/features/groceries/model/store_special.dart';
import 'package:grab_go_customer/shared/widgets/popular_item_card.dart';
import 'package:grab_go_customer/shared/widgets/section_header.dart';
import 'package:grab_go_customer/shared/widgets/store_header.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/shared/utils/app_colors_extension.dart';
import 'package:shimmer/shimmer.dart';

class StoreSpecialsSection extends StatelessWidget {
  final List<StoreSpecial> storeSpecials;
  final bool isLoading;
  final VoidCallback onSeeAll;
  final Function(GroceryItem) onItemTap;
  final Function(GroceryStore) onStoreTap;

  const StoreSpecialsSection({
    super.key,
    required this.storeSpecials,
    required this.isLoading,
    required this.onSeeAll,
    required this.onItemTap,
    required this.onStoreTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColorsExtension>()!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        SectionHeader(title: 'Store Specials', icon: Assets.icons.tag, accentColor: colors.error, onSeeAll: onSeeAll),
        SizedBox(height: 16.h),

        // Loading State
        if (isLoading) _buildLoadingSkeleton(colors),

        // Content
        if (!isLoading && storeSpecials.isEmpty) _buildEmptyState(colors),
        if (!isLoading && storeSpecials.isNotEmpty) _buildStoresList(),
      ],
    );
  }

  Widget _buildLoadingSkeleton(AppColorsExtension colors) {
    final isDark = colors.backgroundPrimary.computeLuminance() < 0.5;

    return Column(
      children: List.generate(2, (index) {
        return Column(
          children: [
            // Store header skeleton
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
              child: Row(
                children: [
                  Shimmer.fromColors(
                    baseColor: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                    highlightColor: isDark ? Colors.grey.shade700 : Colors.grey.shade100,
                    child: Container(
                      width: 40.w,
                      height: 40.h,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDark ? Colors.grey.shade700 : Colors.grey.shade200,
                      ),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Shimmer.fromColors(
                          baseColor: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                          highlightColor: isDark ? Colors.grey.shade700 : Colors.grey.shade100,
                          child: Container(
                            width: 120.w,
                            height: 16.h,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(4.r),
                              color: isDark ? Colors.grey.shade700 : Colors.grey.shade200,
                            ),
                          ),
                        ),
                        SizedBox(height: 4.h),
                        Shimmer.fromColors(
                          baseColor: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                          highlightColor: isDark ? Colors.grey.shade700 : Colors.grey.shade100,
                          child: Container(
                            width: 60.w,
                            height: 12.h,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(4.r),
                              color: isDark ? Colors.grey.shade700 : Colors.grey.shade200,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Items skeleton
            SizedBox(
              height: 260.h,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: 20.w),
                itemCount: 3,
                separatorBuilder: (context, index) => SizedBox(width: 12.w),
                itemBuilder: (context, index) {
                  return Shimmer.fromColors(
                    baseColor: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                    highlightColor: isDark ? Colors.grey.shade700 : Colors.grey.shade100,
                    child: Container(
                      width: 160.w,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12.r),
                        color: isDark ? Colors.grey.shade700 : Colors.grey.shade200,
                      ),
                    ),
                  );
                },
              ),
            ),
            SizedBox(height: 16.h),
          ],
        );
      }),
    );
  }

  Widget _buildEmptyState(AppColorsExtension colors) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 40.h),
      child: Column(
        children: [
          SvgPicture.asset(
            Assets.icons.tag,
            package: 'grab_go_shared',
            height: 48.h,
            width: 48.w,
            colorFilter: ColorFilter.mode(colors.textSecondary.withValues(alpha: 0.3), BlendMode.srcIn),
          ),
          SizedBox(height: 16.h),
          Text(
            'No special deals available',
            style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600, color: colors.textPrimary),
          ),
          SizedBox(height: 8.h),
          Text(
            'Check back soon for great offers!',
            style: TextStyle(fontSize: 14.sp, color: colors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildStoresList() {
    return Column(
      children: storeSpecials.map((storeSpecial) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Store Header
            StoreHeader(store: storeSpecial.store, onTap: () => onStoreTap(storeSpecial.store)),
            SizedBox(height: 8.h),

            // Horizontal Items List
            SizedBox(
              height: 260.h,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: 20.w),
                itemCount: storeSpecial.items.length,
                separatorBuilder: (context, index) => SizedBox(width: 12.w),
                itemBuilder: (context, index) {
                  final item = storeSpecial.items[index];
                  return SizedBox(
                    width: 160.w,
                    child: PopularItemCard(
                      item: item.toFoodItem(), cartItem: item,
                      orderCount: item.orderCount,
                      onTap: () => onItemTap(item),
                    ),
                  );
                },
              ),
            ),
            SizedBox(height: 16.h),
          ],
        );
      }).toList(),
    );
  }
}
