import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_rider/features/home/models/transaction_model.dart';
import 'package:grab_go_rider/features/home/models/transaction_history_model.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:intl/intl.dart';

enum TransactionPeriod { today, thisWeek, thisMonth, allTime }

class TransactionHistoryPage extends StatefulWidget {
  const TransactionHistoryPage({super.key});

  @override
  State<TransactionHistoryPage> createState() => _TransactionHistoryPageState();
}

class _TransactionHistoryPageState extends State<TransactionHistoryPage> {
  List<TransactionHistoryModel> _allTransactions = [];
  List<TransactionHistoryModel> _filteredTransactions = [];
  TransactionPeriod _selectedPeriod = TransactionPeriod.allTime;

  @override
  void initState() {
    _loadTransactions();
    super.initState();
  }

  void _loadTransactions() {
    final now = DateTime.now();
    _allTransactions = [
      TransactionHistoryModel(
        id: '1',
        amount: 25.50,
        type: TransactionHistoryModel.bankAccount,
        description: 'Withdrawal to bank account',
        dateTime: now.subtract(const Duration(hours: 2)),
        status: TransactionHistoryModel.completed,
      ),
      TransactionHistoryModel(
        id: '2',
        amount: 10.00,
        type: TransactionHistoryModel.mtnMobileMoney,
        description: 'Withdrawal to MTN Mobile Money',
        dateTime: now.subtract(const Duration(hours: 3)),
        status: TransactionHistoryModel.completed,
      ),
      TransactionHistoryModel(
        id: '3',
        amount: 38.00,
        type: TransactionHistoryModel.vodafoneCash,
        description: 'Withdrawal to Vodafone Cash',
        dateTime: now.subtract(const Duration(hours: 5)),
        status: TransactionHistoryModel.completed,
      ),
      TransactionHistoryModel(
        id: '4',
        amount: 42.00,
        type: TransactionHistoryModel.mtnMobileMoney,
        description: 'Withdrawal to MTN Mobile Money',
        dateTime: now.subtract(const Duration(days: 2, hours: 3)),
        status: TransactionHistoryModel.pending,
      ),
      TransactionHistoryModel(
        id: '5',
        amount: 5.00,
        type: TransactionHistoryModel.vodafoneCash,
        description: 'Withdrawal to Vodafone Cash',
        dateTime: now.subtract(const Duration(days: 3)),
        status: TransactionHistoryModel.pending,
      ),
      TransactionHistoryModel(
        id: '6',
        amount: 30.00,
        type: TransactionHistoryModel.mtnMobileMoney,
        description: 'Withdrawal to MTN Mobile Money',
        dateTime: now.subtract(const Duration(days: 4)),
        status: TransactionHistoryModel.pending,
      ),
      TransactionHistoryModel(
        id: '7',
        amount: 50.00,
        type: TransactionHistoryModel.vodafoneCash,
        description: 'Withdrawal to Vodafone Cash',
        dateTime: now.subtract(const Duration(days: 5)),
        status: TransactionHistoryModel.pending,
      ),
      TransactionHistoryModel(
        id: '8',
        amount: 35.00,
        type: TransactionHistoryModel.mtnMobileMoney,
        description: 'Withdrawal to MTN Mobile Money',
        dateTime: now.subtract(const Duration(days: 10)),
        status: TransactionHistoryModel.pending,
      ),
      TransactionHistoryModel(
        id: '9',
        amount: 15.00,
        type: TransactionHistoryModel.vodafoneCash,
        description: 'Withdrawal to Vodafone Cash',
        dateTime: now.subtract(const Duration(days: 12)),
        status: TransactionHistoryModel.pending,
      ),
      TransactionHistoryModel(
        id: '10',
        amount: 28.00,
        type: TransactionHistoryModel.mtnMobileMoney,
        description: 'Withdrawal to MTN Mobile Money',
        dateTime: now.subtract(const Duration(days: 15)),
        status: TransactionHistoryModel.pending,
      ),
      TransactionHistoryModel(
        id: '11',
        amount: 100.00,
        type: TransactionHistoryModel.vodafoneCash,
        description: 'Withdrawal to Vodafone Cash',
        dateTime: now.subtract(const Duration(days: 20)),
        status: TransactionHistoryModel.pending,
      ),
      TransactionHistoryModel(
        id: '12',
        amount: 22.00,
        type: TransactionHistoryModel.mtnMobileMoney,
        description: 'Withdrawal to MTN Mobile Money',
        dateTime: now.subtract(const Duration(days: 25)),
        status: TransactionHistoryModel.pending,
      ),
    ];

    _applyFilter();
  }

