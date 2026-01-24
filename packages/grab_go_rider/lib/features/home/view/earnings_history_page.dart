import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_rider/features/home/models/transaction_model.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:intl/intl.dart';

enum EarningsPeriod { today, thisWeek, thisMonth, allTime }

class EarningsHistoryPage extends StatefulWidget {
  const EarningsHistoryPage({super.key});

  @override
  State<EarningsHistoryPage> createState() => _EarningsHistoryPageState();
}

class _EarningsHistoryPageState extends State<EarningsHistoryPage> {
  List<TransactionModel> _allEarnings = [];
  List<TransactionModel> _filteredEarnings = [];
  EarningsPeriod _selectedPeriod = EarningsPeriod.allTime;

  @override
  void initState() {
    super.initState();
    _loadEarnings();
  }

  void _loadEarnings() {
    final now = DateTime.now();
    _allEarnings = [
      TransactionModel(
        id: '1',
        amount: 25.50,
        type: TransactionType.delivery,
        description: 'Delivery to East Legon',
        dateTime: now.subtract(const Duration(hours: 2)),
        status: TransactionStatus.completed,
      ),
      TransactionModel(
        id: '2',
        amount: 10.00,
        type: TransactionType.tip,
        description: 'Tip from customer',
        dateTime: now.subtract(const Duration(hours: 3)),
        status: TransactionStatus.completed,
      ),
      TransactionModel(
        id: '3',
        amount: 38.00,
        type: TransactionType.delivery,
        description: 'Delivery to Cantonments',
        dateTime: now.subtract(const Duration(hours: 5)),
        status: TransactionStatus.completed,
      ),
      TransactionModel(
        id: '4',
        amount: 42.00,
        type: TransactionType.delivery,
        description: 'Delivery to Labone',
        dateTime: now.subtract(const Duration(days: 2, hours: 3)),
        status: TransactionStatus.completed,
      ),
      TransactionModel(
        id: '5',
        amount: 5.00,
        type: TransactionType.tip,
        description: 'Tip from customer',
        dateTime: now.subtract(const Duration(days: 3)),
        status: TransactionStatus.completed,
      ),
      TransactionModel(
        id: '6',
        amount: 30.00,
        type: TransactionType.delivery,
        description: 'Delivery to Osu',
        dateTime: now.subtract(const Duration(days: 4)),
        status: TransactionStatus.completed,
      ),
      TransactionModel(
        id: '7',
        amount: 50.00,
        type: TransactionType.bonus,
        description: 'Weekend bonus',
        dateTime: now.subtract(const Duration(days: 5)),
        status: TransactionStatus.completed,
      ),
      TransactionModel(
        id: '8',
        amount: 35.00,
        type: TransactionType.delivery,
        description: 'Delivery to Airport',
        dateTime: now.subtract(const Duration(days: 10)),
        status: TransactionStatus.completed,
      ),
      TransactionModel(
        id: '9',
        amount: 15.00,
        type: TransactionType.tip,
        description: 'Tip from customer',
        dateTime: now.subtract(const Duration(days: 12)),
        status: TransactionStatus.completed,
      ),
      TransactionModel(
        id: '10',
        amount: 28.00,
        type: TransactionType.delivery,
        description: 'Delivery to Accra Mall',
        dateTime: now.subtract(const Duration(days: 15)),
        status: TransactionStatus.completed,
      ),
      TransactionModel(
        id: '11',
        amount: 100.00,
        type: TransactionType.bonus,
        description: 'Monthly performance bonus',
        dateTime: now.subtract(const Duration(days: 20)),
        status: TransactionStatus.completed,
      ),
      TransactionModel(
        id: '12',
        amount: 22.00,
        type: TransactionType.delivery,
        description: 'Delivery to Tema',
        dateTime: now.subtract(const Duration(days: 25)),
        status: TransactionStatus.completed,
      ),
    ];

    _applyFilter();
  }

  void _applyFilter() {
    final now = DateTime.now();
    setState(() {
      switch (_selectedPeriod) {
        case EarningsPeriod.today:
          _filteredEarnings = _allEarnings.where((earning) {
            return earning.dateTime.year == now.year &&
                earning.dateTime.month == now.month &&
                earning.dateTime.day == now.day;
          }).toList();
          break;
        case EarningsPeriod.thisWeek:
          final weekStart = now.subtract(Duration(days: now.weekday - 1));
          _filteredEarnings = _allEarnings.where((earning) {
            return earning.dateTime.isAfter(weekStart.subtract(const Duration(days: 1)));
          }).toList();
          break;
        case EarningsPeriod.thisMonth:
          _filteredEarnings = _allEarnings.where((earning) {
            return earning.dateTime.year == now.year && earning.dateTime.month == now.month;
          }).toList();
          break;
        case EarningsPeriod.allTime:
          _filteredEarnings = _allEarnings;
          break;
      }
      _filteredEarnings.sort((a, b) => b.dateTime.compareTo(a.dateTime));
    });
  }

  double _getTotalEarnings() {
    return _filteredEarnings.fold(0.0, (sum, earning) => sum + earning.amount);
  }

  String _getTransactionIcon(TransactionType type) {
    switch (type) {
      case TransactionType.delivery:
        return Assets.icons.deliveryTruck;
      case TransactionType.tip:
        return Assets.icons.gift;
      case TransactionType.bonus:
        return Assets.icons.star;
      case TransactionType.withdrawal:
        return Assets.icons.creditCard;
      case TransactionType.penalty:
        return Assets.icons.warningCircle;
    }
  }

