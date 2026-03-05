import 'package:dotted_line/dotted_line.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_rider/features/home/models/partner_models.dart';
import 'package:grab_go_rider/features/home/models/transaction_model.dart';
import 'package:grab_go_rider/features/home/service/rider_partner_service.dart';
import 'package:grab_go_rider/features/home/service/rider_wallet_service.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';

enum WalletTransactionPeriod { today, thisWeek, thisMonth, allTime }

extension WalletTransactionPeriodX on WalletTransactionPeriod {
  String get label {
    switch (this) {
      case WalletTransactionPeriod.today:
        return 'Today';
      case WalletTransactionPeriod.thisWeek:
        return 'This Week';
      case WalletTransactionPeriod.thisMonth:
        return 'This Month';
      case WalletTransactionPeriod.allTime:
        return 'All Time';
    }
  }

  String get apiValue {
    switch (this) {
      case WalletTransactionPeriod.today:
        return 'today';
      case WalletTransactionPeriod.thisWeek:
        return 'thisWeek';
      case WalletTransactionPeriod.thisMonth:
        return 'thisMonth';
      case WalletTransactionPeriod.allTime:
        return 'allTime';
    }
  }
}

class WalletPage extends StatefulWidget {
  const WalletPage({super.key});

  @override
  State<WalletPage> createState() => _WalletPageState();
}

class _WalletPageState extends State<WalletPage> {
  final RiderWalletService _walletService = RiderWalletService();
  final RiderPartnerService _partnerService = RiderPartnerService();

  List<TransactionModel> _allTransactions = [];
  double? _totalBalance;
  double? _todayEarnings;
  double? _thisWeekEarnings;
  double? _thisMonthEarnings;
  double? _totalEarnings;
  IncentiveBalance? _incentiveBalance;
  WithdrawalPolicy? _withdrawalPolicy;
  bool _isLoading = true;
  bool _isScrolled = false;
  String? _error;
  WalletTransactionPeriod _selectedPeriod = WalletTransactionPeriod.thisWeek;

  @override
  void initState() {
    super.initState();
    _loadWalletData();
  }

