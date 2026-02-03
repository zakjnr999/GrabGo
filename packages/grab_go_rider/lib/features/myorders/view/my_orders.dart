import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:grab_go_rider/features/myorders/view/cancelled_orders.dart';
import 'package:grab_go_rider/features/myorders/view/completed_orders.dart';
import 'package:grab_go_rider/features/myorders/view/ongoing_orders.dart';
import 'package:grab_go_shared/shared/utils/app_colors_extension.dart';
import 'package:grab_go_shared/shared/utils/constants.dart';

enum MyOrderFilters { ongoing, completed, cancelled }

class MyOrders extends StatefulWidget {
  const MyOrders({super.key});

  @override
  State<MyOrders> createState() => _MyOrdersState();
}

class _MyOrdersState extends State<MyOrders> {
  MyOrderFilters _selectedPeriod = MyOrderFilters.ongoing;
  final List<Widget> orderScreens = [const OngoingOrders(), const CompletedOrders(), const CancelledOrders()];

  Widget _buildSelectedScreen() {
    return Expanded(
      child: IndexedStack(index: _selectedPeriod.index, children: orderScreens),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: colors.backgroundPrimary,
        systemNavigationBarDividerColor: Colors.transparent,
        systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: colors.backgroundSecondary,
        appBar: AppBar(
          backgroundColor: colors.backgroundPrimary,
          elevation: 0,
          title: Text(
            "My Orders",
            style: TextStyle(
              fontFamily: "Lato",
              package: "grab_go_shared",
              color: colors.textPrimary,
              fontSize: 18.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
          centerTitle: true,
          actionsPadding: EdgeInsets.only(right: 10.w),
        ),
        body: Padding(
          padding: EdgeInsets.symmetric(horizontal: 20.w),
          child: Column(
            children: [
              SizedBox(height: 20.h),
              Row(
                children: [
                  Expanded(child: _buildPeriodFilter("Ongoing", MyOrderFilters.ongoing, colors)),
                  SizedBox(width: 8.w),
                  Expanded(child: _buildPeriodFilter("Completed", MyOrderFilters.completed, colors)),
                  SizedBox(width: 8.w),
                  Expanded(child: _buildPeriodFilter("Cancelled", MyOrderFilters.cancelled, colors)),
                ],
              ),
              const SizedBox(height: 20),
              _buildSelectedScreen(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPeriodFilter(String label, MyOrderFilters type, AppColorsExtension colors) {
    final isSelected = _selectedPeriod == type;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedPeriod = type;
        });
      },
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 8.w),
        decoration: BoxDecoration(
          color: isSelected ? colors.accentGreen : colors.backgroundPrimary,
          borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected ? Colors.white : colors.textPrimary,
            fontSize: 13.sp,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
