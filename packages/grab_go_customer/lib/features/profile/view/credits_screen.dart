import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
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

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final balance = await _creditService.getBalance();
    final transactions = await _creditService.getTransactionHistory(page: 1);

    if (mounted) {
      setState(() {
        _balance = balance;
        _transactions = transactions;
        _isLoading = false;
        _currentPage = 1;
        _hasMore = transactions.length >= 20;
      });
    }
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
    final padding = MediaQuery.of(context).padding;

    final systemUiOverlayStyle = SystemUiOverlayStyle(
      statusBarColor: colors.backgroundSecondary,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      systemNavigationBarColor: colors.backgroundSecondary,
      systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
    );

    SystemChrome.setSystemUIOverlayStyle(systemUiOverlayStyle);

    return AnnotatedRegion(
      value: systemUiOverlayStyle,
      child: Scaffold(
        backgroundColor: colors.backgroundPrimary,
        body: Column(
          children: [
            Padding(
              padding: EdgeInsets.only(top: padding.top, left: 20.w, right: 20.w, bottom: 16.h),
              child: Row(
                children: [
                  Container(
                    height: 44,
                    width: 44,
                    decoration: BoxDecoration(color: colors.backgroundSecondary, shape: BoxShape.circle),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => context.pop(),
                        customBorder: const CircleBorder(),
                        child: Padding(
                          padding: EdgeInsets.all(10.r),
                          child: SvgPicture.asset(
                            Assets.icons.navArrowLeft,
                            package: 'grab_go_shared',
                            colorFilter: ColorFilter.mode(colors.textPrimary, BlendMode.srcIn),
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 16.w),
                  Text(
                    "GrabGo Credits",
                    style: TextStyle(
                      fontFamily: "Lato",
                      package: 'grab_go_shared',
                      color: colors.textPrimary,
                      fontSize: 20.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Divider(color: colors.backgroundSecondary, height: 1.h, thickness: 1),
            Expanded(
              child: AppRefreshIndicator(
                bgColor: colors.accentOrange,
                iconPath: Assets.icons.wallet,
                onRefresh: _loadData,
                child: CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(child: _buildBalanceCard(colors)),

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
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceCard(AppColorsExtension colors) {
    return Container(
      margin: EdgeInsets.all(20.w),
      padding: EdgeInsets.all(24.w),
      decoration: BoxDecoration(
        color: colors.accentOrange,
        borderRadius: BorderRadius.circular(KBorderSize.borderMedium),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SvgPicture.asset(
                Assets.icons.wallet,
                package: 'grab_go_shared',
                colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                width: 24.sp,
                height: 24.sp,
              ),
              SizedBox(width: 8.w),
              Text(
                'Available Balance',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          Text(
            _isLoading ? '...' : _balance?.formatted ?? '₵0.00',
            style: TextStyle(color: Colors.white, fontSize: 36.sp, fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 8.h),
          Text(
            'Use credits at checkout to save on orders',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12.sp),
          ),
        ],
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
