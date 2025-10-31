// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_customer/features/cart/viewmodel/cart_provider.dart';
import 'package:grab_go_customer/features/home/viewmodel/food_provider.dart';
import 'package:grab_go_customer/shared/viewmodels/location_provider.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_customer/features/home/model/food_category.dart';
import 'package:grab_go_customer/shared/widgets/food_category.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:grab_go_customer/shared/widgets/app_drawer.dart';
import 'package:grab_go_customer/shared/widgets/home_search.dart';
import 'package:grab_go_customer/shared/widgets/home_banner.dart';
import 'package:grab_go_customer/shared/widgets/cached_image_widget.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<FoodCategoryModel> _categories = [];
  FoodCategoryModel? _selectedCategory;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  void _initializeData() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<LocationProvider>(context, listen: false).fetchAddress();
      Provider.of<FoodProvider>(context, listen: false).fetchCategories();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Size size = MediaQuery.sizeOf(context);

    final locationProvider = Provider.of<LocationProvider>(context);
    final itemsProvider = Provider.of<FoodProvider>(context);

    if (itemsProvider.categories.isNotEmpty && _categories.isEmpty) {
      _categories = itemsProvider.categories;
      _selectedCategory ??= _categories.first;
    }

    return Scaffold(
      drawer: AppDrawer(
        controller: DrawerController(alignment: DrawerAlignment.start, child: Container()),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {},
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                          decoration: BoxDecoration(
                            color: colors.backgroundPrimary,
                            borderRadius: BorderRadius.circular(12.r),
                            border: Border.all(color: colors.inputBorder.withOpacity(0.3), width: 0.5),
                            boxShadow: [
                              BoxShadow(
                                color: isDark ? Colors.black.withAlpha(20) : Colors.black.withAlpha(5),
                                spreadRadius: 0,
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: EdgeInsets.all(6.r),
                                decoration: BoxDecoration(
                                  color: colors.accentOrange.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: SvgPicture.asset(
                                  Assets.icons.mapPin,
                                  package: 'grab_go_shared',
                                  height: 14.h,
                                  width: 14.w,
                                  colorFilter: ColorFilter.mode(colors.accentOrange, BlendMode.srcIn),
                                ),
                              ),
                              SizedBox(width: 10.w),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Deliver to",
                                      style: TextStyle(
                                        fontFamily: "Lato",
                                        package: 'grab_go_shared',
                                        fontSize: 10.sp,
                                        fontWeight: FontWeight.w500,
                                        color: colors.textSecondary,
                                      ),
                                    ),
                                    SizedBox(height: 2.h),
                                    Text(
                                      locationProvider.address.isEmpty
                                          ? "Fetching location..."
                                          : locationProvider.address,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 13.sp,
                                        fontWeight: FontWeight.w700,
                                        color: colors.textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(width: 6.w),
                              SvgPicture.asset(
                                Assets.icons.navArrowDown,
                                package: 'grab_go_shared',
                                height: 16.h,
                                width: 16.w,
                                colorFilter: ColorFilter.mode(colors.textPrimary, BlendMode.srcIn),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 12.w),

                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                      decoration: BoxDecoration(
                        color: colors.backgroundPrimary,
                        borderRadius: BorderRadius.circular(12.r),
                        border: Border.all(color: colors.inputBorder.withOpacity(0.3), width: 0.5),
                        boxShadow: [
                          BoxShadow(
                            color: isDark ? Colors.black.withAlpha(20) : Colors.black.withAlpha(5),
                            spreadRadius: 0,
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Badge(
                            backgroundColor: colors.accentViolet,
                            label: Text("4", style: TextStyle(fontSize: 8.sp)),
                            offset: const Offset(-4, 4),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () {
                                  context.push("/notification");
                                },
                                customBorder: const CircleBorder(),
                                child: Padding(
                                  padding: EdgeInsets.all(10.r),
                                  child: SvgPicture.asset(
                                    Assets.icons.bell,
                                    package: 'grab_go_shared',
                                    colorFilter: ColorFilter.mode(colors.textPrimary, BlendMode.srcIn),
                                  ),
                                ),
                              ),
                            ),
                          ),

                          Material(
                            color: Colors.transparent,
                            child: Builder(
                              builder: (context) => InkWell(
                                onTap: () {
                                  Scaffold.of(context).openDrawer();
                                },
                                customBorder: const CircleBorder(),
                                child: Padding(
                                  padding: EdgeInsets.all(10.r),
                                  child: SvgPicture.asset(
                                    Assets.icons.menu,
                                    package: 'grab_go_shared',
                                    colorFilter: ColorFilter.mode(colors.textPrimary, BlendMode.srcIn),
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
              ),

              SizedBox(height: KSpacing.md.h),
              const HomeSearch(),
              SizedBox(height: KSpacing.lg.h),
              HomeBanner(size: size),
              SizedBox(height: KSpacing.lg.h),

              Padding(
                padding: EdgeInsets.only(left: 10.w),
                child: Builder(
                  builder: (context) {
                    if (itemsProvider.isLoading) {
                      return Shimmer.fromColors(
                        baseColor: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                        highlightColor: isDark ? Colors.grey.shade700 : Colors.grey.shade100,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: List.generate(4, (index) {
                              return Container(
                                margin: EdgeInsets.symmetric(horizontal: 10.w),
                                height: 95.h,
                                width: size.width * 0.22,
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                                  borderRadius: BorderRadius.circular(KBorderSize.borderMedium),
                                ),
                              );
                            }),
                          ),
                        ),
                      );
                    } else if (itemsProvider.error != null) {
                      return Shimmer.fromColors(
                        baseColor: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                        highlightColor: isDark ? Colors.grey.shade700 : Colors.grey.shade100,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: List.generate(4, (index) {
                              return Container(
                                margin: EdgeInsets.symmetric(horizontal: 10.w),
                                height: 95.h,
                                width: size.width * 0.22,
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                                  borderRadius: BorderRadius.circular(KBorderSize.borderMedium),
                                ),
                              );
                            }),
                          ),
                        ),
                      );
                    } else if (_categories.isEmpty) {
                      return Container(
                        height: 95.h,
                        width: double.infinity,
                        margin: EdgeInsets.only(left: 10.w, right: 20.w),
                        decoration: BoxDecoration(
                          color: colors.backgroundPrimary,
                          borderRadius: BorderRadius.circular(KBorderSize.borderMedium),
                        ),
                        child: const Center(child: Text("No categories available")),
                      );
                    }

                    return FoodCategoryList(
                      categories: _categories,
                      onCategorySelected: (FoodCategoryModel category) {
                        setState(() {
                          _selectedCategory = category;
                        });
                      },
                    );
                  },
                ),
              ),

              SizedBox(height: KSpacing.lg.h),

              Padding(
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
                            color: colors.accentViolet.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(KBorderSize.border),
                          ),
                          child: SvgPicture.asset(
                            Assets.icons.flame,
                            package: 'grab_go_shared',
                            height: 20.h,
                            width: 20.w,
                            colorFilter: ColorFilter.mode(colors.accentViolet, BlendMode.srcIn),
                          ),
                        ),
                        SizedBox(width: 10.w),
                        Text(
                          "Recommended For You",
                          style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w800, color: colors.textPrimary),
                        ),
                      ],
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                      decoration: BoxDecoration(
                        color: colors.accentOrange.withOpacity(0.1),
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
              ),

              SizedBox(height: KSpacing.lg.h),

              if (_selectedCategory == null)
                Shimmer.fromColors(
                  baseColor: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                  highlightColor: isDark ? Colors.grey.shade700 : Colors.grey.shade100,
                  child: Column(
                    children: List.generate(3, (index) {
                      return Container(
                        height: size.height * 0.15,
                        margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(KBorderSize.borderMedium),
                        ),
                      );
                    }),
                  ),
                )
              else
                ListView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  shrinkWrap: true,
                  itemCount: _selectedCategory!.items.length,
                  itemBuilder: (context, index) {
                    final item = _selectedCategory!.items[index];

                    return GestureDetector(
                      onTap: () => context.push("/foodDetails", extra: item),
                      child: Container(
                        margin: EdgeInsets.only(left: 20.w, right: 20.w, bottom: 12.h),
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
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(KBorderSize.borderRadius15),
                                bottomLeft: Radius.circular(KBorderSize.borderRadius15),
                              ),
                              child: SizedBox(
                                height: 118.h,
                                width: 118.w,
                                child: CachedImageWidget(
                                  imageUrl: item.image,
                                  width: 118.w,
                                  height: 118.h,
                                  fit: BoxFit.cover,
                                  placeholder: Container(
                                    color: colors.inputBorder,
                                    child: Center(
                                      child: SvgPicture.asset(
                                        Assets.icons.utensilsCrossed,
                                        package: 'grab_go_shared',
                                        colorFilter: ColorFilter.mode(colors.textSecondary, BlendMode.srcIn),
                                        width: 30.w,
                                        height: 30.h,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            Expanded(
                              child: Padding(
                                padding: EdgeInsets.all(12.r),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.name,
                                          style: TextStyle(
                                            fontSize: 15.sp,
                                            fontWeight: FontWeight.w700,
                                            color: colors.textPrimary,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        SizedBox(height: 6.h),
                                        Row(
                                          children: [
                                            SvgPicture.asset(
                                              Assets.icons.starSolid,
                                              package: 'grab_go_shared',
                                              height: 13.h,
                                              width: 13.w,
                                              colorFilter: ColorFilter.mode(colors.accentOrange, BlendMode.srcIn),
                                            ),
                                            SizedBox(width: 4.w),
                                            Text(
                                              item.rating.toStringAsFixed(1),
                                              style: TextStyle(
                                                fontSize: 12.sp,
                                                color: colors.textPrimary,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            SizedBox(width: 8.w),
                                            Container(
                                              width: 3.w,
                                              height: 3.h,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: colors.textSecondary,
                                              ),
                                            ),
                                            SizedBox(width: 8.w),
                                            SvgPicture.asset(
                                              Assets.icons.timer,
                                              package: 'grab_go_shared',
                                              height: 12.h,
                                              width: 12.w,
                                              colorFilter: ColorFilter.mode(colors.textSecondary, BlendMode.srcIn),
                                            ),
                                            SizedBox(width: 4.w),
                                            Text(
                                              "25-30 min",
                                              style: TextStyle(
                                                fontSize: 11.sp,
                                                fontWeight: FontWeight.w500,
                                                color: colors.textSecondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 10.h),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Container(
                                          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                                          decoration: BoxDecoration(
                                            color: colors.accentOrange.withOpacity(0.15),
                                            borderRadius: BorderRadius.circular(8.r),
                                          ),
                                          child: Text(
                                            "GHS ${item.price.toStringAsFixed(2)}",
                                            style: TextStyle(
                                              fontSize: 13.sp,
                                              fontWeight: FontWeight.w800,
                                              color: colors.accentOrange,
                                            ),
                                          ),
                                        ),
                                        Consumer<CartProvider>(
                                          builder: (context, provider, _) {
                                            final bool isInCart = provider.cartItems.containsKey(item);

                                            return GestureDetector(
                                              onTap: () {
                                                if (isInCart) {
                                                  provider.removeItemCompletely(item);
                                                } else {
                                                  provider.addToCart(item);
                                                }
                                              },
                                              child: Container(
                                                padding: EdgeInsets.all(8.r),
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  color: isInCart ? colors.accentOrange : colors.backgroundSecondary,
                                                  border: Border.all(
                                                    color: isInCart ? colors.accentOrange : colors.inputBorder,
                                                    width: 1,
                                                  ),
                                                ),
                                                child: SvgPicture.asset(
                                                  Assets.icons.cart,
                                                  package: 'grab_go_shared',
                                                  height: 16.h,
                                                  width: 16.w,
                                                  colorFilter: ColorFilter.mode(
                                                    isInCart ? Colors.white : colors.textPrimary,
                                                    BlendMode.srcIn,
                                                  ),
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}
