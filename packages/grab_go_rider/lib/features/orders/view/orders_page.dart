import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';

class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  bool _routeOptimizationEnabled = true;
  bool _showDropPoints = false;
  final List<String> _dropPoints = [
    "COLDSiS GL., Adenta, Cocoyam Street 5",
    "Mary's Office, Kasoa Millennium City",
    "Kek Building, Adenta, Libya Quaters",
  ];

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
          leading: IconButton(
            icon: SvgPicture.asset(
              Assets.icons.navArrowLeft,
              package: 'grab_go_shared',
              width: 24.w,
              height: 24.w,
              colorFilter: ColorFilter.mode(colors.textPrimary, BlendMode.srcIn),
            ),
            onPressed: () => context.pop(),
          ),
          title: Text(
            "Orders",
            style: TextStyle(
              fontFamily: "Lato",
              package: "grab_go_shared",
              color: colors.textPrimary,
              fontSize: 18.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
          centerTitle: true,
        ),
        body: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.symmetric(horizontal: 20.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 20.h),
              Container(
                padding: EdgeInsets.all(20.w),
                decoration: BoxDecoration(
                  color: colors.backgroundPrimary,
                  borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
                  border: Border.all(color: colors.border, width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 20.w,
                          height: 20.w,
                          decoration: BoxDecoration(
                            color: colors.accentGreen,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                          ),
                          child: Center(
                            child: Container(
                              width: 8.w,
                              height: 8.w,
                              decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                            ),
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Text(
                          "Your location",
                          style: TextStyle(color: colors.textPrimary, fontSize: 14.sp, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),

                    SizedBox(height: 16.h),

                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            children: [
                              Container(
                                height: 40.h,
                                width: 2.w,
                                decoration: BoxDecoration(color: colors.border, borderRadius: BorderRadius.circular(2)),
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: List.generate(3, (index) {
                                  return Container(
                                    width: 6.w,
                                    height: 6.w,
                                    decoration: BoxDecoration(color: colors.accentGreen, shape: BoxShape.circle),
                                  );
                                }),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          flex: 4,
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _showDropPoints = !_showDropPoints;
                              });
                            },
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                              decoration: BoxDecoration(
                                color: colors.backgroundSecondary,
                                borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
                                border: Border.all(color: colors.border, width: 1),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    "3 DROP POINTS",
                                    style: TextStyle(
                                      color: colors.textSecondary,
                                      fontSize: 12.sp,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  SizedBox(width: 6.w),
                                  Icon(
                                    _showDropPoints ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                                    size: 16.w,
                                    color: colors.textSecondary,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    if (_showDropPoints) ...[
                      SizedBox(height: 12.h),
                      ...List.generate(_dropPoints.length, (index) {
                        return Padding(
                          padding: EdgeInsets.only(bottom: 12.h),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                margin: EdgeInsets.only(top: 6.h),
                                width: 8.w,
                                height: 8.w,
                                decoration: BoxDecoration(color: colors.accentGreen, shape: BoxShape.circle),
                              ),
                              SizedBox(width: 12.w),
                              Expanded(
                                child: Text(
                                  "${index + 1}. ${_dropPoints[index]}",
                                  style: TextStyle(
                                    color: colors.textSecondary,
                                    fontSize: 12.sp,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],

                    SizedBox(height: 16.h),

                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          margin: EdgeInsets.only(top: 4.h),
                          child: SvgPicture.asset(
                            Assets.icons.mapPin,
                            package: 'grab_go_shared',
                            width: 20.w,
                            height: 20.w,
                            colorFilter: ColorFilter.mode(colors.error, BlendMode.srcIn),
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: Text(
                            "Madina, Zongo Junction, 13th Street...",
                            style: TextStyle(color: colors.textPrimary, fontSize: 14.sp, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              SizedBox(height: 24.h),

              Container(
                padding: EdgeInsets.all(20.w),
                decoration: BoxDecoration(
                  color: colors.backgroundPrimary,
                  borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
                  border: Border.all(color: colors.border, width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "DELIVERY EARNINGS",
                              style: TextStyle(
                                color: colors.textSecondary,
                                fontSize: 11.sp,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                              ),
                            ),
                            SizedBox(height: 6.h),
                            Text(
                              "GHC 39.95",
                              style: TextStyle(
                                color: colors.textPrimary,
                                fontSize: 28.sp,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    SizedBox(height: 24.h),

                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "TOTAL TIPS",
                                style: TextStyle(
                                  color: colors.textSecondary,
                                  fontSize: 11.sp,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              SizedBox(height: 6.h),
                              Text(
                                "GHC 11.50",
                                style: TextStyle(
                                  color: colors.textPrimary,
                                  fontSize: 22.sp,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: 20.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "TOTAL DISTANCE",
                                style: TextStyle(
                                  color: colors.textSecondary,
                                  fontSize: 11.sp,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              SizedBox(height: 6.h),
                              Text(
                                "11.3 mi",
                                style: TextStyle(
                                  color: colors.textPrimary,
                                  fontSize: 22.sp,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 24.h),

                    Container(
                      padding: EdgeInsets.all(16.w),
                      decoration: BoxDecoration(
                        color: colors.accentGreen.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
                        border: Border.all(color: colors.accentGreen.withValues(alpha: 0.3), width: 1),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "TOTAL EST. EARNINGS",
                            style: TextStyle(
                              color: colors.accentGreen,
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                          SizedBox(width: 2.w),
                          Text(
                            "GHC 51.45",
                            style: TextStyle(
                              color: colors.accentGreen,
                              fontSize: 24.sp,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 24.h),

              Container(
                padding: EdgeInsets.all(20.w),
                decoration: BoxDecoration(
                  color: colors.backgroundPrimary,
                  borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
                  border: Border.all(color: colors.border, width: 1),
                ),
                child: Row(
                  children: [
                    Switch.adaptive(
                      value: _routeOptimizationEnabled,
                      onChanged: (value) {
                        setState(() {
                          _routeOptimizationEnabled = value;
                        });
                      },
                      activeThumbColor: AppColors.white,
                      activeTrackColor: colors.accentGreen,
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Text(
                        "Always select best route, ignore traffic",
                        style: TextStyle(color: colors.textPrimary, fontSize: 14.sp, fontWeight: FontWeight.w500),
                      ),
                    ),
                    SizedBox(width: 8.w),
                    GestureDetector(
                      onTap: () {},
                      child: Container(
                        width: 20.w,
                        height: 20.w,
                        decoration: BoxDecoration(color: colors.info.withValues(alpha: 0.1), shape: BoxShape.circle),
                        child: Icon(Icons.info_outline, size: 14.w, color: colors.info),
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 32.h),

              Column(
                children: [
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [colors.accentGreen, colors.accentGreen.withValues(alpha: 0.85)],
                      ),
                      borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
                      boxShadow: [
                        BoxShadow(
                          color: colors.accentGreen.withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          context.push(
                            '/order-confirmation',
                            extra: {
                              'orderId': 'ORD-12345',
                              'restaurantName': 'Pizza Palace',
                              'restaurantAddress': '456 Food Street, Accra',
                              'customerName': 'John Doe',
                              'customerAddress': '123 Main Street, Accra',
                              'customerPhone': '+233 123 456 789',
                              'orderTotal': 'GHS 45.00',
                              'orderItems': ['Pizza Margherita x1', 'Coca Cola x2'],
                              'specialInstructions': 'Ring doorbell twice',
                            },
                          );
                        },
                        borderRadius: BorderRadius.circular(KBorderSize.borderRadius8),
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 18.h, horizontal: 20.w),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SvgPicture.asset(
                                Assets.icons.deliveryTruck,
                                package: 'grab_go_shared',
                                width: 24.w,
                                height: 24.w,
                                colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                              ),
                              SizedBox(width: 12.w),
                              Text(
                                "Accept 4 deliveries",
                                style: TextStyle(color: Colors.white, fontSize: 16.sp, fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: 16.h),

                  GestureDetector(
                    onTap: () {},
                    child: Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(vertical: 18.h, horizontal: 20.w),
                      decoration: BoxDecoration(
                        color: colors.backgroundSecondary,
                        borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
                        border: Border.all(color: colors.border, width: 1),
                      ),
                      child: Center(
                        child: Text(
                          "No, I'll custom select orders",
                          style: TextStyle(color: colors.textSecondary, fontSize: 14.sp, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: KSpacing.lg.h),
                ],
              ),

              SizedBox(height: 32.h),
            ],
          ),
        ),
      ),
    );
  }
}
