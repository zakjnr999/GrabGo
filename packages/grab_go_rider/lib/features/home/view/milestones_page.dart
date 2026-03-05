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
import 'package:shimmer/shimmer.dart';

class MilestonesPage extends StatefulWidget {
  const MilestonesPage({super.key});

  @override
  State<MilestonesPage> createState() => _MilestonesPageState();
}

class _MilestonesPageState extends State<MilestonesPage> {
  final RiderPartnerService _service = RiderPartnerService();

  MilestoneDashboard? _milestones;
  List<PeakWindowSchedule>? _peakSchedule;
  bool _isLoading = true;
  bool _isScrolled = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final cached = MemoryCache.peek<MilestonesPageData>('partner_milestones');
    if (cached != null) {
      _milestones = cached.milestones;
      _peakSchedule = cached.peakSchedule;
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
      final data = await _service.loadMilestonesPage(forceRefresh: forceRefresh);
      if (!mounted) return;

      setState(() {
        _milestones = data.milestones;
        _peakSchedule = data.peakSchedule;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load milestones';
      });
      AppToastMessage.show(
        context: context,
        showIcon: false,
        message: 'Failed to load milestones. Pull down to retry.',
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
      child: NotificationListener<ScrollNotification>(
        onNotification: (notifcation) {
          final scrolled = notifcation.metrics.pixels > 0;
          if (scrolled != _isScrolled) {
            setState(() => _isScrolled = scrolled);
          }
          return false;
        },
        child: Scaffold(
          backgroundColor: colors.backgroundSecondary,
          appBar: AppBar(
            backgroundColor: colors.backgroundPrimary,
            elevation: 0,
            scrolledUnderElevation: 0,
            bottom: _isScrolled
                ? PreferredSize(
                    preferredSize: Size.fromHeight(1),
                    child: Container(height: 1, color: colors.backgroundSecondary),
                  )
                : null,
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
              "Milestones",
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
          body: AppRefreshIndicator(
            onRefresh: () => _loadData(showLoadingState: false, forceRefresh: true),
            bgColor: colors.accentGreen,
            iconPath: Assets.icons.trophy,
            child: _isLoading
                ? _buildSkeletonBody(colors, isDark)
                : SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.symmetric(horizontal: 20.w),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: 20.h),

                        if (_error != null) ...[
                          Container(
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
                          SizedBox(height: 12.h),
                        ],

                        if (_milestones != null) ...[
                          // Hero card — progress overview
                          _buildHeroCard(colors),
                          SizedBox(height: 24.h),

                          // Next milestone
                          if (_milestones!.nextMilestone != null) ...[
                            _buildNextMilestoneCard(colors),
                            SizedBox(height: 24.h),
                          ],

                          // All milestones
                          _buildMilestonesList(colors),
                          SizedBox(height: 24.h),

                          // Peak hours schedule
                          if (_peakSchedule != null && _peakSchedule!.isNotEmpty) ...[
                            _buildPeakSchedule(colors),
                            SizedBox(height: 24.h),
                          ],

                          // Recent rewards
                          if (_milestones!.recentRewards.isNotEmpty) ...[
                            _buildRecentRewards(colors),
                            SizedBox(height: 32.h),
                          ],
                        ],
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeroCard(AppColorsExtension colors) {
    final m = _milestones!;

    return Stack(
      children: [
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(24.w),
          decoration: BoxDecoration(
            color: colors.accentGreen,
            borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "MILESTONE ACHIEVED",
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.5,
                ),
              ),
              SizedBox(height: 8.h),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${m.totalCompleted}',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 56.sp,
                      fontWeight: FontWeight.w800,
                      height: 1,
                      letterSpacing: -2,
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Padding(
                    padding: EdgeInsets.only(bottom: 8.h),
                    child: Text(
                      '/ ${m.totalAvailable}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 20.sp,
                        fontWeight: FontWeight.w600,
                        height: 1,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16.h),
              SteppedProgressBar(
                steps: m.totalAvailable,
                completedSteps: m.totalCompleted,
                activeColor: Colors.white,
                inactiveColor: Colors.white.withValues(alpha: 0.25),
                trackHeight: 5,
                dotRadius: 5,
                showGlow: false,
              ),
              SizedBox(height: 8.h),
              Text(
                '${m.totalCompleted} of ${m.totalAvailable} milestones achieved',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
        Positioned(
          top: 16.h,
          right: 16.w,
          child: SvgPicture.asset(
            Assets.icons.trophy,
            package: 'grab_go_shared',
            width: 48.w,
            height: 48.w,
            colorFilter: ColorFilter.mode(Colors.white.withValues(alpha: 0.15), BlendMode.srcIn),
          ),
        ),
      ],
    );
  }

  Widget _buildNextMilestoneCard(AppColorsExtension colors) {
    final next = _milestones!.nextMilestone!;
    final progressPct = next.percentComplete.toDouble().clamp(0.0, 100.0);

    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: colors.backgroundPrimary,
        borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "NEXT MILESTONE",
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 11.sp,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),
          SizedBox(height: 16.h),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      next.name,
                      style: TextStyle(color: colors.textPrimary, fontSize: 16.sp, fontWeight: FontWeight.w700),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      next.description,
                      style: TextStyle(color: colors.textSecondary, fontSize: 12.sp, fontWeight: FontWeight.w400),
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                decoration: BoxDecoration(
                  color: colors.accentGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
                ),
                child: Text(
                  'GHC ${next.finalReward.toStringAsFixed(2)}',
                  style: TextStyle(color: colors.accentGreen, fontSize: 14.sp, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${next.currentCount} / ${next.targetCount}',
                style: TextStyle(color: colors.textPrimary, fontSize: 13.sp, fontWeight: FontWeight.w600),
              ),
              Text(
                '${progressPct.toStringAsFixed(0)}%',
                style: TextStyle(color: colors.accentGreen, fontSize: 13.sp, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          _buildNextMilestoneSteppedBar(next, colors),
        ],
      ),
    );
  }

  Widget _buildNextMilestoneSteppedBar(MilestoneProgress milestone, AppColorsExtension colors) {
    // Split the target into up to 5 evenly spaced steps for a clean look
    final totalSteps = _computeStepCount(milestone.targetCount);
    final stepsPerSegment = milestone.targetCount / totalSteps;
    final completedSegments = (milestone.currentCount / stepsPerSegment).floor().clamp(0, totalSteps);
    final fractional = ((milestone.currentCount / stepsPerSegment) - completedSegments).clamp(0.0, 1.0);

    return SteppedProgressBar(
      steps: totalSteps,
      completedSteps: completedSegments,
      progress: completedSegments < totalSteps ? fractional : 0.0,
      activeColor: colors.accentGreen,
      inactiveColor: colors.divider.withValues(alpha: 0.35),
      trackHeight: 6,
      dotRadius: 6,
    );
  }

  int _computeStepCount(int target) {
    if (target <= 5) return target;
    if (target <= 10) return 5;
    if (target <= 50) return 5;
    if (target <= 100) return 5;
    if (target <= 500) return 5;
    return 5;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  ALL MILESTONES LIST
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildMilestonesList(AppColorsExtension colors) {
    final milestones = _milestones!.milestones;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "ALL MILESTONES",
          style: TextStyle(
            color: colors.textSecondary,
            fontSize: 11.sp,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
          ),
        ),
        SizedBox(height: 12.h),
        ...milestones.map(
          (milestone) => Padding(
            padding: EdgeInsets.only(bottom: 12.h),
            child: _buildMilestoneRow(milestone, colors),
          ),
        ),
      ],
    );
  }

  Widget _buildMilestoneRow(MilestoneProgress milestone, AppColorsExtension colors) {
    final isCompleted = milestone.isCompleted;

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: colors.backgroundPrimary,
        borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  milestone.name,
                  style: TextStyle(color: colors.textPrimary, fontSize: 14.sp, fontWeight: FontWeight.w600),
                ),
                SizedBox(height: 4.h),
                if (!isCompleted) ...[
                  Text(
                    '${milestone.currentCount} / ${milestone.targetCount}',
                    style: TextStyle(color: colors.textSecondary, fontSize: 12.sp, fontWeight: FontWeight.w400),
                  ),
                  SizedBox(height: 6.h),
                  _buildMilestoneRowSteppedBar(milestone, colors),
                ] else
                  Text(
                    'Completed',
                    style: TextStyle(color: colors.success, fontSize: 12.sp, fontWeight: FontWeight.w500),
                  ),
              ],
            ),
          ),
          SizedBox(width: 8.w),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'GHC ${milestone.finalReward.toStringAsFixed(2)}',
                style: TextStyle(
                  color: isCompleted ? colors.success : colors.textSecondary,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (isCompleted)
                SvgPicture.asset(
                  Assets.icons.checkCircleSolid,
                  package: 'grab_go_shared',
                  width: 16.w,
                  height: 16.w,
                  colorFilter: ColorFilter.mode(colors.success, BlendMode.srcIn),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMilestoneRowSteppedBar(MilestoneProgress milestone, AppColorsExtension colors) {
    final totalSteps = _computeStepCount(milestone.targetCount);
    final stepsPerSegment = milestone.targetCount / totalSteps;
    final completedSegments = (milestone.currentCount / stepsPerSegment).floor().clamp(0, totalSteps);
    final fractional = ((milestone.currentCount / stepsPerSegment) - completedSegments).clamp(0.0, 1.0);

    return SteppedProgressBar(
      steps: totalSteps,
      completedSteps: completedSegments,
      progress: completedSegments < totalSteps ? fractional : 0.0,
      activeColor: colors.accentGreen,
      inactiveColor: colors.divider.withValues(alpha: 0.35),
      trackHeight: 4,
      dotRadius: 4.5,
    );
  }

  Widget _buildPeakSchedule(AppColorsExtension colors) {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: colors.backgroundPrimary,
        borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                "PEAK HOURS SCHEDULE",
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          ..._peakSchedule!.map(
            (window) => Padding(
              padding: EdgeInsets.only(bottom: 12.h),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          window.label,
                          style: TextStyle(color: colors.textPrimary, fontSize: 14.sp, fontWeight: FontWeight.w600),
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          '${window.start} – ${window.end} • ${window.days.join(", ")}',
                          style: TextStyle(color: colors.textSecondary, fontSize: 11.sp, fontWeight: FontWeight.w400),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                    decoration: BoxDecoration(
                      color: colors.accentGreen.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '+${window.bonusPercent}%',
                      style: TextStyle(color: colors.accentGreen, fontSize: 12.sp, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentRewards(AppColorsExtension colors) {
    final rewards = _milestones!.recentRewards;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "RECENT REWARDS",
          style: TextStyle(
            color: colors.textSecondary,
            fontSize: 11.sp,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
          ),
        ),
        SizedBox(height: 12.h),
        ...rewards.map(
          (reward) => Padding(
            padding: EdgeInsets.only(bottom: 12.h),
            child: Container(
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: colors.backgroundPrimary,
                borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
              ),
              child: Row(
                children: [
                  Text(reward.badgeIcon, style: TextStyle(fontSize: 24.sp)),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          reward.milestoneName,
                          style: TextStyle(color: colors.textPrimary, fontSize: 14.sp, fontWeight: FontWeight.w600),
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          _formatDate(reward.awardedAt),
                          style: TextStyle(color: colors.textSecondary, fontSize: 12.sp, fontWeight: FontWeight.w400),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    'GHC ${reward.rewardAmount.toStringAsFixed(2)}',
                    style: TextStyle(color: colors.accentGreen, fontSize: 14.sp, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${date.day}/${date.month}/${date.year}';
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
              height: 180.h,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
              ),
            ),
            SizedBox(height: 24.h),
            Container(
              height: 160.h,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
              ),
            ),
            SizedBox(height: 24.h),
            ...List.generate(
              4,
              (index) => Padding(
                padding: EdgeInsets.only(bottom: 12.h),
                child: Container(
                  height: 80.h,
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
