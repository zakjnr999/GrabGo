import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:grab_go_customer/features/home/model/food_category.dart';
import 'package:grab_go_customer/shared/widgets/popular_item_card.dart';
import 'package:grab_go_customer/shared/widgets/section_header.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';

class PopularSection extends StatelessWidget {
  final List<FoodItem> popularItems;
  final List<dynamic>? originalItems;
  final VoidCallback onSeeAll;
  final Function(FoodItem) onItemTap;
  final bool isLoading;
  final String? title;
  final String? icon;

  const PopularSection({
    super.key,
    required this.popularItems,
    this.originalItems,
    required this.onSeeAll,
    required this.onItemTap,
    this.isLoading = false,
    this.title,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (popularItems.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        SectionHeader(
          title: title ?? "Popular Right Now",
          sectionTotal: popularItems.length,
          accentColor: AppColors.accentOrange,
          onSeeAll: onSeeAll,
        ),
        SizedBox(height: 10.h),
        SizedBox(
            height: 220.h,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.only(left: 20.w),
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: popularItems.length,
              itemBuilder: (context, index) {
                final item = popularItems[index];
                final orderCount = item.orderCount;
                final originalItem = originalItems != null && index < originalItems!.length
                    ? originalItems![index]
                    : null;

                return Padding(
                  padding: EdgeInsets.only(right: 15.w),
                  child: PopularItemCard(
                    item: item,
                    cartItem: originalItem,
                    orderCount: orderCount,
                    deliveryTime: item.estimatedDeliveryTime,
                    onTap: () => onItemTap(item),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}
