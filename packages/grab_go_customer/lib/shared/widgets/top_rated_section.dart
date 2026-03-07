import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:grab_go_customer/features/home/model/food_category.dart';
import 'package:grab_go_customer/shared/widgets/section_header.dart';
import 'package:grab_go_customer/shared/widgets/trailing_see_all_card.dart';
import 'package:grab_go_customer/shared/widgets/top_rated_card.dart';
import 'package:grab_go_shared/grub_go_shared.dart';

class TopRatedSection extends StatelessWidget {
  final List<FoodItem> topRatedItems;
  final List<dynamic>? originalItems;
  final VoidCallback onSeeAll;
  final Function(FoodItem) onItemTap;
  final bool isLoading;
  final String? title;
  final String? icon;
  final bool useVerticalZigzagTag;
  final Color? accentColor;
  final bool showEndSeeAllCard;

  const TopRatedSection({
    super.key,
    required this.topRatedItems,
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
    if (topRatedItems.isEmpty) return const SizedBox.shrink();
    final size = MediaQuery.sizeOf(context);
    final cardWidth = size.width * 0.5;
    final cardHeight = (cardWidth * 1.32).clamp(190.0, 230.0);
    final showTrailingSeeAllCard =
        showEndSeeAllCard && !isLoading && topRatedItems.isNotEmpty;
    final itemCount = topRatedItems.length + (showTrailingSeeAllCard ? 1 : 0);

    return Column(
      children: [
        SectionHeader(
          title: title ?? "Top Rated Dishes",
          sectionTotal: topRatedItems.length,
          accentColor: accentColor ?? AppColors.accentOrange,
          onSeeAll: onSeeAll,
        ),
        SizedBox(height: 16.h),
        SizedBox(
          height: cardHeight,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.only(left: 20.w),
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: itemCount,
            itemBuilder: (context, index) {
              if (showTrailingSeeAllCard && index == topRatedItems.length) {
                return Padding(
                  padding: EdgeInsets.only(right: 20.w),
                  child: TrailingSeeAllCard(
                    width: 136.w,
                    height: cardHeight - 8.h,
                    accentColor: accentColor ?? AppColors.accentOrange,
                    subtitle: 'View more dishes',
                    onTap: onSeeAll,
                  ),
                );
              }

              final item = topRatedItems[index];
              final originalItem =
                  originalItems != null && index < originalItems!.length
                  ? originalItems![index]
                  : null;
              return Padding(
                padding: EdgeInsets.only(right: 15.w),
                child: TopRatedCard(
                  item: item,
                  cartItem: originalItem,
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
