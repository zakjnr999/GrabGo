import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:grab_go_restaurant/shared/widgets/orders_chart.dart';
import 'package:grab_go_restaurant/shared/widgets/revenue_chart.dart';
import '../../../shared/widgets/animated_tab_bar.dart';
import 'package:grab_go_shared/shared/widgets/responsive.dart';
import 'package:grab_go_restaurant/shared/app_colors.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  int selectedPeriodIndex = 1;
  final List<String> periods = ['Today', 'This Week', 'This Month', 'This Year'];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isMobile = Responsive.isMobile(context);
    final isTablet = Responsive.isTablet(context);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: Responsive.getScreenPadding(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.start, children: [_buildPeriodSelector(isDark, isMobile)]),
          SizedBox(height: isMobile ? 20 : 24),

          _buildKeyMetrics(isDark, isMobile, isTablet),
          SizedBox(height: Responsive.getCardSpacing(context)),

          _buildChartsSection(isDark, isMobile, isTablet),
          SizedBox(height: Responsive.getCardSpacing(context)),

          _buildPopularItems(isDark, isMobile),
        ],
      ),
    );
  }

  Widget _buildPeriodSelector(bool isDark, bool isMobile) {
    return AnimatedTabBar(
      tabs: periods,
      selectedIndex: selectedPeriodIndex,
      onTabChanged: (index) {
        setState(() {
          selectedPeriodIndex = index;
        });
      },
      height: isMobile ? 40 : 50,
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 12),
    );
  }

  Widget _buildKeyMetrics(bool isDark, bool isMobile, bool isTablet) {
    final metrics = [
      {
        'title': 'Total Orders',
        'value': '1,247',
        'change': '+15%',
        'isPositive': true,
        'color': AppColors.accentOrange,
      },
      {'title': 'Revenue', 'value': 'GHC 12,450', 'change': '+8%', 'isPositive': true, 'color': AppColors.blueAccent},
      {
        'title': 'Avg. Order Value',
        'value': 'GHC 24.50',
        'change': '+3%',
        'isPositive': true,
        'color': AppColors.violetAccent,
      },
      {
        'title': 'Customer Rating',
        'value': '4.8',
        'change': '+0.2',
        'isPositive': true,
        'color': AppColors.accentOrange,
      },
    ];

    if (isMobile) {
      return Column(
        children: metrics.asMap().entries.map((entry) {
          final index = entry.key;
          final metric = entry.value;
          return Column(
            children: [
              _buildMetricCard(metric, isDark, isMobile),
              if (index < metrics.length - 1) const SizedBox(height: 16),
            ],
          );
        }).toList(),
      );
    } else if (isTablet) {
      return Column(
        children: [
          Row(
            children: [
              Expanded(child: _buildMetricCard(metrics[0], isDark, isMobile)),
              const SizedBox(width: 16),
              Expanded(child: _buildMetricCard(metrics[1], isDark, isMobile)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildMetricCard(metrics[2], isDark, isMobile)),
              const SizedBox(width: 16),
              Expanded(child: _buildMetricCard(metrics[3], isDark, isMobile)),
            ],
          ),
        ],
      );
    } else {
      return Row(
        children: metrics.map((metric) {
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: metric == metrics.last ? 0 : 16),
              child: _buildMetricCard(metric, isDark, isMobile),
            ),
          );
        }).toList(),
      );
    }
  }

  Widget _buildMetricCard(Map<String, dynamic> metric, bool isDark, bool isMobile) {
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
                width: isMobile ? 28 : 32,
                height: isMobile ? 28 : 32,
                decoration: BoxDecoration(
                  color: (metric['color'] as Color).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Padding(
                  padding: EdgeInsets.all(isMobile ? 5 : 7),
                  child: Icon(Icons.trending_up, color: metric['color'], size: isMobile ? 20 : 24),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: metric['isPositive'] ? Colors.green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  metric['change'],
                  style: GoogleFonts.lato(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: metric['isPositive'] ? Colors.green : Colors.red,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: isMobile ? 12 : 16),
          Text(
            metric['value'],
            style: GoogleFonts.lato(
              fontSize: Responsive.getFontSize(context, isMobile ? 20 : 28),
              fontWeight: FontWeight.bold,
              color: isDark ? AppColors.white : AppColors.primary,
            ),
          ),
          SizedBox(height: 4),
          Text(
            metric['title'],
            style: GoogleFonts.lato(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildChartsSection(bool isDark, bool isMobile, bool isTablet) {
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
          const SizedBox(width: 16),
          const Expanded(child: OrdersChart()),
        ],
      );
    }
  }

  Widget _buildPopularItems(bool isDark, bool isMobile) {
    final popularItems = [
      {'name': 'Grilled Chicken', 'orders': 45, 'revenue': 'GHC 850'},
      {'name': 'Caesar Salad', 'orders': 38, 'revenue': 'GHC 475'},
      {'name': 'Chocolate Cake', 'orders': 32, 'revenue': 'GHC 288'},
      {'name': 'Fresh Juice', 'orders': 28, 'revenue': 'GHC 168'},
    ];

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
          Text(
            'Popular Items',
            style: GoogleFonts.lato(
              fontSize: Responsive.getFontSize(context, isMobile ? 18 : 20),
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.white : AppColors.primary,
            ),
          ),
          SizedBox(height: isMobile ? 16 : 20),
          ...popularItems.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            return Container(
              padding: EdgeInsets.symmetric(vertical: isMobile ? 12 : 16),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: isDark ? AppColors.white.withValues(alpha: 0.1) : AppColors.lightSurface,
                    width: index == popularItems.length - 1 ? 0 : 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.accentOrange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: GoogleFonts.lato(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.accentOrange,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: isMobile ? 12 : 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item['name'] as String,
                          style: GoogleFonts.lato(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppColors.white : AppColors.primary,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text('${item['orders']} orders', style: GoogleFonts.lato(fontSize: 12, color: AppColors.grey)),
                      ],
                    ),
                  ),
                  Text(
                    item['revenue'] as String,
                    style: GoogleFonts.lato(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.accentOrange),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
