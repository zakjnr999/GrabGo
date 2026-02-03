import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_rider/shared/widgets/custom_slider.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';

class LoanApplication extends StatefulWidget {
  const LoanApplication({super.key});

  @override
  State<LoanApplication> createState() => _LoanApplicationState();
}

class _LoanApplicationState extends State<LoanApplication> {
  double _amount = 200;
  int _selectedTerm = 7;
  String _selectedPurpose = 'Fuel';
  final double _interestRate = 0.05;

  final List<String> _purposes = ['Fuel', 'Maintenance', 'Health', 'Family', 'Education', 'Other'];

  double get _totalRepayment => _amount + (_amount * _interestRate);
  double get _dailyDeduction => _totalRepayment / _selectedTerm;

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
                    child: Padding(
                      padding: EdgeInsets.all(20.w),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildEligibilityCard(colors),
                          SizedBox(height: 24.h),
                          Text(
                            "How much do you need?",
                            style: TextStyle(color: colors.textPrimary, fontSize: 16.sp, fontWeight: FontWeight.w700),
                          ),
                          SizedBox(height: 16.h),
                          _buildAmountSelector(colors),
                          SizedBox(height: 24.h),
                          Text(
                            "What is it for?",
                            style: TextStyle(color: colors.textPrimary, fontSize: 16.sp, fontWeight: FontWeight.w700),
                          ),
                          SizedBox(height: 12.h),
                          _buildPurposeSelector(colors),
                          SizedBox(height: 24.h),
                          Text(
                            "Repayment Term",
                            style: TextStyle(color: colors.textPrimary, fontSize: 16.sp, fontWeight: FontWeight.w700),
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
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: colors.accentGreen.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(10.w),
            decoration: BoxDecoration(color: colors.accentGreen.withValues(alpha: 0.25), shape: BoxShape.circle),
            child: SvgPicture.asset(
              Assets.icons.star,
              package: 'grab_go_shared',
              width: 20.w,
              height: 20.w,
              colorFilter: ColorFilter.mode(colors.accentGreen, BlendMode.srcIn),
            ),
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "High Trust Level",
                  style: TextStyle(color: colors.accentGreen, fontSize: 14.sp, fontWeight: FontWeight.w700),
                ),
                Text(
                  "Based on your 4.8★ rating, you are eligible for instant approval up to GHC 1,000.",
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
              value: _amount,
              min: 100,
              max: 1000,
              divisions: 18,
              onChanged: (value) {
                HapticFeedback.selectionClick();
                setState(() {
                  _amount = value;
                });
              },
            ),
          ),
          SizedBox(height: 12.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "GHC 100",
                style: TextStyle(color: colors.textSecondary, fontSize: 11.sp, fontWeight: FontWeight.w600),
              ),
              Text(
                "GHC 1,000",
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
    return Row(
      children: [7, 14, 30].map((days) {
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
    return SizedBox(
      width: double.infinity,
      height: 56.h,
      child: AppButton(
        onPressed: _showConfirmationDialog,
        buttonText: "Submit Application",
        backgroundColor: colors.accentGreen,
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
              LoadingDialog.instance().show(
                context: context,
                text: "Submitting Loan Request",
                spinColor: colors.accentGreen,
              );
              await Future.delayed(const Duration(seconds: 4));
              LoadingDialog.instance().hide();

              _showSuccessDialog();
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

  void _showSuccessDialog() {
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
              "Application Submitted",
              style: TextStyle(color: colors.textPrimary, fontSize: 18.sp, fontWeight: FontWeight.w700),
            ),
            SizedBox(height: 12.h),
            Text(
              "Your loan request has been submitted for review. You will receive an update within 24 hours.",
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.textSecondary, fontSize: 14.sp, height: 1.5),
            ),
            SizedBox(height: 32.h),
            AppButton(
              onPressed: () {
                Navigator.pop(context);
                context.pop();
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
}
