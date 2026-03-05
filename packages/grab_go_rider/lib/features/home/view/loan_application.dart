import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_rider/features/home/service/rider_wallet_service.dart';
import 'package:grab_go_shared/shared/widgets/custom_slider.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';

class LoanApplication extends StatefulWidget {
  const LoanApplication({super.key});

  @override
  State<LoanApplication> createState() => _LoanApplicationState();
}

class _LoanApplicationState extends State<LoanApplication> {
  final RiderWalletService _walletService = RiderWalletService();

  // Form state
  double _amount = 200;
  int _selectedTerm = 7;
  String _selectedPurpose = 'Fuel';

  // API-driven state
  LoanEligibility? _eligibility;
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _error;

  final List<String> _purposes = ['Fuel', 'Maintenance', 'Health', 'Family', 'Education', 'Other'];

  double get _interestRate => _eligibility?.interestRate ?? 0.05;
  double get _maxAmount => _eligibility?.maxAmount ?? 1000;
  double get _minAmount => _eligibility?.minAmount ?? 50;
  List<int> get _availableTerms => _eligibility?.availableTerms ?? [7, 14, 30];
  double get _totalRepayment => _amount + (_amount * _interestRate);
  double get _dailyDeduction => _totalRepayment / _selectedTerm;

  @override
  void initState() {
    super.initState();
    _loadEligibility();
  }

  Future<void> _loadEligibility() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final eligibility = await _walletService.fetchLoanEligibility();
      if (!mounted) return;

