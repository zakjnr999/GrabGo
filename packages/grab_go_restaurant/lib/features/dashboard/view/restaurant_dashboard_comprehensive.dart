import 'package:flutter/material.dart';
import 'package:grab_go_restaurant/shared/widgets/orders_chart.dart';
import 'package:grab_go_restaurant/shared/widgets/revenue_chart.dart';
import 'package:grab_go_restaurant/shared/app_colors.dart';
import 'package:grab_go_shared/shared/widgets/app_dialog_panels.dart';
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
            _buildHeader(true),
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
        _buildSidebar(),
        Expanded(
          child: Column(
            children: [
              _buildHeader(false),
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
      onLogout: () => _logout(),
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
      onLogout: () => _logout(),
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
      onLogout: () => _logout(),
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
              const RestaurantSummaryCards(),
              SizedBox(height: Responsive.getCardSpacing(context)),
              _buildChartsSection(),
              SizedBox(height: Responsive.getCardSpacing(context)),
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
