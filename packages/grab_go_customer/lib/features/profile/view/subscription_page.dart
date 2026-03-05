import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_customer/shared/models/subscription_models.dart';
import 'package:grab_go_customer/shared/services/paystack_service.dart' as paystack;
import 'package:grab_go_customer/shared/services/subscription_service.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';

class SubscriptionPage extends StatefulWidget {
  const SubscriptionPage({super.key});

  @override
  State<SubscriptionPage> createState() => _SubscriptionPageState();
}

class _SubscriptionPageState extends State<SubscriptionPage> {
  final SubscriptionService _service = SubscriptionService();

  bool _isLoading = true;
  bool _isSubmitting = false;
  List<SubscriptionPlan> _plans = const [];
  UserSubscription? _current;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final plans = await _service.getPlans();
      final current = await _service.getMySubscription();
      if (!mounted) return;
      setState(() {
        _plans = plans;
        _current = current;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      AppToastMessage.show(
        context: context,
        message: e.toString().replaceFirst('Exception: ', ''),
        backgroundColor: context.appColors.error,
      );
    }
  }

  Future<void> _startSubscription(SubscriptionPlan plan) async {
    if (_isSubmitting) return;

    setState(() => _isSubmitting = true);

    try {
      final start = await _service.subscribe(plan.tier);
      if (!mounted) return;

      final result = await paystack.PaystackService.instance.launchPayment(
        context: context,
        authorizationUrl: start.authorizationUrl,
        reference: start.reference,
      );

      if (!mounted) return;

      if (result.success) {
        AppToastMessage.show(
          context: context,
          message: 'Payment successful. Activating your plan...',
          backgroundColor: context.appColors.success,
        );
        await Future<void>.delayed(const Duration(milliseconds: 800));
        await _loadData();
      } else {
        AppToastMessage.show(
          context: context,
          message: result.message ?? 'Subscription payment not completed',
          backgroundColor: context.appColors.error,
        );
      }
    } catch (e) {
      if (!mounted) return;
      AppToastMessage.show(
        context: context,
        message: e.toString().replaceFirst('Exception: ', ''),
        backgroundColor: context.appColors.error,
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _cancelCurrentPlan() async {
    if (_isSubmitting || _current == null) return;

    final shouldCancel = await AppDialog.show(
      context: context,
      title: 'Cancel GrabGo Pro',
      message: 'Your benefits will remain active until the end of your current billing period. Continue?',
      type: AppDialogType.warning,
      primaryButtonText: 'Cancel Plan',
      secondaryButtonText: 'Keep Plan',
      primaryButtonColor: context.appColors.error,
      onPrimaryPressed: () => Navigator.of(context).pop(true),
      onSecondaryPressed: () => Navigator.of(context).pop(false),
    );

    if (shouldCancel != true) return;

    setState(() => _isSubmitting = true);

    try {
      await _service.cancel();
      if (!mounted) return;
      AppToastMessage.show(
        context: context,
        message: 'Your subscription has been cancelled.',
        backgroundColor: context.appColors.success,
      );
      await _loadData();
    } catch (e) {
      if (!mounted) return;
      AppToastMessage.show(
        context: context,
        message: e.toString().replaceFirst('Exception: ', ''),
        backgroundColor: context.appColors.error,
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Scaffold(
      backgroundColor: colors.backgroundPrimary,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: colors.backgroundPrimary,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: SvgPicture.asset(
            Assets.icons.navArrowLeft,
            package: 'grab_go_shared',
            colorFilter: ColorFilter.mode(colors.textPrimary, BlendMode.srcIn),
          ),
        ),
        title: Text(
          'GrabGo Pro',
          style: TextStyle(color: colors.textPrimary, fontSize: 18.sp, fontWeight: FontWeight.w800),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.all(20.w),
                children: [
                  if (_current != null) _buildCurrentPlanCard(colors),
                  Text(
                    'Choose your plan',
                    style: TextStyle(color: colors.textPrimary, fontSize: 16.sp, fontWeight: FontWeight.w700),
                  ),
                  SizedBox(height: 12.h),
                  ..._plans.map((plan) => _buildPlanCard(plan, colors)),
                  SizedBox(height: 24.h),
                ],
              ),
            ),
    );
  }

  Widget _buildCurrentPlanCard(AppColorsExtension colors) {
    final current = _current!;
    return Container(
      margin: EdgeInsets.only(bottom: 16.h),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: colors.backgroundSecondary,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: colors.accentOrange.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Current Plan',
            style: TextStyle(color: colors.textSecondary, fontSize: 12.sp, fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 6.h),
          Text(
            current.tierName,
            style: TextStyle(color: colors.textPrimary, fontSize: 18.sp, fontWeight: FontWeight.w800),
          ),
          if (current.currentPeriodEnd != null) ...[
            SizedBox(height: 6.h),
            Text(
              'Renews on ${current.currentPeriodEnd!.day}/${current.currentPeriodEnd!.month}/${current.currentPeriodEnd!.year}',
              style: TextStyle(color: colors.textSecondary, fontSize: 12.sp, fontWeight: FontWeight.w500),
            ),
          ],
          SizedBox(height: 12.h),
          AppButton(
            width: double.infinity,
            onPressed: _isSubmitting ? () {} : _cancelCurrentPlan,
            buttonText: _isSubmitting ? 'Please wait...' : 'Cancel Plan',
            backgroundColor: colors.error,
            textColor: Colors.white,
          ),
        ],
      ),
    );
  }

  Widget _buildPlanCard(SubscriptionPlan plan, AppColorsExtension colors) {
    final hasCurrent = _current != null;
    final isCurrentTier = _current?.tier == plan.tier;

    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(color: colors.backgroundSecondary, borderRadius: BorderRadius.circular(12.r)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  plan.name,
                  style: TextStyle(color: colors.textPrimary, fontSize: 16.sp, fontWeight: FontWeight.w800),
                ),
              ),
              Text(
                '${plan.currency} ${plan.price.toStringAsFixed(0)}/${plan.interval == 'monthly' ? 'mo' : plan.interval}',
                style: TextStyle(color: colors.accentOrange, fontSize: 14.sp, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Text(
            '• ${plan.freeDeliveryText}',
            style: TextStyle(color: colors.textSecondary, fontSize: 12.sp),
          ),
          SizedBox(height: 4.h),
          Text(
            '• ${plan.serviceFeeDiscountText}',
            style: TextStyle(color: colors.textSecondary, fontSize: 12.sp),
          ),
          if (plan.prioritySupport) ...[
            SizedBox(height: 4.h),
            Text(
              '• Priority support',
              style: TextStyle(color: colors.textSecondary, fontSize: 12.sp),
            ),
          ],
          if (plan.exclusiveDeals) ...[
            SizedBox(height: 4.h),
            Text(
              '• Exclusive deals',
              style: TextStyle(color: colors.textSecondary, fontSize: 12.sp),
            ),
          ],
          SizedBox(height: 12.h),
          AppButton(
            width: double.infinity,
            onPressed: (isCurrentTier || _isSubmitting || hasCurrent) ? () {} : () => _startSubscription(plan),
            buttonText: isCurrentTier
                ? 'Current Plan'
                : hasCurrent
                ? 'Cancel current plan to switch'
                : (_isSubmitting ? 'Please wait...' : 'Subscribe'),
          ),
        ],
      ),
    );
  }
}
