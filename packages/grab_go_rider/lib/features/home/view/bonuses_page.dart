import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_rider/features/home/models/partner_models.dart';
import 'package:grab_go_rider/features/home/service/rider_partner_service.dart';
import 'package:grab_go_rider/shared/service/memory_cache.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:grab_go_rider/shared/widgets/stepped_progress_bar.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';

class BonusesPage extends StatefulWidget {
  const BonusesPage({super.key});

  @override
  State<BonusesPage> createState() => _BonusesPageState();
}

class _BonusesPageState extends State<BonusesPage> {
  final RiderPartnerService _service = RiderPartnerService();
  int _selectedTab = 0;

  List<QuestProgress> _activeQuests = [];
  List<QuestProgress> _completedQuests = [];
  StreakDashboard? _streaks;
  IncentiveSummary? _incentives;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Hydrate from cache instantly — skip skeleton if data is available
    final cached = MemoryCache.peek<QuestsStreaksPageData>('partner_quests_streaks');
    if (cached != null) {
      _activeQuests = cached.quests.where((q) => q.status == QuestStatus.active).toList();
      _completedQuests = cached.quests.where((q) => q.status == QuestStatus.completed).toList();
      _streaks = cached.streaks;
      _incentives = cached.incentives;
      _isLoading = false;
    }
    _loadData(showLoadingState: cached == null);
  }

  Future<void> _loadData({bool showLoadingState = true, bool forceRefresh = false}) async {
    if (!mounted) return;

    if (showLoadingState) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final data = await _service.loadQuestsStreaksPage(forceRefresh: forceRefresh);
      if (!mounted) return;

      setState(() {
        _activeQuests = data.quests.where((q) => q.status == QuestStatus.active).toList();
        _completedQuests = data.quests.where((q) => q.status == QuestStatus.completed).toList();
        _streaks = data.streaks;
        _incentives = data.incentives;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load quests data';
      });
      AppToastMessage.show(
        context: context,
        showIcon: false,
        message: 'Failed to load quests data. Pull down to retry.',
        backgroundColor: context.appColors.error,
        radius: KBorderSize.borderRadius4,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  double get _totalIncentivesEarned {
    if (_incentives == null) return 0;
    return _incentives!.totalAvailable + _incentives!.totalPaidOut;
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
            "Quests & Streaks",
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
        body: _isLoading
            ? _buildSkeletonBody(colors, isDark)
            : Column(
                children: [
                  // Hero card — total earned + streak
                  _buildHeroSection(colors),

                  // Pill-style tab row
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20.w),
                    child: Row(
                      children: [
                        Expanded(child: _buildTabFilter('Active', 0, colors)),
                        SizedBox(width: 12.w),
                        Expanded(child: _buildTabFilter('Completed', 1, colors)),
                      ],
                    ),
                  ),
                  SizedBox(height: 16.h),

                  if (_error != null)
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20.w),
                      child: Container(
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                        decoration: BoxDecoration(
                          color: colors.error.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
                          border: Border.all(color: colors.error.withValues(alpha: 0.2)),
                        ),
                        child: Text(
                          _error!,
                          style: TextStyle(color: colors.error, fontSize: 12.sp, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ),

                  // Tab content
                  Expanded(
                    child: _selectedTab == 0
                        ? // Active tab — active quests + streak card
                          _activeQuests.isEmpty && _streaks == null
                              ? _buildEmptyState(
                                  "No active quests",
                                  "Check back later for new quest opportunities!",
                                  colors,
                                )
                              : AppRefreshIndicator(
                                  onRefresh: () => _loadData(showLoadingState: false, forceRefresh: true),
                                  bgColor: colors.accentGreen,
                                  iconPath: Assets.icons.fireFlame,
                                  child: ListView(
                                    physics: const AlwaysScrollableScrollPhysics(),
                                    padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 8.h),
                                    children: [
                                      // Streak card (always visible in active tab)
                                      if (_streaks != null && _streaks!.currentStreak > 0) ...[
                                        _buildStreakCard(colors),
                                        SizedBox(height: 16.h),
                                      ],
                                      // Active quests
                                      ..._activeQuests.map(
                                        (quest) => Padding(
                                          padding: EdgeInsets.only(bottom: 16.h),
                                          child: _buildQuestCard(quest, colors, isActive: true),
                                        ),
                                      ),
                                      SizedBox(height: 16.h),
                                    ],
                                  ),
                                )
                        : // Completed tab
                          _completedQuests.isEmpty
                        ? _buildEmptyState("No completed quests", "Complete quests to see your earnings here!", colors)
                        : AppRefreshIndicator(
                            onRefresh: () => _loadData(showLoadingState: false, forceRefresh: true),
                            bgColor: colors.accentGreen,
                            iconPath: Assets.icons.fireFlame,
                            child: ListView.separated(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 8.h),
                              itemCount: _completedQuests.length,
                              separatorBuilder: (context, index) => SizedBox(height: 16.h),
                              itemBuilder: (context, index) {
                                return _buildQuestCard(_completedQuests[index], colors, isActive: false);
                              },
                            ),
                          ),
                  ),
                ],
              ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  TAB FILTER
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildTabFilter(String label, int index, AppColorsExtension colors) {
    final isSelected = _selectedTab == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTab = index;
        });
      },
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 8.w),
        decoration: BoxDecoration(
          color: isSelected ? colors.accentGreen : colors.backgroundPrimary,
          borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected ? Colors.white : colors.textPrimary,
            fontSize: 13.sp,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildHeroSection(AppColorsExtension colors) {
    return Container(
      margin: EdgeInsets.all(20.w),
      padding: EdgeInsets.all(24.w),
      decoration: BoxDecoration(
        color: colors.accentGreen,
        borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "INCENTIVE EARNED",
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 12.sp,
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
                        _totalIncentivesEarned.toStringAsFixed(2),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 36.sp,
                          fontWeight: FontWeight.w800,
                          height: 1,
                          letterSpacing: -1,
                        ),
                      ),
                    ),
                  ],
                ),
                if (_streaks != null) ...[
                  SizedBox(height: 12.h),
                  Row(
                    children: [
                      SvgPicture.asset(
                        Assets.icons.fireFlame,
                        package: 'grab_go_shared',
                        width: 14.w,
                        height: 14.w,
                        colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                      ),
                      SizedBox(width: 4.w),
                      Text(
                        '${_streaks!.currentStreak}-day streak',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          Positioned(
            top: 16.h,
            right: 16.w,
            child: SvgPicture.asset(
              Assets.icons.flag,
              package: 'grab_go_shared',
              width: 48.w,
              height: 48.w,
              colorFilter: ColorFilter.mode(Colors.white.withValues(alpha: 0.15), BlendMode.srcIn),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  STREAK CARD
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildStreakCard(AppColorsExtension colors) {
    final streak = _streaks!;

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: colors.backgroundPrimary,
        borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Delivery Streak',
                      style: TextStyle(color: colors.textPrimary, fontSize: 16.sp, fontWeight: FontWeight.w700),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      '${streak.currentStreak} consecutive days',
                      style: TextStyle(color: colors.textSecondary, fontSize: 12.sp, fontWeight: FontWeight.w400),
                    ),
                  ],
                ),
              ),
              Text(
                'Best: ${streak.longestStreak}',
                style: TextStyle(color: colors.textSecondary, fontSize: 12.sp, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          SizedBox(height: 16.h),

          // Streak milestones (threshold dots)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: streak.allThresholds.map((t) {
              return Column(
                children: [
                  Container(
                    width: 32.w,
                    height: 32.w,
                    decoration: BoxDecoration(
                      color: t.achieved
                          ? colors.accentOrange.withValues(alpha: 0.15)
                          : colors.divider.withValues(alpha: 0.3),
                      shape: BoxShape.circle,
                      border: Border.all(color: t.achieved ? colors.accentGreen : colors.divider, width: 2),
                    ),
                    child: Center(
                      child: t.achieved
                          ? SvgPicture.asset(
                              Assets.icons.check,
                              package: 'grab_go_shared',
                              width: 14.w,
                              height: 14.w,
                              colorFilter: ColorFilter.mode(colors.accentGreen, BlendMode.srcIn),
                            )
                          : Text(
                              '${t.days}',
                              style: TextStyle(
                                color: colors.textSecondary,
                                fontSize: 10.sp,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    '${t.days}d',
                    style: TextStyle(
                      color: t.achieved ? colors.accentGreen : colors.textSecondary,
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              );
            }).toList(),
          ),

          if (streak.nextReward != null) ...[
            SizedBox(height: 12.h),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
              decoration: BoxDecoration(
                color: colors.accentGreen.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
              ),
              child: Row(
                children: [
                  SvgPicture.asset(
                    Assets.icons.gift,
                    package: 'grab_go_shared',
                    width: 14.w,
                    height: 14.w,
                    colorFilter: ColorFilter.mode(colors.accentGreen, BlendMode.srcIn),
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(
                      '${streak.nextReward!.daysNeeded} more days for GHC ${streak.nextReward!.finalReward.toStringAsFixed(2)} reward',
                      style: TextStyle(color: colors.accentGreen, fontSize: 12.sp, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  QUEST CARD
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildQuestCard(QuestProgress quest, AppColorsExtension colors, {required bool isActive}) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: colors.backgroundPrimary,
        borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      quest.name,
                      style: TextStyle(color: colors.textPrimary, fontSize: 16.sp, fontWeight: FontWeight.w700),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      quest.description,
                      style: TextStyle(color: colors.textSecondary, fontSize: 12.sp, fontWeight: FontWeight.w400),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                decoration: BoxDecoration(
                  color: colors.accentGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
                ),
                child: Text(
                  "GHC ${quest.finalReward.toStringAsFixed(2)}",
                  style: TextStyle(color: colors.accentGreen, fontSize: 14.sp, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          if (isActive) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    quest.description,
                    style: TextStyle(color: colors.textPrimary, fontSize: 13.sp, fontWeight: FontWeight.w600),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                SizedBox(width: 8.w),
                Text(
                  "${quest.currentCount}/${quest.targetCount}",
                  style: TextStyle(color: colors.accentGreen, fontSize: 13.sp, fontWeight: FontWeight.w700),
                ),
              ],
            ),
            SizedBox(height: 8.h),
            Builder(
              builder: (context) {
                final totalSteps = quest.targetCount <= 5 ? quest.targetCount : 5;
                final stepsPerSegment = quest.targetCount / totalSteps;
                final completedSegments = stepsPerSegment > 0
                    ? (quest.currentCount / stepsPerSegment).floor().clamp(0, totalSteps)
                    : 0;
                final fractional = stepsPerSegment > 0
                    ? ((quest.currentCount / stepsPerSegment) - completedSegments).clamp(0.0, 1.0)
                    : 0.0;
                return SteppedProgressBar(
                  steps: totalSteps,
                  completedSteps: completedSegments,
                  progress: completedSegments < totalSteps ? fractional : 0.0,
                  activeColor: colors.accentGreen,
                  inactiveColor: colors.divider.withValues(alpha: 0.35),
                  trackHeight: 6,
                  dotRadius: 6,
                );
              },
            ),
            SizedBox(height: 12.h),
            Row(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                  decoration: BoxDecoration(
                    color: colors.accentGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    quest.period == QuestPeriod.daily ? 'DAILY' : 'WEEKLY',
                    style: TextStyle(color: colors.accentGreen, fontSize: 10.sp, fontWeight: FontWeight.w600),
                  ),
                ),
                SizedBox(width: 8.w),
                if (quest.multiplier > 1.0)
                  Text(
                    '${quest.multiplier}x multiplier',
                    style: TextStyle(color: colors.textSecondary, fontSize: 11.sp, fontWeight: FontWeight.w500),
                  ),
                const Spacer(),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: colors.accentGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    "ACTIVE",
                    style: TextStyle(color: colors.accentGreen, fontSize: 10.sp, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ] else ...[
            Row(
              children: [
                SvgPicture.asset(
                  Assets.icons.checkCircleSolid,
                  package: 'grab_go_shared',
                  width: 16.w,
                  height: 16.w,
                  colorFilter: ColorFilter.mode(colors.success, BlendMode.srcIn),
                ),
                SizedBox(width: 6.w),
                Expanded(
                  child: Text(
                    '${quest.currentCount}/${quest.targetCount} completed',
                    style: TextStyle(color: colors.textPrimary, fontSize: 13.sp, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12.h),
            Row(
              children: [
                SvgPicture.asset(
                  Assets.icons.calendar,
                  package: "grab_go_shared",
                  height: 14.h,
                  width: 12.w,
                  colorFilter: ColorFilter.mode(colors.textSecondary, BlendMode.srcIn),
                ),
                SizedBox(width: 4.w),
                Text(
                  quest.completedAt != null
                      ? "Earned on ${DateFormat('MMM dd, yyyy').format(quest.completedAt!)}"
                      : "Completed",
                  style: TextStyle(color: colors.textSecondary, fontSize: 12.sp, fontWeight: FontWeight.w500),
                ),
                const Spacer(),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: colors.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    "COMPLETED",
                    style: TextStyle(color: colors.success, fontSize: 10.sp, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  EMPTY STATE
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildEmptyState(String title, String message, AppColorsExtension colors) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(40.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(24.w),
              decoration: BoxDecoration(color: colors.backgroundPrimary, shape: BoxShape.circle),
              child: SvgPicture.asset(
                Assets.icons.fireFlame,
                package: 'grab_go_shared',
                width: 48.w,
                height: 48.w,
                colorFilter: ColorFilter.mode(colors.textSecondary.withValues(alpha: 0.5), BlendMode.srcIn),
              ),
            ),
            SizedBox(height: 24.h),
            Text(
              title,
              style: TextStyle(color: colors.textPrimary, fontSize: 18.sp, fontWeight: FontWeight.w700),
            ),
            SizedBox(height: 8.h),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.textSecondary, fontSize: 14.sp, fontWeight: FontWeight.w400),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  SKELETON / SHIMMER
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildSkeletonBody(AppColorsExtension colors, bool isDark) {
    return Shimmer.fromColors(
      baseColor: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
      highlightColor: isDark ? Colors.grey.shade700 : Colors.grey.shade100,
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.symmetric(horizontal: 20.w),
        child: Column(
          children: [
            SizedBox(height: 20.h),
            Container(
              height: 140.h,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
              ),
            ),
            SizedBox(height: 20.h),
            ...List.generate(
              3,
              (index) => Padding(
                padding: EdgeInsets.only(bottom: 16.h),
                child: Container(
                  height: 120.h,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
