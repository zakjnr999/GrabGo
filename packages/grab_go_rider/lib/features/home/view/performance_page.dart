import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:intl/intl.dart';

class RatingReview {
  final String id;
  final String customerName;
  final double rating;
  final String comment;
  final DateTime dateTime;
  final String deliveryId;

  RatingReview({
    required this.id,
    required this.customerName,
    required this.rating,
    required this.comment,
    required this.dateTime,
    required this.deliveryId,
  });
}

class PerformancePage extends StatefulWidget {
  const PerformancePage({super.key});

  @override
  State<PerformancePage> createState() => _PerformancePageState();
}

class _PerformancePageState extends State<PerformancePage> {
  double _overallRating = 4.8;
  int _totalDeliveries = 1247;
  double _successRate = 98.5;
  double _averageDeliveryTime = 25.0;
  int _onTimeDeliveries = 1228;
  int _totalRatings = 892;

  List<RatingReview> _recentRatings = [];

  @override
  void initState() {
    super.initState();
    _loadRecentRatings();
  }

  void _loadRecentRatings() {
    final now = DateTime.now();
    _recentRatings = [
      RatingReview(
        id: '1',
        customerName: 'Sarah Mensah',
        rating: 5.0,
        comment: 'Excellent service! Very fast and professional delivery.',
        dateTime: now.subtract(const Duration(hours: 2)),
        deliveryId: '#1234',
      ),
      RatingReview(
        id: '2',
        customerName: 'John Doe',
        rating: 5.0,
        comment: 'Great rider, always on time. Highly recommended!',
        dateTime: now.subtract(const Duration(days: 1)),
        deliveryId: '#1235',
      ),
      RatingReview(
        id: '3',
        customerName: 'Ama Kumi',
        rating: 4.0,
        comment: 'Good service, arrived on time.',
        dateTime: now.subtract(const Duration(days: 2)),
        deliveryId: '#1236',
      ),
      RatingReview(
        id: '4',
        customerName: 'Kwame Asante',
        rating: 5.0,
        comment: 'Very professional and courteous. Food was still hot!',
        dateTime: now.subtract(const Duration(days: 3)),
        deliveryId: '#1237',
      ),
      RatingReview(
        id: '5',
        customerName: 'Efua Bonsu',
        rating: 4.0,
        comment: 'Good delivery, minor delay but overall satisfied.',
        dateTime: now.subtract(const Duration(days: 5)),
        deliveryId: '#1238',
      ),
    ];
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
          scrolledUnderElevation: 0,
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
            "Performance",
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
                padding: EdgeInsets.all(24.w),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [colors.accentViolet, colors.accentViolet.withValues(alpha: 0.85)],
                  ),
                  borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
                  boxShadow: [
                    BoxShadow(
                      color: colors.accentViolet.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _overallRating.toStringAsFixed(1),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 56.sp,
                            fontWeight: FontWeight.w800,
                            height: 1,
                            letterSpacing: -2,
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '/ 5.0',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontSize: 20.sp,
                                fontWeight: FontWeight.w600,
                                height: 1,
                              ),
                            ),
                            SizedBox(height: 4.h),
                            Row(
                              children: List.generate(5, (index) {
                                return SvgPicture.asset(
                                  index < _overallRating.floor() ||
                                          (index == _overallRating.floor() && _overallRating % 1 >= 0.5)
                                      ? Assets.icons.starSolid
                                      : Assets.icons.star,
                                  package: "grab_go_shared",
                                  colorFilter: ColorFilter.mode(Colors.white, BlendMode.srcIn),
                                  height: 18.h,
                                  width: 18.w,
                                );
                              }),
                            ),
                          ],
                        ),
                      ],
                    ),
                    SizedBox(height: 16.h),
                    Text(
                      'Overall Rating',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      'Based on $_totalRatings reviews',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 24.h),

              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      'Total Deliveries',
                      _totalDeliveries.toString(),
                      Assets.icons.deliveryTruck,
                      colors.accentGreen,
                      colors,
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: _buildStatCard(
                      'Success Rate',
                      '${_successRate.toStringAsFixed(1)}%',
                      Assets.icons.check,
                      colors.accentOrange,
                      colors,
                    ),
                  ),
                ],
              ),

              SizedBox(height: 12.h),

              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      'Avg. Time',
                      '${_averageDeliveryTime.toStringAsFixed(0)} min',
                      Assets.icons.clock,
                      colors.accentBlue,
                      colors,
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: _buildStatCard(
                      'On-Time',
                      '$_onTimeDeliveries',
                      Assets.icons.star,
                      colors.accentViolet,
                      colors,
                    ),
                  ),
                ],
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
                    Text(
                      "PERFORMANCE BREAKDOWN",
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.2,
                      ),
                    ),
                    SizedBox(height: 20.h),
                    _buildPerformanceRow("Success Rate", _successRate, 100, colors.accentGreen, colors),
                    SizedBox(height: 16.h),
                    _buildPerformanceRow(
                      "On-Time Rate",
                      (_onTimeDeliveries / _totalDeliveries * 100),
                      100,
                      colors.accentOrange,
                      colors,
                    ),
                    SizedBox(height: 16.h),
                    _buildPerformanceRow(
                      "Customer Satisfaction",
                      _overallRating * 20,
                      100,
                      colors.accentViolet,
                      colors,
                    ),
                  ],
                ),
              ),

              SizedBox(height: 24.h),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Recent Ratings",
                    style: TextStyle(color: colors.textPrimary, fontSize: 18.sp, fontWeight: FontWeight.w700),
                  ),
                  TextButton(
                    onPressed: () {},
                    child: Text(
                      "View All",
                      style: TextStyle(color: colors.accentViolet, fontSize: 14.sp, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),

              SizedBox(height: 16.h),

              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _recentRatings.length,
                separatorBuilder: (context, index) => SizedBox(height: 12.h),
                itemBuilder: (context, index) {
                  final rating = _recentRatings[index];
                  return _buildRatingCard(rating, colors);
                },
              ),

              SizedBox(height: 32.h),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, String icon, Color color, AppColorsExtension colors) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: colors.backgroundPrimary,
        borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
        border: Border.all(color: colors.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(8.r),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
            ),
            child: SvgPicture.asset(
              icon,
              package: 'grab_go_shared',
              width: 20.w,
              height: 20.w,
              colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
            ),
          ),
          SizedBox(height: 12.h),
          Text(
            value,
            style: TextStyle(color: colors.textPrimary, fontSize: 20.sp, fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 4.h),
          Text(
            label,
            style: TextStyle(color: colors.textSecondary, fontSize: 12.sp, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceRow(String label, double value, double max, Color color, AppColorsExtension colors) {
    final percentage = (value / max * 100).clamp(0.0, 100.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(color: colors.textPrimary, fontSize: 14.sp, fontWeight: FontWeight.w600),
            ),
            Text(
              '${percentage.toStringAsFixed(1)}%',
              style: TextStyle(color: color, fontSize: 14.sp, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        SizedBox(height: 8.h),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: percentage / 100,
            minHeight: 8.h,
            backgroundColor: colors.divider.withValues(alpha: 0.3),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  Widget _buildRatingCard(RatingReview rating, AppColorsExtension colors) {
    final timeAgo = _getTimeAgo(rating.dateTime);
    return Container(
      padding: EdgeInsets.all(16.w),
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
                width: 40.w,
                height: 40.w,
                decoration: BoxDecoration(color: colors.accentViolet.withValues(alpha: 0.1), shape: BoxShape.circle),
                child: Center(
                  child: Text(
                    rating.customerName[0].toUpperCase(),
                    style: TextStyle(color: colors.accentViolet, fontSize: 16.sp, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rating.customerName,
                      style: TextStyle(color: colors.textPrimary, fontSize: 14.sp, fontWeight: FontWeight.w600),
                    ),
                    SizedBox(height: 4.h),
                    Row(
                      children: [
                        ...List.generate(5, (index) {
                          return SvgPicture.asset(
                            index < rating.rating.floor() ||
                                    (index == rating.rating.floor() && rating.rating % 1 >= 0.5)
                                ? Assets.icons.starSolid
                                : Assets.icons.star,
                            package: "grab_go_shared",
                            colorFilter: ColorFilter.mode(colors.accentOrange, BlendMode.srcIn),
                            height: 14.h,
                            width: 14.w,
                          );
                        }),
                        SizedBox(width: 6.w),
                        Text(
                          timeAgo,
                          style: TextStyle(color: colors.textSecondary, fontSize: 11.sp, fontWeight: FontWeight.w400),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: colors.accentViolet.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  rating.deliveryId,
                  style: TextStyle(color: colors.accentViolet, fontSize: 10.sp, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          if (rating.comment.isNotEmpty) ...[
            SizedBox(height: 12.h),
            Text(
              rating.comment,
              style: TextStyle(color: colors.textSecondary, fontSize: 13.sp, fontWeight: FontWeight.w400, height: 1.4),
            ),
          ],
        ],
      ),
    );
  }

  String _getTimeAgo(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return DateFormat('MMM d').format(timestamp);
    }
  }
}
