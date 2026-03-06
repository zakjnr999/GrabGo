import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_customer/shared/services/user_service.dart' as customer_user;
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:shimmer/shimmer.dart';

class CreditsScreen extends StatefulWidget {
  const CreditsScreen({super.key});

  @override
  State<CreditsScreen> createState() => _CreditsScreenState();
}

class _CreditsScreenState extends State<CreditsScreen> {
  final CreditService _creditService = CreditService();
  static const Duration _creditsCacheMaxAge = Duration(minutes: 30);
  static const String _creditsPromoAsset = 'lib/assets/icons/grabgo_credit_icon.svg';

  CreditBalance? _balance;
  List<CreditTransaction> _transactions = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  int _currentPage = 1;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  String _creditsCacheKey(String userId) => 'credits_page_cache_v1_$userId';

  Future<void> _loadData({bool forceRefresh = false}) async {
    bool hydratedFromCache = false;

    if (!forceRefresh) {
      final cached = _readCachedCreditsData();
      if (cached != null) {
        if (mounted) {
          setState(() {
            _balance = cached.balance;
            _transactions = cached.transactions;
            _isLoading = false;
            _currentPage = 1;
            _hasMore = cached.transactions.length >= 20;
          });
        }
        hydratedFromCache = true;
        if (!cached.isStale) {
          return;
        }
      }
    }

    try {
      final balance = await _creditService.getBalance();
      final transactions = await _creditService.getTransactionHistory(page: 1);

      if (hydratedFromCache && balance == null && transactions.isEmpty) {
        debugPrint('CreditsScreen: using cached data due to refresh error.');
        return;
      }

      if (!mounted) return;
      setState(() {
        _balance = balance;
        _transactions = transactions;
        _isLoading = false;
        _currentPage = 1;
        _hasMore = transactions.length >= 20;
      });
      await _saveCreditsDataToCache(balance: balance, transactions: transactions);
    } catch (e) {
      if (!mounted) return;
      if (hydratedFromCache) {
        debugPrint('CreditsScreen: using cached data due to refresh error: $e');
      } else {
        setState(() => _isLoading = false);
      }
    }
  }

  _CachedCreditsData? _readCachedCreditsData() {
    try {
      final userId = customer_user.UserService().getUserId();
      if (userId == null || userId.isEmpty) return null;

      final cachedJson = CacheService.getData(_creditsCacheKey(userId));
      if (cachedJson == null || cachedJson.isEmpty) return null;

      final decoded = jsonDecode(cachedJson);
      if (decoded is! Map<String, dynamic>) return null;

      final cachedAtRaw = decoded['cachedAt'];
      final transactionsRaw = decoded['transactions'];
      if (cachedAtRaw is! String || transactionsRaw is! List) return null;

      final cachedAt = DateTime.tryParse(cachedAtRaw);
      if (cachedAt == null) return null;

      final balanceRaw = decoded['balance'];
      CreditBalance? balance;
      if (balanceRaw is Map<String, dynamic>) {
        balance = CreditBalance.fromJson(balanceRaw);
      } else if (balanceRaw is Map) {
        balance = CreditBalance.fromJson(Map<String, dynamic>.from(balanceRaw));
      }

      final transactions = <CreditTransaction>[];
      for (final entry in transactionsRaw) {
        if (entry is Map<String, dynamic>) {
          transactions.add(CreditTransaction.fromJson(entry));
        } else if (entry is Map) {
          transactions.add(CreditTransaction.fromJson(Map<String, dynamic>.from(entry)));
        }
      }

      final isStale = DateTime.now().difference(cachedAt) > _creditsCacheMaxAge;
      return _CachedCreditsData(balance: balance, transactions: transactions, isStale: isStale);
    } catch (e) {
      debugPrint('CreditsScreen: failed to read credits cache: $e');
      return null;
    }
  }

