import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_customer/features/order/model/item_review_models.dart';
import 'package:grab_go_customer/features/order/service/item_review_service_wrapper.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/shared/utils/app_colors_extension.dart';
import 'package:intl/intl.dart';

class ItemReviewsPage extends StatefulWidget {
  const ItemReviewsPage({
    super.key,
    required this.itemId,
    required this.itemType,
    required this.itemName,
    this.initialRating = 4.0,
    this.initialReviewCount = 0,
  });

  final String itemId;
  final String itemType;
  final String itemName;
  final double initialRating;
  final int initialReviewCount;

  @override
  State<ItemReviewsPage> createState() => _ItemReviewsPageState();
}

class _ItemReviewsPageState extends State<ItemReviewsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ItemReviewServiceWrapper _reviewService = ItemReviewServiceWrapper();

  ItemReviewFeed? _feed;
  bool _isLoading = false;
  String? _error;
  String _activeSort = 'popular';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabChange);
    _loadReviews();
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    super.dispose();
  }

  void _handleTabChange() {
    if (_tabController.indexIsChanging) return;
    final nextSort = _tabController.index == 0 ? 'popular' : 'latest';
    if (nextSort == _activeSort) return;
    _loadReviews(sort: nextSort, showLoader: _feed == null);
  }

  Future<void> _loadReviews({
    String sort = 'popular',
    bool showLoader = true,
  }) async {
    if (_isLoading) return;

    setState(() {
      _activeSort = sort;
      _isLoading = true;
      if (showLoader) {
        _error = null;
      }
    });

    try {
      final feed = await _reviewService.getItemReviews(
        itemType: widget.itemType,
        itemId: widget.itemId,
        sort: sort,
      );
      if (!mounted) return;
      setState(() {
        _feed = feed;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e
            .toString()
            .replaceFirst('Exception: ', '')
            .replaceFirst('Failed to load item reviews: ', '');
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final padding = MediaQuery.of(context).padding;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final feed = _feed;
    final itemSnapshot = feed?.item;
    final displayRating = itemSnapshot?.rating ?? widget.initialRating;
    final displayReviewCount =
        itemSnapshot?.totalReviews ?? widget.initialReviewCount;

    final systemUiOverlayStyle = SystemUiOverlayStyle(
      statusBarColor: colors.backgroundPrimary,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      systemNavigationBarColor: colors.backgroundPrimary,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarIconBrightness: isDark
          ? Brightness.light
          : Brightness.dark,
    );

    SystemChrome.setSystemUIOverlayStyle(systemUiOverlayStyle);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: systemUiOverlayStyle,
      child: Scaffold(
        backgroundColor: colors.backgroundPrimary,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.only(
                top: padding.top + 10,
                left: 20.w,
                right: 20.w,
                bottom: 16.h,
              ),
              child: Row(
                children: [
                  Container(
                    height: 44,
                    width: 44,
                    decoration: BoxDecoration(
                      color: colors.backgroundSecondary,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: colors.inputBorder.withValues(alpha: 0.3),
                        width: 0.5,
                      ),
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
                            colorFilter: ColorFilter.mode(
                              colors.textPrimary,
                              BlendMode.srcIn,
                            ),
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
                          "Reviews",
                          style: TextStyle(
                            fontFamily: "Lato",
                            package: 'grab_go_shared',
                            color: colors.textPrimary,
                            fontSize: 20.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          widget.itemName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colors.textSecondary,
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(20.w, 0.h, 20.w, 8.h),
              child: Row(
                children: [
                  Row(
                    children: List.generate(
                      5,
                      (index) => Padding(
                        padding: EdgeInsets.only(right: 2.w),
                        child: SvgPicture.asset(
                          Assets.icons.starSolid,
                          package: 'grab_go_shared',
                          height: 24.h,
                          width: 24.w,
                          colorFilter: ColorFilter.mode(
                            colors.accentOrange,
                            BlendMode.srcIn,
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Text(
                    displayRating.toStringAsFixed(1),
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 24.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.w),
              child: Text(
                displayReviewCount > 0
                    ? 'Based on $displayReviewCount ${displayReviewCount == 1 ? 'review' : 'reviews'}'
                    : 'No reviews yet',
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
            if (feed != null && feed.breakdown.isNotEmpty) ...[
              SizedBox(height: 14.h),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.w),
                child: Column(
                  children: List.generate(5, (index) {
                    final rating = 5 - index;
                    final count = feed.breakdown[rating] ?? 0;
                    final total = feed.item.totalReviews <= 0
                        ? 1
                        : feed.item.totalReviews;
                    final fraction = count / total;

                    return Padding(
                      padding: EdgeInsets.only(bottom: 6.h),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 18.w,
                            child: Text(
                              '$rating',
                              style: TextStyle(
                                color: colors.textSecondary,
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          SizedBox(width: 8.w),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(999.r),
                              child: LinearProgressIndicator(
                                value: fraction.clamp(0.0, 1.0),
                                minHeight: 6.h,
                                backgroundColor: colors.backgroundSecondary,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  colors.accentOrange,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 8.w),
                          SizedBox(
                            width: 24.w,
                            child: Text(
                              '$count',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                color: colors.textSecondary,
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
              ),
            ],
            SizedBox(height: 16.h),
            Container(
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: colors.inputBorder.withValues(alpha: 0.5),
                    width: 1,
                  ),
                ),
              ),
              child: TabBar(
                controller: _tabController,
                labelColor: colors.accentOrange,
                unselectedLabelColor: colors.textSecondary,
                labelStyle: TextStyle(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Lato',
                  package: 'grab_go_shared',
                ),
                unselectedLabelStyle: TextStyle(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Lato',
                  package: 'grab_go_shared',
                ),
                indicatorColor: colors.accentOrange,
                indicatorWeight: 3,
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                splashFactory: NoSplash.splashFactory,
                overlayColor: WidgetStateProperty.all(Colors.transparent),
                tabs: const [
                  Tab(text: 'Popular'),
                  Tab(text: 'Latest'),
                ],
              ),
            ),
            Expanded(child: _buildBody(colors)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(AppColorsExtension colors) {
    if (_isLoading && _feed == null) {
      return ListView.separated(
        padding: EdgeInsets.symmetric(vertical: 16.h),
        itemCount: 6,
        separatorBuilder: (context, index) => Divider(
          color: colors.backgroundSecondary,
          height: 1,
          thickness: 1,
          indent: 20,
          endIndent: 20,
        ),
        itemBuilder: (context, index) => Padding(
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 14.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 130.w,
                height: 14.h,
                decoration: BoxDecoration(
                  color: colors.backgroundSecondary,
                  borderRadius: BorderRadius.circular(999.r),
                ),
              ),
              SizedBox(height: 10.h),
              Container(
                width: double.infinity,
                height: 12.h,
                decoration: BoxDecoration(
                  color: colors.backgroundSecondary,
                  borderRadius: BorderRadius.circular(999.r),
                ),
              ),
              SizedBox(height: 6.h),
              Container(
                width: 0.65.sw,
                height: 12.h,
                decoration: BoxDecoration(
                  color: colors.backgroundSecondary,
                  borderRadius: BorderRadius.circular(999.r),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_error != null && _feed == null) {
      return Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24.w),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 16.h),
              TextButton(
                onPressed: () => _loadReviews(sort: _activeSort),
                child: Text(
                  'Retry',
                  style: TextStyle(
                    color: colors.accentOrange,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final feed = _feed;
    if (feed == null || feed.reviews.isEmpty) {
      return Center(
        child: Text(
          'No comments yet for this item.',
          style: TextStyle(
            color: colors.textSecondary,
            fontSize: 15.sp,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadReviews(sort: _activeSort, showLoader: false),
      child: ListView.separated(
        padding: EdgeInsets.symmetric(vertical: 10.h),
        itemCount: feed.reviews.length,
        separatorBuilder: (context, index) => Divider(
          color: colors.backgroundSecondary,
          height: 1,
          thickness: 1,
          indent: 20,
          endIndent: 20,
        ),
        itemBuilder: (context, index) {
          final review = feed.reviews[index];
          return _buildReviewCard(colors, review);
        },
      ),
    );
  }

  Widget _buildReviewCard(AppColorsExtension colors, ItemReviewEntry review) {
    final createdAt = review.createdAt;
    final subtitle = createdAt == null
        ? review.reviewer.name
        : '${review.reviewer.name} • ${DateFormat('MMM d, yyyy').format(createdAt.toLocal())}';

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 14.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAvatar(colors, review.reviewer),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 6.h),
                    Row(
                      children: List.generate(
                        5,
                        (index) => Padding(
                          padding: EdgeInsets.only(right: 2.w),
                          child: SvgPicture.asset(
                            index < review.rating
                                ? Assets.icons.starSolid
                                : Assets.icons.star,
                            package: 'grab_go_shared',
                            height: 14.h,
                            width: 14.w,
                            colorFilter: ColorFilter.mode(
                              index < review.rating
                                  ? colors.accentOrange
                                  : colors.divider,
                              BlendMode.srcIn,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (review.comment != null && review.comment!.trim().isNotEmpty) ...[
            SizedBox(height: 12.h),
            Text(
              review.comment!.trim(),
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 14.sp,
                fontWeight: FontWeight.w400,
                height: 1.45,
              ),
            ),
          ],
          if (review.feedbackTags.isNotEmpty) ...[
            SizedBox(height: 12.h),
            Wrap(
              spacing: 8.w,
              runSpacing: 8.h,
              children: review.feedbackTags
                  .map((tag) {
                    return Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 10.w,
                        vertical: 6.h,
                      ),
                      decoration: BoxDecoration(
                        color: colors.backgroundSecondary,
                        borderRadius: BorderRadius.circular(999.r),
                      ),
                      child: Text(
                        tag,
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  })
                  .toList(growable: false),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAvatar(AppColorsExtension colors, ItemReviewReviewer reviewer) {
    final imageUrl = reviewer.profilePicture?.trim();
    if (imageUrl != null && imageUrl.isNotEmpty) {
      return ClipOval(
        child: CachedNetworkImage(
          imageUrl: imageUrl,
          width: 40.w,
          height: 40.w,
          fit: BoxFit.cover,
          errorWidget: (context, url, error) => _buildAvatarFallback(colors),
        ),
      );
    }
    return _buildAvatarFallback(colors);
  }

  Widget _buildAvatarFallback(AppColorsExtension colors) {
    return Container(
      width: 40.w,
      height: 40.w,
      decoration: BoxDecoration(
        color: colors.backgroundSecondary,
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.person_outline,
        size: 20.sp,
        color: colors.textSecondary,
      ),
    );
  }
}
