import 'package:dotted_line/dotted_line.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_rider/features/home/models/partner_models.dart';
import 'package:grab_go_rider/features/home/service/rider_partner_service.dart';
import 'package:grab_go_rider/features/home/service/rider_wallet_service.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:shimmer/shimmer.dart';

// ─── Withdrawal method model ───
enum WithdrawalMethod { mtnMobileMoney, vodafoneCash, bankAccount }

extension WithdrawalMethodX on WithdrawalMethod {
  String get label {
    switch (this) {
      case WithdrawalMethod.mtnMobileMoney:
        return 'MTN Mobile Money';
      case WithdrawalMethod.vodafoneCash:
        return 'Vodafone Cash';
      case WithdrawalMethod.bankAccount:
        return 'Bank Account';
    }
  }

  String get apiValue {
    switch (this) {
      case WithdrawalMethod.mtnMobileMoney:
        return 'mtn_mobile_money';
      case WithdrawalMethod.vodafoneCash:
        return 'vodafone_cash';
      case WithdrawalMethod.bankAccount:
        return 'bank_account';
    }
  }

  String get shortLabel {
    switch (this) {
      case WithdrawalMethod.mtnMobileMoney:
        return 'MTN MoMo';
      case WithdrawalMethod.vodafoneCash:
        return 'Vodafone Cash';
      case WithdrawalMethod.bankAccount:
        return 'Bank Account';
    }
  }
}

class WithdrawalPage extends StatefulWidget {
  const WithdrawalPage({super.key});

  @override
  State<WithdrawalPage> createState() => _WithdrawalPageState();
}

class _WithdrawalPageState extends State<WithdrawalPage> {
  final RiderWalletService _walletService = RiderWalletService();
  final RiderPartnerService _partnerService = RiderPartnerService();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _accountController = TextEditingController();

  // Real data from API
  double _availableBalance = 0;
  double _pendingWithdrawals = 0;
  WithdrawalPolicy? _withdrawalPolicy;
  bool _isLoadingData = true;
  bool _isProcessing = false;

