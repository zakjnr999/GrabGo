// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:grab_go_shared/shared/widgets/responsive.dart';
import 'package:grab_go_shared/shared/utils/colors.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import '../models/restaurant_navigation_page.dart';
import 'svg_icon.dart';

class RestaurantSidebar extends StatelessWidget {
  final bool isExpanded;
  final VoidCallback onToggle;
  final RestaurantNavigationPage selectedPage;
  final Function(RestaurantNavigationPage) onPageSelected;
  final VoidCallback? onLogout;

  const RestaurantSidebar({
    super.key,
    required this.isExpanded,
    required this.onToggle,
    required this.selectedPage,
    required this.onPageSelected,
    this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isMobile = Responsive.isMobile(context);
    final sidebarWidth = Responsive.getSidebarWidth(context);

    // Hide sidebar on mobile
    if (isMobile) {
      return const SizedBox.shrink();
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: isExpanded ? sidebarWidth : 0,
      child: Container(
        color: isDark ? AppColors.darkSurface : AppColors.primary,
        child: Column(
          children: [
            SizedBox(height: Responsive.isTablet(context) ? 16 : 20),
            // Logo
            Container(
              width: Responsive.isTablet(context) ? 32 : 40,
              height: Responsive.isTablet(context) ? 32 : 40,
              decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(8)),
              child: Center(
                child: Text(
                  'G',
                  style: GoogleFonts.lato(
                    color: AppColors.primary,
                    fontSize: Responsive.isTablet(context) ? 16 : 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            SizedBox(height: Responsive.isTablet(context) ? 32 : 40),
            // Navigation Icons
            _buildNavItem(context, RestaurantNavigationPage.dashboard, Assets.icons.home),
            _buildNavItem(context, RestaurantNavigationPage.menu, Assets.icons.squareMenu),
            _buildNavItem(context, RestaurantNavigationPage.orders, Assets.icons.cart),
            _buildNavItem(context, RestaurantNavigationPage.analytics, Assets.icons.scale),
            _buildNavItem(context, RestaurantNavigationPage.settings, Assets.icons.slidersHorizontal),
            // Spacer to push logout to bottom
            const Spacer(),
            // Divider
            if (onLogout != null) ...[
              Container(
                height: 1,
                margin: EdgeInsets.symmetric(horizontal: Responsive.isTablet(context) ? 12 : 16, vertical: 8),
                color: isDark ? AppColors.white.withOpacity(0.1) : AppColors.white.withOpacity(0.2),
              ),
              // Logout Button
              _buildLogoutButton(context),
              SizedBox(height: Responsive.isTablet(context) ? 16 : 20),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(BuildContext context, RestaurantNavigationPage page, String icon) {
    final isSelected = selectedPage == page;
    final isTablet = Responsive.isTablet(context);
    final iconSize = Responsive.getIconSize(context);
    final horizontalMargin = isTablet ? 12.0 : 16.0;
    final padding = isTablet ? 8.0 : 12.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      margin: EdgeInsets.symmetric(vertical: 4, horizontal: horizontalMargin),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onPageSelected(page),
          borderRadius: BorderRadius.circular(8),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            padding: EdgeInsets.all(padding),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.accentOrange : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: AppColors.accentOrange.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: AnimatedScale(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              scale: isSelected ? 1.1 : 1.0,
              child: SvgIcon(svgImage: icon, width: iconSize, height: iconSize, color: AppColors.white),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogoutButton(BuildContext context) {
    final isTablet = Responsive.isTablet(context);
    final iconSize = Responsive.getIconSize(context);
    final horizontalMargin = isTablet ? 12.0 : 16.0;
    final padding = isTablet ? 8.0 : 12.0;

    return Container(
      margin: EdgeInsets.symmetric(vertical: 4, horizontal: horizontalMargin),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onLogout,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: EdgeInsets.all(padding),
            decoration: BoxDecoration(color: Colors.transparent, borderRadius: BorderRadius.circular(8)),
            child: SvgIcon(svgImage: Assets.icons.logOut, color: AppColors.white, height: iconSize, width: iconSize),
          ),
        ),
      ),
    );
  }
}
