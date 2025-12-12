import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:grab_go_customer/features/home/model/food_category.dart';
import 'package:grab_go_customer/shared/widgets/horizontal_card_skeleton.dart';
import 'package:grab_go_customer/shared/widgets/section_header.dart';
import 'package:grab_go_customer/shared/widgets/top_rated_card.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';

class TopRatedSection extends StatelessWidget {
  final List<FoodItem> topRatedItems;
  final VoidCallback onSeeAll;
  final Function(FoodItem) onItemTap;
  final bool isLoading;

  const TopRatedSection({
    super.key,
    required this.topRatedItems,
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
          title: "Top Rated This Week",
          icon: Assets.icons.star,
          accentColor: Colors.amber,
          onSeeAll: onSeeAll,
        ),
        SizedBox(height: 16.h),
        if (isLoading)
          HorizontalCardSkeleton(colors: colors, isDark: isDark, height: 240.h, itemCount: 6)
        else if (topRatedItems.isEmpty)
          const SizedBox.shrink()
        else
          SizedBox(
            height: 240.h,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.only(left: 20.w),
              physics: const BouncingScrollPhysics(),
              itemCount: topRatedItems.length,
              itemBuilder: (context, index) {
                final item = topRatedItems[index];

                return Padding(
                  padding: EdgeInsets.only(right: 15.w),
                  child: TopRatedCard(item: item, onTap: () => onItemTap(item)),
                );
              },
            ),
          ),
      ],
    );
  }
}
