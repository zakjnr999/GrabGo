import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:grab_go_customer/features/home/model/food_category.dart';
import 'package:grab_go_customer/shared/widgets/horizontal_card_skeleton.dart';
import 'package:grab_go_customer/shared/widgets/popular_item_card.dart';
import 'package:grab_go_customer/shared/widgets/section_header.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';

class PopularSection extends StatelessWidget {
  final List<FoodItem> popularItems;
  final VoidCallback onSeeAll;
  final Function(FoodItem) onItemTap;
  final bool isLoading;

  const PopularSection({
    super.key,
    required this.popularItems,
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
          title: "Popular Right Now",
          icon: Assets.icons.flame,
          accentColor: AppColors.errorRed,
          onSeeAll: onSeeAll,
        ),
        SizedBox(height: 16.h),
        if (isLoading)
          HorizontalCardSkeleton(colors: colors, isDark: isDark, height: 260.h, itemCount: 6)
        else if (popularItems.isEmpty)
          const SizedBox.shrink()
        else
          SizedBox(
            height: 260.h,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.only(left: 20.w),
              physics: const BouncingScrollPhysics(),
              itemCount: popularItems.length,
              itemBuilder: (context, index) {
                final item = popularItems[index];
                // Mock order count (50-200)
                final orderCount = 50 + (index * 25);

                return Padding(
                  padding: EdgeInsets.only(right: 15.w),
                  child: PopularItemCard(item: item, orderCount: orderCount, onTap: () => onItemTap(item)),
                );
              },
            ),
          ),
      ],
    );
  }
}
