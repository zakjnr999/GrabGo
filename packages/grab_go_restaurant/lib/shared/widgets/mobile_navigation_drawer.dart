// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:grab_go_restaurant/shared/app_colors.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import '../models/restaurant_navigation_page.dart';
import 'svg_icon.dart';

class MobileNavigationDrawer extends StatelessWidget {
  final RestaurantNavigationPage selectedPage;
  final Function(RestaurantNavigationPage) onPageSelected;
  final VoidCallback onClose;
  final VoidCallback? onLogout;

  const MobileNavigationDrawer({
    super.key,
    required this.selectedPage,
    required this.onPageSelected,
    required this.onClose,
    this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Drawer(
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.primary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      child: Column(
        children: [
          // Header
          Container(
            height: 120,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: isDark ? AppColors.darkSurface : AppColors.primary),
            child: Row(
              children: [
                // Logo
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(12)),
                  child: Center(
                    child: Text(
                      'G',
                      style: GoogleFonts.lato(color: AppColors.primary, fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'GrabGo',
                        style: GoogleFonts.lato(color: AppColors.white, fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Admin Panel',
                        style: GoogleFonts.lato(color: AppColors.white.withOpacity(0.8), fontSize: 14),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onClose,
                  icon: Icon(Icons.close, color: AppColors.white, size: 24),
                ),
              ],
            ),
          ),
          // Navigation Items
          Expanded(
            child: ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: 20),
              children: [
                _buildNavItem(context, RestaurantNavigationPage.dashboard, Assets.icons.home, 'Dashboard'),
                _buildNavItem(context, RestaurantNavigationPage.menu, Assets.icons.chefHat, 'Menu'),
                _buildNavItem(context, RestaurantNavigationPage.orders, Assets.icons.cart, 'Orders'),
                _buildNavItem(context, RestaurantNavigationPage.analytics, Assets.icons.squareMenu, 'Analytics'),
                _buildNavItem(context, RestaurantNavigationPage.settings, Assets.icons.slidersHorizontal, 'Settings'),
              ],
            ),
          ),
          // Logout Section
          if (onLogout != null) ...[
            Container(
              height: 1,
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: isDark ? AppColors.white.withOpacity(0.1) : AppColors.white.withOpacity(0.2),
            ),
            _buildLogoutItem(context),
            const SizedBox(height: 20),
          ],
        ],
      ),
    );
  }

  Widget _buildNavItem(BuildContext context, RestaurantNavigationPage page, String icon, String title) {
    final isSelected = selectedPage == page;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            onPageSelected(page);
            onClose();
          },
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.accentOrange : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                SvgIcon(svgImage: icon, width: 24, height: 24, color: AppColors.white),
                const SizedBox(width: 16),
                Text(
                  title,
                  style: GoogleFonts.lato(
                    color: AppColors.white,
                    fontSize: 16,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
                const Spacer(),
                if (isSelected) Icon(Icons.arrow_forward_ios, color: AppColors.white, size: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogoutItem(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            onClose();
            onLogout?.call();
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(color: Colors.transparent, borderRadius: BorderRadius.circular(12)),
            child: Row(
              children: [
                SvgIcon(svgImage: Assets.icons.logOut, color: AppColors.white, height: 24, width: 24),
                const SizedBox(width: 16),
                Text(
                  'Logout',
                  style: GoogleFonts.lato(color: AppColors.white, fontSize: 16, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
