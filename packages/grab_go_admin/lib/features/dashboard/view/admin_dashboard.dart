import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../shared/app_colors.dart';
import '../../../shared/models/navigation_page.dart';
import '../../../shared/utils/responsive.dart';
import '../../../shared/widgets/sidebar.dart';
import '../../../shared/widgets/header.dart';
import '../../../shared/widgets/mobile_navigation_drawer.dart';
import '../../../shared/widgets/summary_cards.dart';
import '../../../shared/widgets/revenue_chart.dart';
import '../../../shared/widgets/orders_chart.dart';
import '../../../shared/widgets/order_list.dart';
import '../../restaurants/view/restaurants_screen.dart';
import '../../payments/view/payments_screen.dart';
import '../../orders/view/orders_screen.dart';
import '../../settings/view/settings_screen.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  bool isSidebarExpanded = true;
  bool isDarkMode = false;
  NavigationPage currentPage = NavigationPage.dashboard;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isMobile = Responsive.isMobile(context);

    if (isMobile) {
      return Scaffold(
        key: _scaffoldKey,
        backgroundColor: isDark ? AppColors.darkBackground : AppColors.secondaryBackground,
        drawer: MobileNavigationDrawer(
          selectedPage: currentPage,
          onPageSelected: (page) {
            setState(() {
              currentPage = page;
            });
          },
          onClose: () {
            Navigator.of(context).pop();
          },
          onLogout: () => _logout(context),
        ),
        body: Column(
          children: [
            // Header
            Header(
              isSidebarExpanded: isSidebarExpanded,
              onToggleSidebar: () {
                _scaffoldKey.currentState?.openDrawer();
              },
              currentPage: currentPage,
              isMobile: true,
            ),
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
        Sidebar(
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
        ),
        // Main Content
        Expanded(
          child: Column(
            children: [
              // Header
              Header(
                isSidebarExpanded: isSidebarExpanded,
                onToggleSidebar: () {
                  setState(() {
                    isSidebarExpanded = !isSidebarExpanded;
                  });
                },
                currentPage: currentPage,
                isMobile: false,
              ),
              // Main Content Area
              Expanded(child: _buildCurrentPage()),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCurrentPage() {
    switch (currentPage) {
      case NavigationPage.dashboard:
        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: Responsive.getScreenPadding(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Summary Cards
              const SummaryCards(),
              SizedBox(height: Responsive.getCardSpacing(context)),
              // Charts Section
              _buildChartsSection(),
              SizedBox(height: Responsive.getCardSpacing(context)),
              // Order List
              const OrderList(),
            ],
          ),
        );
      case NavigationPage.restaurants:
        return const RestaurantsScreen();
      case NavigationPage.payments:
        return const PaymentsScreen();
      case NavigationPage.orders:
        return const OrdersScreen();
      case NavigationPage.settings:
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
