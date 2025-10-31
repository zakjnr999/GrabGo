import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:grab_go_restaurant/shared/widgets/orders_chart.dart';
import 'package:grab_go_restaurant/shared/widgets/revenue_chart.dart';
import 'package:grab_go_shared/shared/utils/colors.dart';
import '../../../shared/models/restaurant_navigation_page.dart';
import 'package:grab_go_shared/shared/widgets/responsive.dart';
import '../../../shared/widgets/restaurant_sidebar.dart';
import '../../../shared/widgets/restaurant_header.dart';
import '../../../shared/widgets/mobile_navigation_drawer.dart';
import '../../../shared/widgets/restaurant_summary_cards.dart';
import '../../../shared/widgets/restaurant_order_list.dart';
import '../../menu/view/menu_screen.dart';
import '../../orders/view/orders_screen.dart';
import '../../analytics/view/analytics_screen.dart';
import '../../settings/view/settings_screen.dart';

class RestaurantDashboardComprehensive extends StatefulWidget {
  const RestaurantDashboardComprehensive({super.key});

  @override
  State<RestaurantDashboardComprehensive> createState() => _RestaurantDashboardComprehensiveState();
}

class _RestaurantDashboardComprehensiveState extends State<RestaurantDashboardComprehensive> {
  bool isSidebarExpanded = true;
  RestaurantNavigationPage currentPage = RestaurantNavigationPage.dashboard;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isMobile = Responsive.isMobile(context);

    if (isMobile) {
      return Scaffold(
        key: _scaffoldKey,
        backgroundColor: isDark ? AppColors.darkBackground : AppColors.secondaryBackground,
        drawer: _buildMobileDrawer(),
        body: Column(
          children: [
            // Header
            _buildHeader(true),
            // Main Content Area
            Expanded(child: _buildCurrentPage()),
          ],
        ),
      );
    } else {
      return Scaffold(
        backgroundColor: isDark ? AppColors.darkBackground : AppColors.secondaryBackground,
        body: _buildDesktopLayout(),
      );
    }
  }

  Widget _buildDesktopLayout() {
    return Row(
      children: [
        // Sidebar
        _buildSidebar(),
        // Main Content
        Expanded(
          child: Column(
            children: [
              // Header
              _buildHeader(false),
              // Main Content Area
              Expanded(child: _buildCurrentPage()),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSidebar() {
    return RestaurantSidebar(
      isExpanded: isSidebarExpanded,
      onToggle: () {
        setState(() {
          isSidebarExpanded = !isSidebarExpanded;
        });
      },
      selectedPage: currentPage,
      onPageSelected: (page) {
        setState(() {
          currentPage = page;
        });
      },
      onLogout: () => _logout(context),
    );
  }

  Widget _buildHeader(bool isMobile) {
    return RestaurantHeader(
      isSidebarExpanded: isSidebarExpanded,
      onToggleSidebar: () {
        if (isMobile) {
          _scaffoldKey.currentState?.openDrawer();
        } else {
          setState(() {
            isSidebarExpanded = !isSidebarExpanded;
          });
        }
      },
      currentPage: currentPage,
      isMobile: isMobile,
      onLogout: () => _logout(context),
    );
  }

  Widget _buildMobileDrawer() {
    return MobileNavigationDrawer(
      selectedPage: currentPage,
      onPageSelected: (page) {
        setState(() {
          currentPage = page;
        });
        Navigator.of(context).pop();
      },
      onClose: () {
        Navigator.of(context).pop();
      },
      onLogout: () => _logout(context),
    );
  }

  Widget _buildCurrentPage() {
    switch (currentPage) {
      case RestaurantNavigationPage.dashboard:
        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: Responsive.getScreenPadding(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Summary Cards
              const RestaurantSummaryCards(),
              SizedBox(height: Responsive.getCardSpacing(context)),
              // Charts Section
              _buildChartsSection(),
              SizedBox(height: Responsive.getCardSpacing(context)),
              // Order List
              const RestaurantOrderList(),
            ],
          ),
        );
      case RestaurantNavigationPage.menu:
        return const MenuScreen();
      case RestaurantNavigationPage.orders:
        return const OrdersScreen();
      case RestaurantNavigationPage.analytics:
        return const AnalyticsScreen();
      case RestaurantNavigationPage.settings:
        return const SettingsScreen();
    }
  }

  Widget _buildChartsSection() {
    final isMobile = Responsive.isMobile(context);
    final isTablet = Responsive.isTablet(context);

    if (isMobile || isTablet) {
      // Vertical list for mobile and tablet
      return Column(
        children: [
          const RevenueChart(),
          SizedBox(height: Responsive.getCardSpacing(context)),
          const OrdersChart(),
        ],
      );
    } else {
      // Grid layout for desktop and large desktop
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Revenue Chart
          const Expanded(child: RevenueChart()),
          SizedBox(width: Responsive.getCardSpacing(context)),
          // Orders Summary Chart
          const Expanded(child: OrdersChart()),
        ],
      );
    }
  }

  void _logout(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? AppColors.darkSurface : AppColors.white,
          title: Text(
            'Logout',
            style: GoogleFonts.lato(color: isDark ? AppColors.white : AppColors.primary, fontWeight: FontWeight.w600),
          ),
          content: Text('Are you sure you want to logout?', style: GoogleFonts.lato(color: AppColors.grey)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel', style: GoogleFonts.lato(color: AppColors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pushReplacementNamed('/');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentOrange,
                foregroundColor: AppColors.white,
              ),
              child: Text('Logout', style: GoogleFonts.lato(fontWeight: FontWeight.w600)),
            ),
          ],
        );
      },
    );
  }
}
