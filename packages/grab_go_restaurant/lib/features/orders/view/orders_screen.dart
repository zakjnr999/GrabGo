import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:grab_go_restaurant/shared/widgets/app_button.dart';
import 'package:grab_go_restaurant/shared/app_colors.dart';
import '../../../shared/widgets/animated_tab_bar.dart';
import 'package:grab_go_shared/shared/widgets/responsive.dart';
import '../../../shared/widgets/restaurant_order_list.dart';
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
          Row(
            children: [
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
              AppButton(
                buttonText: 'Refresh',
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Refreshing orders...'), backgroundColor: AppColors.accentGreen),
                  );
                },
                borderRadius: 4,
                backgroundColor: AppColors.accentOrange,
                textColor: AppColors.white,
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                icon: (SvgIcon(svgImage: Assets.icons.refresh, width: 18, height: 18, color: AppColors.white)),
              ),
            ],
          ),
          SizedBox(height: Responsive.getCardSpacing(context)),

          const RestaurantOrderList(),
        ],
      ),
    );
  }
}
