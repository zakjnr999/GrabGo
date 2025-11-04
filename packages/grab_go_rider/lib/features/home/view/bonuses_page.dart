import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:intl/intl.dart';

enum BonusStatus { active, completed, expired }

class Bonus {
  final String id;
  final String title;
  final String description;
  final double amount;
  final BonusStatus status;
  final DateTime startDate;
  final DateTime endDate;
  final DateTime? earnedDate;
  final String requirement;
  final int progress;
  final int target;
  final String type; // 'weekly', 'monthly', 'milestone', 'special'

  Bonus({
    required this.id,
    required this.title,
    required this.description,
    required this.amount,
    required this.status,
    required this.startDate,
    required this.endDate,
    this.earnedDate,
    required this.requirement,
    required this.progress,
    required this.target,
    required this.type,
  });
}

class BonusesPage extends StatefulWidget {
  const BonusesPage({super.key});

  @override
  State<BonusesPage> createState() => _BonusesPageState();
}

class _BonusesPageState extends State<BonusesPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Bonus> _activeBonuses = [];
  List<Bonus> _completedBonuses = [];

  double _totalBonusesEarned = 0.0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadBonuses();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _loadBonuses() {
    final now = DateTime.now();

    // Active bonuses
    _activeBonuses = [
      Bonus(
        id: '1',
        title: 'Weekend Warrior',
        description: 'Complete 10 deliveries this weekend',
        amount: 50.00,
        status: BonusStatus.active,
        startDate: now.subtract(const Duration(days: 1)),
        endDate: now.add(const Duration(days: 2)),
        requirement: 'Complete 10 deliveries',
        progress: 7,
        target: 10,
        type: 'weekly',
      ),
      Bonus(
        id: '2',
        title: 'Early Bird Bonus',
        description: 'Complete 5 deliveries before 9 AM',
        amount: 25.00,
        status: BonusStatus.active,
        startDate: now.subtract(const Duration(days: 2)),
        endDate: now.add(const Duration(days: 5)),
        requirement: 'Complete 5 early morning deliveries',
        progress: 3,
        target: 5,
        type: 'special',
      ),
      Bonus(
        id: '3',
        title: '100 Deliveries Milestone',
        description: 'Reach 100 total deliveries this month',
        amount: 100.00,
        status: BonusStatus.active,
        startDate: now.subtract(const Duration(days: 15)),
        endDate: now.add(const Duration(days: 15)),
        requirement: 'Complete 100 deliveries',
        progress: 87,
        target: 100,
        type: 'milestone',
      ),
    ];

    // Completed bonuses
    _completedBonuses = [
      Bonus(
        id: '4',
        title: 'Weekend Bonus',
        description: 'Completed weekend challenge',
        amount: 50.00,
        status: BonusStatus.completed,
        startDate: now.subtract(const Duration(days: 7)),
        endDate: now.subtract(const Duration(days: 2)),
        earnedDate: now.subtract(const Duration(days: 2)),
        requirement: 'Complete 10 weekend deliveries',
        progress: 10,
        target: 10,
        type: 'weekly',
      ),
      Bonus(
        id: '5',
        title: 'Monthly Performance Bonus',
        description: 'Excellent performance this month',
        amount: 100.00,
        status: BonusStatus.completed,
        startDate: now.subtract(const Duration(days: 30)),
        endDate: now.subtract(const Duration(days: 1)),
        earnedDate: now.subtract(const Duration(days: 1)),
        requirement: 'Maintain 95%+ success rate',
        progress: 100,
        target: 100,
        type: 'monthly',
      ),
      Bonus(
        id: '6',
        title: 'Perfect Week',
        description: 'No cancellations this week',
        amount: 30.00,
        status: BonusStatus.completed,
        startDate: now.subtract(const Duration(days: 14)),
        endDate: now.subtract(const Duration(days: 7)),
        earnedDate: now.subtract(const Duration(days: 7)),
        requirement: 'Zero cancellations',
        progress: 100,
        target: 100,
        type: 'special',
      ),
      Bonus(
        id: '7',
        title: '50 Deliveries Milestone',
        description: 'Reached 50 deliveries milestone',
        amount: 75.00,
        status: BonusStatus.completed,
        startDate: now.subtract(const Duration(days: 20)),
        endDate: now.subtract(const Duration(days: 10)),
        earnedDate: now.subtract(const Duration(days: 10)),
        requirement: 'Complete 50 deliveries',
        progress: 50,
        target: 50,
        type: 'milestone',
      ),
    ];

    _totalBonusesEarned = _completedBonuses.fold(0.0, (sum, bonus) => sum + bonus.amount);
  }

  String _getBonusTypeIcon(String type) {
    switch (type) {
      case 'weekly':
        return Assets.icons.clock;
      case 'monthly':
        return Assets.icons.calendar;
      case 'milestone':
        return Assets.icons.star;
      case 'special':
        return Assets.icons.gift;
      default:
        return Assets.icons.gift;
    }
  }

  Color _getBonusTypeColor(String type, AppColorsExtension colors) {
    switch (type) {
      case 'weekly':
        return colors.accentGreen;
      case 'monthly':
        return colors.accentBlue;
      case 'milestone':
        return colors.accentViolet;
      case 'special':
        return colors.accentOrange;
      default:
        return colors.accentOrange;
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
      child: Scaffold(
        backgroundColor: colors.backgroundSecondary,
        appBar: AppBar(
          backgroundColor: colors.backgroundPrimary,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: Container(
            margin: EdgeInsets.all(8.w),
            decoration: BoxDecoration(
              color: colors.backgroundSecondary,
              shape: BoxShape.circle,
              border: Border.all(color: colors.border.withValues(alpha: 0.3), width: 1),
            ),
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
          title: Text(
            "Bonuses",
            style: TextStyle(
              fontFamily: "Lato",
              package: "grab_go_shared",
              color: colors.textPrimary,
              fontSize: 18.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
          centerTitle: true,
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: colors.accentOrange,
            labelColor: colors.accentOrange,
            unselectedLabelColor: colors.textSecondary,
            labelStyle: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600),
            unselectedLabelStyle: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w500),
            tabs: const [
              Tab(text: 'Active'),
              Tab(text: 'History'),
            ],
          ),
        ),
        body: Column(
          children: [
            // Total Bonuses Card
            Container(
              margin: EdgeInsets.all(20.w),
              padding: EdgeInsets.all(24.w),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [colors.accentOrange, colors.accentOrange.withValues(alpha: 0.85)],
                ),
                borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
                boxShadow: [
                  BoxShadow(
                    color: colors.accentOrange.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Total Earned",
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 14.sp,
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
                                _totalBonusesEarned.toStringAsFixed(2),
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
                      ],
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.all(16.r),
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
                    child: SvgPicture.asset(
                      Assets.icons.gift,
                      package: 'grab_go_shared',
                      width: 32.w,
                      height: 32.w,
                      colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                    ),
                  ),
                ],
              ),
            ),

            // Tab Content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Active Bonuses
                  _activeBonuses.isEmpty
                      ? _buildEmptyState("No active bonuses", "Check back later for new bonus opportunities!", colors)
                      : ListView.separated(
                          physics: const BouncingScrollPhysics(),
                          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 8.h),
                          itemCount: _activeBonuses.length,
                          separatorBuilder: (context, index) => SizedBox(height: 16.h),
                          itemBuilder: (context, index) {
                            return _buildBonusCard(_activeBonuses[index], colors, isActive: true);
                          },
                        ),

                  // Completed Bonuses
                  _completedBonuses.isEmpty
                      ? _buildEmptyState("No bonus history", "Complete bonuses to see your earnings here!", colors)
                      : ListView.separated(
                          physics: const BouncingScrollPhysics(),
                          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 8.h),
                          itemCount: _completedBonuses.length,
                          separatorBuilder: (context, index) => SizedBox(height: 16.h),
                          itemBuilder: (context, index) {
                            return _buildBonusCard(_completedBonuses[index], colors, isActive: false);
                          },
                        ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBonusCard(Bonus bonus, AppColorsExtension colors, {required bool isActive}) {
    final typeColor = _getBonusTypeColor(bonus.type, colors);
    final iconPath = _getBonusTypeIcon(bonus.type);
    final progressPercentage = (bonus.progress / bonus.target * 100).clamp(0.0, 100.0);
    final daysRemaining = bonus.endDate.difference(DateTime.now()).inDays;

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: colors.backgroundPrimary,
        borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
        border: Border.all(color: isActive ? typeColor.withValues(alpha: 0.3) : colors.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(10.r),
                decoration: BoxDecoration(
                  color: typeColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
                ),
                child: SvgPicture.asset(
                  iconPath,
                  package: 'grab_go_shared',
                  width: 24.w,
                  height: 24.w,
                  colorFilter: ColorFilter.mode(typeColor, BlendMode.srcIn),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      bonus.title,
                      style: TextStyle(color: colors.textPrimary, fontSize: 16.sp, fontWeight: FontWeight.w700),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      bonus.description,
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
                  color: typeColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20.r),
                ),
                child: Text(
                  "GHC ${bonus.amount.toStringAsFixed(2)}",
                  style: TextStyle(color: typeColor, fontSize: 14.sp, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          if (isActive) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  bonus.requirement,
                  style: TextStyle(color: colors.textPrimary, fontSize: 13.sp, fontWeight: FontWeight.w600),
                ),
                Text(
                  "${bonus.progress}/${bonus.target}",
                  style: TextStyle(color: typeColor, fontSize: 13.sp, fontWeight: FontWeight.w700),
                ),
              ],
            ),
            SizedBox(height: 8.h),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progressPercentage / 100,
                minHeight: 8.h,
                backgroundColor: colors.border.withValues(alpha: 0.3),
                valueColor: AlwaysStoppedAnimation<Color>(typeColor),
              ),
            ),
            SizedBox(height: 12.h),
            Row(
              children: [
                Icon(Icons.access_time, size: 14.w, color: colors.textSecondary),
                SizedBox(width: 4.w),
                Text(
                  daysRemaining > 0 ? "$daysRemaining days left" : "Expiring soon",
                  style: TextStyle(color: colors.textSecondary, fontSize: 12.sp, fontWeight: FontWeight.w500),
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
                Icon(Icons.check_circle, size: 16.w, color: colors.success),
                SizedBox(width: 6.w),
                Text(
                  bonus.requirement,
                  style: TextStyle(color: colors.textPrimary, fontSize: 13.sp, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            SizedBox(height: 12.h),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 14.w, color: colors.textSecondary),
                SizedBox(width: 4.w),
                Text(
                  bonus.earnedDate != null
                      ? "Earned on ${DateFormat('MMM dd, yyyy').format(bonus.earnedDate!)}"
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
                Assets.icons.gift,
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
}
