import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:grab_go_shared/grub_go_shared.dart';

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

    return Scaffold(
      backgroundColor: colors.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: colors.backgroundPrimary,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'GrabGo Credits',
          style: TextStyle(color: colors.textPrimary, fontSize: 18.sp, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: CustomScrollView(
                slivers: [
                  // Balance Card
                  SliverToBoxAdapter(child: _buildBalanceCard(colors)),

                  // Info Section
                  SliverToBoxAdapter(child: _buildInfoSection(colors)),

                  // Transactions Header
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(20.w, 24.h, 20.w, 12.h),
                      child: Text(
                        'Transaction History',
                        style: TextStyle(color: colors.textPrimary, fontSize: 16.sp, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),

                  // Transactions List
                  _transactions.isEmpty
                      ? SliverToBoxAdapter(child: _buildEmptyState(colors))
                      : SliverList(
                          delegate: SliverChildBuilderDelegate((context, index) {
                            if (index == _transactions.length) {
                              if (_hasMore) {
                                _loadMore();
                                return Padding(
                                  padding: EdgeInsets.all(16.h),
                                  child: const Center(child: CircularProgressIndicator()),
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
    );
  }

  Widget _buildBalanceCard(AppColorsExtension colors) {
    return Container(
      margin: EdgeInsets.all(20.w),
      padding: EdgeInsets.all(24.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colors.accentOrange, colors.accentOrange.withValues(alpha: 0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(color: colors.accentOrange.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.account_balance_wallet, color: Colors.white, size: 24.sp),
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
            _balance?.formatted ?? '₵0.00',
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
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(color: colors.backgroundSecondary, borderRadius: BorderRadius.circular(12.r)),
      child: Column(
        children: [
          _buildInfoRow(Icons.check_circle_outline, 'Credits are automatically applied at checkout', colors),
          SizedBox(height: 12.h),
          _buildInfoRow(Icons.card_giftcard, 'Earn credits from referrals and promotions', colors),
          SizedBox(height: 12.h),
          _buildInfoRow(Icons.info_outline, 'Credits cannot be withdrawn or transferred', colors),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text, AppColorsExtension colors) {
    return Row(
      children: [
        Icon(icon, color: colors.accentGreen, size: 18.sp),
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

  Widget _buildEmptyState(AppColorsExtension colors) {
    return Padding(
      padding: EdgeInsets.all(40.w),
      child: Column(
        children: [
          Icon(Icons.receipt_long_outlined, size: 64.sp, color: colors.textSecondary.withValues(alpha: 0.5)),
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

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20.w, vertical: 6.h),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(color: colors.backgroundSecondary, borderRadius: BorderRadius.circular(12.r)),
      child: Row(
        children: [
          // Icon
          Container(
            width: 44.w,
            height: 44.w,
            decoration: BoxDecoration(
              color: (isCredit ? colors.accentGreen : colors.error).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Icon(
              isCredit ? Icons.add_circle_outline : Icons.remove_circle_outline,
              color: isCredit ? colors.accentGreen : colors.error,
              size: 22.sp,
            ),
          ),
          SizedBox(width: 12.w),

          // Details
          Expanded(
            child: Column(
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
          ),

          // Amount
          Text(
            tx.formattedAmount,
            style: TextStyle(
              color: isCredit ? colors.accentGreen : colors.error,
              fontSize: 16.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
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
