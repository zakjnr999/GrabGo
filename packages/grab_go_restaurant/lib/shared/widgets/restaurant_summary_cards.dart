import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:grab_go_shared/shared/widgets/responsive.dart';
import 'package:grab_go_shared/shared/utils/colors.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'svg_icon.dart';

class RestaurantSummaryCards extends StatelessWidget {
  const RestaurantSummaryCards({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isMobile = Responsive.isMobile(context);
    final isTablet = Responsive.isTablet(context);

    return _buildCardsGrid(context, isDark, isMobile, isTablet);
  }

  Widget _buildCardsGrid(BuildContext context, bool isDark, bool isMobile, bool isTablet) {
    if (isMobile) {
      return Column(
        children: [
          _buildSummaryCard(
            context: context,
            title: 'Today\'s Orders',
            value: '24',
            change: '+12%',
            isPositive: true,
            icon: Assets.icons.cart,
            color: AppColors.accentOrange,
            isDark: isDark,
            isMobile: isMobile,
          ),
          SizedBox(height: isMobile ? 12 : 16),
          _buildSummaryCard(
            context: context,
            title: 'Revenue',
            value: 'GHC 1,240',
            change: '+8%',
            isPositive: true,
            icon: Assets.icons.creditCard,
            color: AppColors.blueAccent,
            isDark: isDark,
            isMobile: isMobile,
          ),
          SizedBox(height: isMobile ? 12 : 16),
          _buildSummaryCard(
            context: context,
            title: 'Menu Items',
            value: '45',
            change: '+3',
            isPositive: true,
            icon: Assets.icons.utensilsCrossed,
            color: AppColors.violetAccent,
            isDark: isDark,
            isMobile: isMobile,
          ),
          SizedBox(height: isMobile ? 12 : 16),
          _buildSummaryCard(
            context: context,
            title: 'Avg. Rating',
            value: '4.8',
            change: '+0.2',
            isPositive: true,
            icon: Assets.icons.star,
            color: AppColors.accentOrange,
            isDark: isDark,
            isMobile: isMobile,
          ),
        ],
      );
    } else if (isTablet) {
      return Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildSummaryCard(
                  context: context,
                  title: 'Today\'s Orders',
                  value: '24',
                  change: '+12%',
                  isPositive: true,
                  icon: Assets.icons.cart,
                  color: AppColors.accentOrange,
                  isDark: isDark,
                  isMobile: isMobile,
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: _buildSummaryCard(
                  context: context,
                  title: 'Revenue',
                  value: 'GHC 1,240',
                  change: '+8%',
                  isPositive: true,
                  icon: Assets.icons.creditCard,
                  color: AppColors.blueAccent,
                  isDark: isDark,
                  isMobile: isMobile,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildSummaryCard(
                  context: context,
                  title: 'Menu Items',
                  value: '45',
                  change: '+3',
                  isPositive: true,
                  icon: Assets.icons.utensilsCrossed,
                  color: AppColors.violetAccent,
                  isDark: isDark,
                  isMobile: isMobile,
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: _buildSummaryCard(
                  context: context,
                  title: 'Avg. Rating',
                  value: '4.8',
                  change: '+0.2',
                  isPositive: true,
                  icon: Assets.icons.star,
                  color: AppColors.accentOrange,
                  isDark: isDark,
                  isMobile: isMobile,
                ),
              ),
            ],
          ),
        ],
      );
    } else {
      return Row(
        children: [
          Expanded(
            child: _buildSummaryCard(
              context: context,
              title: 'Today\'s Orders',
              value: '24',
              change: '+12%',
              isPositive: true,
              icon: Assets.icons.cart,
              color: AppColors.accentOrange,
              isDark: isDark,
              isMobile: isMobile,
            ),
          ),
          SizedBox(width: Responsive.getCardSpacing(context)),
          Expanded(
            child: _buildSummaryCard(
              context: context,
              title: 'Revenue',
              value: 'GHC 1,240',
              change: '+8%',
              isPositive: true,
              icon: Assets.icons.creditCard,
              color: AppColors.blueAccent,
              isDark: isDark,
              isMobile: isMobile,
            ),
          ),
          SizedBox(width: Responsive.getCardSpacing(context)),
          Expanded(
            child: _buildSummaryCard(
              context: context,
              title: 'Menu Items',
              value: '45',
              change: '+3',
              isPositive: true,
              icon: Assets.icons.utensilsCrossed,
              color: AppColors.violetAccent,
              isDark: isDark,
              isMobile: isMobile,
            ),
          ),
          SizedBox(width: Responsive.getCardSpacing(context)),
          Expanded(
            child: _buildSummaryCard(
              context: context,
              title: 'Avg. Rating',
              value: '4.8',
              change: '+0.2',
              isPositive: true,
              icon: Assets.icons.star,
              color: AppColors.accentOrange,
              isDark: isDark,
              isMobile: isMobile,
            ),
          ),
        ],
      );
    }
  }

  Widget _buildSummaryCard({
    required BuildContext context,
    required String title,
    required String value,
    required String change,
    required bool isPositive,
    required String icon,
    required Color color,
    required bool isDark,
    required bool isMobile,
  }) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: EdgeInsets.all(isMobile ? 8 : 10),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                child: SvgIcon(
                  svgImage: icon,
                  width: Responsive.getIconSize(context),
                  height: Responsive.getIconSize(context),
                  color: color,
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isPositive
                      ? AppColors.accentGreen.withValues(alpha: 0.1)
                      : AppColors.errorRed.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  change,
                  style: GoogleFonts.lato(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isPositive ? AppColors.accentGreen : AppColors.errorRed,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: isMobile ? 12 : 16),
          Text(
            value,
            style: GoogleFonts.lato(
              fontSize: Responsive.getFontSize(context, isMobile ? 24 : 32),
              fontWeight: FontWeight.bold,
              color: isDark ? AppColors.white : AppColors.primary,
            ),
          ),
          SizedBox(height: 4),
          Text(
            title,
            style: GoogleFonts.lato(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.grey),
          ),
        ],
      ),
    );
  }
}
