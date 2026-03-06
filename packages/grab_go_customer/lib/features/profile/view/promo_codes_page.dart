import 'dart:convert';

import 'package:dotted_line/dotted_line.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_customer/features/cart/viewmodel/cart_provider.dart';
import 'package:grab_go_customer/shared/models/promo_models.dart';
import 'package:grab_go_customer/shared/services/promo_service.dart';
import 'package:grab_go_customer/shared/services/user_service.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:provider/provider.dart';

enum _PromoTab { available, used, expired }

class PromoCodesPage extends StatefulWidget {
  const PromoCodesPage({super.key});

  @override
  State<PromoCodesPage> createState() => _PromoCodesPageState();
}

class _PromoCodesPageState extends State<PromoCodesPage> {
  final PromoService _promoService = PromoService();
  static const Duration _promoCacheMaxAge = Duration(minutes: 30);
  static const String _promoArtworkAsset = 'lib/assets/icons/promo_code_icon.svg';

  PromoCodesBucketResponse _promoData = const PromoCodesBucketResponse(
    available: [],
    used: [],
    expired: [],
    fetchedAt: null,
  );
  bool _isLoading = true;
  _PromoTab _selectedTab = _PromoTab.available;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  String _promoCacheKey(String userId) => 'promo_codes_page_cache_v1_$userId';

