import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:grab_go_customer/features/home/model/food_category.dart';
import 'package:grab_go_customer/shared/widgets/deal_card.dart';
import 'package:grab_go_customer/shared/widgets/horizontal_card_skeleton.dart';
import 'package:grab_go_customer/shared/widgets/section_header.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';

class DealsSection extends StatelessWidget {
  final List<FoodItem> dealItems;
  final VoidCallback onSeeAll;
  final Function(FoodItem) onItemTap;
  final bool isLoading;

  const DealsSection({
    super.key,
    required this.dealItems,
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
          title: "Deals & Offers",
          icon: Assets.icons.tag,
          accentColor: colors.accentOrange,
          onSeeAll: onSeeAll,
        ),
        SizedBox(height: 16.h),
        if (isLoading)
          HorizontalCardSkeleton(colors: colors, isDark: isDark, height: 200.h, itemCount: 5)
        else if (dealItems.isEmpty)
          const SizedBox.shrink()
        else
          SizedBox(
            height: 200.h,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.only(left: 20.w),
              physics: const BouncingScrollPhysics(),
              itemCount: dealItems.length,
              itemBuilder: (context, index) {
                final item = dealItems[index];
                // Mock discount percentage (20-50%)
                final discountPercent = 20 + (index % 3) * 10;

                return Padding(
                  padding: EdgeInsets.only(right: 15.w),
                  child: DealCard(item: item, discountPercent: discountPercent, onTap: () => onItemTap(item)),
                );
              },
            ),
          ),
      ],
    );
  }
}