  Future<void> _loadWalletData({bool showLoadingState = true}) async {
    if (!mounted) return;

    if (showLoadingState) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final results = await Future.wait([
        _walletService.fetchDashboard(transactionsPeriod: _selectedPeriod.apiValue),
        _partnerService
            .fetchIncentiveBalance()
            .then<IncentiveBalance?>((v) => v)
            .catchError((_) => null as IncentiveBalance?),
        _partnerService
            .fetchWithdrawalPolicy()
            .then<WithdrawalPolicy?>((v) => v)
            .catchError((_) => null as WithdrawalPolicy?),
      ]);
      if (!mounted) return;

      final data = results[0] as dynamic;
      final incentiveBalance = results[1] as IncentiveBalance?;
      final withdrawalPolicy = results[2] as WithdrawalPolicy?;

      setState(() {
        _totalBalance = data.balance;
        _todayEarnings = data.todayEarnings;
        _thisWeekEarnings = data.thisWeekEarnings;
        _thisMonthEarnings = data.thisMonthEarnings;
        _totalEarnings = data.totalEarnings;
        _allTransactions = data.transactions;
        _incentiveBalance = incentiveBalance;
        _withdrawalPolicy = withdrawalPolicy;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = 'Failed to load wallet data';
      });
      AppToastMessage.show(
        context: context,
        showIcon: false,
        message: 'Failed to load wallet data. Pull down to retry.',
        backgroundColor: context.appColors.error,
        radius: KBorderSize.borderRadius4,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _formatCurrencyText(double? amount, {bool showSymbol = true}) {
    if (_isLoading) return '...';
    if (amount == null) return '--';
    final formatted = amount.toStringAsFixed(2);
    return showSymbol ? 'GHC $formatted' : formatted;
  }

  Future<void> _openPeriodFilter() async {
    final selected = await BlurOptionSelector.show<WalletTransactionPeriod>(
      context: context,
      title: 'Filter Transactions',
      subtitle: 'Choose a period',
      selectedValue: _selectedPeriod,
      options: WalletTransactionPeriod.values
          .map((period) => BlurOptionItem<WalletTransactionPeriod>(value: period, label: period.label))
          .toList(),
    );

    if (selected == null || selected == _selectedPeriod) return;

    setState(() {
      _selectedPeriod = selected;
    });
    await _loadWalletData();
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
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          final scrolled = notification.metrics.pixels > 0;
          if (scrolled != _isScrolled) {
            setState(() {
              _isScrolled = scrolled;
            });
          }
          return false;
        },
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
            bottom: _isScrolled
                ? PreferredSize(
                    preferredSize: Size.fromHeight(1),
                    child: Container(color: colors.backgroundSecondary, height: 1, width: double.infinity),
                  )
                : null,
            centerTitle: true,
            actionsPadding: EdgeInsets.only(right: 10.w),
          ),
          body: AppRefreshIndicator(
            onRefresh: () => _loadWalletData(),
            bgColor: colors.accentGreen,
            iconPath: Assets.icons.wallet,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.symmetric(horizontal: 20.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 20.h),

                  if (_error != null) ...[
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                      decoration: BoxDecoration(
                        color: colors.error.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
                        border: Border.all(color: colors.error.withValues(alpha: 0.2)),
                      ),
                      child: Text(
                        _error!,
                        style: TextStyle(color: colors.error, fontSize: 12.sp, fontWeight: FontWeight.w500),
                      ),
                    ),
                    SizedBox(height: 12.h),
                  ],

                  Stack(
                    children: [
                      Container(
                        padding: EdgeInsets.all(24.w),
                        decoration: BoxDecoration(
                          color: colors.accentGreen,
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
                              "TOTAL BALANCE",
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: 12.sp,
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
                                    _formatCurrencyText(_totalBalance, showSymbol: false),
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
                                  style: TextStyle(
                                    color: colors.textPrimary,
                                    fontSize: 15.sp,
                                    fontWeight: FontWeight.w600,
                                  ),
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
                      Expanded(
                        child: _buildQuickAction("Earnings", Assets.icons.cash, colors.accentGreen, colors, () {}),
                      ),
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
                              _formatCurrencyText(_totalEarnings),
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

                  if (_incentiveBalance != null) ...[SizedBox(height: 24.h), _buildIncentiveBalanceCard(colors)],

                  if (_withdrawalPolicy != null) ...[SizedBox(height: 24.h), _buildWithdrawalPolicyCard(colors)],

                  SizedBox(height: 24.h),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Transaction History",
                        style: TextStyle(color: colors.textPrimary, fontSize: 18.sp, fontWeight: FontWeight.w700),
                      ),
                      GestureDetector(
                        onTap: _openPeriodFilter,
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                          decoration: BoxDecoration(
                            color: colors.backgroundPrimary,
                            borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _selectedPeriod.label,
                                style: TextStyle(
                                  color: colors.textPrimary,
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                              SizedBox(width: 10.w),
                              SvgPicture.asset(
                                Assets.icons.navArrowDown,
                                package: 'grab_go_shared',
                                width: 14.w,
                                height: 14.h,
                                colorFilter: ColorFilter.mode(colors.textPrimary, BlendMode.srcIn),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 6.h),

                  _buildTransactionsSection(colors, isDark),

                  SizedBox(height: 32.h),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBalanceStat(String label, double? amount, AppColorsExtension colors) {
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
            _formatCurrencyText(amount),
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

  Widget _buildEarningsRow(String period, double? amount, AppColorsExtension colors) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          period,
          style: TextStyle(color: colors.textPrimary, fontSize: 14.sp, fontWeight: FontWeight.w500),
        ),
        Text(
          _formatCurrencyText(amount),
          style: TextStyle(color: colors.textPrimary, fontSize: 16.sp, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }

  Widget _buildTransactionsSection(AppColorsExtension colors, bool isDark) {
    if (_isLoading) {
      return Column(
        children: List.generate(
          4,
          (_) => Padding(
            padding: EdgeInsets.only(bottom: 12.h),
            child: _buildTransactionSkeletonCard(colors, isDark),
          ),
        ),
      );
    }

    if (_allTransactions.isEmpty) {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 18.h),
        decoration: BoxDecoration(
          color: colors.backgroundPrimary,
          borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
        ),
        child: Text(
          'No transactions yet',
          style: TextStyle(color: colors.textSecondary, fontSize: 13.sp, fontWeight: FontWeight.w500),
        ),
      );
    }

    return ListView.separated(
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _allTransactions.length,
      separatorBuilder: (context, index) => SizedBox(height: 12.h),
      itemBuilder: (context, index) {
        final transaction = _allTransactions[index];
        final typeColor = _getTransactionTypeColor(transaction.type, colors);
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      transaction.description,
                      style: TextStyle(color: colors.textPrimary, fontSize: 14.sp, fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 8.h),
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
                  SizedBox(height: 8.h),
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
    );
  }

  Widget _buildIncentiveBalanceCard(AppColorsExtension colors) {
    final balance = _incentiveBalance!;
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: colors.backgroundPrimary,
        borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                "INCENTIVE BALANCE",
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          SizedBox(height: 20.h),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Available",
                      style: TextStyle(color: colors.textSecondary, fontSize: 12.sp, fontWeight: FontWeight.w400),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      'GHC ${balance.availableForPayout.toStringAsFixed(2)}',
                      style: TextStyle(color: colors.accentGreen, fontSize: 20.sp, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Pending",
                      style: TextStyle(color: colors.textSecondary, fontSize: 12.sp, fontWeight: FontWeight.w400),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      'GHC ${balance.pendingBudgetApproval.toStringAsFixed(2)}',
                      style: TextStyle(color: colors.warning, fontSize: 20.sp, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
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
                "TOTAL EARNED",
                style: TextStyle(
                  color: colors.accentGreen,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                'GHC ${balance.total.toStringAsFixed(2)}',
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
    );
  }

  Widget _buildWithdrawalPolicyCard(AppColorsExtension colors) {
    final policy = _withdrawalPolicy!;
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: colors.backgroundPrimary,
        borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "WITHDRAWAL POLICY",
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 11.sp,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),
          SizedBox(height: 16.h),
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8.r),
                decoration: BoxDecoration(
                  color: colors.accentGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
                ),
                child: SvgPicture.asset(
                  Assets.icons.shieldCheck,
                  package: 'grab_go_shared',
                  width: 18.w,
                  height: 18.w,
                  colorFilter: ColorFilter.mode(colors.accentGreen, BlendMode.srcIn),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Level ${partnerLevelLabel(policy.partnerLevel)} Benefits',
                      style: TextStyle(color: colors.textPrimary, fontSize: 14.sp, fontWeight: FontWeight.w600),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      policy.instantWithdrawal.totalQuota > 0
                          ? '${policy.instantWithdrawal.freeRemaining} of ${policy.instantWithdrawal.totalQuota} free instant withdrawals left'
                          : 'Instant withdrawal fee: ${(policy.instantWithdrawal.fee * 100).toStringAsFixed(1)}%',
                      style: TextStyle(color: colors.textSecondary, fontSize: 12.sp, fontWeight: FontWeight.w400),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionSkeletonCard(AppColorsExtension colors, bool isDark) {
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: colors.backgroundPrimary,
        borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
      ),
      child: Shimmer.fromColors(
        baseColor: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
        highlightColor: isDark ? Colors.grey.shade700 : Colors.grey.shade100,
        child: Row(
          children: [
            Container(
              width: 46.w,
              height: 46.w,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
              ),
            ),
            SizedBox(width: 14.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 14.h,
                    width: 180.w,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Row(
                    children: [
                      Container(
                        height: 11.h,
                        width: 62.w,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
                        ),
                      ),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: Container(
                          height: 11.h,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(width: 10.w),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  height: 14.h,
                  width: 82.w,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
                  ),
                ),
                SizedBox(height: 8.h),
                Container(
                  height: 16.h,
                  width: 56.w,
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4.r)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
