import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../app_colors.dart';
import '../providers/theme_provider.dart';
import '../models/navigation_page.dart';
import '../utils/responsive.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'svg_icon.dart';

class Header extends StatefulWidget {
  final bool isSidebarExpanded;
  final VoidCallback onToggleSidebar;
  final NavigationPage currentPage;
  final bool isMobile;
  final VoidCallback? onLogout;

  const Header({
    super.key,
    required this.isSidebarExpanded,
    required this.onToggleSidebar,
    required this.currentPage,
    this.isMobile = false,
    this.onLogout,
  });

  @override
  State<Header> createState() => _HeaderState();
}

class _HeaderState extends State<Header> with SingleTickerProviderStateMixin {
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
    final headerHeight = Responsive.getHeaderHeight(context);
    final screenPadding = Responsive.getScreenPadding(context);
    final iconSize = Responsive.getIconSize(context);

    return Container(
      height: headerHeight,
      padding: EdgeInsets.symmetric(horizontal: screenPadding.horizontal / 4),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.white,
        border: Border(
          bottom: BorderSide(color: isDark ? AppColors.white.withValues(alpha: 0.1) : AppColors.lightSurface, width: 1),
        ),
      ),
      child: Row(
        children: [
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
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
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
                          angle: _rotationAnimation.value * 2 * 3.14159,
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
              VerticalDivider(color: isDark ? AppColors.darkBorder : AppColors.lightSurface, indent: 20, endIndent: 20),
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
              if (widget.onLogout != null)
                IconButton(
                  onPressed: widget.onLogout,
                  icon: Icon(Icons.logout, size: iconSize, color: isDark ? AppColors.white : AppColors.primary),
                ),
              SizedBox(width: widget.isMobile ? 8 : 16),
              if (!widget.isMobile) ...[
                Text(
                  'GrabGo Admin',
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
                  child: SvgPicture.asset(
                    Assets.icons.user,
                    package: 'grab_go_shared',
                    width: widget.isMobile ? 16 : 20,
                    height: widget.isMobile ? 16 : 20,
                    colorFilter: ColorFilter.mode(AppColors.white, BlendMode.srcIn),
                  ),
                ),
              ),
              if (!widget.isMobile) ...[
                const SizedBox(width: 8),
                SvgIcon(
                  svgImage: Assets.icons.navArrowDown,
                  width: 20,
                  height: 20,
                  color: isDark ? AppColors.white : AppColors.primary,
                ),
              ],
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
        return Assets.icons.sunLight;
    }
  }
}
