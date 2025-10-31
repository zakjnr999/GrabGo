import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:grab_go_shared/shared/widgets/animated_tab_bar.dart';
import 'package:grab_go_shared/shared/widgets/responsive.dart';
import 'package:grab_go_shared/shared/utils/colors.dart';
import 'package:grab_go_restaurant/shared/widgets/restaurant_order_list.dart';
import '../../../shared/widgets/svg_icon.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  int selectedStatusIndex = 0;
  final List<String> statuses = ['All', 'New', 'Preparing', 'Ready', 'Delivered'];

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: Responsive.getScreenPadding(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Refresh Button and Tab Bar Row
          Row(
            children: [
              // Animated Status Tab Bar
              Expanded(
                child: AnimatedTabBar(
                  tabs: statuses,
                  selectedIndex: selectedStatusIndex,
                  onTabChanged: (index) {
                    setState(() {
                      selectedStatusIndex = index;
                    });
                  },
                  height: isMobile ? 40 : 50,
                  padding: EdgeInsets.zero,
                ),
              ),
              SizedBox(width: isMobile ? 12 : 16),
              // Refresh Button
              ElevatedButton.icon(
                onPressed: () {
                  // Refresh orders
                },
                icon: SvgIcon(svgImage: Assets.icons.alarm, width: 20, height: 20, color: AppColors.white),
                label: Text('Refresh', style: GoogleFonts.lato(fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentOrange,
                  foregroundColor: AppColors.white,
                  padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 20, vertical: isMobile ? 12 : 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
          SizedBox(height: isMobile ? 20 : 24),

          // Order List
          const RestaurantOrderList(),
        ],
      ),
    );
  }
}
