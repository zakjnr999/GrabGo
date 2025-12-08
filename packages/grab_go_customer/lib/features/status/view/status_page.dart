import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_customer/shared/widgets/cached_image_widget.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:grab_go_customer/features/status/model/status_model.dart';
import 'package:grab_go_customer/features/status/viewmodel/status_provider.dart';
import 'package:grab_go_customer/features/status/view/story_viewer.dart';
import 'package:grab_go_customer/shared/widgets/status_card.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'dart:math' as math;

class StatusPage extends StatefulWidget {
  const StatusPage({super.key});

  @override
  State<StatusPage> createState() => _StatusPageState();
}

class _StatusPageState extends State<StatusPage> {
  int _selectedFilterIndex = 0;

  final List<_StatusFilter> _filters = [
    _StatusFilter(label: 'All', category: null),
    _StatusFilter(label: 'Specials', category: StatusCategory.dailySpecial),
    _StatusFilter(label: 'Discounts', category: StatusCategory.discount),
    _StatusFilter(label: 'New Items', category: StatusCategory.newItem),
    _StatusFilter(label: 'Videos', category: StatusCategory.video),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  void _loadData() {
    final provider = context.read<StatusProvider>();
    provider.fetchStories();
    provider.fetchStatuses();
  }

  void _navigateToAllStatuses(StatusCategory? category) {
    context.push('/allStatuses', extra: category);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: colors.backgroundSecondary,
      appBar: _buildAppBar(colors),
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          systemNavigationBarColor: colors.backgroundPrimary,
          systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        ),
        child: SafeArea(
          child: Consumer<StatusProvider>(
            builder: (context, provider, child) {
              return SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.only(bottom: 24.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(colors),
                    SizedBox(height: KSpacing.lg.h),
                    _buildSectionHeader(
                      colors,
                      "New From Restaurants",
                      Assets.icons.flame,
                      colors.accentViolet,
                      onSeeAll: () {},
                    ),
                    SizedBox(height: KSpacing.lg.h),
                    _buildStoriesRow(colors, provider),
                    SizedBox(height: KSpacing.lg.h),
                    _buildCategoryTabs(colors),
                    SizedBox(height: KSpacing.lg.h),
                    _buildSectionHeader(
                      colors,
                      _getSectionTitle(),
                      _getSectionIcon(),
                      _getSectionColor(colors),
                      onSeeAll: () => _navigateToAllStatuses(_filters[_selectedFilterIndex].category),
                    ),
                    SizedBox(height: 12.h),
                    _buildStatusesList(colors, provider, isDark),
                    if (provider.recommendedStatuses.isNotEmpty) ...[
                      SizedBox(height: 24.h),
                      _buildSectionHeader(colors, "Recommended For You", Assets.icons.flame, colors.accentViolet),
                      SizedBox(height: 12.h),
                      _buildRecommendedRow(colors, provider.recommendedStatuses, isDark),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(AppColorsExtension colors) {
    return AppBar(
      backgroundColor: colors.backgroundSecondary,
      automaticallyImplyLeading: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      leadingWidth: 72,
      leading: SizedBox(
        height: KWidgetSize.buttonHeightSmall.h,
        width: KWidgetSize.buttonHeightSmall.w,
        child: Material(
          color: colors.backgroundSecondary,
          shape: const CircleBorder(),
          child: InkWell(
            onTap: () => context.pop(),
            customBorder: const CircleBorder(),
            splashColor: colors.iconSecondary.withAlpha(50),
            child: Padding(
              padding: EdgeInsets.all(14.r),
              child: SvgPicture.asset(
                Assets.icons.navArrowLeft,
                package: 'grab_go_shared',
                colorFilter: ColorFilter.mode(colors.iconPrimary, BlendMode.srcIn),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(AppColorsExtension colors) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(10.r),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [colors.accentOrange, colors.accentOrange.withValues(alpha: 0.8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: colors.accentOrange.withValues(alpha: 0.3),
                      spreadRadius: 0,
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: SvgPicture.asset(
                  Assets.icons.styleBorder,
                  package: 'grab_go_shared',
                  height: 22.h,
                  width: 22.w,
                  colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Stories from restaurants",
                      style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w500, color: colors.textSecondary),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      "Status & Updates",
                      style: TextStyle(color: colors.textPrimary, fontSize: 20.sp, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Text(
            "See what's cooking right now from your favourite restaurants.",
            style: TextStyle(fontSize: 13.sp, color: colors.textSecondary, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(
    AppColorsExtension colors,
    String title,
    String icon,
    Color iconColor, {
    VoidCallback? onSeeAll,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8.r),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(KBorderSize.border),
                ),
                child: SvgPicture.asset(
                  icon,
                  package: 'grab_go_shared',
                  height: 20.h,
                  width: 20.w,
                  colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
                ),
              ),
              SizedBox(width: 10.w),
              Text(
                title,
                style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w700, color: colors.textPrimary),
              ),
            ],
          ),
          if (onSeeAll != null) _buildSeeAllButton(colors, onSeeAll),
        ],
      ),
    );
  }

  Widget _buildSeeAllButton(AppColorsExtension colors, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
        decoration: BoxDecoration(
          color: colors.accentOrange.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20.r),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "See All",
              style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w700, color: colors.accentOrange),
            ),
            SizedBox(width: 4.w),
            SvgPicture.asset(
              Assets.icons.navArrowRight,
              package: 'grab_go_shared',
              height: 12.h,
              width: 12.w,
              colorFilter: ColorFilter.mode(colors.accentOrange, BlendMode.srcIn),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStoriesRow(AppColorsExtension colors, StatusProvider provider) {
    if (provider.isLoadingStories) {
      return _buildStoriesShimmer(colors);
    }

    if (provider.error != null && provider.stories.isEmpty) {
      return _buildStoriesShimmer(colors);
    }

    if (provider.stories.isEmpty) {
      return _buildStoriesShimmer(colors);
    }

    return SizedBox(
      height: 110.h,
      child: ListView.separated(
        padding: EdgeInsets.symmetric(horizontal: 20.w),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: provider.stories.length,
        itemBuilder: (context, index) {
          final story = provider.stories[index];
          return _buildStoryItem(colors, story, provider, index);
        },
        separatorBuilder: (_, _) => SizedBox(width: 12.w),
      ),
    );
  }

  Widget _buildStoryItem(AppColorsExtension colors, StoryModel story, StatusProvider provider, int index) {
    final ringColor = story.isViewed ? colors.accentOrange.withAlpha(80) : colors.accentOrange;

    return GestureDetector(
      key: ValueKey(story.restaurantId),
      onTap: () => _openStoryViewer(story, provider, index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StoryRing(
            size: 80.r,
            segments: story.statusCount,
            color: ringColor,
            backgroundColor: colors.backgroundPrimary,
            child: story.logo != null
                ? CachedImageWidget(
                    imageUrl: story.logo!,
                    fit: BoxFit.cover,
                    placeholder: Container(
                      height: 20.h,
                      width: 20.w,
                      padding: EdgeInsets.all(20.r),
                      child: SvgPicture.asset(
                        Assets.icons.utensilsCrossed,
                        package: "grab_go_shared",
                        colorFilter: ColorFilter.mode(colors.textSecondary, BlendMode.srcIn),
                      ),
                    ),
                    errorWidget: Container(
                      height: 20.h,
                      width: 20.w,
                      padding: EdgeInsets.all(20.r),
                      child: SvgPicture.asset(
                        Assets.icons.utensilsCrossed,
                        package: "grab_go_shared",
                        colorFilter: ColorFilter.mode(colors.textSecondary, BlendMode.srcIn),
                      ),
                    ),
                  )
                : Icon(Icons.restaurant, color: colors.textSecondary, size: 32.r),
          ),
          SizedBox(height: 6.h),
          SizedBox(
            width: 74.w,
            child: Text(
              story.restaurantName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w500, color: colors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  void _openStoryViewer(StoryModel story, StatusProvider provider, int storyIndex) {
    provider.fetchRestaurantStatuses(story.restaurantId, context: context, forceRefresh: false);

    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (context, animation, secondaryAnimation) {
          return _StoryViewerPageView(initialIndex: storyIndex, stories: provider.stories, provider: provider);
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  Widget _buildCategoryTabs(AppColorsExtension colors) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: AnimatedTabBar(
        tabs: _filters.map((f) => f.label).toList(),
        selectedIndex: _selectedFilterIndex,
        onTabChanged: (index) {
          setState(() {
            _selectedFilterIndex = index;
          });
          context.read<StatusProvider>().setSelectedCategory(_filters[index].category);
        },
        height: 46.h,
        padding: EdgeInsets.zero,
      ),
    );
  }

  Widget _buildStatusesList(AppColorsExtension colors, StatusProvider provider, bool isDark) {
    if (provider.isLoadingStatuses) {
      return _buildStatusesShimmer(colors);
    }

    final filteredStatuses = provider.getFilteredStatuses(_filters[_selectedFilterIndex].category);

    if (filteredStatuses.isEmpty) {
      return _buildStatusesShimmer(colors);
    }

    return SizedBox(
      height: 350.h,
      child: ListView.builder(
        padding: EdgeInsets.only(left: 10.w),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: filteredStatuses.length,
        itemBuilder: (context, index) {
          final status = filteredStatuses[index];
          return StatusCardNew(
            status: status,
            isDark: isDark,
            onTap: () => _openStatusDetail(status),
            onLike: () => provider.toggleLike(status.id),
            isLiked: provider.isLiked(status.id),
          );
        },
      ),
    );
  }

  Widget _buildRecommendedRow(AppColorsExtension colors, List<StatusModel> statuses, bool isDark) {
    return SizedBox(
      height: 200.h,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 20.w),
        physics: const BouncingScrollPhysics(),
        itemCount: statuses.length,
        itemBuilder: (context, index) {
          final status = statuses[index];
          return _buildRecommendedCard(colors, status);
        },
        separatorBuilder: (_, _) => SizedBox(width: 12.w),
      ),
    );
  }

  Widget _buildRecommendedCard(AppColorsExtension colors, StatusModel status) {
    final badgeColor = status.category.getColor(context);

    return GestureDetector(
      onTap: () => _openStatusDetail(status),
      child: Container(
        width: 220.w,
        padding: EdgeInsets.all(1.r),
        decoration: BoxDecoration(
          color: colors.backgroundPrimary,
          borderRadius: BorderRadius.circular(KBorderSize.borderRadius15),
          border: Border.all(color: colors.inputBorder.withValues(alpha: 0.3)),
          boxShadow: [BoxShadow(color: Colors.black.withAlpha(8), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(KBorderSize.borderRadius15),
                topRight: Radius.circular(KBorderSize.borderRadius15),
              ),
              child: CachedImageWidget(
                imageUrl: status.mediaUrl,
                height: 90.h,
                width: double.infinity,
                fit: BoxFit.cover,
                placeholder: Container(
                  height: 90.h,
                  width: double.infinity,
                  color: colors.inputBorder,
                  padding: EdgeInsets.all(20.r),
                  child: SvgPicture.asset(
                    Assets.icons.chefHat,
                    package: "grab_go_shared",
                    height: 20.h,
                    width: 20.w,
                    colorFilter: ColorFilter.mode(colors.textSecondary, BlendMode.srcIn),
                  ),
                ),
                errorWidget: Container(
                  height: 90.h,
                  width: double.infinity,
                  color: colors.inputBorder,
                  padding: EdgeInsets.all(20.r),
                  child: SvgPicture.asset(
                    Assets.icons.chefHat,
                    package: "grab_go_shared",
                    height: 20.h,
                    width: 20.w,
                    colorFilter: ColorFilter.mode(colors.textSecondary, BlendMode.srcIn),
                  ),
                ),
              ),
            ),

            Padding(
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                    decoration: BoxDecoration(
                      color: badgeColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20.r),
                    ),
                    child: Text(
                      status.category.label,
                      style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w600, color: badgeColor),
                    ),
                  ),
                  SizedBox(height: 6.h),
                  Text(
                    status.restaurant.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700, color: colors.textPrimary),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    status.timeAgo,
                    style: TextStyle(fontSize: 11.sp, color: colors.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openStatusDetail(StatusModel status) {
    // Record view
    context.read<StatusProvider>().recordView(status.id);

    // Navigate to detail or show bottom sheet
    // TODO: Implement status detail view
  }

  String _getSectionTitle() {
    final category = _filters[_selectedFilterIndex].category;
    if (category == null) return "Latest From Restaurants";
    return category.label;
  }

  String _getSectionIcon() {
    final category = _filters[_selectedFilterIndex].category;
    switch (category) {
      case StatusCategory.dailySpecial:
        return Assets.icons.flame;
      case StatusCategory.discount:
        return Assets.icons.percentageCircle;
      case StatusCategory.newItem:
        return Assets.icons.fireFlame;
      case StatusCategory.video:
        return Assets.icons.play;
      default:
        return Assets.icons.utensilsCrossed;
    }
  }

  Color _getSectionColor(AppColorsExtension colors) {
    final category = _filters[_selectedFilterIndex].category;
    if (category == null) return colors.accentViolet;
    return category.getColor(context);
  }

  Widget _buildStoriesShimmer(AppColorsExtension colors) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      height: 110.h,
      child: ListView.separated(
        padding: EdgeInsets.symmetric(horizontal: 20.w),
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 5,
        itemBuilder: (context, index) {
          return Shimmer.fromColors(
            baseColor: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
            highlightColor: isDark ? Colors.grey.shade700 : Colors.grey.shade100,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80.r,
                  height: 80.r,
                  decoration: BoxDecoration(color: colors.backgroundPrimary, shape: BoxShape.circle),
                ),
                SizedBox(height: 6.h),
                Container(
                  width: 60.w,
                  height: 12.h,
                  decoration: BoxDecoration(color: colors.backgroundPrimary, borderRadius: BorderRadius.circular(4.r)),
                ),
              ],
            ),
          );
        },
        separatorBuilder: (_, _) => SizedBox(width: 12.w),
      ),
    );
  }

  /// Shimmer loading for statuses list
  Widget _buildStatusesShimmer(AppColorsExtension colors) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      height: 350.h,
      child: ListView.builder(
        padding: EdgeInsets.only(left: 20.w),
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 3,
        itemBuilder: (context, index) {
          return Shimmer.fromColors(
            baseColor: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
            highlightColor: isDark ? Colors.grey.shade700 : Colors.grey.shade100,
            child: Container(
              width: 260.w,
              margin: EdgeInsets.only(right: 16.w),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(KBorderSize.borderMedium),
                border: Border.all(color: isDark ? Colors.grey.shade800 : Colors.grey.shade300, width: 0.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Image placeholder
                  Container(
                    height: 200.h,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey.shade700 : Colors.grey.shade200,
                      borderRadius: BorderRadius.only(topLeft: Radius.circular(20.r), topRight: Radius.circular(20.r)),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.all(16.r),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Category badge placeholder
                        Container(
                          width: 80.w,
                          height: 24.h,
                          decoration: BoxDecoration(
                            color: isDark ? Colors.grey.shade700 : Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                        ),
                        SizedBox(height: 12.h),
                        // Title placeholder
                        Container(
                          width: 180.w,
                          height: 16.h,
                          decoration: BoxDecoration(
                            color: isDark ? Colors.grey.shade700 : Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(4.r),
                          ),
                        ),
                        SizedBox(height: 8.h),
                        // Subtitle placeholder
                        Container(
                          width: 120.w,
                          height: 12.h,
                          decoration: BoxDecoration(
                            color: isDark ? Colors.grey.shade700 : Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(4.r),
                          ),
                        ),
                        SizedBox(height: 16.h),
                        // Bottom row placeholder
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              width: 60.w,
                              height: 12.h,
                              decoration: BoxDecoration(
                                color: isDark ? Colors.grey.shade700 : Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(4.r),
                              ),
                            ),
                            Container(
                              width: 40.w,
                              height: 24.h,
                              decoration: BoxDecoration(
                                color: isDark ? Colors.grey.shade700 : Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(12.r),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _StatusFilter {
  final String label;
  final StatusCategory? category;

  _StatusFilter({required this.label, required this.category});
}

/// Story ring widget with segmented border
class _StoryRing extends StatelessWidget {
  final double size;
  final int segments;
  final Color color;
  final Color backgroundColor;
  final Widget child;

  const _StoryRing({
    required this.size,
    required this.segments,
    required this.color,
    required this.backgroundColor,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size.square(size),
            painter: _SegmentedCirclePainter(segments: segments, color: color, strokeWidth: 2.4, gapDegrees: 14),
          ),
          Container(
            width: size - 8.r,
            height: size - 8.r,
            decoration: BoxDecoration(color: backgroundColor, shape: BoxShape.circle),
            child: ClipOval(child: child),
          ),
        ],
      ),
    );
  }
}

class _SegmentedCirclePainter extends CustomPainter {
  final int segments;
  final Color color;
  final double strokeWidth;
  final double gapDegrees;

  _SegmentedCirclePainter({
    required this.segments,
    required this.color,
    required this.strokeWidth,
    required this.gapDegrees,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    if (segments <= 1) {
      canvas.drawCircle(center, radius, paint);
      return;
    }

    final gapRadians = gapDegrees * (math.pi / 180);
    final totalGap = gapRadians * segments;
    final availableAngle = (2 * math.pi) - totalGap;
    final segmentAngle = availableAngle / segments;

    double startAngle = -math.pi / 2; // Start from top

    for (int i = 0; i < segments; i++) {
      canvas.drawArc(Rect.fromCircle(center: center, radius: radius), startAngle, segmentAngle, false, paint);
      startAngle += segmentAngle + gapRadians;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// PageView wrapper for smooth horizontal swiping between restaurant stories
class _StoryViewerPageView extends StatefulWidget {
  final int initialIndex;
  final List<StoryModel> stories;
  final StatusProvider provider;

  const _StoryViewerPageView({required this.initialIndex, required this.stories, required this.provider});

  @override
  State<_StoryViewerPageView> createState() => _StoryViewerPageViewState();
}

class _StoryViewerPageViewState extends State<_StoryViewerPageView> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    if (index != _currentIndex) {
      setState(() {
        _currentIndex = index;
      });
      // Fetch statuses for the new restaurant
      widget.provider.fetchRestaurantStatuses(
        widget.stories[index].restaurantId,
        context: context,
        forceRefresh: false,
      );
    }
  }

  void _goToNextRestaurant() {
    if (_currentIndex < widget.stories.length - 1) {
      _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    } else {
      Navigator.of(context).pop();
    }
  }

  void _goToPreviousRestaurant() {
    if (_currentIndex > 0) {
      _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      controller: _pageController,
      onPageChanged: _onPageChanged,
      itemCount: widget.stories.length,
      physics: const ClampingScrollPhysics(),
      itemBuilder: (context, index) {
        final story = widget.stories[index];
        return StoryViewer(
          key: ValueKey(story.restaurantId),
          restaurantId: story.restaurantId,
          restaurantName: story.restaurantName,
          restaurantLogo: story.logo,
          initialBlurHash: story.latestBlurHash,
          onNextRestaurant: index < widget.stories.length - 1 ? _goToNextRestaurant : null,
          onPreviousRestaurant: index > 0 ? _goToPreviousRestaurant : null,
        );
      },
    );
  }
}
