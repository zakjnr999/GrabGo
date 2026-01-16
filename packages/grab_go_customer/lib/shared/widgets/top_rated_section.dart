import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:grab_go_customer/features/home/model/food_category.dart';
import 'package:grab_go_customer/shared/widgets/horizontal_card_skeleton.dart';
import 'package:grab_go_customer/shared/widgets/section_header.dart';
import 'package:grab_go_customer/shared/widgets/top_rated_card.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';

class TopRatedSection extends StatelessWidget {
  final List<FoodItem> topRatedItems;
  final List<dynamic>? originalItems;
  final VoidCallback onSeeAll;
  final Function(FoodItem) onItemTap;
  final bool isLoading;
  final String? title;
  final String? icon;

  const TopRatedSection({
    super.key,
    required this.topRatedItems,
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

    return Column(
      children: [
        SectionHeader(
          title: title ?? "Top Rated Dishes",
          sectionIcon: icon ?? Assets.icons.star,
          sectionTotal: topRatedItems.length,
          accentColor: AppColors.accentOrange,
          onSeeAll: onSeeAll,
        ),
        SizedBox(height: 16.h),
        if (isLoading && topRatedItems.isEmpty)
          HorizontalCardSkeleton(colors: colors, isDark: isDark, height: 220.h, itemCount: 6)
        else if (topRatedItems.isEmpty)
          _buildEmptyState(colors)
        else
          SizedBox(
            height: 220.h,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.only(left: 20.w),
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: topRatedItems.length,
              itemBuilder: (context, index) {
                final item = topRatedItems[index];
                final originalItem = originalItems != null && index < originalItems!.length
                    ? originalItems![index]
                    : null;
                return Padding(
                  padding: EdgeInsets.only(right: 15.w),
                  child: TopRatedCard(item: item, cartItem: originalItem, onTap: () => onItemTap(item)),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildEmptyState(AppColorsExtension colors) {
    return Container(
      height: 200.h,
      padding: EdgeInsets.symmetric(horizontal: 40.w, vertical: 32.h),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SvgPicture.asset(
            icon ?? Assets.icons.star,
            package: "grab_go_shared",
            height: 48.h,
            width: 48.w,
            colorFilter: ColorFilter.mode(colors.textSecondary.withValues(alpha: 0.5), BlendMode.srcIn),
          ),
          SizedBox(height: 16.h),
          Text(
            title != null ? 'No $title yet' : 'No top rated items yet',
            style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600, color: colors.textPrimary),
          ),
          SizedBox(height: 8.h),
          Text(
            'Check back soon for highly rated items!',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13.sp, color: colors.textSecondary),
          ),
        ],
      ),
    );
  }
}
