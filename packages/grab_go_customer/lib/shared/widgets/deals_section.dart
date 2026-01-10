import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:grab_go_customer/features/home/model/food_category.dart';
import 'package:grab_go_customer/shared/widgets/deal_card.dart';
import 'package:grab_go_customer/shared/widgets/horizontal_card_skeleton.dart';
import 'package:grab_go_customer/shared/widgets/section_header.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';

class DealsSection extends StatelessWidget {
  final List<FoodItem> dealItems;
  final List<dynamic>? originalItems;
  final VoidCallback onSeeAll;
  final Function(FoodItem) onItemTap;
  final bool isLoading;

  const DealsSection({
    super.key,
    required this.dealItems,
    this.originalItems,
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
          sectionIcon: Assets.icons.tag,
          accentColor: colors.accentOrange,
          sectionTotal: dealItems.length,
          onSeeAll: onSeeAll,
        ),
        SizedBox(height: 10.h),
        if (isLoading)
          HorizontalCardSkeleton(colors: colors, isDark: isDark, height: 220.h, itemCount: 5)
        else if (dealItems.isEmpty)
          _buildEmptyState(colors)
        else
          SizedBox(
            height: 220.h,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.only(left: 20.w),
              physics: const BouncingScrollPhysics(),
              itemCount: dealItems.length,
              itemBuilder: (context, index) {
                final item = dealItems[index];
                final discountPercent = item.discountPercentage.toInt();
                final originalItem = originalItems != null && index < originalItems!.length
                    ? originalItems![index]
                    : null;

                return Padding(
                  padding: EdgeInsets.only(right: 15.w),
                  child: DealCard(
                    item: item,
                    cartItem: originalItem,
                    discountPercent: discountPercent,
                    onTap: () => onItemTap(item),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildEmptyState(AppColorsExtension colors) {
    return Container(
      height: 230.h,
      padding: EdgeInsets.symmetric(horizontal: 40.w, vertical: 32.h),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SvgPicture.asset(
            Assets.icons.tag,
            package: "grab_go_shared",
            height: 48.h,
            width: 48.w,
            colorFilter: ColorFilter.mode(colors.textSecondary.withValues(alpha: 0.5), BlendMode.srcIn),
          ),
          SizedBox(height: 16.h),
          Text(
            'No deals available right now',
            style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600, color: colors.textPrimary),
          ),
          SizedBox(height: 8.h),
          Text(
            'Check back later for amazing offers!',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13.sp, color: colors.textSecondary),
          ),
        ],
      ),
    );
  }
}
