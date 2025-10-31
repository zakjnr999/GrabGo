import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:grab_go_shared/shared/utils/constants.dart';
import '../app_colors.dart';
import '../models/summary_card.dart';
import '../utils/responsive.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'svg_icon.dart';

class SummaryCards extends StatelessWidget {
  const SummaryCards({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final cards = [
      SummaryCard(
        title: 'Total Menus',
        value: '120',
        percentage: '45%',
        progress: 0.45,
        icon: Assets.icons.utensilsCrossed,
        color: 'primary',
      ),
      SummaryCard(
        title: 'Total Orders Today',
        value: '180',
        percentage: '62%',
        progress: 0.62,
        icon: Assets.icons.cart,
        color: 'blueAccent',
      ),
      SummaryCard(
        title: 'Total Client Today',
        value: '240',
        percentage: '80%',
        progress: 0.80,
        icon: Assets.icons.alarm,
        color: 'grey',
      ),
      SummaryCard(
        title: 'Revenue Day Ratio',
        value: '140',
        percentage: '85%',
        progress: 0.85,
        icon: Assets.icons.scale,
        color: 'accentOrange',
      ),
    ];

    final isMobile = Responsive.isMobile(context);
    final isTablet = Responsive.isTablet(context);

    if (isMobile) {
      return Column(
        children: cards.map((card) {
          return Padding(padding: const EdgeInsets.only(bottom: 16), child: _buildSummaryCard(context, card, isDark));
        }).toList(),
      );
    } else if (isTablet) {
      return Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 8, bottom: 16),
                  child: _buildSummaryCard(context, cards[0], isDark),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 8, bottom: 16),
                  child: _buildSummaryCard(context, cards[1], isDark),
                ),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _buildSummaryCard(context, cards[2], isDark),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: _buildSummaryCard(context, cards[3], isDark),
                ),
              ),
            ],
          ),
        ],
      );
    } else {
      return Row(
        children: cards.map((card) {
          return Expanded(
            child: Padding(padding: const EdgeInsets.only(right: 16), child: _buildSummaryCard(context, card, isDark)),
          );
        }).toList(),
      );
    }
  }

  Widget _buildSummaryCard(BuildContext context, SummaryCard card, bool isDark) {
    final iconColor = _getColor(card.color);
    final isMobile = Responsive.isMobile(context);
    final padding = isMobile ? 16.0 : 20.0;
    final iconSize = isMobile ? 28.0 : 32.0;
    final iconPadding = isMobile ? 5.0 : 7.0;

    return Container(
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.white,
        borderRadius: BorderRadius.circular(8),
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
              Expanded(
                child: Text(
                  card.title,
                  style: GoogleFonts.lato(
                    fontSize: Responsive.getFontSize(context, 14),
                    fontWeight: FontWeight.w500,
                    color: AppColors.grey,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                width: iconSize,
                height: iconSize,
                decoration: BoxDecoration(color: iconColor, borderRadius: BorderRadius.circular(4)),
                child: Padding(
                  padding: EdgeInsets.all(iconPadding),
                  child: SvgIcon(svgImage: card.icon, color: AppColors.white),
                ),
              ),
            ],
          ),
          SizedBox(height: isMobile ? 12 : 16),
          Text(
            card.value,
            style: GoogleFonts.lato(
              fontSize: Responsive.getFontSize(context, isMobile ? 24 : 32),
              fontWeight: FontWeight.bold,
              color: isDark ? AppColors.white : AppColors.primary,
            ),
          ),
          SizedBox(height: isMobile ? 12 : 16),
          Row(
            children: [
              Expanded(
                child: LinearProgressIndicator(
                  value: card.progress,
                  backgroundColor: isDark ? AppColors.mutedBrown : AppColors.lightSurface,
                  valueColor: AlwaysStoppedAnimation<Color>(iconColor),
                  minHeight: isMobile ? 4 : 6,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              SizedBox(width: isMobile ? 6 : 8),
              Text(
                card.percentage,
                style: GoogleFonts.lato(
                  fontSize: Responsive.getFontSize(context, 12),
                  fontWeight: FontWeight.w500,
                  color: AppColors.grey,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getColor(String colorName) {
    switch (colorName) {
      case 'primary':
        return AppColors.primary;
      case 'blueAccent':
        return AppColors.blueAccent;
      case 'grey':
        return AppColors.grey;
      case 'accentOrange':
        return AppColors.accentOrange;
      default:
        return AppColors.primary;
    }
  }
}
