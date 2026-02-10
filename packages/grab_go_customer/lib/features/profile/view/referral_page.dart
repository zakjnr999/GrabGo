import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:easy_stepper/easy_stepper.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:share_plus/share_plus.dart';
import 'package:grab_go_customer/core/api/api_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ReferralPage extends StatefulWidget {
  const ReferralPage({super.key});

  @override
  State<ReferralPage> createState() => _ReferralPageState();
}

class _ReferralPageState extends State<ReferralPage> with TickerProviderStateMixin {
  String _referralCode = '••••••••';
  int _totalReferrals = 0;
  int _completedReferrals = 0;
  double _totalEarned = 0.0;
  bool isLoadingData = true;
  late AnimationController _animationController;
  late Animation<double> _totalReferralsAnimation;
  late Animation<double> _completedReferralsAnimation;
  late Animation<double> _totalEarnedAnimation;

  late AnimationController _progressAnimationController;
  late Animation<double> _circularProgressAnimation;
  late Animation<double> _linearProgressAnimation;

  int _previousTotalReferrals = 0;
  int _previousCompletedReferrals = 0;
  double _previousTotalEarned = 0.0;

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(duration: const Duration(milliseconds: 1500), vsync: this);

    _totalReferralsAnimation = Tween<double>(
      begin: 0,
      end: 0,
    ).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeOut));

    _completedReferralsAnimation = Tween<double>(
      begin: 0,
      end: 0,
    ).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeOut));

    _totalEarnedAnimation = Tween<double>(
      begin: 0,
      end: 0,
    ).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeOut));

    _progressAnimationController = AnimationController(duration: const Duration(milliseconds: 1200), vsync: this);

    _circularProgressAnimation = Tween<double>(
      begin: 0,
      end: 0,
    ).animate(CurvedAnimation(parent: _progressAnimationController, curve: Curves.easeInOut));

    _linearProgressAnimation = Tween<double>(
      begin: 0,
      end: 0,
    ).animate(CurvedAnimation(parent: _progressAnimationController, curve: Curves.easeInOut));

    _loadReferralData();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _animationController.stop();
    _progressAnimationController.stop();
    _animationController.dispose();
    _progressAnimationController.dispose();
    super.dispose();
  }

  Future<void> _loadReferralData() async {
    if (!mounted) return;

    await _loadFromCache();

    await _fetchFromServer();
  }

  Future<void> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedData = prefs.getString('referral_data');

      if (cachedData != null) {
        try {
          final data = json.decode(cachedData) as Map<String, dynamic>;
          debugPrint('Loaded referral data from cache');

          if (!mounted) return;

          setState(() {
            _referralCode = data['code'] ?? '••••••••';
            _totalReferrals = data['totalReferrals'] ?? 0;
            _completedReferrals = data['completedReferrals'] ?? 0;
            _totalEarned = (data['totalEarned'] ?? 0).toDouble();
            isLoadingData = false;
          });

          _animateStats();
          _animateProgress();

          _previousTotalReferrals = _totalReferrals;
          _previousCompletedReferrals = _completedReferrals;
          _previousTotalEarned = _totalEarned;
        } catch (e) {
          debugPrint('Corrupted cache data, clearing: $e');
          await prefs.remove('referral_data');
        }
      }
    } catch (e) {
      debugPrint('Error loading from cache: $e');
    }
  }

  Future<void> _fetchFromServer() async {
    try {
      debugPrint('Fetching referral data from: ${AppConfig.apiBaseUrl}/referral/my-code');

      final response = await chopperClient
          .get(Uri.parse('${AppConfig.apiBaseUrl}/referral/my-code'))
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw TimeoutException('Request timeout');
            },
          );

      debugPrint('🔍 Response status: ${response.statusCode}');

      if (!mounted) return;

      if (response.statusCode == 200) {
        if (response.body == null) {
          throw Exception('Empty response from server');
        }

        final data = response.body as Map<String, dynamic>;
        debugPrint('Fetched fresh data from server');

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('referral_data', json.encode(data));
        debugPrint('Saved referral data to cache');

        if (!mounted) return;

        setState(() {
          _referralCode = data['code'] ?? 'N/A';
          _totalReferrals = data['totalReferrals'] ?? 0;
          _completedReferrals = data['completedReferrals'] ?? 0;
          _totalEarned = (data['totalEarned'] ?? 0).toDouble();
          isLoadingData = false;
        });

        if (_totalReferrals != _previousTotalReferrals ||
            _completedReferrals != _previousCompletedReferrals ||
            _totalEarned != _previousTotalEarned) {
          _animateStats();
          _animateProgress();

          _previousTotalReferrals = _totalReferrals;
          _previousCompletedReferrals = _completedReferrals;
          _previousTotalEarned = _totalEarned;
        }
      } else if (response.statusCode == 401) {
        throw Exception('Unauthorized - Please log in again');
      } else if (response.statusCode == 404) {
        throw Exception('Referral endpoint not found');
      } else {
        throw Exception('Failed to load referral data: ${response.statusCode}');
      }
    } on SocketException catch (e) {
      debugPrint('SocketException: $e');
      if (!mounted) return;
    } on TimeoutException catch (e) {
      debugPrint('TimeoutException: $e');
      if (!mounted) return;
    } catch (e) {
      debugPrint('Error loading referral data: $e');
      if (!mounted) return;
    }
  }

  void _animateStats() {
    if (!mounted) return;

    _totalReferralsAnimation = Tween<double>(
      begin: _totalReferralsAnimation.value,
      end: _totalReferrals.toDouble(),
    ).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeOut));

    _completedReferralsAnimation = Tween<double>(
      begin: _completedReferralsAnimation.value,
      end: _completedReferrals.toDouble(),
    ).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeOut));

    _totalEarnedAnimation = Tween<double>(
      begin: _totalEarnedAnimation.value,
      end: _totalEarned,
    ).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeOut));

    if (mounted) {
      _animationController.forward(from: 0);
    }
  }

  void _animateProgress() {
    if (!mounted) return;

    final progress = _completedReferrals % 5;
    final progressPercent = (progress / 5.0);

    _circularProgressAnimation = Tween<double>(
      begin: 0,
      end: progressPercent,
    ).animate(CurvedAnimation(parent: _progressAnimationController, curve: Curves.easeInOut));

    _linearProgressAnimation = Tween<double>(
      begin: 0,
      end: progressPercent,
    ).animate(CurvedAnimation(parent: _progressAnimationController, curve: Curves.easeInOut));

    if (mounted) {
      _progressAnimationController.forward(from: 0);
    }
  }

  void _copyReferralCode() {
    try {
      Clipboard.setData(ClipboardData(text: _referralCode));
      AppToastMessage.show(
        context: context,
        message: "Referral code $_referralCode copied!",
        backgroundColor: Colors.green,
      );
    } catch (e) {
      AppToastMessage.show(
        context: context,
        message: "Failed to copy code. Please try again.",
        backgroundColor: AppColors.errorRed,
      );
    }
  }

  void _shareReferralCode() async {
    try {
      await Share.share('Join GrabGo using my referral code $_referralCode and get GHS 10 off your first order! 🎉');
    } catch (e) {
      if (!mounted) return;
      AppToastMessage.show(
        context: context,
        message: "Failed to copy code. Please try again.",
        backgroundColor: AppColors.errorRed,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.sizeOf(context);
    final bool isCompact = size.height < 700;
    final double expandedHeight = (size.height * (isCompact ? 0.54 : 0.48)).clamp(360.0, 520.0);
    final double headerSpacing = isCompact ? 8.0 : 12.0;

    final systemUiOverlayStyle = SystemUiOverlayStyle(
      statusBarColor: colors.accentOrange,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: colors.backgroundPrimary,
      systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: systemUiOverlayStyle,
      child: Scaffold(
        backgroundColor: colors.backgroundPrimary,
        body: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverAppBar(
              pinned: true,
              backgroundColor: colors.accentOrange,
              elevation: 0,
              automaticallyImplyLeading: false,
              expandedHeight: expandedHeight,
              collapsedHeight: 120,
              flexibleSpace: LayoutBuilder(
                builder: (context, constraints) {
                  final collapseRange = expandedHeight - 104;
                  final collapseProgress = (1 - ((constraints.maxHeight - 104) / collapseRange)).clamp(0.0, 1.0);
                  final headerOpacity = (1 - (collapseProgress / 0.55)).clamp(0.0, 1.0);
                  final compactOpacity = ((collapseProgress - 0.45) / 0.55).clamp(0.0, 1.0);
                  final easedHeader = Curves.easeOutCubic.transform(headerOpacity);
                  final easedCompact = Curves.easeOutCubic.transform(compactOpacity);
                  final expandedOffset = 12 * collapseProgress;
                  final compactOffset = 8 * (1 - compactOpacity);
                  final showExpandedContent = constraints.maxHeight > 240;

                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      Container(width: double.infinity, color: colors.accentOrange),
                      if (showExpandedContent && headerOpacity > 0.01)
                        Opacity(
                          opacity: easedHeader,
                          child: Transform.translate(
                            offset: Offset(0, expandedOffset),
                            child: ClipRect(
                              child: Container(
                                width: double.infinity,
                                color: colors.accentOrange,
                                child: SafeArea(
                                  bottom: false,
                                  child: Padding(
                                    padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 0.h),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              height: 44,
                                              width: 44,
                                              decoration: BoxDecoration(
                                                color: colors.backgroundPrimary.withValues(alpha: 0.2),
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
                                                      height: 24,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            SizedBox(width: 16.w),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    "Refer & Earn",
                                                    style: TextStyle(
                                                      fontFamily: "Lato",
                                                      package: 'grab_go_shared',
                                                      fontSize: 20.sp,
                                                      fontWeight: FontWeight.w800,
                                                      color: Colors.white,
                                                    ),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                  SizedBox(height: 2.h),
                                                  Text(
                                                    "Share the love and get rewarded",
                                                    style: TextStyle(
                                                      fontSize: 12.sp,
                                                      fontWeight: FontWeight.w500,
                                                      color: Colors.white.withValues(alpha: 0.8),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            SizedBox(width: 12.w),
                                            Container(
                                              height: 44,
                                              width: 44,
                                              decoration: BoxDecoration(
                                                color: colors.backgroundPrimary.withValues(alpha: 0.2),
                                                shape: BoxShape.circle,
                                              ),
                                              child: Material(
                                                color: Colors.transparent,
                                                child: InkWell(
                                                  onTap: _shareReferralCode,
                                                  customBorder: const CircleBorder(),
                                                  child: Center(
                                                    child: SvgPicture.asset(
                                                      Assets.icons.shareAndroid,
                                                      package: 'grab_go_shared',
                                                      colorFilter: const ColorFilter.mode(
                                                        Colors.white,
                                                        BlendMode.srcIn,
                                                      ),
                                                      width: 20.w,
                                                      height: 20,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        SizedBox(height: headerSpacing),
                                        _buildReferralCodeCard(colors, isDark),
                                        SizedBox(height: 16.h),
                                        _buildStatsSection(colors, isDark),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      Positioned(
                        left: 0,
                        right: 0,
                        top: 0,
                        child: Opacity(
                          opacity: easedCompact,
                          child: Transform.translate(
                            offset: Offset(0, compactOffset),
                            child: SafeArea(
                              bottom: false,
                              child: Padding(
                                padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 0),
                                child: Row(
                                  children: [
                                    Container(
                                      height: 44,
                                      width: 44,
                                      decoration: BoxDecoration(
                                        color: colors.backgroundPrimary.withValues(alpha: 0.2),
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
                                              colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                                              width: 24.w,
                                              height: 24,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 12.w),
                                    Expanded(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            "Refer & Earn",
                                            style: TextStyle(
                                              fontFamily: "Lato",
                                              package: 'grab_go_shared',
                                              fontSize: 20.sp,
                                              fontWeight: FontWeight.w800,
                                              color: Colors.white,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          SizedBox(height: 2.h),
                                          Text(
                                            "Share the love and get rewarded",
                                            style: TextStyle(
                                              fontSize: 11.sp,
                                              fontWeight: FontWeight.w500,
                                              color: Colors.white.withValues(alpha: 0.8),
                                            ),
                                          ),
                                          SizedBox(height: 6.h),
                                          GestureDetector(
                                            onTap: _copyReferralCode,
                                            child: Container(
                                              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                                              decoration: BoxDecoration(
                                                color: Colors.white.withValues(alpha: 0.18),
                                                borderRadius: BorderRadius.circular(10.r),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(
                                                    _referralCode,
                                                    style: TextStyle(
                                                      fontSize: 12.sp,
                                                      fontWeight: FontWeight.w700,
                                                      color: Colors.white.withValues(alpha: 0.95),
                                                      letterSpacing: 1.2,
                                                    ),
                                                  ),
                                                  SizedBox(width: 6.w),
                                                  SvgPicture.asset(
                                                    Assets.icons.copy,
                                                    package: 'grab_go_shared',
                                                    height: 14,
                                                    width: 14,
                                                    colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    SizedBox(width: 12.w),
                                    Container(
                                      height: 44,
                                      width: 44,
                                      decoration: BoxDecoration(
                                        color: colors.backgroundPrimary.withValues(alpha: 0.2),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          onTap: _shareReferralCode,
                                          customBorder: const CircleBorder(),
                                          child: Center(
                                            child: SvgPicture.asset(
                                              Assets.icons.shareAndroid,
                                              package: 'grab_go_shared',
                                              colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                                              width: 20.w,
                                              height: 20,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: 20.w),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  SizedBox(height: 20.h),
                  _buildMilestoneTracker(colors, isDark),
                  SizedBox(height: 24.h),
                  _buildSectionHeader('Recent Referrals', colors),
                  SizedBox(height: 12.h),
                  _buildReferralHistory(colors, isDark),
                  SizedBox(height: 24.h),
                  _buildSectionHeader('How It Works', colors),
                  SizedBox(height: 12.h),
                  _buildHowItWorksSection(colors, isDark),
                  SizedBox(height: 24.h),
                  SizedBox(height: 8.h),
                  _buildRulesLink(colors),
                  SizedBox(height: 40.h),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReferralCodeCard(AppColorsExtension colors, bool isDark) {
    return Padding(
      padding: EdgeInsets.all(20.r),
      child: Column(
        children: [
          SvgPicture.asset(
            Assets.icons.gift,
            package: 'grab_go_shared',
            height: 48.r,
            width: 48.r,
            colorFilter: ColorFilter.mode(Colors.white.withValues(alpha: 0.9), BlendMode.srcIn),
          ),
          SizedBox(height: 16.h),
          Text(
            'Your Referral Code',
            style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.9)),
          ),
          SizedBox(height: 8.h),
          GestureDetector(
            onTap: _copyReferralCode,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(KBorderSize.borderMedium),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _referralCode,
                    style: TextStyle(
                      fontSize: 24.sp,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 2,
                    ),
                  ),
                  SizedBox(width: 10.w),
                  SvgPicture.asset(
                    Assets.icons.copy,
                    package: 'grab_go_shared',
                    height: 24,
                    width: 24,
                    colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 8.h),
        ],
      ),
    );
  }

  Widget _buildStatsSection(AppColorsExtension colors, bool isDark) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        final int totalReferralsValue = _totalReferralsAnimation.value.toInt();
        final int completedReferralsValue = _completedReferralsAnimation.value.toInt();
        final double totalEarnedValue = _totalEarnedAnimation.value;

        return Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Referrals',
                totalReferralsValue == 0 ? '...' : totalReferralsValue.toString(),
                Assets.icons.group,
                colors,
                isDark,
              ),
            ),
            SizedBox(width: 10.w),
            _buildStatDivider(colors),
            SizedBox(width: 10.w),
            Expanded(
              child: _buildStatCard(
                'Completed',
                completedReferralsValue == 0 ? '...' : completedReferralsValue.toString(),
                Assets.icons.check,
                colors,
                isDark,
              ),
            ),
            SizedBox(width: 10.w),
            _buildStatDivider(colors),
            SizedBox(width: 10.w),
            Expanded(
              child: _buildStatCard(
                'Total Earned',
                totalEarnedValue == 0 ? '...' : 'GHS ${totalEarnedValue.toStringAsFixed(2)}',
                Assets.icons.dollar,
                colors,
                isDark,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatCard(String label, String value, String icon, AppColorsExtension colors, bool isDark) {
    return Container(
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(KBorderSize.borderMedium)),
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              maxLines: 1,
              style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w800, color: Colors.white),
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w500, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildStatDivider(AppColorsExtension colors) {
    return Container(width: 1, height: 64.h, color: colors.divider.withValues(alpha: 0.6));
  }

  Widget _buildMilestoneTracker(AppColorsExtension colors, bool isDark) {
    final int currentReferrals = _completedReferrals;
    final int progress = currentReferrals % 5;
    final double progressPercent = (progress / 5.0);
    final int milestonesAchieved = (currentReferrals / 5).floor();
    final double bonusEarned = milestonesAchieved * 5.0;
    final int nextMilestone = (milestonesAchieved + 1) * 5;
    final int referralsToGo = nextMilestone - currentReferrals;

    String motivationalMessage;
    if (progressPercent == 0) {
      motivationalMessage = "Great start! Keep sharing!";
    } else if (progressPercent <= 0.4) {
      motivationalMessage = "You're making progress!";
    } else if (progressPercent <= 0.6) {
      motivationalMessage = "More than halfway there!";
    } else if (progressPercent <= 0.8) {
      motivationalMessage = "Almost there! Keep going!";
    } else {
      motivationalMessage = "So close! Just a bit more!";
    }

    return Container(
      decoration: BoxDecoration(
        color: colors.backgroundPrimary,
        borderRadius: BorderRadius.circular(KBorderSize.borderRadius15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Milestone Progress',
            style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w800, color: colors.textPrimary),
          ),
          SizedBox(height: 24.h),

          Center(
            child: SizedBox(
              width: 160.r,
              height: 160.r,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 160.r,
                    height: 160.r,
                    child: CircularProgressIndicator(
                      value: 1.0,
                      strokeWidth: 14.w,
                      valueColor: AlwaysStoppedAnimation<Color>(colors.backgroundSecondary),
                    ),
                  ),
                  AnimatedBuilder(
                    animation: _progressAnimationController,
                    builder: (context, child) {
                      return SizedBox(
                        width: 160.r,
                        height: 160.r,
                        child: CircularProgressIndicator(
                          value: _circularProgressAnimation.value,
                          strokeWidth: 14.w,
                          strokeCap: StrokeCap.round,
                          backgroundColor: Colors.transparent,
                          valueColor: AlwaysStoppedAnimation<Color>(colors.accentOrange),
                        ),
                      );
                    },
                  ),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$progress/5',
                        style: TextStyle(
                          fontSize: 40.sp,
                          fontWeight: FontWeight.w900,
                          color: colors.textPrimary,
                          letterSpacing: -1,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 20.h),

          Center(
            child: Text(
              '$progress of 5 referrals',
              style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w500, color: colors.textSecondary),
            ),
          ),

          SizedBox(height: 20.h),

          Container(
            padding: EdgeInsets.all(16.r),
            decoration: BoxDecoration(
              color: colors.accentOrange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(KBorderSize.borderMedium),
            ),
            child: Row(
              children: [
                SvgPicture.asset(
                  Assets.icons.gift,
                  package: "grab_go_shared",
                  height: 30.h,
                  width: 30.w,
                  colorFilter: ColorFilter.mode(colors.accentOrange, BlendMode.srcIn),
                ),
                SizedBox(width: 18.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Next Reward: GHS 5.00',
                        style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w700, color: colors.textPrimary),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        '$referralsToGo more ${referralsToGo == 1 ? 'referral' : 'referrals'} to go!',
                        style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w500, color: colors.accentOrange),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 16.h),

          Center(
            child: Text(
              motivationalMessage,
              style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600, color: colors.textSecondary),
            ),
          ),
          SizedBox(height: 20.h),

          Row(
            children: [
              Expanded(
                child: Container(
                  padding: EdgeInsets.all(12.r),
                  child: Column(
                    children: [
                      Text(
                        milestonesAchieved == 0 ? '...' : '$milestonesAchieved',
                        style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.w800, color: colors.textPrimary),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        'Milestones\nAchieved',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w500, color: colors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(width: 12.w),
              _buildStatDivider(colors),
              SizedBox(width: 12.w),
              Expanded(
                child: Container(
                  padding: EdgeInsets.all(12.r),
                  child: Column(
                    children: [
                      Text(
                        bonusEarned == 0 ? '...' : 'GHS ${bonusEarned.toStringAsFixed(2)}',
                        style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.w800, color: colors.textPrimary),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        'Total Bonus\nEarned',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w500, color: colors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReferralHistory(AppColorsExtension colors, bool isDark) {
    final referrals = [
      {'name': 'John Doe', 'status': 'completed', 'date': '2 days ago', 'reward': 'GHS 10'},
      {'name': 'Jane Smith', 'status': 'pending', 'date': '5 days ago', 'reward': 'Pending'},
      {'name': 'Mike Johnson', 'status': 'completed', 'date': '1 week ago', 'reward': 'GHS 10'},
      {'name': 'Sarah Williams', 'status': 'pending', 'date': '2 weeks ago', 'reward': 'Pending'},
    ];

    if (referrals.isEmpty) {
      return _buildEmptyHistory(colors);
    }

    return Container(
      padding: EdgeInsets.symmetric(vertical: 8.r),
      decoration: BoxDecoration(color: colors.backgroundPrimary),
      child: Column(
        children: referrals.asMap().entries.map((entry) {
          final index = entry.key;
          final referral = entry.value;
          final isLast = index == referrals.length - 1;

          return Column(
            children: [
              _buildReferralItem(
                referral['name']!,
                referral['status']!,
                referral['date']!,
                referral['reward']!,
                colors,
              ),
              if (!isLast) Divider(height: 1, color: colors.inputBorder.withValues(alpha: 0.2)),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildReferralItem(String name, String status, String date, String reward, AppColorsExtension colors) {
    final isCompleted = status == 'completed';
    final statusText = isCompleted ? 'Completed' : 'Pending';

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 12.h),
      child: Row(
        children: [
          Container(
            width: 40.r,
            height: 40.r,
            decoration: BoxDecoration(color: colors.accentOrange.withValues(alpha: 0.2), shape: BoxShape.circle),
            child: Center(
              child: Text(
                name.substring(0, 1).toUpperCase(),
                style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w800, color: colors.accentOrange),
              ),
            ),
          ),
          SizedBox(width: 12.w),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700, color: colors.textPrimary),
                ),
                SizedBox(height: 2.h),
                Text(
                  date,
                  style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w500, color: colors.textSecondary),
                ),
              ],
            ),
          ),

          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(width: 4.w),
                  Text(
                    statusText,
                    style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w600, color: colors.accentOrange),
                  ),
                ],
              ),
              SizedBox(height: 2.h),
              Text(
                reward,
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w700,
                  color: isCompleted ? colors.accentGreen : colors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyHistory(AppColorsExtension colors) {
    return Container(
      padding: EdgeInsets.all(32.r),
      decoration: BoxDecoration(
        color: colors.backgroundPrimary,
        borderRadius: BorderRadius.circular(KBorderSize.borderRadius15),
        border: Border.all(color: colors.inputBorder.withValues(alpha: 0.3), width: 0.5),
      ),
      child: Column(
        children: [
          Icon(Icons.people_outline, size: 48.r, color: colors.textSecondary.withValues(alpha: 0.5)),
          SizedBox(height: 12.h),
          Text(
            'No Referrals Yet',
            style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w700, color: colors.textPrimary),
          ),
          SizedBox(height: 4.h),
          Text(
            'Share your code to start earning!',
            style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w500, color: colors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, AppColorsExtension colors) {
    return Text(
      title,
      style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w800, color: colors.textPrimary),
    );
  }

  Widget _buildHowItWorksSection(AppColorsExtension colors, bool isDark) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 12.r),
      decoration: BoxDecoration(color: colors.backgroundPrimary),
      child: EasyStepper(
        activeStep: 2,
        stepRadius: 20.r,
        enableStepTapping: false,
        showTitle: true,
        disableScroll: true,
        lineStyle: LineStyle(
          lineLength: 80.w,
          lineSpace: 0,
          lineThickness: 3,
          lineType: LineType.normal,
          defaultLineColor: colors.inputBorder,
          finishedLineColor: colors.accentOrange,
        ),
        showStepBorder: false,
        unreachedStepBackgroundColor: colors.inputBorder,
        activeStepBackgroundColor: colors.accentOrange,
        finishedStepBackgroundColor: colors.accentOrange,
        stepShape: StepShape.circle,
        showLoadingAnimation: false,
        steps: [
          EasyStep(
            customTitle: Text(
              'Share code',
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.textPrimary, fontSize: 12.sp, fontWeight: FontWeight.w600),
            ),
            customStep: Container(
              width: 40.w,
              height: 40.h,
              decoration: BoxDecoration(color: colors.accentOrange, shape: BoxShape.circle),
              child: Center(
                child: SvgPicture.asset(
                  Assets.icons.shareAndroid,
                  package: 'grab_go_shared',
                  width: 18.w,
                  height: 18.h,
                  colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                ),
              ),
            ),
          ),
          EasyStep(
            customTitle: Text(
              'Friend joins',
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.textPrimary, fontSize: 12.sp, fontWeight: FontWeight.w600),
            ),
            customStep: Container(
              width: 40.w,
              height: 40.h,
              decoration: BoxDecoration(color: colors.accentOrange, shape: BoxShape.circle),
              child: Center(
                child: SvgPicture.asset(
                  Assets.icons.group,
                  package: 'grab_go_shared',
                  width: 18.w,
                  height: 18.h,
                  colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                ),
              ),
            ),
          ),
          EasyStep(
            customTitle: Text(
              'You earn',
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.textPrimary, fontSize: 12.sp, fontWeight: FontWeight.w600),
            ),
            customStep: Container(
              width: 40.w,
              height: 40.h,
              decoration: BoxDecoration(color: colors.accentOrange, shape: BoxShape.circle),
              child: Center(
                child: SvgPicture.asset(
                  Assets.icons.gift,
                  package: 'grab_go_shared',
                  width: 18.w,
                  height: 18.h,
                  colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRulesLink(AppColorsExtension colors) {
    return Align(
      alignment: Alignment.centerLeft,
      child: InkWell(
        onTap: () => _showRulesSheet(colors),
        borderRadius: BorderRadius.circular(12.r),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 6.h, horizontal: 4.w),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Rules',
                style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700, color: colors.accentOrange),
              ),
              SizedBox(width: 4.w),
              Icon(Icons.chevron_right, size: 18.sp, color: colors.accentOrange),
            ],
          ),
        ),
      ),
    );
  }

  void _showRulesSheet(AppColorsExtension colors) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: colors.backgroundPrimary,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
          ),
          padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 24.h),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36.w,
                      height: 4.h,
                      decoration: BoxDecoration(color: colors.divider, borderRadius: BorderRadius.circular(10.r)),
                    ),
                  ),
                  SizedBox(height: 16.h),
                  Text(
                    'Rules',
                    style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w800, color: colors.textPrimary),
                  ),
                  SizedBox(height: 12.h),
                  _buildTermItem('• Referral credit valid for 30 days', colors),
                  SizedBox(height: 8.h),
                  _buildTermItem('• Minimum order value: GHS 20', colors),
                  SizedBox(height: 8.h),
                  _buildTermItem('• One referral code per user', colors),
                  SizedBox(height: 8.h),
                  _buildTermItem('• Credits cannot be withdrawn', colors),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTermItem(String text, AppColorsExtension colors) {
    return Text(
      text,
      style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w500, color: colors.textSecondary, height: 1.5),
    );
  }
}