      setState(() {
        _eligibility = eligibility;
        _isLoading = false;
        // Clamp amount to the allowed range
        if (_amount > eligibility.maxAmount) _amount = eligibility.maxAmount;
        if (_amount < eligibility.minAmount) _amount = eligibility.minAmount;
        // Default to first available term
        if (eligibility.availableTerms.isNotEmpty && !eligibility.availableTerms.contains(_selectedTerm)) {
          _selectedTerm = eligibility.availableTerms.first;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
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
        body: Column(
          children: [
            Expanded(
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverAppBar(
                    expandedHeight: 140.h,
                    pinned: true,
                    backgroundColor: colors.accentGreen,
                    elevation: 0,
                    leading: IconButton(
                      icon: SvgPicture.asset(
                        Assets.icons.navArrowLeft,
                        package: 'grab_go_shared',
                        width: 24.w,
                        height: 24.w,
                        colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                      ),
                      onPressed: () => context.pop(),
                    ),
                    flexibleSpace: FlexibleSpaceBar(
                      title: Text(
                        "Loan Application",
                        style: TextStyle(color: Colors.white, fontSize: 18.sp, fontWeight: FontWeight.w700),
                      ),
                      centerTitle: true,
                      background: Stack(
                        fit: StackFit.expand,
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [colors.accentGreen, colors.accentGreen.withValues(alpha: 0.8)],
                              ),
                            ),
                          ),
                          Positioned(
                            right: -20.w,
                            bottom: -20.h,
                            child: Opacity(
                              opacity: 0.2,
                              child: SvgPicture.asset(
                                Assets.icons.handCash,
                                package: 'grab_go_shared',
                                width: 150.w,
                                height: 150.w,
                                colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: _isLoading
                        ? Padding(
                            padding: EdgeInsets.all(60.w),
                            child: Center(
                              child: SizedBox(
                                width: 28.w,
                                height: 28.w,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  valueColor: AlwaysStoppedAnimation<Color>(colors.accentGreen),
                                ),
                              ),
                            ),
                          )
                        : _error != null
                        ? Padding(
                            padding: EdgeInsets.all(40.w),
                            child: Column(
                              children: [
                                Text(
                                  _error!,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: colors.error, fontSize: 14.sp),
                                ),
                                SizedBox(height: 16.h),
                                AppButton(
                                  onPressed: _loadEligibility,
                                  buttonText: "Retry",
                                  backgroundColor: colors.accentGreen,
                                  borderRadius: KBorderSize.borderRadius4,
                                  width: 120.w,
                                  height: 40.h,
                                  textStyle: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : Padding(
                            padding: EdgeInsets.all(20.w),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildEligibilityCard(colors),
                                SizedBox(height: 24.h),
                                Text(
                                  "How much do you need?",
                                  style: TextStyle(
                                    color: colors.textPrimary,
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                SizedBox(height: 16.h),
                                _buildAmountSelector(colors),
                                SizedBox(height: 24.h),
                                Text(
                                  "What is it for?",
                                  style: TextStyle(
                                    color: colors.textPrimary,
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                SizedBox(height: 12.h),
                                _buildPurposeSelector(colors),
                                SizedBox(height: 24.h),
                                Text(
                                  "Repayment Term",
                                  style: TextStyle(
                                    color: colors.textPrimary,
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                SizedBox(height: 12.h),
                                _buildTermSelector(colors),
                                SizedBox(height: 24.h),
                                _buildRepaymentSummary(colors),
                                SizedBox(height: 24.h),
                              ],
                            ),
                          ),
                  ),
                ],
              ),
            ),
            Container(
              padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 24.h),
              decoration: BoxDecoration(
                color: colors.backgroundPrimary,
                boxShadow: [
                  BoxShadow(color: colors.shadow.withValues(alpha: 0.1), blurRadius: 5, offset: const Offset(0, -2)),
                ],
              ),
              child: SafeArea(top: false, child: _buildSubmitButton(colors)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEligibilityCard(AppColorsExtension colors) {
    final isEligible = _eligibility?.eligible ?? false;
    final rating = _eligibility?.averageRating ?? 0;
    final cardColor = isEligible ? colors.accentGreen : colors.warning;

    String title;
    String subtitle;
    if (isEligible) {
      title = 'Eligible for Loan';
      subtitle =
          'Based on your ${rating.toStringAsFixed(1)}★ rating & ${_eligibility?.partnerLevel ?? 'L1'} partner level, '
          'you qualify for up to GHC ${_maxAmount.toStringAsFixed(0)} at ${(_interestRate * 100).toStringAsFixed(0)}% interest.';
    } else {
      title = 'Not Eligible';
      subtitle = _eligibility?.reasons.isNotEmpty == true
          ? _eligibility!.reasons.first
          : 'You do not currently qualify for a loan.';
    }

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: cardColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(10.w),
            decoration: BoxDecoration(color: cardColor.withValues(alpha: 0.25), shape: BoxShape.circle),
            child: SvgPicture.asset(
              isEligible ? Assets.icons.star : Assets.icons.infoCircle,
              package: 'grab_go_shared',
              width: 20.w,
              height: 20.w,
              colorFilter: ColorFilter.mode(cardColor, BlendMode.srcIn),
            ),
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(color: cardColor, fontSize: 14.sp, fontWeight: FontWeight.w700),
                ),
                Text(
                  subtitle,
                  style: TextStyle(color: colors.textSecondary, fontSize: 12.sp, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmountSelector(AppColorsExtension colors) {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: colors.backgroundPrimary,
        borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
      ),
      child: Column(
        children: [
          Text(
            "GHC ${_amount.toInt()}",
            style: TextStyle(color: colors.accentGreen, fontSize: 36.sp, fontWeight: FontWeight.w900, letterSpacing: 1),
          ),
          SizedBox(height: 20.h),
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 10.h,
              activeTrackColor: colors.accentGreen,
              inactiveTrackColor: colors.accentGreen.withValues(alpha: 0.1),
              thumbColor: Colors.white,
              overlayColor: colors.accentGreen.withValues(alpha: 0.15),
              thumbShape: CustomSliderThumbShape(enabledThumbRadius: 16.r, thumbColor: colors.accentGreen),
              trackShape: const CustomSliderTrackShape(),
              overlayShape: RoundSliderOverlayShape(overlayRadius: 26.r),
              tickMarkShape: const RoundSliderTickMarkShape(tickMarkRadius: 2),
              activeTickMarkColor: Colors.white.withValues(alpha: 0.5),
              inactiveTickMarkColor: colors.accentGreen.withValues(alpha: 0.3),
            ),
            child: Slider(
              value: _amount.clamp(_minAmount, _maxAmount),
              min: _minAmount,
              max: _maxAmount,
              divisions: ((_maxAmount - _minAmount) / 50).round().clamp(1, 100),
              onChanged: (_eligibility?.eligible ?? false)
                  ? (value) {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _amount = value;
                      });
                    }
                  : null,
            ),
          ),
          SizedBox(height: 12.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "GHC ${_minAmount.toStringAsFixed(0)}",
                style: TextStyle(color: colors.textSecondary, fontSize: 11.sp, fontWeight: FontWeight.w600),
              ),
              Text(
                "GHC ${_maxAmount.toStringAsFixed(0)}",
                style: TextStyle(color: colors.textSecondary, fontSize: 11.sp, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPurposeSelector(AppColorsExtension colors) {
    return Wrap(
      spacing: 8.w,
      runSpacing: 2.h,
      children: _purposes.map((purpose) {
        final isSelected = _selectedPurpose == purpose;
        return ChoiceChip(
          label: Text(purpose),
          selected: isSelected,
          onSelected: (selected) {
            setState(() {
              _selectedPurpose = purpose;
            });
          },
          surfaceTintColor: colors.accentGreen,
          selectedColor: colors.accentGreen,
          backgroundColor: colors.backgroundPrimary,
          labelStyle: TextStyle(
            color: isSelected ? Colors.white : colors.textPrimary,
            fontSize: 13.sp,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.r),
            side: BorderSide(color: isSelected ? colors.accentGreen : colors.border.withValues(alpha: 0.5)),
          ),
          showCheckmark: false,
        );
      }).toList(),
    );
  }

  Widget _buildTermSelector(AppColorsExtension colors) {
    final terms = _availableTerms.isEmpty ? [7, 14, 30] : _availableTerms;
    return Row(
      children: terms.map((days) {
        final isSelected = _selectedTerm == days;
        return Expanded(
          child: GestureDetector(
            onTap: () {
              setState(() {
                _selectedTerm = days;
              });
            },
            child: Container(
              margin: EdgeInsets.symmetric(horizontal: 4.w),
              padding: EdgeInsets.symmetric(vertical: 12.h),
              decoration: BoxDecoration(
                color: isSelected ? colors.accentGreen : colors.backgroundPrimary,
                borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
                border: Border.all(color: isSelected ? colors.accentGreen : colors.border.withValues(alpha: 0.5)),
              ),
              child: Center(
                child: Text(
                  "$days Days",
                  style: TextStyle(
                    color: isSelected ? Colors.white : colors.textPrimary,
                    fontSize: 14.sp,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildRepaymentSummary(AppColorsExtension colors) {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: colors.backgroundPrimary,
        borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Total Repayment",
                style: TextStyle(color: colors.textSecondary, fontSize: 14.sp),
              ),
              Text(
                "GHC ${_totalRepayment.toStringAsFixed(2)}",
                style: TextStyle(color: colors.textPrimary, fontSize: 16.sp, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Daily Deduction",
                style: TextStyle(color: colors.textSecondary, fontSize: 14.sp),
              ),
              Text(
                "GHC ${_dailyDeduction.toStringAsFixed(2)}",
                style: TextStyle(color: colors.accentGreen, fontSize: 18.sp, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: colors.error.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: colors.error, size: 16.w),
                SizedBox(width: 8.w),
                Expanded(
                  child: Text(
                    "Deductions will be made automatically from your wallet daily starting from tomorrow.",
                    style: TextStyle(color: colors.error, fontSize: 11.sp, height: 1.4, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton(AppColorsExtension colors) {
    final isDisabled = !(_eligibility?.eligible ?? false) || _isSubmitting;
    return SizedBox(
      width: double.infinity,
      height: 56.h,
      child: AppButton(
        onPressed: () => isDisabled ? null : _showConfirmationDialog,
        buttonText: _isSubmitting ? "Submitting..." : "Submit Application",
        isLoading: _isSubmitting,
        backgroundColor: isDisabled ? colors.accentGreen.withValues(alpha: 0.5) : colors.accentGreen,
        borderRadius: KBorderSize.borderRadius4,
        textStyle: TextStyle(color: Colors.white, fontSize: 16.sp, fontWeight: FontWeight.w700),
      ),
    );
  }

  void _showConfirmationDialog() {
    final colors = context.appColors;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colors.backgroundPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(KBorderSize.borderRadius4)),
        title: Text(
          "Confirm Loan Request",
          style: TextStyle(fontSize: 18.sp, color: colors.textPrimary, fontWeight: FontWeight.w700),
        ),
        content: Text(
          "You are requesting GHC ${_amount.toInt()} for $_selectedPurpose. The total repayable amount is GHC ${_totalRepayment.toStringAsFixed(2)} over $_selectedTerm days.",
          style: TextStyle(color: colors.textSecondary, fontSize: 14.sp, height: 1.5),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          AppButton(
            onPressed: () {
              Navigator.pop(context);
            },
            buttonText: "Edit",
            width: 120.w,
            height: 46.h,
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
            backgroundColor: colors.backgroundSecondary,
            borderRadius: KBorderSize.borderRadius4,
            textStyle: TextStyle(color: colors.textSecondary, fontSize: 14.sp, fontWeight: FontWeight.w700),
          ),
          const Spacer(),
          AppButton(
            onPressed: () async {
              Navigator.pop(context);
              _submitLoanApplication();
            },
            buttonText: "Confirm",
            width: 120.w,
            height: 46.h,
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
            backgroundColor: colors.accentGreen,
            borderRadius: KBorderSize.borderRadius4,
            textStyle: TextStyle(color: Colors.white, fontSize: 14.sp, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog({bool wasAutoApproved = false}) {
    final colors = context.appColors;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: colors.backgroundPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(KBorderSize.borderRadius4)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: 20.h),
            Container(
              padding: EdgeInsets.all(20.w),
              decoration: BoxDecoration(color: colors.accentGreen.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: SvgPicture.asset(
                Assets.icons.check,
                package: 'grab_go_shared',
                width: 40.w,
                height: 40.w,
                colorFilter: ColorFilter.mode(colors.accentGreen, BlendMode.srcIn),
              ),
            ),
            SizedBox(height: 24.h),
            Text(
              wasAutoApproved ? "Loan Approved!" : "Application Submitted",
              style: TextStyle(color: colors.textPrimary, fontSize: 18.sp, fontWeight: FontWeight.w700),
            ),
            SizedBox(height: 12.h),
            Text(
              wasAutoApproved
                  ? "GHC ${_amount.toStringAsFixed(0)} has been credited to your wallet. Daily deductions of GHC ${_dailyDeduction.toStringAsFixed(2)} start tomorrow."
                  : "Your loan request has been submitted for review. You will receive a notification once it's approved.",
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.textSecondary, fontSize: 14.sp, height: 1.5),
            ),
            SizedBox(height: 32.h),
            AppButton(
              onPressed: () {
                Navigator.pop(context);
                context.pop(true); // Pass true to refresh wallet page
              },
              buttonText: "Okay",
              width: double.infinity,
              height: 46.h,
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
              backgroundColor: colors.accentGreen,
              borderRadius: KBorderSize.borderRadius4,
              textStyle: TextStyle(color: Colors.white, fontSize: 14.sp, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitLoanApplication() async {
    if (_isSubmitting) return;

    setState(() => _isSubmitting = true);

    final colors = context.appColors;
    LoadingDialog.instance().show(context: context, text: "Submitting loan request...", spinColor: colors.accentGreen);

    try {
      final result = await _walletService.applyForLoan(
        amount: _amount,
        termDays: _selectedTerm,
        purpose: _selectedPurpose,
      );

      if (!mounted) return;
      LoadingDialog.instance().hide();

      // Check if the loan was auto-approved (L4/L5 riders)
      final loanData = result['data'] as Map<String, dynamic>?;
      final wasAutoApproved = loanData?['status'] == 'active';

      _showSuccessDialog(wasAutoApproved: wasAutoApproved);
    } catch (e) {
      LoadingDialog.instance().hide();

      if (!mounted) return;

      final message = e.toString().replaceFirst('Exception: ', '');
      AppToastMessage.show(
        context: context,
        showIcon: false,
        message: message,
        backgroundColor: colors.error,
        radius: KBorderSize.borderRadius4,
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
}
