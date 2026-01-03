import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';

class WithdrawalPage extends StatefulWidget {
  const WithdrawalPage({super.key});

  @override
  State<WithdrawalPage> createState() => _WithdrawalPageState();
}

class _WithdrawalPageState extends State<WithdrawalPage> {
  final TextEditingController _amountController = TextEditingController();
  final double _availableBalance = 184.90;
  final double _minWithdrawal = 10.00;
  final double _maxWithdrawal = 1000.00;
  final double _withdrawalFee = 2.50;
  final String _selectedBankAccount = "Ghana Commercial Bank - ****7890";
  bool _isProcessing = false;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _setQuickAmount(double amount) {
    if (amount <= _availableBalance) {
      setState(() {
        _amountController.text = amount.toStringAsFixed(2);
      });
    }
  }

  double? _getEnteredAmount() {
    final text = _amountController.text.trim();
    if (text.isEmpty) return null;
    final amount = double.tryParse(text);
    return amount;
  }

  bool _isValidAmount() {
    final amount = _getEnteredAmount();
    if (amount == null) return false;
    return amount >= _minWithdrawal && amount <= _maxWithdrawal && amount <= _availableBalance;
  }

  double _getTotalDeduction() {
    final amount = _getEnteredAmount();
    if (amount == null) return 0;
    return amount + _withdrawalFee;
  }

