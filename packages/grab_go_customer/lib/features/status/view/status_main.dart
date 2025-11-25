import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_customer/features/status/model/status.dart';
import 'package:grab_go_customer/features/status/model/status_posts.dart';
import 'package:grab_go_customer/shared/utils/constants.dart';
import 'package:grab_go_customer/shared/widgets/status_card.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:grab_go_shared/shared/widgets/animated_tab_bar.dart';

class StatusMain extends StatefulWidget {
  const StatusMain({super.key});

  @override
  State<StatusMain> createState() => _StatusMainState();
}

class _StatusMainState extends State<StatusMain> {
  StatusCategory? _selectedCategory;
  int _selectedFilterIndex = 0;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final filteredPosts = demoStatusPosts
        .where((post) => _selectedCategory == null || post.category == _selectedCategory)
        .toList();

    final recommendedPosts = demoStatusPosts.where((post) => post.isRecommended).toList();

    final headerTitle = feedSectionTitle(_selectedCategory);
    final headerIconAsset = feedSectionIconAsset(_selectedCategory);
    final headerIconColor = feedSectionIconColor(_selectedCategory, colors);

    return Scaffold(
      backgroundColor: colors.backgroundSecondary,
      appBar: AppBar(
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
              onTap: () {
                context.pop();
              },
              customBorder: const CircleBorder(),
              splashColor: colors.iconSecondary.withAlpha(50),
              child: Padding(
                padding: EdgeInsets.all(KSpacing.md12.r),
                child: SvgPicture.asset(
                  Assets.icons.navArrowLeft,
                  package: 'grab_go_shared',
                  colorFilter: ColorFilter.mode(colors.iconPrimary, BlendMode.srcIn),
                ),
              ),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.only(bottom: 24.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
                child: Row(
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
                            "Status & updates",
                            style: TextStyle(color: colors.textPrimary, fontSize: 20.sp, fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.w),
                child: Text(
                  "See what's cooking right now from your favourite restaurants.",
                  style: TextStyle(fontSize: 13.sp, color: colors.textSecondary, height: 1.4),
                ),
              ),
              SizedBox(height: KSpacing.lg.h),
              _buildCategoryHeader(colors, "New From Restaurant", Assets.icons.flame, colors.accentViolet),
              SizedBox(height: KSpacing.lg.h),
              _buildStoriesRow(colors),
              SizedBox(height: KSpacing.lg.h),
              _buildCategoryTabs(colors),
              SizedBox(height: KSpacing.lg.h),
              _buildCategoryHeader(colors, headerTitle, headerIconAsset, headerIconColor),
              SizedBox(height: 12.h),
              if (filteredPosts.isNotEmpty)
                SizedBox(
                  height: 350.h,
                  child: ListView.builder(
                    padding: EdgeInsets.only(left: 10.r),
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    itemCount: filteredPosts.length,
                    itemBuilder: (context, index) {
                      final post = filteredPosts[index];
                      return StatusCard(post: post, isDark: isDark);
                    },
                  ),
                ),
              if (recommendedPosts.isNotEmpty) ...[
                SizedBox(height: 24.h),
                _buildCategoryHeader(colors, "Recommended For You", Assets.icons.flame, colors.accentViolet),
                SizedBox(height: 12.h),
                _buildRecommendedRow(colors, recommendedPosts),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Padding _buildCategoryHeader(AppColorsExtension colors, String title, String icon, Color iconColor) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
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
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
            decoration: BoxDecoration(
              color: colors.accentOrange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20.r),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {},
                borderRadius: BorderRadius.circular(20.r),
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
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStoriesRow(AppColorsExtension colors) {
    return SizedBox(
      height: 110.h,
      child: ListView.separated(
        padding: EdgeInsets.symmetric(horizontal: 20.w),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemBuilder: (context, index) {
          final story = demoStories[index];
          final ringColor = story.isViewed ? colors.accentOrange.withAlpha(80) : colors.accentOrange;

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              StoryRing(
                size: 80.r,
                segments: story.statusCount,
                color: ringColor,
                backgroundColor: colors.backgroundPrimary,
                child: story.logo.image(fit: BoxFit.cover, package: 'grab_go_shared'),
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
          );
        },
        separatorBuilder: (_, _) => SizedBox(width: 12.w),
        itemCount: demoStories.length,
      ),
    );
  }

  Widget _buildCategoryTabs(AppColorsExtension colors) {
    final filters = [
      _StatusFilter(label: 'All', category: null),
      _StatusFilter(label: 'Specials', category: StatusCategory.dailySpecial),
      _StatusFilter(label: 'Discounts', category: StatusCategory.discount),
      _StatusFilter(label: 'Updates', category: StatusCategory.newItem),
      _StatusFilter(label: 'Videos', category: StatusCategory.video),
    ];

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: AnimatedTabBar(
        tabs: filters.map((f) => f.label).toList(),
        selectedIndex: _selectedFilterIndex,
        onTabChanged: (index) {
          setState(() {
            _selectedFilterIndex = index;
            _selectedCategory = filters[index].category;
          });
        },
        height: 46.h,
        padding: EdgeInsets.zero,
      ),
    );
  }

  Widget _buildRecommendedRow(AppColorsExtension colors, List<StatusPost> posts) {
    return SizedBox(
      height: 200.h,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 20.w),
        physics: const BouncingScrollPhysics(),
        itemBuilder: (context, index) {
          final post = posts[index];
          final badgeColor = categoryColor(post.category, colors);

          return Container(
            width: 220.w,
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
                  child: post.coverImage.image(
                    height: 90.h,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    package: 'grab_go_shared',
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
                          categoryLabel(post.category),
                          style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w600, color: badgeColor),
                        ),
                      ),
                      SizedBox(height: 6.h),
                      Text(
                        post.restaurantName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700, color: colors.textPrimary),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        post.timeAgo,
                        style: TextStyle(fontSize: 11.sp, color: colors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
        separatorBuilder: (_, __) => SizedBox(width: 12.w),
        itemCount: posts.length,
      ),
    );
  }
}

class _StatusFilter {
  final String label;
  final StatusCategory? category;

  _StatusFilter({required this.label, required this.category});
}