  String _getTransactionTypeLabel(TransactionType type) {
    switch (type) {
      case TransactionType.delivery:
        return 'Delivery';
      case TransactionType.tip:
        return 'Tip';
      case TransactionType.bonus:
        return 'Bonus';
      case TransactionType.withdrawal:
        return 'Withdrawal';
      case TransactionType.penalty:
        return 'Penalty';
    }
  }

  Color _getTransactionTypeColor(TransactionType type, AppColorsExtension colors) {
    switch (type) {
      case TransactionType.delivery:
        return colors.accentGreen;
      case TransactionType.tip:
        return colors.accentOrange;
      case TransactionType.bonus:
        return colors.accentViolet;
      case TransactionType.withdrawal:
        return colors.error;
      case TransactionType.penalty:
        return colors.error;
    }
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
            "Earnings History",
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
          physics: const AlwaysScrollableScrollPhysics(),
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
                    colors: [colors.accentGreen, colors.accentGreen.withValues(alpha: 0.85)],
                  ),
                  borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
                  boxShadow: [
                    BoxShadow(
                      color: colors.accentGreen.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Total Earnings",
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.5,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "GHC",
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 20.sp,
                            fontWeight: FontWeight.w600,
                            height: 1,
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: Text(
                            _getTotalEarnings().toStringAsFixed(2),
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 40.sp,
                              fontWeight: FontWeight.w800,
                              height: 1,
                              letterSpacing: -1,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16.h),
                    Text(
                      "${_filteredEarnings.length} ${_filteredEarnings.length == 1 ? 'transaction' : 'transactions'}",
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 24.h),

              Row(
                children: [
                  Expanded(child: _buildPeriodFilter("Today", EarningsPeriod.today, colors)),
                  SizedBox(width: 8.w),
                  Expanded(child: _buildPeriodFilter("Week", EarningsPeriod.thisWeek, colors)),
                  SizedBox(width: 8.w),
                  Expanded(child: _buildPeriodFilter("Month", EarningsPeriod.thisMonth, colors)),
                  SizedBox(width: 8.w),
                  Expanded(child: _buildPeriodFilter("All", EarningsPeriod.allTime, colors)),
                ],
              ),

              SizedBox(height: 24.h),

              if (_filteredEarnings.isEmpty)
                _buildEmptyState(colors)
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _filteredEarnings.length,
                  separatorBuilder: (context, index) => SizedBox(height: 12.h),
                  itemBuilder: (context, index) {
                    final earning = _filteredEarnings[index];
                    final typeColor = _getTransactionTypeColor(earning.type, colors);
                    final iconPath = _getTransactionIcon(earning.type);
                    final typeLabel = _getTransactionTypeLabel(earning.type);

                    final timeFormat = DateFormat('MMM dd, hh:mm a');
                    final timeString = timeFormat.format(earning.dateTime);

                    return Container(
                      padding: EdgeInsets.all(16.w),
                      decoration: BoxDecoration(
                        color: colors.backgroundPrimary,
                        borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
                        border: Border.all(color: colors.border, width: 1),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 48.w,
                            height: 48.w,
                            decoration: BoxDecoration(
                              color: typeColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
                            ),
                            child: Center(
                              child: SvgPicture.asset(
                                iconPath,
                                package: 'grab_go_shared',
                                width: 24.w,
                                height: 24.w,
                                colorFilter: ColorFilter.mode(typeColor, BlendMode.srcIn),
                              ),
                            ),
                          ),
                          SizedBox(width: 16.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  earning.description,
                                  style: TextStyle(
                                    color: colors.textPrimary,
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                SizedBox(height: 6.h),
                                Row(
                                  children: [
                                    Text(
                                      typeLabel,
                                      style: TextStyle(color: typeColor, fontSize: 12.sp, fontWeight: FontWeight.w600),
                                    ),
                                    SizedBox(width: 8.w),
                                    Flexible(
                                      child: Text(
                                        timeString,
                                        style: TextStyle(
                                          overflow: TextOverflow.ellipsis,
                                          color: colors.textSecondary,
                                          fontSize: 12.sp,
                                          fontWeight: FontWeight.w400,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                "+GHC ${earning.amount.toStringAsFixed(2)}",
                                style: TextStyle(
                                  color: colors.accentGreen,
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              SizedBox(height: 4.h),
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                                decoration: BoxDecoration(
                                  color: colors.success.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  earning.status.name.toUpperCase(),
                                  style: TextStyle(color: colors.success, fontSize: 9.sp, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),

              SizedBox(height: 32.h),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPeriodFilter(String label, EarningsPeriod period, AppColorsExtension colors) {
    final isSelected = _selectedPeriod == period;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedPeriod = period;
          _applyFilter();
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

  Widget _buildEmptyState(AppColorsExtension colors) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 48.h),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(24.w),
            decoration: BoxDecoration(color: colors.backgroundPrimary, shape: BoxShape.circle),
            child: SvgPicture.asset(
              Assets.icons.dollar,
              package: 'grab_go_shared',
              width: 48.w,
              height: 48.w,
              colorFilter: ColorFilter.mode(colors.textSecondary.withValues(alpha: 0.5), BlendMode.srcIn),
            ),
          ),
          SizedBox(height: 24.h),
          Text(
            "No earnings found",
            style: TextStyle(color: colors.textPrimary, fontSize: 18.sp, fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 8.h),
          Text(
            "No earnings recorded for this period.",
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.textSecondary, fontSize: 14.sp, fontWeight: FontWeight.w400),
          ),
        ],
      ),
    );
  }
}
