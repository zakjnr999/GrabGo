import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_customer/shared/services/user_service.dart';
import 'package:grab_go_customer/shared/models/subscription_models.dart';
import 'package:grab_go_customer/shared/services/paystack_service.dart'
    as paystack;
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
  static const String _subscriptionPromoAsset =
      'lib/assets/icons/promo_banner_five.svg';
  static const Duration _subscriptionCacheMaxAge = Duration(minutes: 30);

  bool _isLoading = true;
  bool _isSubmitting = false;
  List<SubscriptionPlan> _plans = const [];
  UserSubscription? _current;
  String? _selectedTier;
  Timer? _pendingPollingTimer;
  bool _isConfirmingPending = false;
  int _pendingPollAttempts = 0;
  static const int _maxPendingPollAttempts = 8;

  bool get _hasPendingSubscription =>
      _current?.status.toLowerCase() == 'pending';
  String? get _pendingPaymentReference => _current?.pendingPaymentReference;

  SubscriptionPlan? get _selectedPlan {
    if (_plans.isEmpty) return null;
    if (_selectedTier != null) {
      final selected = _findPlanByTier(_selectedTier!);
      if (selected != null) return selected;
    }
    return _plans.first;
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _pendingPollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadData({bool forceRefresh = false}) async {
    bool hydratedFromCache = false;

    if (!forceRefresh) {
      final cached = _readCachedSubscriptionData();
      if (cached != null) {
        final selectedTier = _resolveSelectedTier(
          plans: cached.plans,
          current: cached.current,
          existingSelectedTier: _selectedTier,
        );
        if (mounted) {
          setState(() {
            _plans = cached.plans;
            _current = cached.current;
            _selectedTier = selectedTier;
            _isLoading = false;
          });
          _configurePendingPolling();
        }
        hydratedFromCache = true;
        // Render cached data immediately, then always do a silent refresh.
        // Subscription status can change quickly (e.g. pending -> active).
      }
    }

    try {
      final plans = await _service.getPlans();
      final current = await _service.getMySubscription();
      final selectedTier = _resolveSelectedTier(
        plans: plans,
        current: current,
        existingSelectedTier: _selectedTier,
      );
      if (!mounted) return;
      setState(() {
        _plans = plans;
        _current = current;
        _selectedTier = selectedTier;
        _isLoading = false;
      });
      _configurePendingPolling();
      await _saveSubscriptionDataToCache(plans: plans, current: current);
    } catch (e) {
      if (!mounted) return;
      if (hydratedFromCache) {
        debugPrint(
          'SubscriptionPage: using cached data due to refresh error: $e',
        );
      } else {
        setState(() => _isLoading = false);
        AppToastMessage.show(
          context: context,
          message: e.toString().replaceFirst('Exception: ', ''),
          backgroundColor: context.appColors.error,
        );
      }
    }
  }

  void _configurePendingPolling() {
    _pendingPollingTimer?.cancel();
    _pendingPollAttempts = 0;

    if (!_hasPendingSubscription ||
        (_pendingPaymentReference?.isEmpty ?? true)) {
      return;
    }

    _pendingPollingTimer = Timer.periodic(const Duration(seconds: 8), (
      timer,
    ) async {
      if (!mounted || !_hasPendingSubscription) {
        timer.cancel();
        return;
      }
      if (_pendingPollAttempts >= _maxPendingPollAttempts) {
        timer.cancel();
        return;
      }

      _pendingPollAttempts += 1;
      final confirmed = await _confirmPendingPayment(silent: true);
      if (confirmed) {
        timer.cancel();
      }
    });
  }

  Future<bool> _confirmPendingPayment({bool silent = false}) async {
    if (_isConfirmingPending) return false;
    final reference = _pendingPaymentReference;
    if (reference == null || reference.isEmpty) {
      if (!silent && mounted) {
        AppToastMessage.show(
          context: context,
          message:
              'No pending payment reference found. Start a new payment attempt.',
          backgroundColor: context.appColors.error,
        );
      }
      return false;
    }

    _isConfirmingPending = true;
    if (!silent && mounted) {
      setState(() => _isSubmitting = true);
    }

    try {
      final result = await _service.confirmPayment(reference);
      if (!mounted) return false;

      if (result.confirmed) {
        if (!silent) {
          AppToastMessage.show(
            context: context,
            message: result.alreadyConfirmed
                ? 'Payment already confirmed. Loading your subscription...'
                : 'Payment confirmed. Activating your plan...',
            backgroundColor: context.appColors.success,
          );
        }
        await _loadData(forceRefresh: true);
        return true;
      }

      if (!silent) {
        AppToastMessage.show(
          context: context,
          message: result.message ?? 'Payment is still pending or failed.',
          backgroundColor: context.appColors.error,
        );
      }
      return false;
    } catch (e) {
      if (!silent && mounted) {
        AppToastMessage.show(
          context: context,
          message: e.toString().replaceFirst('Exception: ', ''),
          backgroundColor: context.appColors.error,
        );
      }
      return false;
    } finally {
      _isConfirmingPending = false;
      if (!silent && mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _startSubscription(SubscriptionPlan plan) async {
    if (_isSubmitting) return;

    setState(() => _isSubmitting = true);
    _pendingPollingTimer?.cancel();

    try {
      final start = await _service.subscribe(plan.tier);
      if (!mounted) return;

      final result = await paystack.PaystackService.instance.launchPayment(
        context: context,
        authorizationUrl: start.authorizationUrl,
        reference: start.reference,
      );

      if (!mounted) return;

      if (result.status == paystack.PaystackPaymentStatus.cancelled) {
        AppToastMessage.show(
          context: context,
          message: result.message ?? 'Payment was cancelled.',
          backgroundColor: context.appColors.error,
        );
        return;
      }

      final confirmationResult = await context.push<bool>(
        '/paymentConfirming',
        extra: {
          'reference': result.reference ?? start.reference,
          'paymentData': const <String, dynamic>{},
          'flow': 'subscription',
        },
      );

      if (!mounted) return;

      if (confirmationResult == true) {
        AppToastMessage.show(
          context: context,
          message: 'Payment successful. Activating your plan...',
          backgroundColor: context.appColors.success,
        );
        await Future<void>.delayed(const Duration(milliseconds: 800));
        await _loadData(forceRefresh: true);
      } else {
        AppToastMessage.show(
          context: context,
          message: 'Subscription payment not completed',
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
      message:
          'Your benefits will remain active until the end of your current billing period. Continue?',
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
      await _loadData(forceRefresh: true);
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

  String _subscriptionCacheKey(String userId) =>
      'subscription_page_cache_v1_$userId';

  _CachedSubscriptionData? _readCachedSubscriptionData() {
    try {
      final userId = UserService().getUserId();
      if (userId == null || userId.isEmpty) return null;

      final cachedJson = CacheService.getData(_subscriptionCacheKey(userId));
      if (cachedJson == null || cachedJson.isEmpty) return null;

      final decoded = jsonDecode(cachedJson);
      if (decoded is! Map<String, dynamic>) return null;

      final cachedAtRaw = decoded['cachedAt'];
      final plansRaw = decoded['plans'];
      if (cachedAtRaw is! String || plansRaw is! List) return null;

      final cachedAt = DateTime.tryParse(cachedAtRaw);
      if (cachedAt == null) return null;

      final plans = <SubscriptionPlan>[];
      for (final entry in plansRaw) {
        if (entry is Map) {
          plans.add(
            SubscriptionPlan.fromJson(Map<String, dynamic>.from(entry)),
          );
        }
      }

      final currentRaw = decoded['current'];
      UserSubscription? current;
      if (currentRaw is Map) {
        current = UserSubscription.fromJson(
          Map<String, dynamic>.from(currentRaw),
        );
      }

      final isStale =
          DateTime.now().difference(cachedAt) > _subscriptionCacheMaxAge;
      return _CachedSubscriptionData(
        plans: plans,
        current: current,
        isStale: isStale,
      );
    } catch (e) {
      debugPrint('SubscriptionPage: failed to read subscription cache: $e');
      return null;
    }
  }

  Future<void> _saveSubscriptionDataToCache({
    required List<SubscriptionPlan> plans,
    required UserSubscription? current,
  }) async {
    try {
      final userId = UserService().getUserId();
      if (userId == null || userId.isEmpty) return;

      final payload = {
        'cachedAt': DateTime.now().toIso8601String(),
        'plans': plans.map(_mapPlanToJson).toList(),
        'current': current == null ? null : _mapCurrentToJson(current),
      };

      await CacheService.saveData(
        _subscriptionCacheKey(userId),
        jsonEncode(payload),
      );
    } catch (e) {
      debugPrint('SubscriptionPage: failed to save subscription cache: $e');
    }
  }

  Map<String, dynamic> _mapPlanToJson(SubscriptionPlan plan) {
    return {
      'tier': plan.tier,
      'name': plan.name,
      'price': plan.price,
      'currency': plan.currency,
      'interval': plan.interval,
      'description': plan.description,
      'benefits': {
        'freeDelivery': plan.freeDeliveryText,
        'serviceFeeDiscount': plan.serviceFeeDiscountText,
        'prioritySupport': plan.prioritySupport,
        'exclusiveDeals': plan.exclusiveDeals,
      },
    };
  }

  Map<String, dynamic> _mapCurrentToJson(UserSubscription current) {
    return {
      'id': current.id,
      'tier': current.tier,
      'tierName': current.tierName,
      'status': current.status,
      'pendingPaymentReference': current.pendingPaymentReference,
      'currentPeriodStart': current.currentPeriodStart?.toIso8601String(),
      'currentPeriodEnd': current.currentPeriodEnd?.toIso8601String(),
      'cancelledAt': current.cancelledAt?.toIso8601String(),
    };
  }

  String? _resolveSelectedTier({
    required List<SubscriptionPlan> plans,
    required UserSubscription? current,
    required String? existingSelectedTier,
  }) {
    bool hasTier(String? tier) =>
        tier != null && plans.any((plan) => plan.tier == tier);

    if (plans.isEmpty) return null;
    if (hasTier(existingSelectedTier)) return existingSelectedTier;
    if (hasTier(current?.tier)) return current?.tier;
    return plans.first.tier;
  }

  SubscriptionPlan? _findPlanByTier(String tier) {
    for (final plan in _plans) {
      if (plan.tier == tier) return plan;
    }
    return null;
  }

  String _formatPriceLabel(SubscriptionPlan plan) {
    final priceText = plan.price == plan.price.roundToDouble()
        ? plan.price.toStringAsFixed(0)
        : plan.price.toStringAsFixed(2);
    return 'GH₵$priceText';
  }

  String _formatInterval(String interval) {
    switch (interval.trim().toLowerCase()) {
      case 'monthly':
        return 'per month';
      case 'yearly':
      case 'annual':
        return 'per year';
      case 'weekly':
        return 'per week';
      default:
        return interval.trim().isEmpty ? '' : 'per ${interval.toLowerCase()}';
    }
  }

  String _buildPlanDescription(SubscriptionPlan? plan) {
    if (plan == null) {
      return _isLoading
          ? '...'
          : 'Select a plan to view your GrabGo subscription details and benefits.';
    }

    final description = plan.description.trim();
    if (description.isNotEmpty) return description;

    final bits = <String>[];
    if (plan.freeDeliveryText.trim().isNotEmpty) {
      bits.add(plan.freeDeliveryText.trim());
    }
    if (plan.serviceFeeDiscountText.trim().isNotEmpty) {
      bits.add(plan.serviceFeeDiscountText.trim());
    }
    if (plan.prioritySupport) {
      bits.add('Priority support');
    }
    if (plan.exclusiveDeals) {
      bits.add('Exclusive deals');
    }

    if (bits.isNotEmpty) return bits.join('. ');
    return 'Enjoy premium GrabGo delivery perks and subscriber-only value on every order.';
  }

  String _formatRenewalDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  String? _badgeAssetForTier(String? tier) {
    if (tier == null) return null;
    switch (tier.trim().toLowerCase()) {
      case 'grabgo_plus':
        return Assets.icons.grabgoPlusBadge;
      case 'grabgo_premium':
        return Assets.icons.grabgoPremiumBadge;
      default:
        return null;
    }
  }

  Widget _buildTierBadge(
    String? tier,
    AppColorsExtension colors, {
    double size = 18,
    bool onOrangeSurface = false,
  }) {
    final asset = _badgeAssetForTier(tier);
    if (asset == null) return const SizedBox.shrink();

    final badge = SvgPicture.asset(
      asset,
      package: 'grab_go_shared',
      width: size,
      height: size,
      fit: BoxFit.contain,
    );

    if (!onOrangeSurface) {
      return badge;
    }

    return Container(
      padding: EdgeInsets.all(4.r),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999.r),
      ),
      child: badge,
    );
  }

  Future<void> _onPrimaryAction(SubscriptionPlan selectedPlan) async {
    if (_isSubmitting) return;
    if (_hasPendingSubscription) {
      await _confirmPendingPayment();
      return;
    }
    if (_current == null) {
      await _startSubscription(selectedPlan);
      return;
    }

    final isPastDueCurrentTier =
        _current?.status.trim().toLowerCase() == 'past_due' &&
        _current?.tier == selectedPlan.tier;
    if (isPastDueCurrentTier) {
      await _startSubscription(selectedPlan);
      return;
    }

    await _cancelCurrentPlan();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selectedPlan = _selectedPlan;
    final safePadding = MediaQuery.of(context).padding;

    final systemUiOverlayStyle = SystemUiOverlayStyle(
      statusBarColor: colors.accentViolet,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: colors.backgroundPrimary,
      systemNavigationBarIconBrightness: isDark
          ? Brightness.light
          : Brightness.dark,
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: systemUiOverlayStyle,
      child: Scaffold(
        backgroundColor: colors.backgroundPrimary,
        body: Column(
          children: [
            Expanded(
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  _buildHeaderSliver(colors, selectedPlan),
                  if (_plans.isEmpty && !_isLoading)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 24.w),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.subscriptions_outlined,
                              size: 42.r,
                              color: colors.textSecondary,
                            ),
                            SizedBox(height: 12.h),
                            Text(
                              'No subscription plans are available right now.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: colors.textSecondary,
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(16.w, 18.h, 16.w, 24.h),
                      sliver: SliverToBoxAdapter(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_current != null) _buildCurrentPlanCard(colors),
                            Text(
                              'Choose a plan',
                              style: TextStyle(
                                color: colors.textPrimary,
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            SizedBox(height: 12.h),
                            if (_plans.isNotEmpty)
                              ..._buildPlanCardsWithDividers(colors)
                            else
                              ..._buildLoadingPlanCardsWithDividers(colors),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (_isLoading || _plans.isNotEmpty)
              Container(
                padding: EdgeInsets.only(
                  left: 16.w,
                  right: 16.w,
                  top: 14.h,
                  bottom: safePadding.bottom + 14.h,
                ),
                decoration: BoxDecoration(
                  color: colors.backgroundPrimary,
                  border: Border(
                    top: BorderSide(
                      color: colors.backgroundSecondary,
                      width: 0.5,
                    ),
                  ),
                ),
                child: _isLoading
                    ? _buildLoadingActionButton(colors)
                    : _buildPrimaryActionButton(colors, selectedPlan),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderSliver(
    AppColorsExtension colors,
    SubscriptionPlan? selectedPlan,
  ) {
    final expandedHeight = (MediaQuery.sizeOf(context).height * 0.34)
        .clamp(260.0, 330.0)
        .toDouble();
    final headerDescription = _buildPlanDescription(selectedPlan);

    return SliverAppBar(
      pinned: true,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      backgroundColor: colors.accentOrange,
      automaticallyImplyLeading: false,
      expandedHeight: expandedHeight,
      leadingWidth: 72.w,
      leading: Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: EdgeInsets.only(left: 12.w),
          child: SizedBox(
            height: 44,
            width: 44,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => context.pop(),
                  customBorder: const CircleBorder(),
                  child: Center(
                    child: SvgPicture.asset(
                      Assets.icons.navArrowLeft,
                      package: 'grab_go_shared',
                      colorFilter: const ColorFilter.mode(
                        Colors.white,
                        BlendMode.srcIn,
                      ),
                      width: 24.w,
                      height: 24.h,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      titleSpacing: 0,
      title: Text(
        'Subscription',
        style: TextStyle(
          fontFamily: 'Lato',
          package: 'grab_go_shared',
          color: Colors.white,
          fontSize: 20.sp,
          fontWeight: FontWeight.w800,
        ),
      ),
      flexibleSpace: LayoutBuilder(
        builder: (context, constraints) {
          final topPadding = MediaQuery.paddingOf(context).top;
          final minHeight = kToolbarHeight + topPadding;
          final rawProgress =
              (constraints.maxHeight - minHeight) /
              (expandedHeight - minHeight);
          final expandedProgress = rawProgress.clamp(0.0, 1.0);
          final artworkOpacity =
              (Curves.easeOut.transform(expandedProgress) * 0.36).clamp(
                0.0,
                0.36,
              );
          final artworkScale = 0.88 + (expandedProgress * 0.12);

          return Stack(
            fit: StackFit.expand,
            children: [
              Container(color: colors.accentOrange),
              Positioned(
                right: -16.w,
                top: 62.h,
                child: IgnorePointer(
                  child: Opacity(
                    opacity: artworkOpacity,
                    child: Transform.scale(
                      scale: artworkScale,
                      alignment: Alignment.topRight,
                      child: SvgPicture.asset(
                        _subscriptionPromoAsset,
                        package: 'grab_go_shared',
                        width: 172.w,
                        height: 172.w,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              ),
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(20.w, 76.h, 20.w, 20.h),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        'Choose Your Subscription Plan',
                        style: TextStyle(
                          fontFamily: 'Lato',
                          package: 'grab_go_shared',
                          color: Colors.white,
                          fontSize: 29.sp,
                          fontWeight: FontWeight.w900,
                          height: 1.05,
                        ),
                      ),
                      SizedBox(height: 12.h),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        child: Text(
                          headerDescription,
                          key: ValueKey<String>(selectedPlan?.tier ?? 'none'),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.92),
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w500,
                            height: 1.45,
                          ),
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCurrentPlanCard(AppColorsExtension colors) {
    final current = _current!;
    final currentStatus = current.status.trim().toLowerCase();
    final isPending = currentStatus == 'pending';
    final isPastDue = currentStatus == 'past_due';
    final hasPendingReference =
        (current.pendingPaymentReference?.isNotEmpty ?? false);
    final currentBadgeAsset = _badgeAssetForTier(current.tier);
    final headerTitle = isPending
        ? 'Payment Pending'
        : isPastDue
        ? 'Payment Overdue'
        : 'Active Plan';
    final backgroundColor = isPending
        ? colors.accentOrange.withValues(alpha: 0.08)
        : isPastDue
        ? colors.error.withValues(alpha: 0.08)
        : colors.accentViolet.withValues(alpha: 0.08);
    final borderColor = isPending
        ? colors.accentOrange.withValues(alpha: 0.32)
        : isPastDue
        ? colors.error.withValues(alpha: 0.32)
        : colors.accentViolet.withValues(alpha: 0.32);

    return Container(
      margin: EdgeInsets.only(bottom: 14.h),
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            headerTitle,
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 11.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 4.h),
          Row(
            children: [
              Expanded(
                child: Text(
                  current.tierName,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (currentBadgeAsset != null) ...[
                SizedBox(width: 8.w),
                _buildTierBadge(current.tier, colors, size: 20),
              ],
            ],
          ),
          if (isPending) ...[
            SizedBox(height: 4.h),
            Text(
              'We are waiting for Paystack confirmation. Tap confirm after payment.',
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: 12.sp,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 10.h),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    width: double.infinity,
                    onPressed: _isSubmitting
                        ? () {}
                        : () => _confirmPendingPayment(),
                    isLoading: _isSubmitting,
                    backgroundColor: colors.accentOrange,
                    borderRadius: 12.r,
                    buttonText: 'Confirm Payment',
                    padding: EdgeInsets.symmetric(vertical: 12.h),
                    textStyle: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 12.sp,
                    ),
                  ),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isSubmitting
                        ? null
                        : () async {
                            final pendingPlan = _findPlanByTier(current.tier);
                            if (pendingPlan == null) {
                              AppToastMessage.show(
                                context: context,
                                message:
                                    'Plan not available. Please refresh and try again.',
                                backgroundColor: colors.error,
                              );
                              return;
                            }
                            if (!hasPendingReference) {
                              AppToastMessage.show(
                                context: context,
                                message: 'Starting a new payment attempt...',
                                backgroundColor: colors.accentOrange,
                              );
                            }
                            await _startSubscription(pendingPlan);
                          },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colors.textPrimary,
                      side: BorderSide(
                        color: colors.inputBorder.withValues(alpha: 0.8),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      padding: EdgeInsets.symmetric(vertical: 12.h),
                    ),
                    child: Text(
                      'Start New Payment',
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ] else if (isPastDue) ...[
            SizedBox(height: 4.h),
            Text(
              'Your latest renewal payment failed. Retry payment to keep this plan active.',
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: 12.sp,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 10.h),
            AppButton(
              width: double.infinity,
              onPressed: _isSubmitting
                  ? () {}
                  : () async {
                      final overduePlan = _findPlanByTier(current.tier);
                      if (overduePlan == null) {
                        AppToastMessage.show(
                          context: context,
                          message:
                              'Plan not available. Please refresh and try again.',
                          backgroundColor: colors.error,
                        );
                        return;
                      }
                      await _startSubscription(overduePlan);
                    },
              isLoading: _isSubmitting,
              backgroundColor: colors.accentOrange,
              borderRadius: 12.r,
              buttonText: 'Retry Payment',
              padding: EdgeInsets.symmetric(vertical: 12.h),
              textStyle: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 12.sp,
              ),
            ),
          ] else if (current.currentPeriodEnd != null) ...[
            SizedBox(height: 4.h),
            Text(
              'Renews on ${_formatRenewalDate(current.currentPeriodEnd!)}',
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: 12.sp,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPlanCard(SubscriptionPlan plan, AppColorsExtension colors) {
    final isSelected = _selectedTier == plan.tier;
    final isCurrentTier = _current?.tier == plan.tier;
    final planDescription = _buildPlanDescription(plan);
    final planBadgeAsset = _badgeAssetForTier(plan.tier);

    return GestureDetector(
      onTap: (_isSubmitting || _hasPendingSubscription)
          ? null
          : () => setState(() => _selectedTier = plan.tier),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        margin: EdgeInsets.zero,
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
        decoration: BoxDecoration(
          color: colors.backgroundPrimary,
          borderRadius: BorderRadius.circular(14.r),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.only(top: 2.h),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutCubic,
                height: 24.h,
                width: 24.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected
                      ? colors.accentOrange.withValues(alpha: 0.12)
                      : Colors.transparent,
                ),
                child: Center(
                  child: AnimatedScale(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutBack,
                    scale: isSelected ? 1 : 0,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 180),
                      opacity: isSelected ? 1 : 0,
                      child: Container(
                        height: 10.h,
                        width: 10.w,
                        decoration: BoxDecoration(
                          color: colors.accentOrange,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(
                                plan.name,
                                style: TextStyle(
                                  color: colors.textPrimary,
                                  fontSize: 21.sp,
                                  fontWeight: FontWeight.w800,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (planBadgeAsset != null) ...[
                              SizedBox(width: 6.w),
                              _buildTierBadge(plan.tier, colors, size: 20),
                            ],
                          ],
                        ),
                      ),
                      SizedBox(width: 8.w),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            _formatPriceLabel(plan),
                            style: TextStyle(
                              color: colors.textPrimary,
                              fontSize: 28.sp,
                              fontWeight: FontWeight.w900,
                              height: 1,
                            ),
                          ),
                          SizedBox(height: 2.h),
                          Text(
                            _formatInterval(plan.interval),
                            style: TextStyle(
                              color: colors.textSecondary,
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    planDescription,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                    ),
                  ),
                  if (isCurrentTier) ...[
                    SizedBox(height: 6.h),
                    Text(
                      'Current plan',
                      style: TextStyle(
                        color: colors.accentOrange,
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildLoadingPlanCardsWithDividers(AppColorsExtension colors) {
    const totalItems = 3;
    return List<Widget>.generate(totalItems, (index) {
      return Column(
        children: [
          _buildLoadingPlanCard(colors, isSelected: index == 0),
          if (index != totalItems - 1)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 14.w),
              child: Column(
                children: [
                  SizedBox(height: 12.h),
                  Divider(
                    height: 1.h,
                    thickness: 1,
                    color: colors.inputBorder.withValues(alpha: 0.35),
                  ),
                  SizedBox(height: 12.h),
                ],
              ),
            ),
        ],
      );
    });
  }

  Widget _buildLoadingPlanCard(
    AppColorsExtension colors, {
    required bool isSelected,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      margin: EdgeInsets.zero,
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
      decoration: BoxDecoration(
        color: colors.backgroundPrimary,
        borderRadius: BorderRadius.circular(14.r),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(top: 2.h),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              height: 24.h,
              width: 24.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected
                    ? colors.accentOrange.withValues(alpha: 0.12)
                    : Colors.transparent,
              ),
              child: Center(
                child: AnimatedScale(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutBack,
                  scale: isSelected ? 1 : 0,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 180),
                    opacity: isSelected ? 1 : 0,
                    child: Container(
                      height: 10.h,
                      width: 10.w,
                      decoration: BoxDecoration(
                        color: colors.accentOrange,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        '...',
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 21.sp,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '...',
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontSize: 28.sp,
                            fontWeight: FontWeight.w900,
                            height: 1,
                          ),
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          '...',
                          style: TextStyle(
                            color: colors.textSecondary,
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                SizedBox(height: 8.h),
                Text(
                  '...',
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w500,
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

  List<Widget> _buildPlanCardsWithDividers(AppColorsExtension colors) {
    return _plans.asMap().entries.expand((entry) {
      final index = entry.key;
      final plan = entry.value;
      final widgets = <Widget>[_buildPlanCard(plan, colors)];
      if (index != _plans.length - 1) {
        widgets.add(
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 14.w),
            child: Column(
              children: [
                SizedBox(height: 12.h),
                Divider(
                  height: 1.h,
                  thickness: 1,
                  color: colors.inputBorder.withValues(alpha: 0.35),
                ),
                SizedBox(height: 12.h),
              ],
            ),
          ),
        );
      }
      return widgets;
    }).toList();
  }

  Widget _buildLoadingActionButton(AppColorsExtension colors) {
    return AppButton(
      width: double.infinity,
      onPressed: () {},
      isLoading: false,
      backgroundColor: colors.accentOrange.withValues(alpha: 0.7),
      borderRadius: KBorderSize.borderRadius15,
      buttonText: '...',
      padding: EdgeInsets.symmetric(vertical: 16.h),
      textStyle: TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w700,
        fontSize: 15.sp,
      ),
    );
  }

  Widget _buildPrimaryActionButton(
    AppColorsExtension colors,
    SubscriptionPlan? selectedPlan,
  ) {
    if (selectedPlan == null) return const SizedBox.shrink();

    if (_hasPendingSubscription) {
      return AppButton(
        width: double.infinity,
        onPressed: () => _onPrimaryAction(selectedPlan),
        isLoading: _isSubmitting,
        backgroundColor: _isSubmitting
            ? colors.accentOrange.withValues(alpha: 0.7)
            : colors.accentOrange,
        borderRadius: KBorderSize.borderRadius15,
        buttonText: 'Confirm Payment',
        padding: EdgeInsets.symmetric(vertical: 16.h),
        textStyle: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 15.sp,
        ),
      );
    }

    final hasCurrent = _current != null;
    final isCurrentTier = _current?.tier == selectedPlan.tier;
    final isPastDueCurrentTier =
        _current?.status.trim().toLowerCase() == 'past_due' && isCurrentTier;
    final buttonText = hasCurrent
        ? (isPastDueCurrentTier
              ? 'Retry Payment'
              : (isCurrentTier
                    ? 'Cancel Plan'
                    : 'Cancel current plan to switch'))
        : 'Start Subscription';

    return AppButton(
      width: double.infinity,
      onPressed: () => _onPrimaryAction(selectedPlan),
      isLoading: _isSubmitting,
      backgroundColor: _isSubmitting
          ? colors.accentOrange.withValues(alpha: 0.7)
          : colors.accentOrange,
      borderRadius: KBorderSize.borderRadius15,
      buttonText: buttonText,
      padding: EdgeInsets.symmetric(vertical: 16.h),
      textStyle: TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w700,
        fontSize: 15.sp,
      ),
    );
  }
}

class _CachedSubscriptionData {
  final List<SubscriptionPlan> plans;
  final UserSubscription? current;
  final bool isStale;

  const _CachedSubscriptionData({
    required this.plans,
    required this.current,
    required this.isStale,
  });
}
