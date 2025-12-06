import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:grab_go_customer/features/status/model/status_model.dart';
import 'package:grab_go_customer/features/status/viewmodel/status_provider.dart';
import 'package:grab_go_customer/features/status/view/story_viewer.dart';

/// All Statuses Page with virtualized grid and lazy image loading
class AllStatusesPage extends StatefulWidget {
  final StatusCategory? initialCategory;

  const AllStatusesPage({super.key, this.initialCategory});

  @override
  State<AllStatusesPage> createState() => _AllStatusesPageState();
}

class _AllStatusesPageState extends State<AllStatusesPage> {
  late ScrollController _scrollController;
  late StatusProvider _provider;
  int _selectedTabIndex = 0;

  // Category mapping for tabs
  final List<StatusCategory?> _categories = [
    null, // All
    StatusCategory.dailySpecial,
    StatusCategory.discount,
    StatusCategory.newItem,
    StatusCategory.video,
  ];

  final List<String> _tabLabels = ['All', 'Special', 'Discount', 'New', 'Video'];

  // Cache for filtered statuses to avoid rebuilding on every build
  List<StatusModel>? _cachedFilteredStatuses;
  StatusCategory? _lastFilterCategory;
  int _lastStatusesLength = 0;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _provider = context.read<StatusProvider>();

    // Set initial tab based on passed category
    if (widget.initialCategory != null) {
      final index = _categories.indexOf(widget.initialCategory);
      if (index != -1) _selectedTabIndex = index;
    }