  void _applyFilter() {
    final now = DateTime.now();
    setState(() {
      switch (_selectedPeriod) {
        case TransactionPeriod.today:
          _filteredTransactions = _allTransactions.where((transaction) {
            return transaction.dateTime.year == now.year &&
                transaction.dateTime.month == now.month &&
                transaction.dateTime.day == now.day;
          }).toList();
          break;
        case TransactionPeriod.thisWeek:
          final weekStart = now.subtract(Duration(days: now.weekday - 1));
          _filteredTransactions = _allTransactions.where((transaction) {
            return transaction.dateTime.isAfter(weekStart.subtract(const Duration(days: 1)));
          }).toList();
          break;
        case TransactionPeriod.thisMonth:
          _filteredTransactions = _allTransactions.where((transaction) {
            return transaction.dateTime.year == now.year && transaction.dateTime.month == now.month;
          }).toList();
          break;
        case TransactionPeriod.allTime:
          _filteredTransactions = _allTransactions;
          break;
      }
      _filteredTransactions.sort((a, b) => b.dateTime.compareTo(a.dateTime));
    });
  }

  double _getTotalTransactions() {
    return _filteredTransactions.fold(0.0, (sum, transaction) => sum + transaction.amount);
  }

  Color _getTransactionTypeColor(TransactionType type, AppColorsExtension colors) {
    switch (type) {
      case TransactionType.mobileMoney:
        return colors.accentGreen;
      case TransactionType.bankAccount:
        return colors.accentGreen;
      case TransactionType.vodafoneCash:
        return colors.accentGreen;
      case TransactionType.mtnMobileMoney:
        return colors.accentGreen;
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
            "Transaction History",
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
            children: [
              SizedBox(height: 20.h),
              Container(
                padding: EdgeInsets.all(24.r),
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
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),

                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Total Transactions",
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
                            _getTotalTransactions().toStringAsFixed(2),
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
                      "${_filteredTransactions.length} ${_filteredTransactions.length == 1 ? 'transaction' : 'transactions'}",
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
                  Expanded(child: _buildPeriodFilter("Today", TransactionPeriod.today, colors)),
                  SizedBox(width: 8.w),
                  Expanded(child: _buildPeriodFilter("Week", TransactionPeriod.thisWeek, colors)),
                  SizedBox(width: 8.w),
                  Expanded(child: _buildPeriodFilter("Month", TransactionPeriod.thisMonth, colors)),
                  SizedBox(width: 8.w),
                  Expanded(child: _buildPeriodFilter("All", TransactionPeriod.allTime, colors)),
                ],
              ),
              SizedBox(height: 24.h),

              if (_filteredTransactions.isEmpty)
                _buildEmptyState(colors)
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _filteredTransactions.length,
                  separatorBuilder: (context, index) => SizedBox(height: 12.h),
                  itemBuilder: (context, index) {
                    final transaction = _filteredTransactions[index];
                    final typeColor = _getTransactionTypeColor(transaction.type, colors);
                    final iconPath = _getTransactionIcon(transaction.type);
                    final typeLabel = _getTransactionTypeLabel(transaction.type);

                    final timeFormat = DateFormat('MMM dd, hh:mm a');
                    final timeString = timeFormat.format(transaction.dateTime);

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
                                  transaction.description,
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
                                    Container(
                                      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                                      decoration: BoxDecoration(
                                        color: typeColor.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        typeLabel,
                                        style: TextStyle(
                                          color: typeColor,
                                          fontSize: 10.sp,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
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
                                "+GHC ${transaction.amount.toStringAsFixed(2)}",
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
                                  transaction.status.name.toUpperCase(),
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPeriodFilter(String label, TransactionPeriod period, AppColorsExtension colors) {
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
          border: Border.all(color: isSelected ? colors.accentGreen : colors.border, width: 1),
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
            "No transactions found",
            style: TextStyle(color: colors.textPrimary, fontSize: 18.sp, fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 8.h),
          Text(
            "No transactions recorded for this period.",
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.textSecondary, fontSize: 14.sp, fontWeight: FontWeight.w400),
          ),
        ],
      ),
    );
  }
}