  Future<void> _loadData({bool forceRefresh = false}) async {
    var hydratedFromCache = false;

    if (!forceRefresh) {
      final cached = _readCachedPromoData();
      if (cached != null) {
        if (mounted) {
          setState(() {
            _promoData = cached.data;
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
      final data = await _promoService.getMyCodes();
      if (!mounted) return;
      setState(() {
        _promoData = data;
        _isLoading = false;
      });
      await _savePromoDataToCache(data);
    } catch (e) {
      if (!mounted) return;
      if (hydratedFromCache) {
        debugPrint('PromoCodesPage: using cached data due to refresh error: $e');
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

  _CachedPromoData? _readCachedPromoData() {
    try {
      final userId = UserService().getUserId();
      if (userId == null || userId.isEmpty) return null;

      final cachedJson = CacheService.getData(_promoCacheKey(userId));
      if (cachedJson == null || cachedJson.isEmpty) return null;

      final decoded = jsonDecode(cachedJson);
      if (decoded is! Map<String, dynamic>) return null;
      final cachedAtRaw = decoded['cachedAt'];
      final dataRaw = decoded['data'];
      if (cachedAtRaw is! String || dataRaw is! Map) return null;

      final cachedAt = DateTime.tryParse(cachedAtRaw);
      if (cachedAt == null) return null;

      final parsed = PromoCodesBucketResponse.fromJson(Map<String, dynamic>.from(dataRaw));
      final isStale = DateTime.now().difference(cachedAt) > _promoCacheMaxAge;
      return _CachedPromoData(data: parsed, isStale: isStale);
    } catch (e) {
      debugPrint('PromoCodesPage: failed to read cache: $e');
      return null;
    }
  }

  Future<void> _savePromoDataToCache(PromoCodesBucketResponse data) async {
    try {
      final userId = UserService().getUserId();
      if (userId == null || userId.isEmpty) return;

      final payload = {'cachedAt': DateTime.now().toIso8601String(), 'data': data.toJson()};
      await CacheService.saveData(_promoCacheKey(userId), jsonEncode(payload));
    } catch (e) {
      debugPrint('PromoCodesPage: failed to save cache: $e');
    }
  }

  List<PromoCodeListItem> get _activeItems {
    switch (_selectedTab) {
      case _PromoTab.available:
        return _promoData.available;
      case _PromoTab.used:
        return _promoData.used;
      case _PromoTab.expired:
        return _promoData.expired;
    }
  }

  String _headerDescription() {
    switch (_selectedTab) {
      case _PromoTab.available:
        return 'Use available promo codes on eligible single-vendor food and grocery carts.';
      case _PromoTab.used:
        return 'Track promo codes you have already used and the total savings you earned.';
      case _PromoTab.expired:
        return 'View promo codes that are no longer active or have reached usage limits.';
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'N/A';
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${date.day.toString().padLeft(2, '0')} ${months[date.month - 1]} ${date.year}';
  }

  String _formatPrice(double amount) {
    return amount == amount.roundToDouble() ? amount.toStringAsFixed(0) : amount.toStringAsFixed(2);
  }

  String _benefitSummary(PromoCodeListItem item) {
    switch (item.type.toLowerCase()) {
      case 'percentage':
        final percent = _formatPrice(item.value);
        if (item.maxDiscountAmount != null && item.maxDiscountAmount! > 0) {
          return '$percent% off (up to GH₵${_formatPrice(item.maxDiscountAmount!)})';
        }
        return '$percent% off';
      case 'fixed':
        return 'GH₵${_formatPrice(item.value)} off';
      case 'free_delivery':
        return 'Free delivery';
      default:
        return item.description.trim().isEmpty ? 'Special offer' : item.description.trim();
    }
  }

  String _orderTypesLabel(List<String> orderTypes) {
    if (orderTypes.isEmpty) return 'Food & Grocery';
    final labels = orderTypes
        .map((type) => type.trim().toLowerCase())
        .where((type) => type.isNotEmpty)
        .map((type) {
          if (type == 'food') return 'Food';
          if (type == 'grocery') return 'Grocery';
          if (type == 'grabmart') return 'GrabMart';
          if (type == 'pharmacy') return 'Pharmacy';
          return type[0].toUpperCase() + type.substring(1);
        })
        .toList(growable: false);
    return labels.isEmpty ? 'Food & Grocery' : labels.join(', ');
  }

  String _constraintsSummary(PromoCodeListItem item) {
    final parts = <String>[];
    if (item.minOrderAmount > 0) {
      parts.add('Min order GH₵${_formatPrice(item.minOrderAmount)}');
    }
    parts.add('Applies to ${_orderTypesLabel(item.applicableOrderTypes)}');
    if (item.endDate != null) {
      parts.add('Expires ${_formatDate(item.endDate)}');
    }
    if (item.firstOrderOnly) {
      parts.add('First order only');
    }
    return parts.join(' • ');
  }

  Future<void> _copyCode(String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) return;
    AppToastMessage.show(
      context: context,
      message: 'Promo code $code copied.',
      backgroundColor: context.appColors.accentGreen,
    );
  }

  Future<void> _applyInCart(PromoCodeListItem promo) async {
    final provider = context.read<CartProvider>();
    LoadingDialog.instance().show(context: context, text: 'Applying promo code...');
    try {
      final error = await provider.applyPromoCode(promo.code);
      if (!mounted) return;

      if (error == null) {
        AppToastMessage.show(
          context: context,
          message: 'Promo code ${promo.code} applied.',
          backgroundColor: context.appColors.accentGreen,
        );
        context.push('/cart');
        return;
      }

      AppToastMessage.show(context: context, message: error, backgroundColor: context.appColors.error);
    } catch (e) {
      if (!mounted) return;
      AppToastMessage.show(
        context: context,
        message: e.toString().replaceFirst('Exception: ', ''),
        backgroundColor: context.appColors.error,
      );
    } finally {
      LoadingDialog.instance().hide();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final systemUiOverlayStyle = SystemUiOverlayStyle(
      statusBarColor: colors.accentOrange,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: colors.backgroundPrimary,
      systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
    );

    final activeItems = _activeItems;
    final showLoadingCards = _isLoading && activeItems.isEmpty;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: systemUiOverlayStyle,
      child: Scaffold(
        backgroundColor: colors.backgroundPrimary,
        body: AppRefreshIndicator(
          bgColor: colors.accentOrange,
          iconPath: Assets.icons.badgePercent,
          onRefresh: () => _loadData(forceRefresh: true),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              _buildHeaderSliver(colors),
              SliverToBoxAdapter(child: SizedBox(height: 16.h)),
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  child: _buildTabSelector(colors),
                ),
              ),
              SliverToBoxAdapter(child: SizedBox(height: 14.h)),
              if (showLoadingCards)
                SliverPadding(
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      const loadingCount = 3;
                      return Column(
                        children: [
                          _buildLoadingCard(colors),
                          if (index != loadingCount - 1) ...[
                            SizedBox(height: 12.h),
                            _buildCardDivider(colors),
                            SizedBox(height: 12.h),
                          ],
                        ],
                      );
                    }, childCount: 3),
                  ),
                )
              else if (activeItems.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 30.w),
                      child: Text(
                        _emptyStateLabel(),
                        textAlign: TextAlign.center,
                        style: TextStyle(color: colors.textSecondary, fontSize: 13.sp, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: EdgeInsets.symmetric(horizontal: 20.w),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final item = activeItems[index];
                      return Column(
                        children: [
                          _buildPromoCard(colors, item),
                          if (index != activeItems.length - 1) ...[
                            SizedBox(height: 12.h),
                            _buildCardDivider(colors),
                            SizedBox(height: 12.h),
                          ],
                        ],
                      );
                    }, childCount: activeItems.length),
                  ),
                ),
              SliverToBoxAdapter(child: SizedBox(height: 28.h)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderSliver(AppColorsExtension colors) {
    final expandedHeight = (MediaQuery.sizeOf(context).height * 0.34).clamp(260.0, 330.0).toDouble();

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
        'Promo Codes',
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
          final artworkOpacity = (Curves.easeOut.transform(expandedProgress) * 0.36).clamp(0.0, 0.34);
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
                        _promoArtworkAsset,
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
                        'Save More with GrabGo',
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
                          _isLoading &&
                                  _promoData.available.isEmpty &&
                                  _promoData.used.isEmpty &&
                                  _promoData.expired.isEmpty
                              ? '...'
                              : _headerDescription(),
                          key: ValueKey<String>(_selectedTab.name),
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

  Widget _buildTabSelector(AppColorsExtension colors) {
    final tabConfigs = <({String label, _PromoTab tab, int count})>[
      (label: 'Available', tab: _PromoTab.available, count: _promoData.available.length),
      (label: 'Used', tab: _PromoTab.used, count: _promoData.used.length),
      (label: 'Expired', tab: _PromoTab.expired, count: _promoData.expired.length),
    ];
    final selectedIndex = tabConfigs.indexWhere((config) => config.tab == _selectedTab);

    return Container(
      padding: EdgeInsets.all(4.r),
      decoration: BoxDecoration(color: colors.backgroundSecondary, borderRadius: BorderRadius.circular(999.r)),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tabWidth = constraints.maxWidth / tabConfigs.length;
          return Stack(
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                left: tabWidth * selectedIndex,
                top: 0,
                bottom: 0,
                width: tabWidth,
                child: Container(
                  decoration: BoxDecoration(color: colors.accentOrange, borderRadius: BorderRadius.circular(999.r)),
                ),
              ),
              Row(
                children: tabConfigs
                    .map((config) {
                      final selected = _selectedTab == config.tab;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedTab = config.tab),
                          behavior: HitTestBehavior.opaque,
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 8.w),
                            child: AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 220),
                              curve: Curves.easeOutCubic,
                              style: TextStyle(
                                color: selected ? Colors.white : colors.textSecondary,
                                fontSize: 12.sp,
                                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                              ),
                              child: Text('${config.label} (${config.count})', textAlign: TextAlign.center),
                            ),
                          ),
                        ),
                      );
                    })
                    .toList(growable: false),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPromoCard(AppColorsExtension colors, PromoCodeListItem item) {
    final isAvailable = _selectedTab == _PromoTab.available;
    final isUsed = _selectedTab == _PromoTab.used;
    final statusLabel = isUsed ? 'Used' : 'Expired';
    final statusColor = isUsed ? colors.accentGreen : colors.error;
    final description = item.description.trim().isEmpty ? _benefitSummary(item) : item.description.trim();

    return Container(
      padding: EdgeInsets.symmetric(vertical: 14.h),
      decoration: BoxDecoration(color: colors.backgroundPrimary, borderRadius: BorderRadius.circular(14.r)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.code,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w900,
                    fontSize: 17.sp,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              if (!isAvailable)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999.r),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(color: statusColor, fontWeight: FontWeight.w700, fontSize: 10.sp),
                  ),
                ),
            ],
          ),
          SizedBox(height: 6.h),
          Text(
            _benefitSummary(item),
            style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w700, fontSize: 13.sp),
          ),
          SizedBox(height: 4.h),
          Text(
            description,
            style: TextStyle(color: colors.textSecondary, fontWeight: FontWeight.w500, fontSize: 11.sp, height: 1.35),
          ),
          SizedBox(height: 8.h),
          if (isAvailable)
            Text(
              _constraintsSummary(item),
              style: TextStyle(color: colors.textSecondary, fontWeight: FontWeight.w500, fontSize: 10.5.sp),
            )
          else if (isUsed)
            Text(
              'Last used: ${_formatDate(item.lastUsedAt)} • Saved GH₵${_formatPrice(item.totalSaved)}',
              style: TextStyle(color: colors.textSecondary, fontWeight: FontWeight.w500, fontSize: 10.5.sp),
            )
          else
            Text(
              item.statusReason?.trim().isNotEmpty == true
                  ? 'Reason: ${item.statusReason!.replaceAll('_', ' ')}'
                  : 'Expired on ${_formatDate(item.endDate)}',
              style: TextStyle(color: colors.textSecondary, fontWeight: FontWeight.w500, fontSize: 10.5.sp),
            ),
          if (isAvailable) ...[
            SizedBox(height: 12.h),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _copyCode(item.code),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: colors.inputBorder.withValues(alpha: 0.8)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
                      padding: EdgeInsets.symmetric(vertical: 14.h),
                    ),
                    child: Text(
                      'Copy',
                      style: TextStyle(color: colors.textPrimary, fontSize: 12.sp, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: AppButton(
                    onPressed: () => _applyInCart(item),
                    buttonText: 'Apply in Cart',
                    borderRadius: KBorderSize.borderMedium,
                    padding: EdgeInsets.symmetric(vertical: 14.h),
                    textStyle: TextStyle(color: Colors.white, fontSize: 12.sp, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLoadingCard(AppColorsExtension colors) {
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: colors.backgroundPrimary,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: colors.inputBorder.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '...',
            style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w900, fontSize: 17.sp),
          ),
          SizedBox(height: 6.h),
          Text(
            '...',
            style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w700, fontSize: 13.sp),
          ),
          SizedBox(height: 4.h),
          Text(
            '...',
            style: TextStyle(color: colors.textSecondary, fontWeight: FontWeight.w500, fontSize: 11.sp, height: 1.35),
          ),
          SizedBox(height: 8.h),
          Text(
            '...',
            style: TextStyle(color: colors.textSecondary, fontWeight: FontWeight.w500, fontSize: 10.5.sp),
          ),
          if (_selectedTab == _PromoTab.available) ...[
            SizedBox(height: 12.h),
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 40.h,
                    decoration: BoxDecoration(
                      color: colors.backgroundSecondary,
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '...',
                      style: TextStyle(color: colors.textSecondary, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: Container(
                    height: 40.h,
                    decoration: BoxDecoration(
                      color: colors.accentOrange.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      '...',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCardDivider(AppColorsExtension colors) {
    return DottedLine(dashLength: 6, dashGapLength: 4, lineThickness: 1, dashColor: colors.textSecondary.withAlpha(50));
  }

  String _emptyStateLabel() {
    switch (_selectedTab) {
      case _PromoTab.available:
        return 'No promo codes available right now.';
      case _PromoTab.used:
        return 'No used promo codes yet.';
      case _PromoTab.expired:
        return 'No expired promo codes yet.';
    }
  }
}

class _CachedPromoData {
  final PromoCodesBucketResponse data;
  final bool isStale;

  const _CachedPromoData({required this.data, required this.isStale});
}