    // Add scroll listener for pagination
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _cachedFilteredStatuses = null; // Clear cache
    super.dispose();
  }

  void _onScroll() {
    // Use cached provider reference instead of context.read on every scroll
    // Load more when near bottom
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - KStatusConstants.paginationThreshold) {
      if (!_provider.isLoadingMore && _provider.hasMore) {
        _provider.loadMoreStatuses();
      }
    }
  }

  StatusCategory? get _selectedCategory => _categories[_selectedTabIndex];

  List<StatusModel> _getFilteredStatuses(StatusProvider provider) {
    // Check if we can use cached results
    final currentStatusesLength = provider.statuses.length;
    final hasStatusesChanged = currentStatusesLength != _lastStatusesLength;
    final hasCategoryChanged = _selectedCategory != _lastFilterCategory;

    // Rebuild cache if category changed or statuses list changed
    if (_cachedFilteredStatuses == null || hasCategoryChanged || hasStatusesChanged) {
      _lastFilterCategory = _selectedCategory;
      _lastStatusesLength = currentStatusesLength;

      if (_selectedCategory == null) {
        _cachedFilteredStatuses = provider.statuses;
      } else {
        _cachedFilteredStatuses = provider.statuses.where((s) => s.category == _selectedCategory).toList();
      }
    }

    return _cachedFilteredStatuses!;
  }

  void _openStatus(StatusModel status) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => StoryViewer(
          restaurantId: status.restaurant.id,
          restaurantName: status.restaurant.name,
          restaurantLogo: status.restaurant.logo,
          initialBlurHash: status.blurHash,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: colors.backgroundSecondary,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          systemNavigationBarColor: colors.backgroundPrimary,
          systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAppBar(colors),
              _buildPageTitle(colors),
              _buildCategoryFilter(colors),
              SizedBox(height: 10.h),
              Expanded(
                child: Consumer<StatusProvider>(
                  builder: (context, provider, _) {
                    final statuses = _getFilteredStatuses(provider);

                    if (provider.isLoadingStatuses && statuses.isEmpty) {
                      return _buildLoadingGrid(colors);
                    }

                    if (statuses.isEmpty) {
                      return _buildLoadingGrid(colors);
                    }

                    return RefreshIndicator(
                      onRefresh: () => provider.refreshStatuses(),
                      color: colors.accentOrange,
                      child: _buildStatusGrid(colors, statuses, provider, isDark),
                    );
                  },
                ),
              ),
            ],
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
              padding: EdgeInsets.all(16.r),
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

  Widget _buildPageTitle(AppColorsExtension colors) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
      child: Text(
        "All Statuses",
        textAlign: TextAlign.start,
        style: TextStyle(color: colors.textPrimary, fontSize: 20.sp, fontWeight: FontWeight.w800),
      ),
    );
  }

  Widget _buildCategoryFilter(AppColorsExtension colors) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: AnimatedTabBar(
        tabs: _tabLabels,
        selectedIndex: _selectedTabIndex,
        onTabChanged: (index) {
          setState(() => _selectedTabIndex = index);
        },
        height: 46.h,
        padding: EdgeInsets.zero,
      ),
    );
  }

  Widget _buildStatusGrid(AppColorsExtension colors, List<StatusModel> statuses, StatusProvider provider, bool isDark) {
    final itemCount = statuses.length + (provider.isLoadingMore ? 2 : 0);

    return MasonryGridView.count(
      controller: _scrollController,
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      crossAxisCount: 2,
      mainAxisSpacing: 12.h,
      crossAxisSpacing: 12.w,
      itemCount: itemCount,
      itemBuilder: (context, index) {
        // Show loading indicators at the end
        if (index >= statuses.length) {
          return _buildLoadingCard(colors);
        }

        // Safety check to prevent crashes from race conditions
        if (index >= statuses.length) {
          return _buildLoadingCard(colors);
        }

        final status = statuses[index];

        // Vary heights for staggered effect based on content
        final isVideo = status.isVideo;
        final hasDiscount = status.discountPercentage != null && status.discountPercentage! > 0;

        return _StatusGridCard(
          key: ValueKey(status.id),
          status: status,
          index: index,
          colors: colors,
          isDark: isDark,
          isLiked: provider.isLiked(status.id),
          heightFactor: _getHeightFactor(index, isVideo, hasDiscount),
          onTap: () => _openStatus(status),
          onLike: () => provider.toggleLike(status.id),
        );
      },
    );
  }

  /// Calculate height factor for staggered effect
  double _getHeightFactor(int index, bool isVideo, bool hasDiscount) {
    // Videos get taller cards
    if (isVideo) return 1.3;
    // Discounts get slightly taller
    if (hasDiscount) return 1.15;
    // Alternate between normal and slightly shorter for variety
    return index % 3 == 0 ? 1.0 : (index % 3 == 1 ? 1.1 : 0.95);
  }

  Widget _buildLoadingCard(AppColorsExtension colors) {
    return Container(
      height: 200.h,
      decoration: BoxDecoration(
        color: colors.inputBorder.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Center(
        child: SizedBox(
          width: 24.w,
          height: 24.h,
          child: CircularProgressIndicator(strokeWidth: 2, color: colors.accentOrange),
        ),
      ),
    );
  }

  Widget _buildLoadingGrid(AppColorsExtension colors) {
    return MasonryGridView.count(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      crossAxisCount: 2,
      mainAxisSpacing: 12.h,
      crossAxisSpacing: 12.w,
      itemCount: 6,
      itemBuilder: (context, index) => _buildShimmerCard(colors, index),
    );
  }

  Widget _buildShimmerCard(AppColorsExtension colors, int index) {
    // Vary shimmer heights to match staggered effect
    final heightFactor = index % 3 == 0 ? 1.0 : (index % 3 == 1 ? 1.15 : 0.9);
    final imageHeight = (160 * heightFactor).h;

    return Container(
      decoration: BoxDecoration(
        color: colors.inputBorder.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: imageHeight,
            width: double.infinity,
            decoration: BoxDecoration(
              color: colors.inputBorder.withValues(alpha: 0.2),
              borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(12.r),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 12.h,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: colors.inputBorder.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(4.r),
                  ),
                ),
                SizedBox(height: 8.h),
                Container(
                  height: 10.h,
                  width: 80.w,
                  decoration: BoxDecoration(
                    color: colors.inputBorder.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4.r),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Individual status card with image caching
class _StatusGridCard extends StatefulWidget {
  final StatusModel status;
  final int index;
  final AppColorsExtension colors;
  final bool isDark;
  final bool isLiked;
  final double heightFactor;
  final VoidCallback onTap;
  final VoidCallback onLike;

  const _StatusGridCard({
    super.key,
    required this.status,
    required this.index,
    required this.colors,
    required this.isDark,
    required this.isLiked,
    this.heightFactor = 1.0,
    required this.onTap,
    required this.onLike,
  });

  @override
  State<_StatusGridCard> createState() => _StatusGridCardState();
}

class _StatusGridCardState extends State<_StatusGridCard> with AutomaticKeepAliveClientMixin {
  bool _imageLoaded = false;

  @override
  bool get wantKeepAlive => _imageLoaded; // Keep alive once image is loaded

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin

    final categoryColor = widget.status.category.getColor(context);
    // Base image height, modified by heightFactor for staggered effect
    final imageHeight = (160 * widget.heightFactor).h;

    return GestureDetector(
      onTap: widget.onTap,
      onDoubleTap: widget.onLike,
      child: Container(
        decoration: BoxDecoration(
          color: widget.colors.backgroundPrimary,
          borderRadius: BorderRadius.circular(16.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: widget.isDark ? 0.3 : 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image section - always load, keep alive preserves state
            SizedBox(
              height: imageHeight,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
                    child: CachedNetworkImage(
                      imageUrl: widget.status.mediaUrl,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => _buildPlaceholder(),
                      errorWidget: (context, url, error) => _buildPlaceholder(),
                      imageBuilder: (context, imageProvider) {
                        // Mark as loaded to trigger keep alive
                        if (!_imageLoaded) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted) {
                              setState(() => _imageLoaded = true);
                              updateKeepAlive(); // Update keep alive status
                            }
                          });
                        }
                        return Image(image: imageProvider, fit: BoxFit.cover);
                      },
                    ),
                  ),
                  // Category badge
                  Positioned(
                    top: 8.h,
                    left: 8.w,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                      decoration: BoxDecoration(
                        color: categoryColor.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      child: Text(
                        widget.status.category.label,
                        style: TextStyle(fontSize: 10.sp, fontWeight: FontWeight.w600, color: Colors.white),
                      ),
                    ),
                  ),
                  // Like button
                  Positioned(
                    top: 8.h,
                    right: 8.w,
                    child: GestureDetector(
                      onTap: widget.onLike,
                      child: Container(
                        padding: EdgeInsets.all(6.r),
                        decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.4), shape: BoxShape.circle),
                        child: SvgPicture.asset(
                          widget.isLiked ? Assets.icons.heartSolid : Assets.icons.heart,
                          package: 'grab_go_shared',
                          height: 16.h,
                          width: 16.w,
                          colorFilter: ColorFilter.mode(widget.isLiked ? Colors.red : Colors.white, BlendMode.srcIn),
                        ),
                      ),
                    ),
                  ),
                  // Video indicator
                  if (widget.status.isVideo)
                    Positioned(
                      bottom: 8.h,
                      right: 8.w,
                      child: Container(
                        padding: EdgeInsets.all(4.r),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(4.r),
                        ),
                        child: SvgPicture.asset(
                          Assets.icons.play,
                          package: 'grab_go_shared',
                          height: 12.h,
                          width: 12.w,
                          colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Info section - fixed height
            Padding(
              padding: EdgeInsets.all(10.r),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.status.restaurant.name,
                    style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600, color: widget.colors.textPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 4.h),
                  Row(
                    children: [
                      SvgPicture.asset(
                        Assets.icons.heart,
                        package: 'grab_go_shared',
                        height: 12.h,
                        width: 12.w,
                        colorFilter: ColorFilter.mode(widget.colors.textSecondary, BlendMode.srcIn),
                      ),
                      SizedBox(width: 4.w),
                      Text(
                        '${widget.status.likeCount}',
                        style: TextStyle(fontSize: 11.sp, color: widget.colors.textSecondary),
                      ),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: Text(
                          widget.status.timeAgo,
                          style: TextStyle(fontSize: 11.sp, color: widget.colors.textSecondary),
                          overflow: TextOverflow.ellipsis,
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
  }

  Widget _buildPlaceholder() {
    return Container(
      color: widget.colors.inputBorder.withValues(alpha: 0.2),
      child: Center(
        child: SvgPicture.asset(
          Assets.icons.mediaImage,
          package: 'grab_go_shared',
          height: 32.h,
          width: 32.w,
          colorFilter: ColorFilter.mode(widget.colors.textSecondary.withValues(alpha: 0.3), BlendMode.srcIn),
        ),
      ),
    );
  }
}
