import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_customer/features/order/model/vendor_review_models.dart';
import 'package:grab_go_customer/features/order/service/vendor_review_service_wrapper.dart';
import 'package:grab_go_customer/shared/services/auth_guard.dart';
import 'package:grab_go_customer/shared/widgets/fractional_star_rating.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:intl/intl.dart';

class _ReviewReportOption {
  const _ReviewReportOption({required this.value, required this.label});

  final String value;
  final String label;
}

class VendorReviewsPage extends StatefulWidget {
  static const routePath = '/vendor-reviews';

  const VendorReviewsPage({
    super.key,
    required this.vendorId,
    required this.vendorType,
    required this.vendorName,
    this.initialRating = 4.0,
    this.initialReviewCount = 0,
  });

  final String vendorId;
  final String vendorType;
  final String vendorName;
  final double initialRating;
  final int initialReviewCount;

  static String location({
    required String vendorId,
    required String vendorType,
    required String vendorName,
    double initialRating = 4.0,
    int initialReviewCount = 0,
  }) {
    return Uri(
      path: routePath,
      queryParameters: {
        'vendorId': vendorId,
        'vendorType': vendorType,
        'vendorName': vendorName,
        'rating': initialRating.toString(),
        'reviewCount': initialReviewCount.toString(),
      },
    ).toString();
  }

  @override
  State<VendorReviewsPage> createState() => _VendorReviewsPageState();
}

class _VendorReviewsPageState extends State<VendorReviewsPage> {
  static const List<_ReviewReportOption> _reportOptions = [
    _ReviewReportOption(
      value: 'abusive_offensive',
      label: 'Abusive or offensive',
    ),
    _ReviewReportOption(value: 'spam', label: 'Spam'),
    _ReviewReportOption(value: 'personal_info', label: 'Personal information'),
    _ReviewReportOption(value: 'unrelated', label: 'Unrelated to the vendor'),
    _ReviewReportOption(
      value: 'false_misleading',
      label: 'False or misleading',
    ),
  ];

  final VendorReviewServiceWrapper _reviewService =
      VendorReviewServiceWrapper();

  VendorReviewFeed? _feed;
  bool _isLoading = false;
  bool _showBodySkeleton = false;
  bool _isReportingReview = false;
  String? _error;
  static const String _reviewSort = 'latest';

  @override
  void initState() {
    super.initState();
    _loadReviews();
  }

