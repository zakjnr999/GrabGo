import 'package:dotted_line/dotted_line.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_rider/features/home/models/transaction_model.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:intl/intl.dart';

class WalletPage extends StatefulWidget {
  const WalletPage({super.key});

  @override
  State<WalletPage> createState() => _WalletPageState();
}

class _WalletPageState extends State<WalletPage> {
  List<TransactionModel> _allTransactions = [];
  final double _totalBalance = 184.90;
  final double _todayEarnings = 45.50;
  final double _thisWeekEarnings = 320.75;
  final double _thisMonthEarnings = 1250.30;

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  void _loadTransactions() {
    final now = DateTime.now();
    _allTransactions = [
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
        amount: 150.00,
        type: TransactionType.withdrawal,
        description: 'Withdrawal to bank account',
        dateTime: now.subtract(const Duration(days: 1)),
        status: TransactionStatus.completed,
      ),
      TransactionModel(
        id: '5',
        amount: 50.00,
        type: TransactionType.bonus,
        description: 'Weekend bonus',
        dateTime: now.subtract(const Duration(days: 2)),
        status: TransactionStatus.completed,
      ),
      TransactionModel(
        id: '6',
        amount: 42.00,
        type: TransactionType.delivery,
        description: 'Delivery to Labone',
        dateTime: now.subtract(const Duration(days: 2, hours: 3)),
        status: TransactionStatus.completed,
      ),
      TransactionModel(
        id: '7',
        amount: 5.00,
        type: TransactionType.tip,
        description: 'Tip from customer',
        dateTime: now.subtract(const Duration(days: 3)),
        status: TransactionStatus.completed,
      ),
      TransactionModel(
        id: '8',
        amount: 30.00,
        type: TransactionType.delivery,
        description: 'Delivery to Osu',
        dateTime: now.subtract(const Duration(days: 4)),
        status: TransactionStatus.completed,
      ),
    ];
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
          title: Text(
            "Wallet",
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
        body: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.symmetric(horizontal: 20.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 20.h),

              Stack(
                children: [
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
                          color: colors.accentGreen.withValues(alpha: 0.2),
                          blurRadius: 12,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Total Balance",
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
                                _totalBalance.toStringAsFixed(2),
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
                        SizedBox(height: 20.h),
                        Row(
                          children: [
                            Expanded(child: _buildBalanceStat("Today", _todayEarnings, colors)),
                            SizedBox(width: 16.w),
                            Expanded(child: _buildBalanceStat("This Week", _thisWeekEarnings, colors)),
                          ],
                        ),
                      ],
                    ),
                  ),

