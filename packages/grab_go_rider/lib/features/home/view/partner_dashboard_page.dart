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

class PartnerDashboardPage extends StatefulWidget {
  const PartnerDashboardPage({super.key});

  @override
  State<PartnerDashboardPage> createState() => _PartnerDashboardPageState();
}

class _PartnerDashboardPageState extends State<PartnerDashboardPage> {
  final RiderPartnerService _service = RiderPartnerService();

  PartnerDashboardPageData? _data;
  bool _isLoading = true;
  bool _isScrolled = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Hydrate from cache instantly — skip skeleton if data is available
    final cached = MemoryCache.peek<PartnerDashboardPageData>('partner_dashboard_page');
    if (cached != null) {
      _data = cached;
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
      final data = await _service.loadPartnerDashboardPage(forceRefresh: forceRefresh);
      if (!mounted) return;

      setState(() {
        _data = data;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = 'Failed to load partner data';
      });
      AppToastMessage.show(
        context: context,
        showIcon: false,
        message: 'Failed to load partner data. Pull down to retry.',
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

  // ─────────────────────── helpers ───────────────────────

  Color _levelColor(PartnerLevel level, AppColorsExtension colors) {
    switch (level) {
      case PartnerLevel.L1:
        return colors.textSecondary;
      case PartnerLevel.L2:
        return colors.accentBlue;
      case PartnerLevel.L3:
        return colors.accentOrange;
      case PartnerLevel.L4:
        return colors.accentViolet;
      case PartnerLevel.L5:
        return colors.accentGreen;
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
        onNotification: (notification) {
          final scrolled = notification.metrics.pixels > 0;
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
                    preferredSize: const Size.fromHeight(1),
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
              "Partner Dashboard",
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

                        // Error banner
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

                        // Hero card — level & score
                        if (_data != null) ...[
                          _buildHeroCard(colors),
                          SizedBox(height: 24.h),

                          // Quick stats row
                          _buildQuickStatsRow(colors),
                          SizedBox(height: 24.h),

                          // Performance breakdown
                          _buildPerformanceBreakdown(colors),
                          SizedBox(height: 24.h),

                          // Next level target
                          if (_data!.dashboard.nextLevel != null) ...[
                            _buildNextLevelCard(colors),
                            SizedBox(height: 24.h),
                          ],

                          // Peak hour status
                          if (_data!.peakHourStatus != null) ...[_buildPeakHourCard(colors), SizedBox(height: 24.h)],

                          // Incentive balance
                          if (_data!.incentiveBalance != null) ...[
                            _buildIncentiveBalanceCard(colors),
                            SizedBox(height: 24.h),
                          ],

                          // Quick actions
                          _buildQuickActions(colors),
                          SizedBox(height: 24.h),

                          // Level history
                          if (_data!.dashboard.recentHistory.isNotEmpty) ...[
                            _buildLevelHistory(colors),
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

  // ═══════════════════════════════════════════════════════════════════════════
  //  HERO CARD
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildHeroCard(AppColorsExtension colors) {
    final dashboard = _data!.dashboard;
    final level = dashboard.profile.partnerLevel;
    final score = dashboard.liveScore?.partnerScore ?? dashboard.profile.partnerScore;
    final color = _levelColor(level, colors);

    return Stack(
      children: [
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(24.w),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [color, color.withValues(alpha: 0.85)],
            ),
            borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Level label
              Text(
                partnerLevelLabel(level).toUpperCase(),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.5,
                ),
              ),
              SizedBox(height: 8.h),

              // Partner Score
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    score.toString(),
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
                      '/ 100',
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
              SizedBox(height: 8.h),

              Text(
                'Partner Score',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),

              SizedBox(height: 16.h),

              // Level multiplier & dispatch bonus
              Row(
                children: [
                  _buildHeroBadge('${dashboard.level.multiplier}x', 'Multiplier', colors),
                  SizedBox(width: 12.w),
                  _buildHeroBadge('+${dashboard.level.dispatchBonus}', 'Dispatch Bonus', colors),
                  if (dashboard.level.isLocked) ...[
                    SizedBox(width: 12.w),
                    _buildHeroBadge('${dashboard.level.lockDaysRemaining}d', 'Lock Left', colors),
                  ],
                ],
              ),
            ],
          ),
        ),

        // Icon overlay (top-right)
        Positioned(
          top: 16.h,
          right: 16.w,
          child: SvgPicture.asset(
            Assets.icons.chart,
            package: 'grab_go_shared',
            width: 48.w,
            height: 48.w,
            colorFilter: ColorFilter.mode(Colors.white.withValues(alpha: 0.15), BlendMode.srcIn),
          ),
        ),
      ],
    );
  }

  Widget _buildHeroBadge(String value, String label, AppColorsExtension colors) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(color: Colors.white, fontSize: 14.sp, fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 2.h),
          Text(
            label,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 10.sp, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  QUICK STATS ROW
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildQuickStatsRow(AppColorsExtension colors) {
    final metrics = _data!.dashboard.metrics;

    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Deliveries',
            metrics.deliveryVolume.toString(),
            Assets.icons.deliveryTruck,
            colors.accentGreen,
            colors,
          ),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: _buildStatCard(
            'Rating',
            metrics.customerRating.toStringAsFixed(1),
            Assets.icons.star,
            colors.accentGreen,
            colors,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, String icon, Color color, AppColorsExtension colors) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: colors.backgroundPrimary,
        borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(8.r),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
            ),
            child: SvgPicture.asset(
              icon,
              package: 'grab_go_shared',
              width: 20.w,
              height: 20.w,
              colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
            ),
          ),
          SizedBox(height: 12.h),
          Text(
            value,
            style: TextStyle(color: colors.textPrimary, fontSize: 20.sp, fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 4.h),
          Text(
            label,
            style: TextStyle(color: colors.textSecondary, fontSize: 12.sp, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  PERFORMANCE BREAKDOWN
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildPerformanceBreakdown(AppColorsExtension colors) {
    final metrics = _data!.dashboard.metrics;

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
            "PERFORMANCE BREAKDOWN",
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 11.sp,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),
          SizedBox(height: 20.h),
          _buildPerformanceRow("On-Time Rate", metrics.onTimeRate, 100, colors),
          SizedBox(height: 16.h),
          _buildPerformanceRow("Completion Rate", metrics.completionRate, 100, colors),
          SizedBox(height: 16.h),
          _buildPerformanceRow("Acceptance Rate", metrics.acceptanceRate, 100, colors),
          SizedBox(height: 16.h),
          _buildPerformanceRow(
            "Customer Rating",
            metrics.customerRating * 20,
            100,
            colors,
            displayValue: '${metrics.customerRating.toStringAsFixed(1)} / 5.0',
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceRow(
    String label,
    double value,
    double max,
    AppColorsExtension colors, {
    String? displayValue,
    double threshold = 80,
  }) {
    final percentage = (value / max * 100).clamp(0.0, 100.0);
    final isGood = percentage >= threshold;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(color: colors.textPrimary, fontSize: 14.sp, fontWeight: FontWeight.w500),
            ),
            Text(
              displayValue ?? '${percentage.toStringAsFixed(1)}%',
              style: TextStyle(
                color: isGood ? colors.textPrimary : colors.warning,
                fontSize: 14.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        SizedBox(height: 8.h),
        SizedBox(
          height: 16.h,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final barWidth = constraints.maxWidth;
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  // Background track
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      height: 6.h,
                      decoration: BoxDecoration(
                        color: colors.divider.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                  // Filled track
                  Positioned(
                    left: 0,
                    bottom: 0,
                    child: Container(
                      width: barWidth * (percentage / 100),
                      height: 6.h,
                      decoration: BoxDecoration(
                        color: isGood ? colors.accentGreen : colors.warning.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                  // Threshold marker — custom arrow shape
                  Positioned(
                    left: barWidth * (threshold / 100) - 5.w,
                    top: 0,
                    bottom: 0,
                    child: CustomPaint(
                      size: Size(10.w, 16.h),
                      painter: _ThresholdMarkerPainter(color: colors.warning.withValues(alpha: 0.7)),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  NEXT LEVEL CARD
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildNextLevelCard(AppColorsExtension colors) {
    final next = _data!.dashboard.nextLevel!;
    final metrics = _data!.dashboard.metrics;
    final currentScore = _data!.dashboard.liveScore?.partnerScore ?? _data!.dashboard.profile.partnerScore;
    final scoreProgress = next.scoreRequired > 0 ? (currentScore / next.scoreRequired).clamp(0.0, 1.0) : 0.0;

    // Calculate overall progress across all criteria (score + requirements)
    final reqs = next.requirements;
    final criteriaProgress = <double>[scoreProgress];
    if (reqs != null) {
      criteriaProgress.add((metrics.deliveryVolume / reqs.minDeliveries).clamp(0.0, 1.0));
      criteriaProgress.add((metrics.customerRating / reqs.minRating).clamp(0.0, 1.0));
      criteriaProgress.add((metrics.completionRate / reqs.minCompletionRate).clamp(0.0, 1.0));
    }
    final overallProgress = criteriaProgress.reduce((a, b) => a + b) / criteriaProgress.length;
    final overallPercent = (overallProgress * 100).clamp(0.0, 100.0);
    final metCount = criteriaProgress.where((p) => p >= 1.0).length;

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
            "NEXT LEVEL",
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    partnerLevelLabel(next.nextLevel),
                    style: TextStyle(color: colors.textPrimary, fontSize: 16.sp, fontWeight: FontWeight.w700),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    '${next.scoreGap} points needed • ${next.multiplier}x multiplier',
                    style: TextStyle(color: colors.textSecondary, fontSize: 12.sp, fontWeight: FontWeight.w400),
                  ),
                ],
              ),
            ],
          ),

          SizedBox(height: 16.h),

          // Progress bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$metCount of ${criteriaProgress.length} requirements met',
                style: TextStyle(color: colors.textPrimary, fontSize: 13.sp, fontWeight: FontWeight.w600),
              ),
              Text(
                '${overallPercent.toStringAsFixed(0)}%',
                style: TextStyle(
                  color: metCount == criteriaProgress.length ? colors.accentGreen : colors.warning,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Builder(
            builder: (context) {
              final totalSteps = criteriaProgress.length;
              return SteppedProgressBar(
                steps: totalSteps,
                completedSteps: metCount,
                progress: metCount < totalSteps
                    ? criteriaProgress.where((p) => p < 1.0).fold(0.0, (a, b) => a + b) /
                          criteriaProgress.where((p) => p < 1.0).length
                    : 0.0,
                activeColor: colors.accentGreen,
                inactiveColor: colors.divider.withValues(alpha: 0.35),
                trackHeight: 6,
                dotRadius: 6,
              );
            },
          ),

          // Requirements
          SizedBox(height: 16.h),
          _buildRequirementRow('Score', next.scoreRequired.toString(), currentScore >= next.scoreRequired, colors),
          if (next.requirements != null) ...[
            SizedBox(height: 8.h),
            _buildRequirementRow(
              'Min. Deliveries',
              '${metrics.deliveryVolume} / ${next.requirements!.minDeliveries}',
              metrics.deliveryVolume >= next.requirements!.minDeliveries,
              colors,
            ),
            SizedBox(height: 8.h),
            _buildRequirementRow(
              'Min. Rating',
              next.requirements!.minRating.toStringAsFixed(1),
              metrics.customerRating >= next.requirements!.minRating,
              colors,
            ),
            SizedBox(height: 8.h),
            _buildRequirementRow(
              'Min. Completion',
              '${next.requirements!.minCompletionRate.toStringAsFixed(0)}%',
              metrics.completionRate >= next.requirements!.minCompletionRate,
              colors,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRequirementRow(String label, String value, bool met, AppColorsExtension colors) {
    return Row(
      children: [
        SvgPicture.asset(
          met ? Assets.icons.checkCircleSolid : Assets.icons.circleAlert,
          package: 'grab_go_shared',
          width: 16.w,
          height: 16.w,
          colorFilter: ColorFilter.mode(met ? colors.success : colors.warning, BlendMode.srcIn),
        ),
        SizedBox(width: 8.w),
        Text(
          label,
          style: TextStyle(color: colors.textPrimary, fontSize: 13.sp, fontWeight: FontWeight.w500),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(color: met ? colors.success : colors.warning, fontSize: 13.sp, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  PEAK HOUR CARD
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildPeakHourCard(AppColorsExtension colors) {
    final peak = _data!.peakHourStatus!;

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
                "PEAK HOURS",
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                ),
              ),
              const Spacer(),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: peak.isPeakHour
                      ? colors.accentOrange.withValues(alpha: 0.1)
                      : colors.divider.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (peak.isPeakHour)
                      SvgPicture.asset(
                        Assets.icons.fireFlame,
                        package: 'grab_go_shared',
                        width: 12.w,
                        height: 12.w,
                        colorFilter: ColorFilter.mode(colors.accentOrange, BlendMode.srcIn),
                      ),
                    if (peak.isPeakHour) SizedBox(width: 4.w),
                    Text(
                      peak.isPeakHour ? 'ACTIVE' : 'OFF-PEAK',
                      style: TextStyle(
                        color: peak.isPeakHour ? colors.accentOrange : colors.textSecondary,
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),

          if (peak.isPeakHour && peak.activeWindows.isNotEmpty)
            ...peak.activeWindows.map(
              (w) => Padding(
                padding: EdgeInsets.only(bottom: 12.h),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(8.r),
                      decoration: BoxDecoration(
                        color: colors.accentOrange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
                      ),
                      child: SvgPicture.asset(
                        Assets.icons.fireFlame,
                        package: 'grab_go_shared',
                        width: 20.w,
                        height: 20.w,
                        colorFilter: ColorFilter.mode(colors.accentOrange, BlendMode.srcIn),
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            w.label,
                            style: TextStyle(color: colors.textPrimary, fontSize: 14.sp, fontWeight: FontWeight.w600),
                          ),
                          SizedBox(height: 2.h),
                          Text(
                            '${w.start} – ${w.end}',
                            style: TextStyle(color: colors.textSecondary, fontSize: 12.sp, fontWeight: FontWeight.w400),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                      decoration: BoxDecoration(
                        color: colors.accentOrange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
                      ),
                      child: Text(
                        '+${w.bonusPercent}%',
                        style: TextStyle(color: colors.accentOrange, fontSize: 14.sp, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          if (!peak.isPeakHour && peak.nextWindow != null) ...[
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Next: ${peak.nextWindow!.label}',
                        style: TextStyle(color: colors.textPrimary, fontSize: 14.sp, fontWeight: FontWeight.w600),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        _formatMinutes(peak.nextWindow!.startsInMinutes),
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
                    '+${peak.nextWindow!.bonusPercent}%',
                    style: TextStyle(color: colors.accentGreen, fontSize: 14.sp, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ],

          if (!peak.isPeakHour && peak.nextWindow == null)
            Text(
              'No upcoming peak windows today',
              style: TextStyle(color: colors.textSecondary, fontSize: 13.sp, fontWeight: FontWeight.w400),
            ),
        ],
      ),
    );
  }

  String _formatMinutes(int minutes) {
    if (minutes < 60) return 'Starts in ${minutes}m';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m > 0 ? 'Starts in ${h}h ${m}m' : 'Starts in ${h}h';
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  INCENTIVE BALANCE CARD
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildIncentiveBalanceCard(AppColorsExtension colors) {
    final balance = _data!.incentiveBalance!;

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
            "INCENTIVE BALANCE",
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
                child: _buildBalanceStat(
                  'Available',
                  'GHC ${balance.availableForPayout.toStringAsFixed(2)}',
                  colors.accentGreen,
                  colors,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: _buildBalanceStat(
                  'Pending',
                  'GHC ${balance.pendingBudgetApproval.toStringAsFixed(2)}',
                  colors.accentOrange,
                  colors,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceStat(String label, String value, Color color, AppColorsExtension colors) {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(color: colors.textSecondary, fontSize: 11.sp, fontWeight: FontWeight.w500),
          ),
          SizedBox(height: 6.h),
          Text(
            value,
            style: TextStyle(color: color, fontSize: 16.sp, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  QUICK ACTIONS
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildQuickActions(AppColorsExtension colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "EXPLORE",
          style: TextStyle(
            color: colors.textSecondary,
            fontSize: 11.sp,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
          ),
        ),
        SizedBox(height: 12.h),
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                'Quests & Streaks',
                Assets.icons.fireFlame,
                colors.accentGreen,
                colors,
                () => context.push('/bonuses'),
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: _buildActionCard(
                'Milestones',
                Assets.icons.trophy,
                colors.accentGreen,
                colors,
                () => context.push('/milestones'),
              ),
            ),
          ],
        ),
        SizedBox(height: 12.h),
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                'Performance',
                Assets.icons.star,
                colors.accentGreen,
                colors,
                () => context.push('/performance'),
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: _buildActionCard(
                'Payout History',
                Assets.icons.wallet,
                colors.accentGreen,
                colors,
                () => context.push('/payout-history'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionCard(String label, String icon, Color color, AppColorsExtension colors, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: colors.backgroundPrimary,
          borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8.r),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
              ),
              child: SvgPicture.asset(
                icon,
                package: 'grab_go_shared',
                width: 20.w,
                height: 20.w,
                colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
              ),
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: Text(
                label,
                style: TextStyle(color: colors.textPrimary, fontSize: 13.sp, fontWeight: FontWeight.w600),
              ),
            ),
            SvgPicture.asset(
              Assets.icons.navArrowRight,
              package: 'grab_go_shared',
              width: 16.w,
              height: 16.w,
              colorFilter: ColorFilter.mode(colors.textSecondary, BlendMode.srcIn),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  LEVEL HISTORY
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildLevelHistory(AppColorsExtension colors) {
    final history = _data!.dashboard.recentHistory;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "LEVEL HISTORY",
          style: TextStyle(
            color: colors.textSecondary,
            fontSize: 11.sp,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
          ),
        ),
        SizedBox(height: 12.h),
        ...history.take(5).map((entry) {
          final isUpgrade = entry.toLevel.index > entry.fromLevel.index;
          final entryColor = isUpgrade ? colors.accentGreen : colors.error;

          return Padding(
            padding: EdgeInsets.only(bottom: 12.h),
            child: Container(
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: colors.backgroundPrimary,
                borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
              ),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8.r),
                    decoration: BoxDecoration(
                      color: entryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
                    ),
                    child: SvgPicture.asset(
                      isUpgrade ? Assets.icons.navArrowUp : Assets.icons.navArrowDown,
                      package: 'grab_go_shared',
                      width: 20.w,
                      height: 20.w,
                      colorFilter: ColorFilter.mode(entryColor, BlendMode.srcIn),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${partnerLevelLabel(entry.fromLevel)} → ${partnerLevelLabel(entry.toLevel)}',
                          style: TextStyle(color: colors.textPrimary, fontSize: 14.sp, fontWeight: FontWeight.w600),
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          'Score: ${entry.score}',
                          style: TextStyle(color: colors.textSecondary, fontSize: 12.sp, fontWeight: FontWeight.w400),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    _formatDate(entry.changedAt),
                    style: TextStyle(color: colors.textSecondary, fontSize: 11.sp, fontWeight: FontWeight.w400),
                  ),
                ],
              ),
            ),
          );
        }),
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
  //  SKELETON / SHIMMER LOADING
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildSkeletonBody(AppColorsExtension colors, bool isDark) {
    return Shimmer.fromColors(
      baseColor: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
      highlightColor: isDark ? Colors.grey.shade700 : Colors.grey.shade100,
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.symmetric(horizontal: 20.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 20.h),

            // Hero card skeleton
            Container(
              height: 200.h,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
              ),
            ),
            SizedBox(height: 24.h),

            // Stats row skeleton
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 100.h,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
                    ),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Container(
                    height: 100.h,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 24.h),

            // Performance section skeleton
            Container(
              height: 200.h,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
              ),
            ),
            SizedBox(height: 24.h),

            // Next level skeleton
            Container(
              height: 150.h,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
              ),
            ),
            SizedBox(height: 24.h),

            // Quick actions skeleton
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 60.h,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
                    ),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Container(
                    height: 60.h,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Custom painter for threshold marker — draws a downward-pointing
/// arrow/pin above the bar with a thin stem through it.
class _ThresholdMarkerPainter extends CustomPainter {
  final Color color;
  _ThresholdMarkerPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final arrowH = size.height * 0.45;
    final stemTop = arrowH;
    final stemBottom = size.height;

    // Downward-pointing triangle
    final arrowPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final arrow = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(cx, arrowH)
      ..close();
    canvas.drawPath(arrow, arrowPaint);

    // Thin stem line
    final stemPaint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(cx, stemTop), Offset(cx, stemBottom), stemPaint);
  }

  @override
  bool shouldRepaint(covariant _ThresholdMarkerPainter old) => old.color != color;
}
