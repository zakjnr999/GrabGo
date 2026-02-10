import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/shared/utils/app_colors_extension.dart';

class ItemReviewsPage extends StatefulWidget {
  const ItemReviewsPage({super.key});

  @override
  State<ItemReviewsPage> createState() => _ItemReviewsPageState();
}

class _ItemReviewsPageState extends State<ItemReviewsPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final padding = MediaQuery.of(context).padding;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final systemUiOverlayStyle = SystemUiOverlayStyle(
      statusBarColor: colors.backgroundPrimary,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      systemNavigationBarColor: colors.backgroundPrimary,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
    );

    SystemChrome.setSystemUIOverlayStyle(systemUiOverlayStyle);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: systemUiOverlayStyle,
      child: Scaffold(
        backgroundColor: colors.backgroundPrimary,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: EdgeInsets.only(top: padding.top + 10, left: 20.w, right: 20.w, bottom: 16.h),
              child: Row(
                children: [
                  Container(
                    height: 44,
                    width: 44,
                    decoration: BoxDecoration(
                      color: colors.backgroundSecondary,
                      shape: BoxShape.circle,
                      border: Border.all(color: colors.inputBorder.withValues(alpha: 0.3), width: 0.5),
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
                  SizedBox(width: 16.w),
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
                ],
              ),
            ),

            // Rating star section
            Padding(
              padding: EdgeInsets.fromLTRB(20.w, 0.h, 20.w, 8.h),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Row(
                    children: List.generate(
                      5,
                      (index) => SvgPicture.asset(
                        Assets.icons.starSolid,
                        package: 'grab_go_shared',
                        height: 36.h,
                        width: 36.w,
                        colorFilter: ColorFilter.mode(colors.accentOrange, BlendMode.srcIn),
                      ),
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Text(
                    '5.0',
                    style: TextStyle(color: colors.textPrimary, fontSize: 24.sp, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),

            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.w),
              child: Text(
                'Based on 49 reviews',
                style: TextStyle(color: colors.textSecondary, fontSize: 14.sp, fontWeight: FontWeight.w400),
              ),
            ),

            SizedBox(height: 16.h),

            // TabBar
            Container(
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: colors.inputBorder.withValues(alpha: 0.5), width: 1)),
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

            // TabBarView
            Expanded(
              child: TabBarView(
                controller: _tabController,
                physics: const AlwaysScrollableScrollPhysics(),
                children: [_buildReviewsList(colors, 'popular'), _buildReviewsList(colors, 'latest')],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewsList(AppColorsExtension colors, String type) {
    // Placeholder review data
    final reviews = List.generate(
      type == 'my' ? 2 : 10,
      (index) => {
        'name': type == 'my' ? 'You' : 'User ${index + 1}',
        'rating': 5.0,
        'date': '2 days ago',
        'comment': 'Amazing food! The taste was incredible and delivery was super fast. Highly recommend!',
      },
    );

    if (reviews.isEmpty) {
      return Center(
        child: Text(
          type == 'my' ? 'No reviews yet' : 'No reviews available',
          style: TextStyle(color: colors.textSecondary, fontSize: 16.sp, fontWeight: FontWeight.w600),
        ),
      );
    }

    return ListView.separated(
      padding: EdgeInsets.symmetric(vertical: 10.h),
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: reviews.length,
      separatorBuilder: (context, index) =>
          Divider(color: colors.backgroundSecondary, height: 1, thickness: 1, indent: 20, endIndent: 20),
      itemBuilder: (context, index) {
        final review = reviews[index];
        return _buildReviewCard(colors, review);
      },
    );
  }

  Widget _buildReviewCard(AppColorsExtension colors, Map<String, dynamic> review) {
    return Container(
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(color: colors.backgroundPrimary, borderRadius: BorderRadius.circular(12.r)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Row(
                children: List.generate(
                  5,
                  (index) => SvgPicture.asset(
                    Assets.icons.starSolid,
                    package: 'grab_go_shared',
                    height: 14.h,
                    width: 14.w,
                    colorFilter: ColorFilter.mode(colors.accentOrange, BlendMode.srcIn),
                  ),
                ),
              ),
              SizedBox(width: 12.w),
              Text(
                review['name'],
                style: TextStyle(color: colors.textPrimary, fontSize: 13.sp, fontWeight: FontWeight.w400),
              ),
              SizedBox(width: 6.h),
              Container(
                height: 4.h,
                width: 4.w,
                decoration: BoxDecoration(color: colors.textPrimary, shape: BoxShape.circle),
              ),
              SizedBox(width: 6.h),
              Text(
                review['date'],
                style: TextStyle(color: colors.textSecondary, fontSize: 13.sp, fontWeight: FontWeight.w400),
              ),
            ],
          ),

          Text(
            review['comment'],
            style: TextStyle(color: colors.textPrimary, fontSize: 14.sp, fontWeight: FontWeight.w400, height: 1.5),
          ),
          SizedBox(height: 12.h),
          Row(
            children: [
              _buildReactSection(colors, Assets.icons.thumbsUp, 'Was Helpful (10)', () {}),
              SizedBox(width: 25.w),
              _buildReactSection(colors, Assets.icons.thumbsDown, 'Not Helpful (10)', () {}),
            ],
          ),
        ],
      ),
    );
  }
}

Widget _buildReactSection(AppColorsExtension colors, String icon, String text, GestureTapCallback ontap) {
  return GestureDetector(
    onTap: ontap,
    child: Row(
      children: [
        SvgPicture.asset(
          icon,
          package: 'grab_go_shared',
          height: 14.h,
          width: 14.w,
          colorFilter: ColorFilter.mode(colors.textPrimary, BlendMode.srcIn),
        ),
        SizedBox(width: 10.w),
        Text(
          text,
          style: TextStyle(color: colors.textSecondary, fontSize: 12.sp, fontWeight: FontWeight.w400),
        ),
      ],
    ),
  );
}
