import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:grab_go_customer/features/home/model/food_category.dart';
import 'package:grab_go_customer/shared/widgets/popular_item_card.dart';
import 'package:grab_go_customer/shared/widgets/section_header.dart';
import 'package:grab_go_shared/grub_go_shared.dart';

class PopularSection extends StatelessWidget {
  final List<FoodItem> popularItems;
  final List<dynamic>? originalItems;
  final VoidCallback onSeeAll;
  final Function(FoodItem) onItemTap;
  final bool isLoading;
  final String? title;
  final String? icon;
  final bool useVerticalZigzagTag;
  final Color? accentColor;

  const PopularSection({
    super.key,
    required this.popularItems,
    this.originalItems,
    required this.onSeeAll,
    required this.onItemTap,
    this.isLoading = false,
    this.title,
    this.icon,
    this.useVerticalZigzagTag = false,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    if (popularItems.isEmpty) return const SizedBox.shrink();
    final size = MediaQuery.sizeOf(context);
    final cardWidth = size.width * 0.5;
    final imageHeight = (cardWidth * 0.60).clamp(96.0, 120.0);
    final cardHeight = (imageHeight + 114.0).clamp(210.0, 250.0);

    return Column(
      children: [
        SectionHeader(
          title: title ?? "Popular Right Now",
          sectionTotal: popularItems.length,
          accentColor: accentColor ?? AppColors.accentOrange,
          onSeeAll: onSeeAll,
        ),
        SizedBox(height: 10.h),
        SizedBox(
          height: cardHeight,
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
                  useVerticalZigzagTag: useVerticalZigzagTag,
                  accentColor: accentColor,
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
