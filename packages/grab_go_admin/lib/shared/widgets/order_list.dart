import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../app_colors.dart';
import '../models/order.dart';
import '../utils/responsive.dart';

class OrderList extends StatefulWidget {
  const OrderList({super.key});

  @override
  State<OrderList> createState() => _OrderListState();
}

class _OrderListState extends State<OrderList> {
  String selectedTimeframe = 'Monthly';

  final List<Order> orders = [
    const Order(
      id: '#12345',
      number: '1',
      date: 'Jan 24th, 2020',
      customerName: 'Abban Justice',
      location: 'Kasoa Mellinnium City, Sector 4',
      amount: 'GHC 34.20',
      status: 'New Order',
      statusColor: 'primary',
    ),
    const Order(
      id: '#12366',
      number: '2',
      date: 'Jan 22th, 2020',
      customerName: 'Maame Ama',
      location: 'Tema Community 10',
      amount: 'GHC 44.25',
      status: 'On Delivery',
      statusColor: 'blueAccent',
    ),
    const Order(
      id: '#12378',
      number: '3',
      date: 'Jan 20th, 2020',
      customerName: 'Kwame Adu',
      location: 'Main Street 3rd Accra',
      amount: 'GHC 28.50',
      status: 'Refund',
      statusColor: 'errorRed',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isMobile = Responsive.isMobile(context);
    final isTablet = Responsive.isTablet(context);

    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.white,
        borderRadius: BorderRadius.circular(8),
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
              Text(
                'Quick Stats',
                style: GoogleFonts.lato(
                  fontSize: Responsive.getFontSize(context, isMobile ? 16 : 18),
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.white : AppColors.primary,
                ),
              ),
              if (!isMobile)
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
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          timeframe,
                          style: GoogleFonts.lato(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: selectedTimeframe == timeframe
                                ? AppColors.white
                                : (isDark ? AppColors.white.withValues(alpha: 0.7) : AppColors.grey),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
            ],
          ),
          if (isMobile) ...[
            const SizedBox(height: 12),
            Row(
              children: ['Monthly', 'Weekly', 'Today'].map((timeframe) {
                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        selectedTimeframe = timeframe;
                      });
                    },
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: selectedTimeframe == timeframe ? AppColors.accentOrange : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: selectedTimeframe == timeframe
                              ? AppColors.accentOrange
                              : (isDark ? AppColors.white.withValues(alpha: 0.1) : AppColors.lightSurface),
                        ),
                      ),
                      child: Text(
                        timeframe,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.lato(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: selectedTimeframe == timeframe
                              ? AppColors.white
                              : (isDark ? AppColors.white.withValues(alpha: 0.7) : AppColors.grey),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
          SizedBox(height: isMobile ? 16 : 20),
          if (isMobile)
            ...orders.map((order) => _buildMobileOrderCard(order, isDark)).toList()
          else
            _buildTableLayout(isDark, isTablet),
        ],
      ),
    );
  }

  Widget _buildTableLayout(bool isDark, bool isTablet) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkBackground : AppColors.secondaryBackground,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Expanded(flex: 1, child: _buildTableHeader('No', isDark)),
              Expanded(flex: 2, child: _buildTableHeader('ID ↑↓', isDark)),
              Expanded(flex: 2, child: _buildTableHeader('Date', isDark)),
              Expanded(flex: 3, child: _buildTableHeader('Customer Name ↑↓', isDark)),
              Expanded(flex: 3, child: _buildTableHeader('Location', isDark)),
              Expanded(flex: 2, child: _buildTableHeader('Amount ↑↓', isDark)),
              Expanded(flex: 2, child: _buildTableHeader('Status Order ↑↓', isDark)),
              Expanded(flex: 1, child: _buildTableHeader('Action', isDark)),
            ],
          ),
        ),
        ...orders.map((order) => _buildTableRow(order, isDark, isTablet)),
      ],
    );
  }

  Widget _buildMobileOrderCard(Order order, bool isDark) {
    final statusColor = _getStatusColor(order.statusColor);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.mutedBrown.withValues(alpha: 0.3) : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDark ? AppColors.white.withValues(alpha: 0.1) : AppColors.lightSurface, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                order.id,
                style: GoogleFonts.lato(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.white : AppColors.primary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: statusColor, borderRadius: BorderRadius.circular(12)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(color: AppColors.white, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      order.status,
                      style: GoogleFonts.lato(fontSize: 10, fontWeight: FontWeight.w500, color: AppColors.white),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildMobileInfoRow('Customer', order.customerName, isDark),
          const SizedBox(height: 8),
          _buildMobileInfoRow('Location', order.location, isDark),
          const SizedBox(height: 8),
          _buildMobileInfoRow('Date', order.date, isDark),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                order.amount,
                style: GoogleFonts.lato(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.accentOrange),
              ),
              IconButton(
                onPressed: () {},
                icon: Icon(Icons.more_vert, color: isDark ? AppColors.white : AppColors.primary, size: 20),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMobileInfoRow(String label, String value, bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: GoogleFonts.lato(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isDark ? AppColors.white.withValues(alpha: 0.7) : AppColors.grey,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.lato(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: isDark ? AppColors.white : AppColors.primary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildTableHeader(String text, bool isDark) {
    return Text(
      text,
      style: GoogleFonts.lato(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: isDark ? AppColors.white : AppColors.primary,
      ),
    );
  }

  Widget _buildTableRow(Order order, bool isDark, bool isTablet) {
    final statusColor = _getStatusColor(order.statusColor);

    return Container(
      padding: EdgeInsets.symmetric(vertical: isTablet ? 12 : 16, horizontal: isTablet ? 12 : 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: isDark ? AppColors.white.withValues(alpha: 0.1) : AppColors.lightSurface, width: 1),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 1,
            child: Text(
              order.number,
              style: _tableTextStyle(isTablet, isDark),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              order.id,
              style: _tableTextStyle(isTablet, isDark),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              order.date,
              style: _tableTextStyle(isTablet, isDark),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              order.customerName,
              style: _tableTextStyle(isTablet, isDark),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              order.location,
              style: _tableTextStyle(isTablet, isDark),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              order.amount,
              style: _tableTextStyle(isTablet, isDark),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: statusColor, borderRadius: BorderRadius.circular(12)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(color: AppColors.white, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      order.status,
                      style: GoogleFonts.lato(
                        fontSize: isTablet ? 9 : 10,
                        fontWeight: FontWeight.w500,
                        color: AppColors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Icon(
              Icons.more_vert,
              color: isDark ? AppColors.white.withValues(alpha: 0.7) : AppColors.grey,
              size: isTablet ? 18 : 20,
            ),
          ),
        ],
      ),
    );
  }

  TextStyle _tableTextStyle(bool isTablet, bool isDark) {
    return GoogleFonts.lato(fontSize: isTablet ? 11 : 12, color: isDark ? AppColors.white : AppColors.primary);
  }

  Color _getStatusColor(String colorName) {
    switch (colorName) {
      case 'primary':
        return AppColors.primary;
      case 'blueAccent':
        return AppColors.blueAccent;
      case 'accentOrange':
        return AppColors.accentOrange;
      case 'errorRed':
        return AppColors.errorRed;
      default:
        return AppColors.primary;
    }
  }
}
