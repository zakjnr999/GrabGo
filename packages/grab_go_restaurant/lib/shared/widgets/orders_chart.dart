// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:grab_go_shared/shared/widgets/responsive.dart';
import 'package:grab_go_shared/shared/utils/colors.dart';

class OrdersChart extends StatefulWidget {
  const OrdersChart({super.key});

  @override
  State<OrdersChart> createState() => _OrdersChartState();
}

class _OrdersChartState extends State<OrdersChart> {
  String selectedTimeframe = 'Weekly';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isMobile = Responsive.isMobile(context);
    final isTablet = Responsive.isTablet(context);

    return Container(
      padding: EdgeInsets.all(
        isMobile
            ? 16
            : isTablet
            ? 18
            : 20,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(isDark ? 0.3 : 0.05), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Orders Summary',
                style: GoogleFonts.lato(
                  fontSize: Responsive.getFontSize(context, isMobile ? 16 : 18),
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.white : AppColors.primary,
                ),
              ),
              Row(
                children: ['Monthly', 'Weekly', 'Today'].map((timeframe) {
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        selectedTimeframe = timeframe;
                      });
                    },
                    child: Container(
                      margin: const EdgeInsets.only(left: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: selectedTimeframe == timeframe ? AppColors.accentOrange : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        timeframe,
                        style: GoogleFonts.lato(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: selectedTimeframe == timeframe ? AppColors.white : AppColors.grey,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 235,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: 25,
                barTouchData: BarTouchData(enabled: false),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          '${(value / 1000).toInt()}k',
                          style: GoogleFonts.lato(fontSize: 10, color: AppColors.grey),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        const days = ['Jun 24', 'Jun 25', 'Jun 26', 'Jun 27'];
                        return Text(days[value.toInt()], style: GoogleFonts.lato(fontSize: 10, color: AppColors.grey));
                      },
                    ),
                  ),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                barGroups: [
                  BarChartGroupData(
                    x: 0,
                    barRods: [
                      BarChartRodData(toY: 20, color: AppColors.grey, width: 8),
                      BarChartRodData(toY: 15, color: AppColors.blueAccent, width: 8),
                      BarChartRodData(toY: 8, color: AppColors.primary, width: 8),
                    ],
                  ),
                  BarChartGroupData(
                    x: 1,
                    barRods: [
                      BarChartRodData(toY: 18, color: AppColors.grey, width: 8),
                      BarChartRodData(toY: 12, color: AppColors.blueAccent, width: 8),
                      BarChartRodData(toY: 6, color: AppColors.primary, width: 8),
                    ],
                  ),
                  BarChartGroupData(
                    x: 2,
                    barRods: [
                      BarChartRodData(toY: 22, color: AppColors.grey, width: 8),
                      BarChartRodData(toY: 18, color: AppColors.blueAccent, width: 8),
                      BarChartRodData(toY: 10, color: AppColors.primary, width: 8),
                    ],
                  ),
                  BarChartGroupData(
                    x: 3,
                    barRods: [
                      BarChartRodData(toY: 16, color: AppColors.grey, width: 8),
                      BarChartRodData(toY: 14, color: AppColors.blueAccent, width: 8),
                      BarChartRodData(toY: 7, color: AppColors.primary, width: 8),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