                  Positioned(
                    top: 10.r,
                    right: 10.r,
                    child: Opacity(
                      opacity: 0.65,
                      child: SvgPicture.asset(
                        Assets.icons.wallet,
                        package: "grab_go_shared",
                        height: 40.h,
                        width: 40.w,
                        colorFilter: ColorFilter.mode(Colors.white, BlendMode.srcIn),
                      ),
                    ),
                  ),
                ],
              ),

              SizedBox(height: 24.h),

              Container(
                decoration: BoxDecoration(
                  color: colors.backgroundPrimary,
                  borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => context.push("/loanApplication"),
                    borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
                      child: Row(
                        children: [
                          Container(
                            width: 40.w,
                            height: 40.w,
                            decoration: BoxDecoration(
                              color: colors.accentGreen.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
                            ),
                            child: Center(
                              child: SvgPicture.asset(
                                Assets.icons.handCash,
                                package: 'grab_go_shared',
                                width: 20.w,
                                height: 20.w,
                                colorFilter: ColorFilter.mode(colors.accentGreen, BlendMode.srcIn),
                              ),
                            ),
                          ),
                          SizedBox(width: 16.w),
                          Expanded(
                            child: Text(
                              "Request for loan",
                              style: TextStyle(color: colors.textPrimary, fontSize: 15.sp, fontWeight: FontWeight.w600),
                            ),
                          ),
                          SvgPicture.asset(
                            Assets.icons.navArrowRight,
                            package: 'grab_go_shared',
                            width: 20.w,
                            height: 20.w,
                            colorFilter: ColorFilter.mode(colors.textSecondary, BlendMode.srcIn),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              SizedBox(height: 24.h),

              Row(
                children: [
                  Expanded(
                    child: _buildQuickAction("Withdraw", Assets.icons.wallet, colors.accentGreen, colors, () {
                      context.push("/withdrawal-page");
                    }),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(child: _buildQuickAction("Earnings", Assets.icons.cash, colors.accentGreen, colors, () {})),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: _buildQuickAction("History", Assets.icons.clock, colors.accentGreen, colors, () {
                      context.push("/transaction-history-page");
                    }),
                  ),
                ],
              ),

              SizedBox(height: 24.h),

              Container(
                padding: EdgeInsets.all(20.w),
                decoration: BoxDecoration(
                  color: colors.backgroundPrimary,
                  borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "EARNINGS SUMMARY",
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.2,
                      ),
                    ),
                    SizedBox(height: 20.h),
                    _buildEarningsRow("Today", _todayEarnings, colors),
                    SizedBox(height: 16.h),
                    _buildEarningsRow("This Week", _thisWeekEarnings, colors),
                    SizedBox(height: 16.h),
                    _buildEarningsRow("This Month", _thisMonthEarnings, colors),
                    SizedBox(height: 20.h),
                    DottedLine(
                      direction: Axis.horizontal,
                      lineLength: double.infinity,
                      lineThickness: 1.5,
                      dashLength: 6,
                      dashColor: colors.inputBorder.withValues(alpha: 0.65),
                      dashGapLength: 4,
                    ),
                    SizedBox(height: 12.h),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "TOTAL EARNINGS",
                          style: TextStyle(
                            color: colors.accentGreen,
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                        Text(
                          "GHC ${_thisMonthEarnings.toStringAsFixed(2)}",
                          style: TextStyle(
                            color: colors.accentGreen,
                            fontSize: 18.sp,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              SizedBox(height: 24.h),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Transaction History",
                    style: TextStyle(color: colors.textPrimary, fontSize: 18.sp, fontWeight: FontWeight.w700),
                  ),
                  TextButton(
                    onPressed: () {},
                    child: Row(
                      children: [
                        Text(
                          "All",
                          style: TextStyle(color: colors.accentGreen, fontSize: 14.sp, fontWeight: FontWeight.w600),
                        ),
                        SizedBox(width: 4.w),
                        SvgPicture.asset(
                          Assets.icons.navArrowRight,
                          package: 'grab_go_shared',
                          width: 16.w,
                          height: 16.w,
                          colorFilter: ColorFilter.mode(colors.accentGreen, BlendMode.srcIn),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              SizedBox(height: 6.h),

              ListView.separated(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _allTransactions.length,
                separatorBuilder: (context, index) => SizedBox(height: 12.h),
                itemBuilder: (context, index) {
                  final transaction = _allTransactions[index];
                  final typeColor = _getTransactionTypeColor(transaction.type, colors);
                  final iconPath = _getTransactionIcon(transaction.type);
                  final typeLabel = _getTransactionTypeLabel(transaction.type);

                  final timeFormat = DateFormat('MMM dd, hh:mm a');
                  final timeString = timeFormat.format(transaction.dateTime);

                  final isWithdrawal = transaction.type == TransactionType.withdrawal;

                  return Container(
                    padding: EdgeInsets.all(14.w),
                    decoration: BoxDecoration(
                      color: colors.backgroundPrimary,
                      borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
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
                              SizedBox(height: 4.h),
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
                        SizedBox(width: 4.w),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              "${isWithdrawal ? '-' : '+'}GHC ${transaction.amount.toStringAsFixed(2)}",
                              style: TextStyle(
                                color: isWithdrawal ? colors.error : colors.accentGreen,
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(height: 2.h),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                              decoration: BoxDecoration(
                                color: transaction.status == TransactionStatus.completed
                                    ? colors.success.withValues(alpha: 0.15)
                                    : transaction.status == TransactionStatus.pending
                                    ? colors.warning.withValues(alpha: 0.15)
                                    : colors.error.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                transaction.status.name.toUpperCase(),
                                style: TextStyle(
                                  color: transaction.status == TransactionStatus.completed
                                      ? colors.success
                                      : transaction.status == TransactionStatus.pending
                                      ? colors.warning
                                      : colors.error,
                                  fontSize: 9.sp,
                                  fontWeight: FontWeight.w600,
                                ),
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

  Widget _buildBalanceStat(String label, double amount, AppColorsExtension colors) {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 11.sp, fontWeight: FontWeight.w500),
          ),
          SizedBox(height: 4.h),
          Text(
            "GHC ${amount.toStringAsFixed(2)}",
            style: TextStyle(color: Colors.white, fontSize: 16.sp, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAction(String label, String icon, Color color, AppColorsExtension colors, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 16.h, horizontal: 12.w),
        decoration: BoxDecoration(
          color: colors.backgroundPrimary,
          borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
        ),
        child: Column(
          children: [
            Container(
              width: 40.w,
              height: 40.w,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
              ),
              child: Center(
                child: SvgPicture.asset(
                  icon,
                  package: 'grab_go_shared',
                  width: 20.w,
                  height: 20.w,
                  colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
                ),
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              label,
              style: TextStyle(color: colors.textPrimary, fontSize: 12.sp, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEarningsRow(String period, double amount, AppColorsExtension colors) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          period,
          style: TextStyle(color: colors.textPrimary, fontSize: 14.sp, fontWeight: FontWeight.w500),
        ),
        Text(
          "GHC ${amount.toStringAsFixed(2)}",
          style: TextStyle(color: colors.textPrimary, fontSize: 16.sp, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}
