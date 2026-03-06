import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_customer/shared/services/user_service.dart';
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
  static const String _subscriptionPromoAsset = 'lib/assets/icons/promo_banner_five.svg';
  static const Duration _subscriptionCacheMaxAge = Duration(minutes: 30);

  bool _isLoading = true;
  bool _isSubmitting = false;
  List<SubscriptionPlan> _plans = const [];
  UserSubscription? _current;
  String? _selectedTier;

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
        }
        hydratedFromCache = true;
        if (!cached.isStale) {
          return;
        }
      }
    }

    try {
      final plans = await _service.getPlans();
      final current = await _service.getMySubscription();
      final selectedTier = _resolveSelectedTier(plans: plans, current: current, existingSelectedTier: _selectedTier);
      if (!mounted) return;
      setState(() {
        _plans = plans;
        _current = current;
        _selectedTier = selectedTier;
        _isLoading = false;
      });
      await _saveSubscriptionDataToCache(plans: plans, current: current);
    } catch (e) {
      if (!mounted) return;
      if (hydratedFromCache) {
        debugPrint('SubscriptionPage: using cached data due to refresh error: $e');
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
        await _loadData(forceRefresh: true);
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

  String _subscriptionCacheKey(String userId) => 'subscription_page_cache_v1_$userId';

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
          plans.add(SubscriptionPlan.fromJson(Map<String, dynamic>.from(entry)));
        }
      }

      final currentRaw = decoded['current'];
      UserSubscription? current;
      if (currentRaw is Map) {
        current = UserSubscription.fromJson(Map<String, dynamic>.from(currentRaw));
      }

      final isStale = DateTime.now().difference(cachedAt) > _subscriptionCacheMaxAge;
      return _CachedSubscriptionData(plans: plans, current: current, isStale: isStale);
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

      await CacheService.saveData(_subscriptionCacheKey(userId), jsonEncode(payload));
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
    bool hasTier(String? tier) => tier != null && plans.any((plan) => plan.tier == tier);

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
      return _isLoading ? '...' : 'Select a plan to view your GrabGo subscription details and benefits.';
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

  Future<void> _onPrimaryAction(SubscriptionPlan selectedPlan) async {
    if (_isSubmitting) return;
    if (_current == null) {
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
      systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
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
                            Icon(Icons.subscriptions_outlined, size: 42.r, color: colors.textSecondary),
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
                              style: TextStyle(color: colors.textPrimary, fontSize: 16.sp, fontWeight: FontWeight.w800),
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
                padding: EdgeInsets.only(left: 16.w, right: 16.w, top: 14.h, bottom: safePadding.bottom + 14.h),
                decoration: BoxDecoration(
                  color: colors.backgroundPrimary,
                  border: Border(top: BorderSide(color: colors.backgroundSecondary, width: 0.5)),
                ),
                child: _isLoading ? _buildLoadingActionButton(colors) : _buildPrimaryActionButton(colors, selectedPlan),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderSliver(AppColorsExtension colors, SubscriptionPlan? selectedPlan) {
    final expandedHeight = (MediaQuery.sizeOf(context).height * 0.34).clamp(260.0, 330.0).toDouble();
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
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => context.pop(),
                  customBorder: const CircleBorder(),
                  child: Center(
                    child: SvgPicture.asset(
                      Assets.icons.navArrowLeft,
                      package: 'grab_go_shared',
                      colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
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
          final rawProgress = (constraints.maxHeight - minHeight) / (expandedHeight - minHeight);
          final expandedProgress = rawProgress.clamp(0.0, 1.0);
          final artworkOpacity = (Curves.easeOut.transform(expandedProgress) * 0.36).clamp(0.0, 0.36);
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
    return Container(
      margin: EdgeInsets.only(bottom: 14.h),
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: colors.accentViolet.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: colors.accentViolet.withValues(alpha: 0.32)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Active Plan',
            style: TextStyle(color: colors.textSecondary, fontSize: 11.sp, fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 4.h),
          Text(
            current.tierName,
            style: TextStyle(color: colors.textPrimary, fontSize: 16.sp, fontWeight: FontWeight.w800),
          ),
          if (current.currentPeriodEnd != null) ...[
            SizedBox(height: 4.h),
            Text(
              'Renews on ${_formatRenewalDate(current.currentPeriodEnd!)}',
              style: TextStyle(color: colors.textSecondary, fontSize: 12.sp, fontWeight: FontWeight.w500),
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

    return GestureDetector(
      onTap: _isSubmitting ? null : () => setState(() => _selectedTier = plan.tier),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        margin: EdgeInsets.zero,
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
        decoration: BoxDecoration(color: colors.backgroundPrimary, borderRadius: BorderRadius.circular(14.r)),
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
                  color: isSelected ? colors.accentOrange.withValues(alpha: 0.12) : Colors.transparent,
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
                        decoration: BoxDecoration(color: colors.accentOrange, shape: BoxShape.circle),
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
                          plan.name,
                          style: TextStyle(color: colors.textPrimary, fontSize: 21.sp, fontWeight: FontWeight.w800),
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
                            style: TextStyle(color: colors.textSecondary, fontSize: 11.sp, fontWeight: FontWeight.w600),
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
                      style: TextStyle(color: colors.accentOrange, fontSize: 11.sp, fontWeight: FontWeight.w700),
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
                  Divider(height: 1.h, thickness: 1, color: colors.inputBorder.withValues(alpha: 0.35)),
                  SizedBox(height: 12.h),
                ],
              ),
            ),
        ],
      );
    });
  }

  Widget _buildLoadingPlanCard(AppColorsExtension colors, {required bool isSelected}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      margin: EdgeInsets.zero,
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
      decoration: BoxDecoration(color: colors.backgroundPrimary, borderRadius: BorderRadius.circular(14.r)),
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
                color: isSelected ? colors.accentOrange.withValues(alpha: 0.12) : Colors.transparent,
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
                      decoration: BoxDecoration(color: colors.accentOrange, shape: BoxShape.circle),
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
                        style: TextStyle(color: colors.textPrimary, fontSize: 21.sp, fontWeight: FontWeight.w800),
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
                          style: TextStyle(color: colors.textSecondary, fontSize: 11.sp, fontWeight: FontWeight.w600),
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
                Divider(height: 1.h, thickness: 1, color: colors.inputBorder.withValues(alpha: 0.35)),
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
      textStyle: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15.sp),
    );
  }

  Widget _buildPrimaryActionButton(AppColorsExtension colors, SubscriptionPlan? selectedPlan) {
    if (selectedPlan == null) return const SizedBox.shrink();

    final hasCurrent = _current != null;
    final isCurrentTier = _current?.tier == selectedPlan.tier;
    final buttonText = hasCurrent
        ? (isCurrentTier ? 'Cancel Plan' : 'Cancel current plan to switch')
        : 'Start Subscription';

    return AppButton(
      width: double.infinity,
      onPressed: () => _onPrimaryAction(selectedPlan),
      isLoading: _isSubmitting,
      backgroundColor: _isSubmitting ? colors.accentOrange.withValues(alpha: 0.7) : colors.accentOrange,
      borderRadius: KBorderSize.borderRadius15,
      buttonText: buttonText,
      padding: EdgeInsets.symmetric(vertical: 16.h),
      textStyle: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15.sp),
    );
  }
}

class _CachedSubscriptionData {
  final List<SubscriptionPlan> plans;
  final UserSubscription? current;
  final bool isStale;

  const _CachedSubscriptionData({required this.plans, required this.current, required this.isStale});
}