  Future<void> _saveCreditsDataToCache({
    required CreditBalance? balance,
    required List<CreditTransaction> transactions,
  }) async {
    try {
      final userId = customer_user.UserService().getUserId();
      if (userId == null || userId.isEmpty) return;

      final payload = {
        'cachedAt': DateTime.now().toIso8601String(),
        'balance': balance == null ? null : _mapBalanceToJson(balance),
        'transactions': transactions.map(_mapTransactionToJson).toList(),
      };

      await CacheService.saveData(_creditsCacheKey(userId), jsonEncode(payload));
    } catch (e) {
      debugPrint('CreditsScreen: failed to save credits cache: $e');
    }
  }

  Map<String, dynamic> _mapBalanceToJson(CreditBalance balance) {
    return {'balance': balance.balance, 'currency': balance.currency, 'formatted': balance.formatted};
  }

  Map<String, dynamic> _mapTransactionToJson(CreditTransaction transaction) {
    return {
      'id': transaction.id,
      'amount': transaction.amount,
      'formattedAmount': transaction.formattedAmount,
      'type': transaction.type,
      'typeLabel': transaction.typeLabel,
      'description': transaction.description,
      'orderId': transaction.orderId,
      'createdAt': transaction.createdAt.toIso8601String(),
      'isCredit': transaction.isCredit,
    };
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;

    setState(() => _isLoadingMore = true);

    final nextPage = _currentPage + 1;
    final moreTransactions = await _creditService.getTransactionHistory(page: nextPage);

    if (mounted) {
      setState(() {
        _transactions.addAll(moreTransactions);
        _currentPage = nextPage;
        _hasMore = moreTransactions.length >= 20;
        _isLoadingMore = false;
      });
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

    SystemChrome.setSystemUIOverlayStyle(systemUiOverlayStyle);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: systemUiOverlayStyle,
      child: Scaffold(
        backgroundColor: colors.backgroundPrimary,
        body: AppRefreshIndicator(
          bgColor: colors.accentOrange,
          iconPath: Assets.icons.wallet,
          onRefresh: () => _loadData(forceRefresh: true),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              _buildHeaderSliver(colors),
              SliverToBoxAdapter(child: SizedBox(height: 16.h)),
              SliverToBoxAdapter(child: _buildInfoSection(colors)),
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(20.w, 24.h, 20.w, 0.h),
                  child: Text(
                    'Transaction History',
                    style: TextStyle(color: colors.textPrimary, fontSize: 18.sp, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              if (_isLoading)
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _buildTransactionTileSkeleton(colors, isDark),
                    childCount: 5,
                  ),
                )
              else if (_transactions.isEmpty)
                SliverToBoxAdapter(child: _buildEmptyState(colors))
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    if (index == _transactions.length) {
                      if (_hasMore) {
                        _loadMore();
                        return LoadingMore(
                          colors: colors,
                          spinnerColor: colors.accentOrange,
                          borderColor: colors.accentOrange,
                        );
                      }
                      return null;
                    }
                    return _buildTransactionTile(_transactions[index], colors);
                  }, childCount: _transactions.length + (_hasMore ? 1 : 0)),
                ),
              SliverToBoxAdapter(child: SizedBox(height: 32.h)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderSliver(AppColorsExtension colors) {
    final expandedHeight = (MediaQuery.sizeOf(context).height * 0.32).clamp(250.0, 320.0).toDouble();

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
        'GrabGo Credits',
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
                        _creditsPromoAsset,
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
                        'Available Balance',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.92),
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 10.h),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        child: Text(
                          _isLoading ? '...' : _balance?.formatted ?? '₵0.00',
                          key: ValueKey<String>(_isLoading ? 'loading-balance' : (_balance?.formatted ?? '0')),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 42.sp,
                            fontWeight: FontWeight.w900,
                            height: 1,
                          ),
                        ),
                      ),
                      SizedBox(height: 8.h),
                      Text(
                        'Use credits at checkout to save on orders',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.92),
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w500,
                          height: 1.45,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
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

  Widget _buildInfoSection(AppColorsExtension colors) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20.w),
      decoration: BoxDecoration(
        color: colors.backgroundPrimary,
        borderRadius: BorderRadius.circular(KBorderSize.borderMedium),
      ),
      child: Column(
        children: [
          _buildInfoRow(Assets.icons.check, 'Credits are automatically applied at checkout', colors),
          SizedBox(height: 12.h),
          _buildInfoRow(Assets.icons.gift, 'Earn credits from referrals and promotions', colors),
          SizedBox(height: 12.h),
          _buildInfoRow(Assets.icons.infoCircle, 'Credits cannot be withdrawn or transferred', colors),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String icon, String text, AppColorsExtension colors) {
    return Row(
      children: [
        SvgPicture.asset(
          icon,
          package: 'grab_go_shared',
          colorFilter: ColorFilter.mode(colors.accentOrange, BlendMode.srcIn),
          width: 18.sp,
          height: 18.sp,
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: colors.textSecondary, fontSize: 13.sp),
          ),
        ),
      ],
    );
  }

  Widget _buildShimmerBox({
    required double width,
    required double height,
    required AppColorsExtension colors,
    required bool isDark,
    double? borderRadius,
  }) {
    return Shimmer.fromColors(
      baseColor: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
      highlightColor: isDark ? Colors.grey.shade700 : Colors.grey.shade100,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(borderRadius ?? 8.r)),
      ),
    );
  }

  Widget _buildTransactionTileSkeleton(AppColorsExtension colors, bool isDark) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 16.h, horizontal: 20.w),
      color: colors.backgroundPrimary,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildShimmerBox(width: 120.w, height: 14.h, colors: colors, isDark: isDark),
              SizedBox(height: 8.h),
              _buildShimmerBox(width: 180.w, height: 12.h, colors: colors, isDark: isDark),
              SizedBox(height: 8.h),
              _buildShimmerBox(width: 80.w, height: 10.h, colors: colors, isDark: isDark),
            ],
          ),

          // Amount
          _buildShimmerBox(width: 60.w, height: 16.h, colors: colors, isDark: isDark),
        ],
      ),
    );
  }

  Widget _buildEmptyState(AppColorsExtension colors) {
    return Padding(
      padding: EdgeInsets.all(40.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SvgPicture.asset(
            Assets.icons.squareMenu,
            package: 'grab_go_shared',
            width: 60.w,
            height: 60.h,
            colorFilter: ColorFilter.mode(colors.textSecondary, BlendMode.srcIn),
          ),
          SizedBox(height: 16.h),
          Text(
            'No transactions yet',
            style: TextStyle(color: colors.textSecondary, fontSize: 16.sp, fontWeight: FontWeight.w500),
          ),
          SizedBox(height: 8.h),
          Text(
            'Your credit transactions will appear here',
            style: TextStyle(color: colors.textSecondary.withValues(alpha: 0.7), fontSize: 14.sp),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionTile(CreditTransaction tx, AppColorsExtension colors) {
    final isCredit = tx.isCredit;

    return Column(
      children: [
        Container(
          padding: EdgeInsets.symmetric(vertical: 16.h, horizontal: 20.w),
          color: colors.backgroundPrimary,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Details
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tx.typeLabel,
                    style: TextStyle(color: colors.textPrimary, fontSize: 14.sp, fontWeight: FontWeight.w600),
                  ),
                  if (tx.description != null) ...[
                    SizedBox(height: 2.h),
                    Text(
                      tx.description!,
                      style: TextStyle(color: colors.textSecondary, fontSize: 12.sp),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  SizedBox(height: 4.h),
                  Text(
                    _formatDate(tx.createdAt),
                    style: TextStyle(color: colors.textSecondary.withValues(alpha: 0.7), fontSize: 11.sp),
                  ),
                ],
              ),

              // Amount
              Text(
                tx.formattedAmount,
                style: TextStyle(
                  color: isCredit ? colors.accentOrange : colors.error,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        Divider(color: colors.backgroundSecondary, height: 1, thickness: 1, indent: 20, endIndent: 20),
      ],
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      return 'Today';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}

class _CachedCreditsData {
  final CreditBalance? balance;
  final List<CreditTransaction> transactions;
  final bool isStale;

  const _CachedCreditsData({required this.balance, required this.transactions, required this.isStale});
}