  // Selected method
  WithdrawalMethod _selectedMethod = WithdrawalMethod.mtnMobileMoney;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _accountController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoadingData = true);

    try {
      final results = await Future.wait([
        _walletService.fetchDashboard(),
        _partnerService
            .fetchWithdrawalPolicy()
            .then<WithdrawalPolicy?>((v) => v)
            .catchError((_) => null as WithdrawalPolicy?),
      ]);

      if (!mounted) return;

      final walletData = results[0] as RiderWalletDashboardData;
      final policy = results[1] as WithdrawalPolicy?;

      setState(() {
        _availableBalance = walletData.balance - walletData.pendingWithdrawals;
        _pendingWithdrawals = walletData.pendingWithdrawals;
        _withdrawalPolicy = policy;
        _isLoadingData = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingData = false);
    }
  }

  // ─── Derived values ───

  double get _minWithdrawal => _withdrawalPolicy?.minWithdrawalAmount ?? 50.0;

  double get _withdrawalFee {
    if (_withdrawalPolicy == null) return 0;
    return _withdrawalPolicy!.instantWithdrawal.fee;
  }

  bool get _isFreeWithdrawal {
    if (_withdrawalPolicy == null) return false;
    return _withdrawalPolicy!.instantWithdrawal.isFree;
  }

  int get _freeWithdrawalsRemaining {
    if (_withdrawalPolicy == null) return 0;
    return _withdrawalPolicy!.instantWithdrawal.freeRemaining;
  }

  int get _totalFreeQuota {
    if (_withdrawalPolicy == null) return 0;
    return _withdrawalPolicy!.instantWithdrawal.totalQuota;
  }

  double? _getEnteredAmount() {
    final text = _amountController.text.trim();
    if (text.isEmpty) return null;
    return double.tryParse(text);
  }

  bool _isValidAmount() {
    final amount = _getEnteredAmount();
    if (amount == null) return false;
    return amount >= _minWithdrawal && amount <= _availableBalance;
  }

  bool get _hasValidAccount => _accountController.text.trim().isNotEmpty;

  double _getNetAmount() {
    final amount = _getEnteredAmount();
    if (amount == null) return 0;
    return (amount - _withdrawalFee).clamp(0, double.infinity);
  }

  void _setQuickAmount(double amount) {
    if (amount <= _availableBalance) {
      setState(() {
        _amountController.text = amount.toStringAsFixed(2);
      });
    }
  }

  String? _getValidationError() {
    final amount = _getEnteredAmount();
    if (amount == null) return null;
    if (amount < _minWithdrawal) {
      return "Minimum withdrawal is GHC ${_minWithdrawal.toStringAsFixed(2)}";
    }
    if (amount > _availableBalance) {
      return "Insufficient balance";
    }
    return null;
  }

  // ─── Confirmation & Submit ───

  void _showConfirmationSheet() {
    if (!_isValidAmount() || !_hasValidAccount) return;

    final colors = context.appColors;
    final amount = _getEnteredAmount()!;
    final fee = _withdrawalFee;
    final net = _getNetAmount();
    final account = _accountController.text.trim();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isDismissible: !_isProcessing,
      enableDrag: !_isProcessing,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (sheetCtx, setSheetState) => PopScope(
          canPop: !_isProcessing,
          child: Container(
            padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 32.h),
            decoration: BoxDecoration(
              color: colors.backgroundPrimary,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Drag handle ──
                Container(
                  width: 40.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: colors.border,
                    borderRadius: BorderRadius.circular(KBorderSize.borderRadius20),
                  ),
                ),
                SizedBox(height: 20.h),

                // ── Shield icon ──
                Container(
                  width: 56.w,
                  height: 56.w,
                  decoration: BoxDecoration(color: colors.accentGreen.withValues(alpha: 0.1), shape: BoxShape.circle),
                  child: Center(
                    child: SvgPicture.asset(
                      Assets.icons.shieldCheck,
                      package: 'grab_go_shared',
                      width: 28.w,
                      height: 28.w,
                      colorFilter: ColorFilter.mode(colors.accentGreen, BlendMode.srcIn),
                    ),
                  ),
                ),
                SizedBox(height: 16.h),

                Text(
                  "Confirm Withdrawal",
                  style: TextStyle(color: colors.textPrimary, fontSize: 20.sp, fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 6.h),
                Text(
                  "Please review the details below before confirming.",
                  style: TextStyle(color: colors.textSecondary, fontSize: 13.sp),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 24.h),

                // ── Summary ──
                Container(
                  padding: EdgeInsets.all(16.w),
                  decoration: BoxDecoration(
                    color: colors.backgroundSecondary,
                    borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
                  ),
                  child: Column(
                    children: [
                      _buildSummaryRow("Amount", "GHC ${amount.toStringAsFixed(2)}", colors),
                      SizedBox(height: 10.h),
                      _buildSummaryRow("Method", _selectedMethod.shortLabel, colors),
                      SizedBox(height: 10.h),
                      _buildSummaryRow("Account", account, colors),
                      SizedBox(height: 10.h),
                      _buildSummaryRow(
                        "Fee",
                        _isFreeWithdrawal ? "FREE" : "GHC ${fee.toStringAsFixed(2)}",
                        colors,
                        valueColor: _isFreeWithdrawal ? colors.accentGreen : null,
                      ),
                      SizedBox(height: 10.h),
                      DottedLine(
                        direction: Axis.horizontal,
                        lineLength: double.infinity,
                        lineThickness: 1.4,
                        dashLength: 6,
                        dashGapLength: 4,
                        dashColor: colors.inputBorder.withValues(alpha: 0.65),
                      ),
                      SizedBox(height: 10.h),
                      _buildSummaryRow("You'll Receive", "GHC ${net.toStringAsFixed(2)}", colors, isTotal: true),
                    ],
                  ),
                ),
                SizedBox(height: 24.h),

                // ── Confirm button ──
                SizedBox(
                  width: double.infinity,
                  height: 52.h,
                  child: ElevatedButton(
                    onPressed: _isProcessing
                        ? null
                        : () {
                            Navigator.of(sheetCtx).pop();
                            _executeWithdrawal();
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.accentGreen,
                      disabledBackgroundColor: colors.accentGreen.withValues(alpha: 0.5),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(KBorderSize.borderRadius4)),
                    ),
                    child: Text(
                      "Confirm & Withdraw",
                      style: TextStyle(
                        fontFamily: "Lato",
                        package: "grab_go_shared",
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 12.h),

                // ── Cancel button ──
                SizedBox(
                  width: double.infinity,
                  height: 48.h,
                  child: TextButton(
                    onPressed: _isProcessing ? null : () => Navigator.of(sheetCtx).pop(),
                    style: TextButton.styleFrom(
                      foregroundColor: colors.textSecondary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
                        side: BorderSide(color: colors.border),
                      ),
                    ),
                    child: Text(
                      "Cancel",
                      style: TextStyle(
                        fontFamily: "Lato",
                        package: "grab_go_shared",
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _executeWithdrawal() async {
    if (!_isValidAmount() || !_hasValidAccount) return;

    setState(() => _isProcessing = true);

    try {
      await _walletService.requestWithdrawal(
        amount: _getEnteredAmount()!,
        withdrawalMethod: _selectedMethod.apiValue,
        withdrawalAccount: _accountController.text.trim(),
      );

      if (!mounted) return;

      // Bust cached wallet data so wallet page refreshes
      RiderPartnerService.invalidateAll();

      AppToastMessage.show(
        context: context,
        showIcon: false,
        message: 'Withdrawal request submitted successfully!',
        backgroundColor: context.appColors.accentGreen,
        radius: KBorderSize.borderRadius4,
      );

      context.pop(true);
    } catch (e) {
      if (!mounted) return;

      final message = e.toString().replaceFirst('Exception: ', '');
      AppToastMessage.show(
        context: context,
        showIcon: false,
        message: message,
        backgroundColor: context.appColors.error,
        radius: KBorderSize.borderRadius4,
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  // ─── Method picker ───

  void _showMethodPicker() {
    final colors = context.appColors;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        padding: EdgeInsets.all(20.w),
        decoration: BoxDecoration(
          color: colors.backgroundPrimary,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: colors.border,
                  borderRadius: BorderRadius.circular(KBorderSize.borderRadius20),
                ),
              ),
            ),
            SizedBox(height: 20.h),
            Text(
              "Choose Withdrawal Method",
              style: TextStyle(color: colors.textPrimary, fontSize: 18.sp, fontWeight: FontWeight.w700),
            ),
            SizedBox(height: 20.h),
            _buildMethodOption(
              sheetContext,
              WithdrawalMethod.mtnMobileMoney,
              'MTN Mobile Money',
              Assets.icons.mom,
              colors,
            ),
            SizedBox(height: 12.h),
            _buildMethodOptionSvg(
              sheetContext,
              WithdrawalMethod.bankAccount,
              'Bank Account',
              Assets.icons.creditCard,
              colors,
            ),
            SizedBox(height: 16.h),
          ],
        ),
      ),
    );
  }

  Widget _buildMethodOption(
    BuildContext sheetContext,
    WithdrawalMethod method,
    String label,
    AssetGenImage image,
    AppColorsExtension colors,
  ) {
    final isSelected = _selectedMethod == method;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() => _selectedMethod = method);
          Navigator.pop(sheetContext);
        },
        borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
          decoration: BoxDecoration(
            color: isSelected ? colors.accentGreen.withValues(alpha: 0.06) : null,
            borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
            border: isSelected ? Border.all(color: colors.accentGreen, width: 1.5) : null,
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
                child: image.image(package: 'grab_go_shared', height: 40.h, width: 60.w, fit: BoxFit.cover),
              ),
              SizedBox(width: 16.w),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(color: colors.textPrimary, fontSize: 14.sp, fontWeight: FontWeight.w600),
                ),
              ),
              if (isSelected)
                SvgPicture.asset(
                  Assets.icons.checkCircleSolid,
                  package: 'grab_go_shared',
                  width: 20.w,
                  height: 20.w,
                  colorFilter: ColorFilter.mode(colors.accentGreen, BlendMode.srcIn),
                )
              else
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
    );
  }

  Widget _buildMethodOptionSvg(
    BuildContext sheetContext,
    WithdrawalMethod method,
    String label,
    String svgAsset,
    AppColorsExtension colors,
  ) {
    final isSelected = _selectedMethod == method;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() => _selectedMethod = method);
          Navigator.pop(sheetContext);
        },
        borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
          decoration: BoxDecoration(
            color: isSelected ? colors.accentGreen.withValues(alpha: 0.06) : null,
            borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
            border: isSelected ? Border.all(color: colors.accentGreen, width: 1.5) : null,
          ),
          child: Row(
            children: [
              Container(
                width: 60.w,
                height: 40.h,
                decoration: BoxDecoration(
                  color: colors.accentGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
                ),
                child: Center(
                  child: SvgPicture.asset(
                    svgAsset,
                    package: 'grab_go_shared',
                    width: 24.w,
                    height: 24.w,
                    colorFilter: ColorFilter.mode(colors.accentGreen, BlendMode.srcIn),
                  ),
                ),
              ),
              SizedBox(width: 16.w),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(color: colors.textPrimary, fontSize: 14.sp, fontWeight: FontWeight.w600),
                ),
              ),
              if (isSelected)
                SvgPicture.asset(
                  Assets.icons.checkCircleSolid,
                  package: 'grab_go_shared',
                  width: 20.w,
                  height: 20.w,
                  colorFilter: ColorFilter.mode(colors.accentGreen, BlendMode.srcIn),
                )
              else
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
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  BUILD
  // ═══════════════════════════════════════════════════════════════════════════

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
            "Withdrawal",
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
        body: _isLoadingData ? _buildSkeleton(colors, isDark) : _buildContent(colors),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  MAIN CONTENT
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildContent(AppColorsExtension colors) {
    final validationError = _amountController.text.isNotEmpty ? _getValidationError() : null;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Balance card ──
          _buildBalanceCard(colors),

          // ── Free withdrawals remaining badge ──
          if (_withdrawalPolicy != null && _totalFreeQuota > 0) ...[
            SizedBox(height: 12.h),
            _buildFreeWithdrawalsBadge(colors),
          ],

          SizedBox(height: 24.h),

          // ── Withdrawal method ──
          _buildSectionHeader("WITHDRAWAL METHOD", colors),
          SizedBox(height: 12.h),
          _buildMethodCard(colors),

          SizedBox(height: 24.h),

          // ── Account details ──
          _buildSectionHeader("ACCOUNT DETAILS", colors),
          SizedBox(height: 12.h),
          _buildAccountInput(colors),

          SizedBox(height: 24.h),

          // ── Amount ──
          _buildSectionHeader("WITHDRAWAL AMOUNT", colors),
          SizedBox(height: 12.h),
          _buildAmountInput(colors),

          // ── Validation error ──
          if (validationError != null) ...[SizedBox(height: 12.h), _buildValidationError(validationError, colors)],

          SizedBox(height: 24.h),

          // ── Summary ──
          if (_isValidAmount()) ...[_buildSummaryCard(colors), SizedBox(height: 24.h)],

          // ── Info notes ──
          _buildSectionHeader("GOOD TO KNOW", colors),
          SizedBox(height: 16.h),
          _buildInfoCard(
            colors: colors,
            icon: Assets.icons.clock,
            iconColor: colors.accentGreen,
            title: "Processing Time",
            description:
                "Instant withdrawals are processed immediately. Bank transfers may take 1\u20133 business days.",
          ),
          SizedBox(height: 12.h),
          _buildInfoCard(
            colors: colors,
            icon: Assets.icons.infoCircle,
            iconColor: colors.accentGreen,
            title: "Withdrawal Fee",
            description: _isFreeWithdrawal
                ? "This withdrawal is free! You have $_freeWithdrawalsRemaining of $_totalFreeQuota free withdrawals left this week."
                : "A fee of GHC ${_withdrawalFee.toStringAsFixed(2)} applies. Upgrade your partner level for free withdrawals.",
          ),
          SizedBox(height: 12.h),
          _buildInfoCard(
            colors: colors,
            icon: Assets.icons.shieldCheck,
            iconColor: colors.accentGreen,
            title: "Secure Transaction",
            description: "Your withdrawal is secured with bank-level encryption.",
          ),

          SizedBox(height: 32.h),

          // ── Submit button ──
          SizedBox(
            width: double.infinity,
            height: 56.h,
            child: ElevatedButton(
              onPressed: _isValidAmount() && _hasValidAccount && !_isProcessing ? _showConfirmationSheet : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.accentGreen,
                disabledBackgroundColor: colors.accentGreen.withValues(alpha: 0.5),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(KBorderSize.borderRadius4)),
              ),
              child: _isProcessing
                  ? SizedBox(
                      width: 24.w,
                      height: 24.w,
                      child: const CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      "Request Withdrawal",
                      style: TextStyle(
                        fontFamily: "Lato",
                        package: "grab_go_shared",
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
            ),
          ),

          SizedBox(height: 16.h),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  BALANCE CARD
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildBalanceCard(AppColorsExtension colors) {
    return Container(
      padding: EdgeInsets.all(24.w),
      decoration: BoxDecoration(
        color: colors.accentGreen,
        borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "AVAILABLE BALANCE",
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
                  _availableBalance.toStringAsFixed(2),
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
          if (_pendingWithdrawals > 0) ...[
            SizedBox(height: 12.h),
            Row(
              children: [
                SvgPicture.asset(
                  Assets.icons.clock,
                  package: 'grab_go_shared',
                  width: 14.w,
                  height: 14.w,
                  colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                ),
                SizedBox(width: 6.w),
                Text(
                  'GHC ${_pendingWithdrawals.toStringAsFixed(2)} pending',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  FREE WITHDRAWALS BADGE
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildFreeWithdrawalsBadge(AppColorsExtension colors) {
    final remaining = _freeWithdrawalsRemaining;
    final total = _totalFreeQuota;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: remaining > 0 ? colors.accentGreen.withValues(alpha: 0.08) : colors.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
        border: Border.all(
          color: remaining > 0 ? colors.accentGreen.withValues(alpha: 0.2) : colors.warning.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          SvgPicture.asset(
            remaining > 0 ? Assets.icons.checkCircleSolid : Assets.icons.warningCircle,
            package: 'grab_go_shared',
            width: 16.w,
            height: 16.w,
            colorFilter: ColorFilter.mode(remaining > 0 ? colors.accentGreen : colors.warning, BlendMode.srcIn),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Text(
              remaining > 0
                  ? '$remaining of $total free instant withdrawals remaining this week'
                  : 'No free withdrawals left. Fee of GHC ${_withdrawalFee.toStringAsFixed(2)} applies.',
              style: TextStyle(
                color: remaining > 0 ? colors.accentGreen : colors.warning,
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  METHOD CARD
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildMethodCard(AppColorsExtension colors) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _showMethodPicker,
        borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
        child: Container(
          padding: EdgeInsets.all(16.w),
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
                  color: colors.accentGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
                ),
                child: Center(
                  child: SvgPicture.asset(
                    Assets.icons.creditCard,
                    package: 'grab_go_shared',
                    width: 24.w,
                    height: 24.w,
                    colorFilter: ColorFilter.mode(colors.accentGreen, BlendMode.srcIn),
                  ),
                ),
              ),
              SizedBox(width: 16.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selectedMethod.label,
                      style: TextStyle(color: colors.textPrimary, fontSize: 14.sp, fontWeight: FontWeight.w600),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      "Tap to change",
                      style: TextStyle(color: colors.textSecondary, fontSize: 12.sp, fontWeight: FontWeight.w400),
                    ),
                  ],
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
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  ACCOUNT INPUT
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildAccountInput(AppColorsExtension colors) {
    final isMomo =
        _selectedMethod == WithdrawalMethod.mtnMobileMoney || _selectedMethod == WithdrawalMethod.vodafoneCash;

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: colors.backgroundPrimary,
        borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isMomo ? "Phone Number" : "Account Number",
            style: TextStyle(color: colors.textSecondary, fontSize: 12.sp, fontWeight: FontWeight.w500),
          ),
          SizedBox(height: 8.h),
          TextField(
            controller: _accountController,
            keyboardType: isMomo ? TextInputType.phone : TextInputType.text,
            inputFormatters: isMomo
                ? [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)]
                : [],
            style: TextStyle(
              fontFamily: "Lato",
              package: "grab_go_shared",
              color: colors.textPrimary,
              fontSize: 16.sp,
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              hintText: isMomo ? "e.g. 0241234567" : "e.g. 1234567890",
              hintStyle: TextStyle(
                color: colors.textSecondary.withValues(alpha: 0.5),
                fontSize: 16.sp,
                fontWeight: FontWeight.w400,
              ),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  AMOUNT INPUT
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildAmountInput(AppColorsExtension colors) {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: colors.backgroundPrimary,
        borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
            style: TextStyle(
              fontFamily: "Lato",
              package: "grab_go_shared",
              color: colors.textPrimary,
              fontSize: 24.sp,
              fontWeight: FontWeight.w700,
            ),
            decoration: InputDecoration(
              prefixText: "GHC ",
              prefixStyle: TextStyle(
                fontFamily: "Lato",
                package: "grab_go_shared",
                color: colors.textPrimary,
                fontSize: 24.sp,
                fontWeight: FontWeight.w700,
              ),
              hintText: "0.00",
              hintStyle: TextStyle(
                color: colors.textSecondary.withValues(alpha: 0.5),
                fontSize: 24.sp,
                fontWeight: FontWeight.w400,
              ),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
            onChanged: (_) => setState(() {}),
          ),
          SizedBox(height: 16.h),
          Wrap(
            spacing: 12.w,
            runSpacing: 12.h,
            children: [
              _buildQuickAmountButton("GHC 50", 50.00, colors),
              _buildQuickAmountButton("GHC 100", 100.00, colors),
              _buildQuickAmountButton("GHC 200", 200.00, colors),
              _buildQuickAmountButton("All", _availableBalance, colors),
            ],
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  VALIDATION ERROR
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildValidationError(String message, AppColorsExtension colors) {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: colors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
        border: Border.all(color: colors.error.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          SvgPicture.asset(
            Assets.icons.warningCircle,
            package: 'grab_go_shared',
            width: 20.w,
            height: 20.w,
            colorFilter: ColorFilter.mode(colors.error, BlendMode.srcIn),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: colors.error, fontSize: 12.sp, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  SUMMARY CARD
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildSummaryCard(AppColorsExtension colors) {
    final amount = _getEnteredAmount()!;
    final fee = _withdrawalFee;
    final net = _getNetAmount();

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
            "WITHDRAWAL SUMMARY",
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 11.sp,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),
          SizedBox(height: 16.h),
          _buildSummaryRow("Withdrawal Amount", "GHC ${amount.toStringAsFixed(2)}", colors),
          SizedBox(height: 12.h),
          _buildSummaryRow("Method", _selectedMethod.shortLabel, colors),
          SizedBox(height: 12.h),
          _buildSummaryRow(
            "Processing Fee",
            _isFreeWithdrawal ? "FREE" : "GHC ${fee.toStringAsFixed(2)}",
            colors,
            valueColor: _isFreeWithdrawal ? colors.accentGreen : null,
          ),
          SizedBox(height: 12.h),
          DottedLine(
            direction: Axis.horizontal,
            lineLength: double.infinity,
            lineThickness: 1.4,
            dashLength: 6,
            dashGapLength: 4,
            dashColor: colors.inputBorder.withValues(alpha: 0.65),
          ),
          SizedBox(height: 12.h),
          _buildSummaryRow("You'll Receive", "GHC ${net.toStringAsFixed(2)}", colors, isTotal: true),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  SKELETON
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildSkeleton(AppColorsExtension colors, bool isDark) {
    return Shimmer.fromColors(
      baseColor: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
      highlightColor: isDark ? Colors.grey.shade700 : Colors.grey.shade100,
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 120.h,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
              ),
            ),
            SizedBox(height: 24.h),
            Container(height: 14.h, width: 160.w, color: Colors.white),
            SizedBox(height: 12.h),
            Container(
              height: 80.h,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
              ),
            ),
            SizedBox(height: 24.h),
            Container(height: 14.h, width: 140.w, color: Colors.white),
            SizedBox(height: 12.h),
            Container(
              height: 80.h,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
              ),
            ),
            SizedBox(height: 24.h),
            Container(height: 14.h, width: 180.w, color: Colors.white),
            SizedBox(height: 12.h),
            Container(
              height: 120.h,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  HELPER WIDGETS
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildSectionHeader(String title, AppColorsExtension colors) {
    return Text(
      title,
      style: TextStyle(color: colors.textSecondary, fontSize: 11.sp, fontWeight: FontWeight.w600, letterSpacing: 1.2),
    );
  }

  Widget _buildQuickAmountButton(String label, double amount, AppColorsExtension colors) {
    final isSelected = _getEnteredAmount() == amount;
    final isDisabled = amount > _availableBalance;

    return GestureDetector(
      onTap: isDisabled ? null : () => _setQuickAmount(amount),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
        decoration: BoxDecoration(
          color: isSelected ? colors.accentGreen.withValues(alpha: 0.15) : colors.backgroundSecondary,
          borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isDisabled
                ? colors.textSecondary.withValues(alpha: 0.5)
                : isSelected
                ? colors.accentGreen
                : colors.textPrimary,
            fontSize: 14.sp,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryRow(
    String label,
    String value,
    AppColorsExtension colors, {
    bool isTotal = false,
    Color? valueColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: isTotal ? colors.textPrimary : colors.textSecondary,
            fontSize: isTotal ? 15.sp : 14.sp,
            fontWeight: isTotal ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? (isTotal ? colors.accentGreen : colors.textPrimary),
            fontSize: isTotal ? 18.sp : 16.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard({
    required AppColorsExtension colors,
    required String icon,
    required Color iconColor,
    required String title,
    required String description,
  }) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: colors.backgroundPrimary,
        borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40.w,
            height: 40.w,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
            ),
            child: Center(
              child: SvgPicture.asset(
                icon,
                package: 'grab_go_shared',
                width: 20.w,
                height: 20.w,
                colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
              ),
            ),
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(color: colors.textPrimary, fontSize: 14.sp, fontWeight: FontWeight.w600),
                ),
                SizedBox(height: 4.h),
                Text(
                  description,
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w400,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
