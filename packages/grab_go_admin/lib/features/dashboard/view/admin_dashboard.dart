import 'package:flutter/material.dart';
import 'package:grab_go_shared/shared/widgets/app_dialog_panels.dart';
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
          onLogout: () => _logout(),
        ),
        body: Column(
          children: [
            Header(
              isSidebarExpanded: isSidebarExpanded,
              onToggleSidebar: () {
                _scaffoldKey.currentState?.openDrawer();
              },
              currentPage: currentPage,
              isMobile: true,
            ),
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
          onLogout: () => _logout(),
        ),
        Expanded(
          child: Column(
            children: [
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
              const SummaryCards(),
              SizedBox(height: Responsive.getCardSpacing(context)),
              _buildChartsSection(),
              SizedBox(height: Responsive.getCardSpacing(context)),
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
      return Column(
        children: [
          const RevenueChart(),
          SizedBox(height: Responsive.getCardSpacing(context)),
          const OrdersChart(),
        ],
      );
    } else {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Expanded(child: RevenueChart()),
          SizedBox(width: 16),
          const Expanded(child: OrdersChart()),
        ],
      );
    }
  }

  Future<void> _logout() async {
    final logout = await AppDialogPanels.show(
      context: context,
      title: 'Logout',
      message: 'Are you sure you want to logout?',
      type: AppDialogType.logout,
      primaryButtonText: 'Logout',
      secondaryButtonText: 'Cancel',
      primaryButtonColor: AppColors.accentOrange,
      onPrimaryPressed: () => Navigator.of(context).pop(true),
      onSecondaryPressed: () => Navigator.of(context).pop(false),
    );
    if (logout == true && mounted) {
      Navigator.of(context).pushReplacementNamed('/');
    }
  }
}
