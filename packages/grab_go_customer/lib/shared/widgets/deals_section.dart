import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:grab_go_customer/features/home/model/food_category.dart';
import 'package:grab_go_customer/shared/widgets/deal_card.dart';
import 'package:grab_go_customer/shared/widgets/section_header.dart';
import 'package:grab_go_customer/shared/widgets/trailing_see_all_card.dart';
import 'package:grab_go_shared/grub_go_shared.dart';

class DealsSection extends StatelessWidget {
  final List<FoodItem> dealItems;
  final List<dynamic>? originalItems;
  final VoidCallback onSeeAll;
  final Function(FoodItem) onItemTap;
  final bool isLoading;
  final String? title;
  final String? icon;
  final bool useVerticalZigzagTag;
  final Color? accentColor;
  final bool showEndSeeAllCard;

  const DealsSection({
    super.key,
    required this.dealItems,
    this.originalItems,
    required this.onSeeAll,
    required this.onItemTap,
    this.isLoading = false,
    this.title,
    this.icon,
    this.useVerticalZigzagTag = false,
    this.accentColor,
    this.showEndSeeAllCard = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final size = MediaQuery.sizeOf(context);
    final cardWidth = (size.width * 0.78).clamp(230.0, 320.0);
    final imageHeight = (cardWidth * 0.45).clamp(90.0, 125.0);
    final cardHeight = (imageHeight + 110.h).clamp(208.0, 250.0);
    final showTrailingSeeAllCard =
        showEndSeeAllCard && !isLoading && dealItems.isNotEmpty;
    final itemCount = dealItems.length + (showTrailingSeeAllCard ? 1 : 0);

    if (dealItems.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        SectionHeader(
          title: title ?? "Deals & Offers",
          accentColor: accentColor ?? colors.accentOrange,
          sectionTotal: dealItems.length,
          onSeeAll: onSeeAll,
        ),
        SizedBox(height: 10.h),
        SizedBox(
          height: cardHeight,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.only(left: 20.w),
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: itemCount,
            itemBuilder: (context, index) {
              if (showTrailingSeeAllCard && index == dealItems.length) {
                return Padding(
                  padding: EdgeInsets.only(right: 20.w),
                  child: TrailingSeeAllCard(
                    width: 136.w,
                    height: cardHeight - 8.h,
                    accentColor: accentColor ?? colors.accentOrange,
                    subtitle: 'View more offers',
                    onTap: onSeeAll,
                  ),
                );
              }

              final item = dealItems[index];
              final discountPercent = item.discountPercentage.toInt();
              final originalItem =
                  originalItems != null && index < originalItems!.length
                  ? originalItems![index]
                  : null;

              return Padding(
                padding: EdgeInsets.only(right: 15.w),
                child: DealCard(
                  item: item,
                  cartItem: originalItem,
                  deliveryTime: item.estimatedDeliveryTime,
                  discountPercent: discountPercent,
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