  Future<void> _loadReviews({
    String sort = _reviewSort,
    bool showLoader = true,
  }) async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      if (showLoader) {
        _showBodySkeleton = true;
        _error = null;
      }
    });

    try {
      final feed = await _reviewService.getVendorReviews(
        vendorType: widget.vendorType,
        vendorId: widget.vendorId,
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
            .replaceFirst('Failed to load vendor reviews: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _showBodySkeleton = false;
        });
      }
    }
  }

  Future<void> _reportReview(VendorReviewEntry review) async {
    if (_isReportingReview) return;

    final isAuthenticated = await AuthGuard.ensureAuthenticated(
      context,
      returnTo: VendorReviewsPage.location(
        vendorId: widget.vendorId,
        vendorType: widget.vendorType,
        vendorName: widget.vendorName,
        initialRating: widget.initialRating,
        initialReviewCount: widget.initialReviewCount,
      ),
    );
    if (!mounted || !isAuthenticated) return;

    final reason = await _showReportReasonSheet();
    if (!mounted || reason == null) return;

    final colors = context.appColors;

    setState(() => _isReportingReview = true);
    LoadingDialog.instance().show(
      context: context,
      text: 'Reporting review...',
    );

    try {
      await _reviewService.reportVendorReview(
        reviewId: review.id,
        reason: reason,
      );
      LoadingDialog.instance().hide();
      if (!mounted) return;
      AppToastMessage.show(
        context: context,
        message: 'Review reported. We will take a look.',
        backgroundColor: colors.accentOrange,
      );
    } catch (e) {
      LoadingDialog.instance().hide();
      if (!mounted) return;
      final message = e
          .toString()
          .replaceFirst('Exception: ', '')
          .replaceFirst('Failed to report vendor review: ', '');
      AppToastMessage.show(
        context: context,
        message: message,
        backgroundColor: colors.error,
        maxLines: 3,
      );
    } finally {
      if (mounted) {
        setState(() => _isReportingReview = false);
      }
    }
  }

  Future<String?> _showReportReasonSheet() {
    final colors = context.appColors;
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: colors.backgroundPrimary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      builder: (context) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 12.h),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40.w,
                    height: 4.h,
                    decoration: BoxDecoration(
                      color: colors.textSecondary.withAlpha(110),
                      borderRadius: BorderRadius.circular(999.r),
                    ),
                  ),
                ),
                SizedBox(height: 12.h),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20.h),
                  child: Text(
                    'Report review',
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                SizedBox(height: 4.h),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20.h),
                  child: Text(
                    'Choose the reason that best matches this review.',
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                SizedBox(height: 16.h),
                ..._reportOptions.map((option) {
                  return ListTile(
                    contentPadding: EdgeInsets.symmetric(horizontal: 20.w),
                    title: Text(
                      option.label,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    trailing: SvgPicture.asset(
                      Assets.icons.navArrowRight,
                      package: 'grab_go_shared',
                      colorFilter: ColorFilter.mode(
                        colors.textSecondary,
                        BlendMode.srcIn,
                      ),
                    ),
                    onTap: () => Navigator.of(context).pop(option.value),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final padding = MediaQuery.of(context).padding;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final feed = _feed;
    final vendorSnapshot = feed?.vendor;
    final displayRating = vendorSnapshot?.rating ?? widget.initialRating;
    final displayReviewCount =
        vendorSnapshot?.totalReviews ?? widget.initialReviewCount;

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
          crossAxisAlignment: CrossAxisAlignment.stretch,
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
                          "Vendor Reviews",
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
                          widget.vendorName,
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
            Divider(
              color: colors.backgroundSecondary,
              height: 1.h,
              thickness: 1,
            ),
            Expanded(
              child: AppRefreshIndicator(
                bgColor: colors.accentOrange,
                iconPath: Assets.icons.star,
                onRefresh: () =>
                    _loadReviews(sort: _reviewSort, showLoader: true),
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  slivers: [
                    SliverToBoxAdapter(
                      child: _buildSummarySection(
                        colors,
                        feed,
                        displayRating,
                        displayReviewCount,
                      ),
                    ),
                    ..._buildReviewSlivers(colors),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummarySection(
    AppColorsExtension colors,
    VendorReviewFeed? feed,
    double displayRating,
    int displayReviewCount,
  ) {
    return Padding(
      padding: EdgeInsets.only(bottom: 16.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(20.w, 0.h, 20.w, 8.h),
            child: Row(
              children: [
                FractionalStarRating(
                  rating: displayRating,
                  size: 24,
                  spacing: 2,
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
                  final total = feed.vendor.totalReviews <= 0
                      ? 1
                      : feed.vendor.totalReviews;
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
        ],
      ),
    );
  }

  List<Widget> _buildReviewSlivers(AppColorsExtension colors) {
    if (_showBodySkeleton || (_isLoading && _feed == null)) {
      return [
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) => Padding(
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
                  SizedBox(height: 14.h),
                  Divider(
                    color: colors.backgroundSecondary,
                    height: 1,
                    thickness: 1,
                  ),
                ],
              ),
            ),
            childCount: 6,
          ),
        ),
      ];
    }

    if (_error != null && _feed == null) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
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
                    onPressed: () => _loadReviews(sort: _reviewSort),
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
          ),
        ),
      ];
    }

    final feed = _feed;
    if (feed == null || feed.reviews.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Text(
              'No comments yet for this vendor.',
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: 15.sp,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ];
    }

    return [
      SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          final review = feed.reviews[index];
          return Column(
            children: [
              _buildReviewCard(colors, review),
              Divider(
                color: colors.backgroundSecondary,
                height: 1,
                thickness: 1,
                indent: 20,
                endIndent: 20,
              ),
            ],
          );
        }, childCount: feed.reviews.length),
      ),
    ];
  }

  Widget _buildReviewCard(AppColorsExtension colors, VendorReviewEntry review) {
    final createdAt = review.createdAt;
    final Size size = MediaQuery.sizeOf(context);
    final reviewDate = createdAt == null
        ? null
        : DateFormat('MMM d, yyyy').format(createdAt.toLocal());

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAvatar(colors, review.reviewer, size),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildReviewerMeta(
                      colors,
                      review.reviewer.name,
                      reviewDate,
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
                            height: 13,
                            width: 13,
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
              IconButton(
                onPressed: _isReportingReview
                    ? null
                    : () => _reportReview(review),
                splashRadius: 18.r,
                icon: SvgPicture.asset(
                  Assets.icons.flag,
                  height: 15,
                  width: 15,
                  package: 'grab_go_shared',
                  colorFilter: ColorFilter.mode(
                    colors.textSecondary,
                    BlendMode.srcIn,
                  ),
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
                        vertical: 4.h,
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

  Widget _buildReviewerMeta(
    AppColorsExtension colors,
    String reviewerName,
    String? reviewDate,
  ) {
    if (reviewDate == null || reviewDate.isEmpty) {
      return Text(
        reviewerName,
        style: TextStyle(
          color: colors.textPrimary,
          fontSize: 14.sp,
          fontWeight: FontWeight.w700,
        ),
      );
    }

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 6.w,
      runSpacing: 2.h,
      children: [
        Text(
          reviewerName,
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: 14.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
        Container(
          width: 4.w,
          height: 4.w,
          decoration: BoxDecoration(
            color: colors.textSecondary.withAlpha(110),
            borderRadius: BorderRadius.circular(999.r),
          ),
        ),
        Text(
          reviewDate,
          style: TextStyle(
            color: colors.textSecondary,
            fontSize: 13.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildAvatar(
    AppColorsExtension colors,
    VendorReviewReviewer reviewer,
    Size size,
  ) {
    final imageUrl = reviewer.profilePicture?.trim();
    final double avatarSize = size.width * 0.10;
    return ClipOval(
      child: CachedNetworkImage(
        height: avatarSize,
        width: avatarSize,
        fit: BoxFit.cover,
        imageUrl: ImageOptimizer.getPreviewUrl(imageUrl ?? '', width: 200),
        memCacheWidth: 200,
        maxHeightDiskCache: 200,
        placeholder: (context, url) => Container(
          height: avatarSize,
          width: avatarSize,
          padding: EdgeInsets.all(12.r),
          color: colors.accentOrange.withValues(alpha: 0.1),
          child: SvgPicture.asset(
            Assets.icons.user,
            package: "grab_go_shared",
            colorFilter: ColorFilter.mode(colors.accentOrange, BlendMode.srcIn),
          ),
        ),
        errorWidget: (context, url, error) => Container(
          height: avatarSize,
          width: avatarSize,
          padding: EdgeInsets.all(12.r),
          color: colors.accentOrange.withValues(alpha: 0.1),
          child: SvgPicture.asset(
            Assets.icons.user,
            package: "grab_go_shared",
            colorFilter: ColorFilter.mode(colors.accentOrange, BlendMode.srcIn),
          ),
        ),
      ),
    );
  }
}
