// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:grab_go_shared/shared/widgets/responsive.dart';
import 'package:provider/provider.dart';
import 'package:grab_go_shared/shared/utils/colors.dart';
import '../providers/theme_provider.dart';
import '../models/restaurant_navigation_page.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'svg_icon.dart';

class RestaurantHeader extends StatefulWidget {
  final bool isSidebarExpanded;
  final VoidCallback onToggleSidebar;
  final RestaurantNavigationPage currentPage;
  final bool isMobile;
  final VoidCallback? onLogout;

  const RestaurantHeader({
    super.key,
    required this.isSidebarExpanded,
    required this.onToggleSidebar,
    required this.currentPage,
    this.isMobile = false,
    this.onLogout,
  });

  @override
  State<RestaurantHeader> createState() => _RestaurantHeaderState();
}

class _RestaurantHeaderState extends State<RestaurantHeader> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(duration: const Duration(milliseconds: 600), vsync: this);
    _rotationAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconSize = Responsive.getIconSize(context);
    final headerHeight = Responsive.getHeaderHeight(context);
    final screenPadding = Responsive.getScreenPadding(context);

    return Container(
      height: headerHeight,
      padding: EdgeInsets.symmetric(horizontal: screenPadding.horizontal / 2),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.white,
        border: Border(
          bottom: BorderSide(color: isDark ? AppColors.white.withOpacity(0.1) : AppColors.lightSurface, width: 1),
        ),
      ),
      child: Row(
        children: [
          // Hamburger Menu - always show on mobile, show on desktop when sidebar is collapsed
          if (widget.isMobile || !widget.isSidebarExpanded)
            IconButton(
              onPressed: widget.onToggleSidebar,
              icon: SvgIcon(
                svgImage: Assets.icons.menu,
                width: iconSize,
                height: iconSize,
                color: isDark ? AppColors.white : AppColors.primary,
              ),
            ),
          SizedBox(width: widget.isMobile ? 8 : 16),
          // Page Title
          Expanded(
            child: Text(
              widget.currentPage.title,
              style: GoogleFonts.lato(
                fontSize: Responsive.getFontSize(context, widget.isMobile ? 18 : 24),
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.white : AppColors.primary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Right side icons and profile
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Theme Toggle
              Consumer<ThemeProvider>(
                builder: (context, themeProvider, child) {
                  return IconButton(
                    onPressed: () {
                      _animationController.forward().then((_) {
                        _animationController.reset();
                      });
                      themeProvider.toggleTheme();
                    },
                    icon: AnimatedBuilder(
                      animation: _rotationAnimation,
                      builder: (context, child) {
                        return Transform.rotate(
                          angle: _rotationAnimation.value * 2 * 3.14159, // Full rotation
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            transitionBuilder: (child, animation) {
                              return ScaleTransition(scale: animation, child: child);
                            },
                            child: SvgIcon(
                              svgImage: _getThemeIcon(themeProvider.themeMode),
                              width: iconSize,
                              height: iconSize,
                              color: isDark ? AppColors.white : AppColors.primary,
                              key: ValueKey(themeProvider.themeMode),
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
              // Notifications
              Badge(
                backgroundColor: AppColors.blueAccent,
                label: Text(
                  '4',
                  style: GoogleFonts.lato(fontSize: 8, fontWeight: FontWeight.w600, color: AppColors.white),
                ),
                child: IconButton(
                  onPressed: () {},
                  icon: SvgIcon(
                    svgImage: Assets.icons.bell,
                    width: iconSize,
                    height: iconSize,
                    color: isDark ? AppColors.white : AppColors.primary,
                  ),
                ),
              ),
              SizedBox(width: widget.isMobile ? 8 : 16),
              // Profile Section
              if (!widget.isMobile) ...[
                Text(
                  'GrabGo Restaurant',
                  style: GoogleFonts.lato(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: isDark ? AppColors.white : AppColors.primary,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Container(
                width: widget.isMobile ? 28 : 32,
                height: widget.isMobile ? 28 : 32,
                decoration: BoxDecoration(
                  color: AppColors.accentOrange,
                  borderRadius: BorderRadius.circular(widget.isMobile ? 14 : 16),
                ),
                child: Padding(
                  padding: EdgeInsets.all(widget.isMobile ? 3 : 4),
                  child: Image.asset(
                    Assets.icons.appIcon.path,
                    width: widget.isMobile ? 16 : 20,
                    height: widget.isMobile ? 16 : 20,
                    color: AppColors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getThemeIcon(ThemeMode themeMode) {
    switch (themeMode) {
      case ThemeMode.light:
        return Assets.icons.sunLight;
      case ThemeMode.dark:
        return Assets.icons.halfMoon;
      case ThemeMode.system:
        return Assets.icons.sunLight; // Fallback, should not occur
    }
  }
}