  void _processWithdrawal() {
    if (!_isValidAmount()) return;

    setState(() {
      _isProcessing = true;
    });

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Withdrawal request submitted successfully!",
              style: TextStyle(
                fontFamily: "Lato",
                package: "grab_go_shared",
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
            backgroundColor: context.appColors.accentGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(KBorderSize.borderRadius4)),
          ),
        );
        context.pop();
      }
    });
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
        body: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
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
                      "Available Balance",
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
                  ],
                ),
              ),

              SizedBox(height: 24.h),
              _buildSectionHeader("BANK ACCOUNT", colors),
              SizedBox(height: 12.h),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      backgroundColor: Colors.transparent,
                      builder: (context) => Container(
                        padding: EdgeInsets.all(20.w),
                        decoration: BoxDecoration(color: colors.backgroundPrimary),
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

                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "Choose Method",
                                  style: TextStyle(
                                    color: colors.textPrimary,
                                    fontSize: 18.sp,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                IconButton(
                                  onPressed: () {
                                    context.pop();
                                  },
                                  icon: SvgPicture.asset(
                                    Assets.icons.edit,
                                    package: 'grab_go_shared',
                                    width: 20.w,
                                    height: 20.w,
                                    colorFilter: ColorFilter.mode(colors.textPrimary, BlendMode.srcIn),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 20.h),

                            _buildMethodSelector(colors, "MTN MOMO", Assets.icons.mom, () {}),
                            SizedBox(height: 12.h),
                            _buildMethodSelector(colors, "Vodafone Cash", Assets.icons.vodafoneCash, () {}),
                            SizedBox(height: 12.h),
                          ],
                        ),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
                  child: Container(
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
                                _selectedBankAccount,
                                style: TextStyle(
                                  color: colors.textPrimary,
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(height: 4.h),
                              Text(
                                "Tap to change",
                                style: TextStyle(
                                  color: colors.textSecondary,
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w400,
                                ),
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
              ),

              SizedBox(height: 24.h),

              _buildSectionHeader("WITHDRAWAL AMOUNT", colors),
              SizedBox(height: 12.h),
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
                      onChanged: (value) {
                        setState(() {});
                      },
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
              ),

              if (_amountController.text.isNotEmpty && !_isValidAmount())
                Container(
                  padding: EdgeInsets.all(12.w),
                  decoration: BoxDecoration(
                    color: colors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
                    border: Border.all(color: colors.error.withValues(alpha: 0.3), width: 1),
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
                          _getEnteredAmount() != null && _getEnteredAmount()! < _minWithdrawal
                              ? "Minimum withdrawal is GHC ${_minWithdrawal.toStringAsFixed(2)}"
                              : _getEnteredAmount() != null && _getEnteredAmount()! > _maxWithdrawal
                              ? "Maximum withdrawal is GHC ${_maxWithdrawal.toStringAsFixed(2)}"
                              : _getEnteredAmount() != null && _getEnteredAmount()! > _availableBalance
                              ? "Insufficient balance"
                              : "Invalid amount",
                          style: TextStyle(color: colors.error, fontSize: 12.sp, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),

              SizedBox(height: 24.h),

              if (_isValidAmount())
                Container(
                  padding: EdgeInsets.all(20.w),
                  margin: EdgeInsets.only(bottom: 24.h),
                  decoration: BoxDecoration(
                    color: colors.backgroundPrimary,
                    borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
                    border: Border.all(color: colors.border, width: 1),
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
                      _buildSummaryRow("Withdrawal Amount", "GHC ${_getEnteredAmount()!.toStringAsFixed(2)}", colors),
                      SizedBox(height: 12.h),
                      _buildSummaryRow("Processing Fee", "GHC ${_withdrawalFee.toStringAsFixed(2)}", colors),
                      SizedBox(height: 12.h),
                      Divider(color: colors.border, height: 1),
                      SizedBox(height: 12.h),
                      _buildSummaryRow(
                        "Total Deduction",
                        "GHC ${_getTotalDeduction().toStringAsFixed(2)}",
                        colors,
                        isTotal: true,
                      ),
                    ],
                  ),
                ),

              Text(
                "NOTE SUMMARY",
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                ),
              ),
              SizedBox(height: 16.h),

              _buildInfoCard(
                colors: colors,
                icon: Assets.icons.clock,
                iconColor: colors.accentOrange,
                title: "Processing Time",
                description: "Withdrawals are processed within 1-3 business days",
              ),
              SizedBox(height: 12.h),
              _buildInfoCard(
                colors: colors,
                icon: Assets.icons.infoCircle,
                iconColor: colors.accentViolet,
                title: "Withdrawal Limits",
                description:
                    "Minimum: GHC ${_minWithdrawal.toStringAsFixed(2)} | Maximum: GHC ${_maxWithdrawal.toStringAsFixed(2)}",
              ),
              SizedBox(height: 12.h),
              _buildInfoCard(
                colors: colors,
                icon: Assets.icons.shieldCheck,
                iconColor: colors.accentGreen,
                title: "Secure Transaction",
                description: "Your withdrawal is secured with bank-level encryption",
              ),

              SizedBox(height: 32.h),

              SizedBox(
                width: double.infinity,
                height: 56.h,
                child: ElevatedButton(
                  onPressed: _isValidAmount() && !_isProcessing ? _processWithdrawal : null,
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
                          child: CircularProgressIndicator(
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
        ),
      ),
    );
  }

  Widget _buildMethodSelector(AppColorsExtension colors, String method, AssetGenImage imgPath, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
                child: imgPath.image(package: "grab_go_shared", height: 40.h, width: 60.w, fit: BoxFit.cover),
              ),
              SizedBox(width: 16.w),
              Expanded(
                child: Text(
                  method,
                  style: TextStyle(color: colors.textPrimary, fontSize: 14.sp, fontWeight: FontWeight.w600),
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

  Widget _buildSectionHeader(String title, AppColorsExtension colors) {
    return Text(
      title,
      style: TextStyle(color: colors.textSecondary, fontSize: 12.sp, fontWeight: FontWeight.w600, letterSpacing: 1.2),
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
          border: Border.all(
            color: isSelected
                ? colors.accentGreen
                : isDisabled
                ? colors.border.withValues(alpha: 0.3)
                : colors.border,
            width: isSelected ? 2 : 1,
          ),
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

  Widget _buildSummaryRow(String label, String value, AppColorsExtension colors, {bool isTotal = false}) {
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
            color: isTotal ? colors.accentGreen : colors.textPrimary,
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
        border: Border.all(color: colors.border, width: 1),
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
