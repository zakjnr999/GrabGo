// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_customer/shared/widgets/app_refresh_indicator.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:share_plus/share_plus.dart';
import 'package:grab_go_customer/core/api/api_client.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:grab_go_customer/shared/widgets/umbrella_header.dart';
import 'package:flutter/services.dart';

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
  // Animation controllers
  late AnimationController _animationController;
  late Animation<double> _totalReferralsAnimation;
  late Animation<double> _completedReferralsAnimation;
  late Animation<double> _totalEarnedAnimation;

  // Progress animations for milestone tracker
  late AnimationController _progressAnimationController;
  late Animation<double> _circularProgressAnimation;
  late Animation<double> _linearProgressAnimation;

  // Track previous values to prevent duplicate animations
  int _previousTotalReferrals = 0;
  int _previousCompletedReferrals = 0;
  double _previousTotalEarned = 0.0;

  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<double> _scrollOffsetNotifier = ValueNotifier<double>(0.0);
  static const double _collapsedHeight = 80.0;
  static const double _scrollThreshold = 100.0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);

    // Stats animation controller
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

    // Progress animation controller for milestone tracker
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
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _scrollOffsetNotifier.dispose();
    // Stop and dispose animation controllers
    _animationController.stop();
    _progressAnimationController.stop();
    _animationController.dispose();
    _progressAnimationController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    _scrollOffsetNotifier.value = _scrollController.offset;
  }

  Future<void> _loadReferralData() async {
    if (!mounted) return;

    // Load from cache first for instant display
    await _loadFromCache();

    // Then fetch from server in background
    await _fetchFromServer();
  }

  Future<void> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedData = prefs.getString('referral_data');

      if (cachedData != null) {
        try {
          final data = json.decode(cachedData) as Map<String, dynamic>;
          debugPrint('📦 Loaded referral data from cache');

          if (!mounted) return;

          setState(() {
            _referralCode = data['code'] ?? '••••••••';
            _totalReferrals = data['totalReferrals'] ?? 0;
            _completedReferrals = data['completedReferrals'] ?? 0;
            _totalEarned = (data['totalEarned'] ?? 0).toDouble();
            isLoadingData = false;
          });

          // Animate with cached data
          _animateStats();
          _animateProgress();

          // Update previous values to prevent re-animation if server data is same
          _previousTotalReferrals = _totalReferrals;
          _previousCompletedReferrals = _completedReferrals;
          _previousTotalEarned = _totalEarned;
        } catch (e) {
          debugPrint('❌ Corrupted cache data, clearing: $e');
          // Clear corrupted cache
          await prefs.remove('referral_data');
        }
      }
    } catch (e) {
      debugPrint('❌ Error loading from cache: $e');
    }
  }

  Future<void> _fetchFromServer() async {
    try {
      debugPrint('🔍 Fetching referral data from: ${AppConfig.apiBaseUrl}/referral/my-code');

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
        debugPrint('✅ Fetched fresh data from server');

        // Save to cache
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('referral_data', json.encode(data));
        debugPrint('💾 Saved referral data to cache');

        if (!mounted) return;

        setState(() {
          _referralCode = data['code'] ?? 'N/A';
          _totalReferrals = data['totalReferrals'] ?? 0;
          _completedReferrals = data['completedReferrals'] ?? 0;
          _totalEarned = (data['totalEarned'] ?? 0).toDouble();
          isLoadingData = false;
        });

        // Only animate if data actually changed
        if (_totalReferrals != _previousTotalReferrals ||
            _completedReferrals != _previousCompletedReferrals ||
            _totalEarned != _previousTotalEarned) {
          _animateStats();
          _animateProgress();

          // Update previous values
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

    final systemUiOverlayStyle = SystemUiOverlayStyle(
      statusBarColor: colors.accentOrange,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: colors.backgroundSecondary,
      systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: systemUiOverlayStyle,
      child: Scaffold(
        backgroundColor: colors.backgroundSecondary,
        body: SafeArea(
          top: false,
          child: ClipRect(
            child: Stack(
              children: [
                AppRefreshIndicator(
                  onRefresh: _loadReferralData,
                  iconPath: Assets.icons.gift,
                  bgColor: colors.accentOrange,
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.symmetric(horizontal: 20.w),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: size.height * 0.22),

                        // Referral Code Card
                        _buildReferralCodeCard(colors, isDark),
                        SizedBox(height: 20.h),

                        // Stats Cards
                        _buildStatsSection(colors, isDark),
                        SizedBox(height: 24.h),

                        // Milestone Tracker
                        _buildMilestoneTracker(colors, isDark),
                        SizedBox(height: 24.h),

                        // Referral History
                        _buildSectionHeader('Recent Referrals', colors), // Referral Code Card

                        SizedBox(height: 12.h),
                        _buildReferralHistory(colors, isDark),
                        SizedBox(height: 24.h),

                        // How it Works
                        _buildSectionHeader('How It Works', colors),
                        SizedBox(height: 12.h),
                        _buildHowItWorksSection(colors, isDark),
                        SizedBox(height: 24.h),

                        // Terms
                        _buildSectionHeader('Terms & Conditions', colors),
                        SizedBox(height: 12.h),
                        _buildTermsSection(colors, isDark),
                        SizedBox(height: 40.h),
                      ],
                    ),
                  ),
                ),

                Positioned(top: 0, left: 0, right: 0, child: _buildCollapsibleReferralHeader(colors, size)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCollapsibleReferralHeader(AppColorsExtension colors, Size size) {
    return ValueListenableBuilder<double>(
      valueListenable: _scrollOffsetNotifier,
      builder: (context, scrollOffset, _) {
        final collapseProgress = (scrollOffset / _scrollThreshold).clamp(0.0, 1.0);
        final expandedHeight = size.height * 0.20;
        final currentHeight = expandedHeight - ((expandedHeight - _collapsedHeight) * collapseProgress);
        final contentOpacity = (1.0 - collapseProgress).clamp(0.0, 1.0);

        return SizedBox(
          height: currentHeight,
          child: UmbrellaHeaderWithShadow(
            curveDepth: 25.h,
            numberOfCurves: 10,
            height: currentHeight,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 100),
              opacity: contentOpacity,
              child: _buildReferralHeader(colors),
            ),
          ),
        );
      },
    );
  }

  Widget _buildReferralHeader(AppColorsExtension colors) {
    final statusBarHeight = MediaQuery.of(context).padding.top;

    return SizedBox.expand(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20.w, statusBarHeight.h, 20.w, 16.h),
        child: Row(
          children: [
            Container(
              height: 44.h,
              width: 44.w,
              decoration: BoxDecoration(color: colors.backgroundPrimary.withValues(alpha: 0.2), shape: BoxShape.circle),
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
            SizedBox(width: 16.w),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Refer & Earn",
                    style: TextStyle(
                      fontFamily: "Lato",
                      package: 'grab_go_shared',
                      fontSize: 24.sp,
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
          ],
        ),
      ),
    );
  }

  Widget _buildReferralCodeCard(AppColorsExtension colors, bool isDark) {
    return Container(
      padding: EdgeInsets.all(24.r),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colors.accentOrange, colors.accentOrange.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(KBorderSize.borderRadius15),
        boxShadow: [
          BoxShadow(
            color: colors.accentOrange.withOpacity(0.3),
            spreadRadius: 0,
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -20,
            right: -20,
            child: Container(
              width: 120.r,
              height: 120.r,
              decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.05)),
            ),
          ),
          Positioned(
            bottom: -30,
            left: -30,
            child: Container(
              width: 100.r,
              height: 100.r,
              decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.05)),
            ),
          ),
          Positioned(
            top: 40,
            left: 20,
            child: Container(
              width: 8.r,
              height: 8.r,
              decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.3)),
            ),
          ),
          Positioned(
            top: 60,
            right: 40,
            child: Container(
              width: 6.r,
              height: 6.r,
              decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.4)),
            ),
          ),
          Positioned(
            bottom: 50,
            right: 30,
            child: Container(
              width: 10.r,
              height: 10.r,
              decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.2)),
            ),
          ),

          Column(
            children: [
              SvgPicture.asset(
                Assets.icons.gift,
                package: 'grab_go_shared',
                height: 48.r,
                width: 48.r,
                colorFilter: ColorFilter.mode(Colors.white.withOpacity(0.9), BlendMode.srcIn),
              ),
              SizedBox(height: 16.h),
              Text(
                'Your Referral Code',
                style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600, color: Colors.white.withOpacity(0.9)),
              ),
              SizedBox(height: 8.h),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
                ),
                child: Text(
                  _referralCode,
                  style: TextStyle(fontSize: 24.sp, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 2),
                ),
              ),
              SizedBox(height: 20.h),
              Row(
                children: [
                  Expanded(
                    child: _buildActionButton(
                      'Copy Code',
                      Assets.icons.copy,
                      _copyReferralCode,
                      Colors.white,
                      colors.accentOrange,
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: _buildActionButton(
                      'Share',
                      Assets.icons.shareAndroid,
                      _shareReferralCode,
                      colors.accentOrange,
                      Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(String label, String icon, VoidCallback onTap, Color bgColor, Color textColor) {
    return Material(
      color: bgColor,
      borderRadius: BorderRadius.circular(12.r),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12.r),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 12.h),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SvgPicture.asset(
                icon,
                package: "grab_go_shared",
                height: 18.h,
                width: 18.w,
                colorFilter: ColorFilter.mode(textColor, BlendMode.srcIn),
              ),
              SizedBox(width: 8.w),
              Text(
                label,
                style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700, color: textColor),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsSection(AppColorsExtension colors, bool isDark) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Referrals',
                _totalReferralsAnimation.value.toInt().toString(),
                Assets.icons.group,
                colors,
                isDark,
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: _buildStatCard(
                'Completed',
                _completedReferralsAnimation.value.toInt().toString(),
                Assets.icons.check,
                colors,
                isDark,
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: _buildStatCard(
                'Total Earned',
                'GHS ${_totalEarnedAnimation.value.toStringAsFixed(2)}',
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
      decoration: BoxDecoration(
        color: colors.backgroundPrimary,
        borderRadius: BorderRadius.circular(KBorderSize.borderRadius15),
        border: Border.all(color: colors.inputBorder.withOpacity(0.3), width: 0.5),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withAlpha(30) : Colors.black.withAlpha(8),
            spreadRadius: 0,
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(8.r),
            decoration: BoxDecoration(color: colors.accentOrange.withOpacity(0.1), shape: BoxShape.circle),
            child: SvgPicture.asset(
              icon,
              package: "grab_go_shared",
              height: 20.h,
              width: 20.w,
              colorFilter: ColorFilter.mode(colors.accentOrange, BlendMode.srcIn),
            ),
          ),
          SizedBox(height: 12.h),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              maxLines: 1,
              style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w800, color: colors.textPrimary),
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w500, color: colors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildMilestoneTracker(AppColorsExtension colors, bool isDark) {
    // Calculate milestone progress
    final int currentReferrals = _completedReferrals;
    final int progress = currentReferrals % 5; // Progress within current milestone
    final double progressPercent = (progress / 5.0);
    final int milestonesAchieved = (currentReferrals / 5).floor();
    final double bonusEarned = milestonesAchieved * 5.0;
    final int nextMilestone = (milestonesAchieved + 1) * 5;
    final int referralsToGo = nextMilestone - currentReferrals;

    // Motivational message based on progress
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
      padding: EdgeInsets.all(24.r),
      decoration: BoxDecoration(
        color: colors.backgroundPrimary,
        borderRadius: BorderRadius.circular(KBorderSize.borderRadius15),
        border: Border.all(color: colors.inputBorder.withValues(alpha: 0.3), width: 0.5),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withAlpha(20) : Colors.black.withAlpha(5),
            spreadRadius: 0,
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              SvgPicture.asset(
                Assets.icons.trophy,
                package: "grab_go_shared",
                height: 30.h,
                width: 30.w,
                colorFilter: ColorFilter.mode(colors.accentOrange, BlendMode.srcIn),
              ),
              SizedBox(width: 8.w),
              Text(
                'Milestone Progress',
                style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w800, color: colors.textPrimary),
              ),
            ],
          ),
          SizedBox(height: 24.h),

          // Circular Progress Indicator
          Center(
            child: SizedBox(
              width: 160.r,
              height: 160.r,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Background circle (always visible)
                  SizedBox(
                    width: 160.r,
                    height: 160.r,
                    child: CircularProgressIndicator(
                      value: 1.0,
                      strokeWidth: 14.w,
                      valueColor: AlwaysStoppedAnimation<Color>(colors.backgroundSecondary),
                    ),
                  ),
                  // Progress circle (orange) - Animated
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
                  // Center text
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

          // Progress text
          Center(
            child: Text(
              '$progress of 5 referrals',
              style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w500, color: colors.textSecondary),
            ),
          ),
          SizedBox(height: 16.h),

          // Progress bar - Animated
          AnimatedBuilder(
            animation: _progressAnimationController,
            builder: (context, child) {
              return Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10.r),
                  border: Border.all(color: colors.inputBorder.withValues(alpha: 0.3), width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: colors.accentOrange.withValues(alpha: _linearProgressAnimation.value > 0 ? 0.2 : 0),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(9.r),
                  child: LinearProgressIndicator(
                    value: _linearProgressAnimation.value,
                    backgroundColor: colors.inputBorder.withValues(alpha: 0.15),
                    valueColor: AlwaysStoppedAnimation<Color>(colors.accentOrange),
                    minHeight: 14.h,
                  ),
                ),
              );
            },
          ),
          SizedBox(height: 20.h),

          // Reward info
          Container(
            padding: EdgeInsets.all(16.r),
            decoration: BoxDecoration(
              color: colors.accentOrange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12.r),
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
                        style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w500, color: colors.accentGreen),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 16.h),

          // Motivational message
          Center(
            child: Text(
              motivationalMessage,
              style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600, color: colors.textSecondary),
            ),
          ),
          SizedBox(height: 20.h),

          // Stats row
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: EdgeInsets.all(12.r),
                  decoration: BoxDecoration(
                    color: colors.accentGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '$milestonesAchieved',
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
              Expanded(
                child: Container(
                  padding: EdgeInsets.all(12.r),
                  decoration: BoxDecoration(
                    color: colors.accentOrange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'GHS ${bonusEarned.toStringAsFixed(2)}',
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
    // Dummy data for referral history
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
      decoration: BoxDecoration(
        color: colors.backgroundPrimary,
        borderRadius: BorderRadius.circular(KBorderSize.borderRadius15),
        border: Border.all(color: colors.inputBorder.withOpacity(0.3), width: 0.5),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withAlpha(30) : Colors.black.withAlpha(8),
            spreadRadius: 0,
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
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
              if (!isLast) Divider(height: 1, color: colors.inputBorder.withOpacity(0.2)),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildReferralItem(String name, String status, String date, String reward, AppColorsExtension colors) {
    final isCompleted = status == 'completed';
    final statusColor = isCompleted ? colors.accentGreen : colors.accentOrange;
    final statusIcon = isCompleted ? Icons.check_circle : Icons.pending;
    final statusText = isCompleted ? 'Completed' : 'Pending';

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 40.r,
            height: 40.r,
            decoration: BoxDecoration(color: statusColor.withOpacity(0.1), shape: BoxShape.circle),
            child: Center(
              child: Text(
                name.substring(0, 1).toUpperCase(),
                style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w800, color: statusColor),
              ),
            ),
          ),
          SizedBox(width: 12.w),

          // Name and date
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

          // Status and reward
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(statusIcon, size: 14.r, color: statusColor),
                  SizedBox(width: 4.w),
                  Text(
                    statusText,
                    style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w600, color: statusColor),
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
        border: Border.all(color: colors.inputBorder.withOpacity(0.3), width: 0.5),
      ),
      child: Column(
        children: [
          Icon(Icons.people_outline, size: 48.r, color: colors.textSecondary.withOpacity(0.5)),
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
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        color: colors.backgroundPrimary,
        borderRadius: BorderRadius.circular(KBorderSize.borderRadius15),
        border: Border.all(color: colors.inputBorder.withOpacity(0.3), width: 0.5),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withAlpha(30) : Colors.black.withAlpha(8),
            spreadRadius: 0,
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildStep(1, 'Share Your Code', 'Send your referral code to friends', colors),
          SizedBox(height: 16.h),
          _buildStep(2, 'Friend Signs Up', 'They register using your code', colors),
          SizedBox(height: 16.h),
          _buildStep(3, 'Both Get Rewards', 'You both get GHS 10 credit!', colors),
        ],
      ),
    );
  }

  Widget _buildStep(int number, String title, String description, AppColorsExtension colors) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32.r,
          height: 32.r,
          decoration: BoxDecoration(color: colors.accentOrange, shape: BoxShape.circle),
          child: Center(
            child: Text(
              '$number',
              style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w800, color: Colors.white),
            ),
          ),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700, color: colors.textPrimary),
              ),
              SizedBox(height: 4.h),
              Text(
                description,
                style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w500, color: colors.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTermsSection(AppColorsExtension colors, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: colors.backgroundPrimary,
        borderRadius: BorderRadius.circular(KBorderSize.borderRadius15),
        border: Border.all(color: colors.inputBorder.withOpacity(0.3), width: 0.5),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withAlpha(30) : Colors.black.withAlpha(8),
            spreadRadius: 0,
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
          childrenPadding: EdgeInsets.only(left: 16.w, right: 16.w, bottom: 16.h),
          title: Row(
            children: [
              SvgPicture.asset(
                Assets.icons.infoCircle,
                package: "grab_go_shared",
                height: 24.h,
                width: 24.w,
                colorFilter: ColorFilter.mode(colors.accentOrange, BlendMode.srcIn),
              ),
              SizedBox(width: 8.w),
              Text(
                'Terms & Conditions',
                style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700, color: colors.textPrimary),
              ),
            ],
          ),
          iconColor: colors.textPrimary,
          collapsedIconColor: colors.textSecondary,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTermItem('• Referral credit valid for 30 days', colors),
                SizedBox(height: 8.h),
                _buildTermItem('• Minimum order value: GHS 20', colors),
                SizedBox(height: 8.h),
                _buildTermItem('• One referral code per user', colors),
                SizedBox(height: 8.h),
                _buildTermItem('• Credits cannot be withdrawn', colors),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTermItem(String text, AppColorsExtension colors) {
    return Text(
      text,
      style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w500, color: colors.textSecondary, height: 1.5),
    );
  }
}
