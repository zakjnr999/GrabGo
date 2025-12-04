// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:grab_go_customer/features/restaurant/viewmodel/restaurant_provider.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_customer/features/restaurant/model/restaurants_model.dart';
import 'package:grab_go_customer/shared/widgets/restaurant_list.dart';
import 'package:grab_go_customer/shared/widgets/restaurant_search.dart';
import 'package:grab_go_customer/shared/widgets/restaurants_near.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:grab_go_shared/grub_go_shared.dart';

class Restaurants extends StatefulWidget {
  const Restaurants({super.key});

  @override
  State<Restaurants> createState() => _RestaurantsState();
}

class _RestaurantsState extends State<Restaurants> {
  String greeting = "";
  int selectedTabIndex = 0;
  String searchQuery = "";

  final List<String> locationCategories = ['All', 'Accra', 'Kumasi', 'Tema', 'Cape Coast', 'Takoradi', 'Tamale'];

  @override
  void initState() {
    super.initState();
    greeting = _getGreeting();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<RestaurantProvider>(context, listen: false).fetchRestaurants();
    });
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return "Good morning";
    } else if (hour < 17) {
      return "Good afternoon";
    } else {
      return "Good evening";
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.sizeOf(context);

    return Scaffold(
      backgroundColor: colors.backgroundSecondary,
      body: SafeArea(
        child: RefreshIndicator(
          color: colors.accentOrange,
          onRefresh: () async {
            await Provider.of<RestaurantProvider>(context, listen: false).refreshRestaurants();
          },
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
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
                            colors: [colors.accentViolet, colors.accentViolet.withOpacity(0.8)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: colors.accentViolet.withOpacity(0.3),
                              spreadRadius: 0,
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: SvgPicture.asset(
                          Assets.icons.chefHat,
                          package: 'grab_go_shared',
                          height: 24.h,
                          width: 24.w,
                          colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "$greeting!",
                              style: TextStyle(
                                fontSize: 13.sp,
                                fontWeight: FontWeight.w500,
                                color: colors.textSecondary,
                              ),
                            ),
                            SizedBox(height: 2.h),
                            Text(
                              "Find Your Restaurant",
                              style: TextStyle(
                                fontFamily: "Lato",
                                color: colors.textPrimary,
                                fontSize: 20.sp,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                RestaurantSearch(
                  onSearchChanged: (query) {
                    setState(() {
                      searchQuery = query;
                    });
                  },
                  onFilterPressed: () {},
                ),
                SizedBox(height: 16.h),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20.w),
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(8.r),
                        decoration: BoxDecoration(color: colors.accentOrange.withOpacity(0.1), shape: BoxShape.circle),
                        child: SvgPicture.asset(
                          Assets.icons.mapPin,
                          package: 'grab_go_shared',
                          height: 18.h,
                          width: 18.w,
                          colorFilter: ColorFilter.mode(colors.accentOrange, BlendMode.srcIn),
                        ),
                      ),
                      SizedBox(width: 10.w),
                      Text(
                        "Restaurant Locations",
                        style: TextStyle(fontSize: 17.sp, fontWeight: FontWeight.w800, color: colors.textPrimary),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 12.h),

                AnimatedTabBar(
                  tabs: locationCategories,
                  selectedIndex: selectedTabIndex,
                  onTabChanged: (index) {
                    setState(() {
                      selectedTabIndex = index;
                    });
                  },
                ),
                SizedBox(height: 20.h),

                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20.w),
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(8.r),
                        decoration: BoxDecoration(color: colors.accentViolet.withOpacity(0.1), shape: BoxShape.circle),
                        child: SvgPicture.asset(
                          Assets.icons.star,
                          package: 'grab_go_shared',
                          height: 16.h,
                          width: 16.w,
                          colorFilter: ColorFilter.mode(colors.accentViolet, BlendMode.srcIn),
                        ),
                      ),
                      SizedBox(width: 10.w),
                      Expanded(
                        child: Text(
                          "Popular Restaurants",
                          style: TextStyle(fontSize: 17.sp, fontWeight: FontWeight.w800, color: colors.textPrimary),
                        ),
                      ),
                      GestureDetector(
                        onTap: () {},
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                          decoration: BoxDecoration(
                            color: colors.accentOrange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20.r),
                          ),
                          child: Row(
                            children: [
                              Text(
                                "See All",
                                style: TextStyle(
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w700,
                                  color: colors.accentOrange,
                                ),
                              ),
                              SizedBox(width: 4.w),
                              SvgPicture.asset(
                                Assets.icons.navArrowRight,
                                package: 'grab_go_shared',
                                height: 14.h,
                                width: 14.w,
                                colorFilter: ColorFilter.mode(colors.accentOrange, BlendMode.srcIn),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16.h),
                Consumer<RestaurantProvider>(
                  builder: (context, provider, _) {
                    final filteredRestaurants = provider.getRestaurantsByCityAndSearch(
                      locationCategories[selectedTabIndex],
                      searchQuery,
                    );

                    if (provider.isLoading && provider.restaurants.isEmpty) {
                      return SizedBox(
                        height: 360.h,
                        child: Shimmer.fromColors(
                          baseColor: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                          highlightColor: isDark ? Colors.grey.shade700 : Colors.grey.shade100,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            padding: EdgeInsets.only(left: 20.w),
                            child: Row(
                              children: [
                                Row(
                                  children: List.generate(4, (index) {
                                    return Container(
                                      width: size.width * 0.8,
                                      margin: EdgeInsets.only(right: 16.w),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(KBorderSize.borderMedium),
                                        border: Border.all(
                                          color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                                          width: 0.5,
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          // Restuarant banner placeholder
                                          Container(
                                            height: size.height * 0.18,
                                            decoration: BoxDecoration(
                                              color: isDark ? Colors.grey.shade700 : Colors.grey.shade200,
                                              borderRadius: const BorderRadius.only(
                                                topLeft: Radius.circular(KBorderSize.borderMedium),
                                                topRight: Radius.circular(KBorderSize.borderMedium),
                                              ),
                                            ),
                                          ),
                                          Padding(
                                            padding: EdgeInsets.all(16.r),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                // Restaurant name placeholder
                                                Container(
                                                  width: 80.w,
                                                  height: 16.h,
                                                  decoration: BoxDecoration(
                                                    color: isDark ? Colors.grey.shade700 : Colors.grey.shade200,
                                                    borderRadius: BorderRadius.circular(4.r),
                                                  ),
                                                ),
                                                SizedBox(height: KSpacing.sm.h),
                                                // Info badges placeholder
                                                Row(
                                                  children: List.generate(3, (index) {
                                                    return Wrap(
                                                      spacing: 4.w,
                                                      runSpacing: 4.h,
                                                      children: [
                                                        Container(
                                                          width: 60.w,
                                                          height: 28.h,
                                                          margin: EdgeInsets.only(right: 8.w),
                                                          decoration: BoxDecoration(
                                                            color: isDark ? Colors.grey.shade700 : Colors.grey.shade200,
                                                            borderRadius: BorderRadius.circular(4.r),
                                                          ),
                                                        ),
                                                      ],
                                                    );
                                                  }),
                                                ),
                                                SizedBox(height: KSpacing.sm.h),
                                                // Restaurant foodtype placeholder
                                                Container(
                                                  width: 120.w,
                                                  height: 12.h,
                                                  decoration: BoxDecoration(
                                                    color: isDark ? Colors.grey.shade700 : Colors.grey.shade200,
                                                    borderRadius: BorderRadius.circular(4.r),
                                                  ),
                                                ),
                                                SizedBox(height: 4.h),
                                                // Restaurant description placeholder
                                                Container(
                                                  width: double.infinity,
                                                  height: 100.h,
                                                  decoration: BoxDecoration(
                                                    color: isDark ? Colors.grey.shade700 : Colors.grey.shade200,
                                                    borderRadius: BorderRadius.circular(4.r),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }

                    if (provider.error != null && provider.restaurants.isEmpty) {
                      return SizedBox(
                        height: 360.h,
                        child: Shimmer.fromColors(
                          baseColor: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                          highlightColor: isDark ? Colors.grey.shade700 : Colors.grey.shade100,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            padding: EdgeInsets.only(left: 20.w),
                            child: Row(
                              children: [
                                Row(
                                  children: List.generate(4, (index) {
                                    return Container(
                                      width: size.width * 0.8,
                                      margin: EdgeInsets.only(right: 16.w),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(KBorderSize.borderMedium),
                                        border: Border.all(
                                          color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                                          width: 0.5,
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          // Restuarant banner placeholder
                                          Container(
                                            height: size.height * 0.18,
                                            decoration: BoxDecoration(
                                              color: isDark ? Colors.grey.shade700 : Colors.grey.shade200,
                                              borderRadius: const BorderRadius.only(
                                                topLeft: Radius.circular(KBorderSize.borderMedium),
                                                topRight: Radius.circular(KBorderSize.borderMedium),
                                              ),
                                            ),
                                          ),
                                          Padding(
                                            padding: EdgeInsets.all(16.r),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                // Restaurant name placeholder
                                                Container(
                                                  width: 80.w,
                                                  height: 16.h,
                                                  decoration: BoxDecoration(
                                                    color: isDark ? Colors.grey.shade700 : Colors.grey.shade200,
                                                    borderRadius: BorderRadius.circular(4.r),
                                                  ),
                                                ),
                                                SizedBox(height: KSpacing.sm.h),
                                                // Info badges placeholder
                                                Row(
                                                  children: List.generate(3, (index) {
                                                    return Wrap(
                                                      spacing: 4.w,
                                                      runSpacing: 4.h,
                                                      children: [
                                                        Container(
                                                          width: 60.w,
                                                          height: 28.h,
                                                          margin: EdgeInsets.only(right: 8.w),
                                                          decoration: BoxDecoration(
                                                            color: isDark ? Colors.grey.shade700 : Colors.grey.shade200,
                                                            borderRadius: BorderRadius.circular(4.r),
                                                          ),
                                                        ),
                                                      ],
                                                    );
                                                  }),
                                                ),
                                                SizedBox(height: KSpacing.sm.h),
                                                // Restaurant foodtype placeholder
                                                Container(
                                                  width: 120.w,
                                                  height: 16.h,
                                                  decoration: BoxDecoration(
                                                    color: isDark ? Colors.grey.shade700 : Colors.grey.shade200,
                                                    borderRadius: BorderRadius.circular(4.r),
                                                  ),
                                                ),
                                                SizedBox(height: KSpacing.sm.h),
                                                // Restaurant description placeholder
                                                Container(
                                                  width: double.infinity,
                                                  height: 40.h,
                                                  decoration: BoxDecoration(
                                                    color: isDark ? Colors.grey.shade700 : Colors.grey.shade200,
                                                    borderRadius: BorderRadius.circular(4.r),
                                                  ),
                                                ),
                                                SizedBox(height: 20.h),
                                                // Restaurant delivery info placeholder
                                                Container(
                                                  width: double.infinity,
                                                  height: 30.h,
                                                  decoration: BoxDecoration(
                                                    color: isDark ? Colors.grey.shade700 : Colors.grey.shade200,
                                                    borderRadius: BorderRadius.circular(4.r),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }

                    if (filteredRestaurants.isEmpty) {
                      return SizedBox(
                        height: size.height * 0.35,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                searchQuery.isNotEmpty
                                    ? 'No restaurants found for "$searchQuery"'
                                    : 'No restaurants found in ${locationCategories[selectedTabIndex]}',
                                style: TextStyle(
                                  color: colors.textSecondary,
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(height: KSpacing.sm.h),
                              Text(
                                searchQuery.isNotEmpty
                                    ? 'Try a different search term or clear the search'
                                    : 'Try selecting a different location',
                                style: TextStyle(
                                  color: colors.textTertiary,
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    return RestaurantList(restaurants: filteredRestaurants);
                  },
                ),
                SizedBox(height: 20.h),

                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20.w),
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(8.r),
                        decoration: BoxDecoration(color: colors.accentGreen.withOpacity(0.1), shape: BoxShape.circle),
                        child: SvgPicture.asset(
                          Assets.icons.sendDiagonal,
                          package: 'grab_go_shared',
                          height: 16.h,
                          width: 16.w,
                          colorFilter: ColorFilter.mode(colors.accentGreen, BlendMode.srcIn),
                        ),
                      ),
                      SizedBox(width: 10.w),
                      Expanded(
                        child: Text(
                          "Restaurants Near You",
                          style: TextStyle(
                            fontFamily: "Lato",
                            fontSize: 17.sp,
                            fontWeight: FontWeight.w800,
                            color: colors.textPrimary,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () {},
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                          decoration: BoxDecoration(
                            color: colors.accentOrange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20.r),
                          ),
                          child: Row(
                            children: [
                              Text(
                                "See All",
                                style: TextStyle(
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w700,
                                  color: colors.accentOrange,
                                ),
                              ),
                              SizedBox(width: 4.w),
                              SvgPicture.asset(
                                Assets.icons.navArrowRight,
                                package: 'grab_go_shared',
                                height: 14.h,
                                width: 14.w,
                                colorFilter: ColorFilter.mode(colors.accentOrange, BlendMode.srcIn),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16.h),
                Consumer<RestaurantProvider>(
                  builder: (context, provider, _) {
                    List<RestaurantModel> nearbyRestaurants = provider.restaurants.take(3).toList();

                    if (searchQuery.isNotEmpty) {
                      nearbyRestaurants = provider.searchRestaurants(searchQuery).take(3).toList();
                    }

                    return RestaurantsNear(restaurants: nearbyRestaurants, isLoading: provider.isLoading);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
