import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_customer/features/groceries/model/grocery_category.dart';
import 'package:grab_go_customer/features/groceries/model/grocery_item.dart';
import 'package:grab_go_customer/features/groceries/viewmodel/grocery_provider.dart';
import 'package:grab_go_customer/features/pharmacy/model/pharmacy_category.dart';
import 'package:grab_go_customer/features/pharmacy/model/pharmacy_item.dart';
import 'package:grab_go_customer/features/pharmacy/viewmodel/pharmacy_provider.dart';
import 'package:grab_go_customer/features/grabmart/model/grabmart_category.dart';
import 'package:grab_go_customer/features/grabmart/model/grabmart_item.dart';
import 'package:grab_go_customer/features/grabmart/viewmodel/grabmart_provider.dart';
import 'package:grab_go_customer/features/home/model/food_category.dart';
import 'package:grab_go_customer/features/home/viewmodel/food_provider.dart';
import 'package:grab_go_customer/shared/viewmodels/service_provider.dart';
import 'package:grab_go_customer/shared/widgets/area_unavailable_screen.dart';
import 'package:grab_go_customer/shared/widgets/browse_page_skeleton.dart';
import 'package:grab_go_customer/shared/widgets/umbrella_header.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:provider/provider.dart';

class BrowsePage extends StatefulWidget {
  const BrowsePage({super.key});

  @override
  State<BrowsePage> createState() => _BrowsePageState();
}

class _BrowsePageState extends State<BrowsePage> {
  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<double> _scrollOffsetNotifier = ValueNotifier<double>(0.0);
  static const double _collapsedHeight = 70.0;
  static const double _scrollThreshold = 150.0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    _scrollOffsetNotifier.value = _scrollController.offset;
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _scrollOffsetNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final serviceProvider = Provider.of<ServiceProvider>(context);
    final padding = MediaQuery.of(context).padding;

    final size = MediaQuery.sizeOf(context);

    final systemUiOverlayStyle = SystemUiOverlayStyle(
      statusBarColor: colors.accentOrange,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: colors.backgroundPrimary,
      systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: systemUiOverlayStyle,
      child: Scaffold(
        backgroundColor: colors.backgroundPrimary,
        body: SafeArea(
          top: false,
          child: Stack(
            children: [
              AppRefreshIndicator(
                bgColor: colors.accentOrange,
                iconPath: Assets.icons.search,
                onRefresh: () async {
                  if (serviceProvider.isFoodService) {
                    await Provider.of<FoodProvider>(context, listen: false).fetchCategories();
                  } else if (serviceProvider.isGroceryService) {
                    await Provider.of<GroceryProvider>(context, listen: false).fetchCategories();
                  } else if (serviceProvider.isPharmacyService) {
                    await Provider.of<PharmacyProvider>(context, listen: false).fetchCategories();
                  } else if (serviceProvider.isStoresService) {
                    await Provider.of<GrabMartProvider>(context, listen: false).fetchCategories();
                  }
                },
                child: _buildContent(colors, isDark, serviceProvider, size),
              ),

              Positioned(top: 0, left: 0, right: 0, child: _buildCollapsibleHeader(colors, size, padding)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCollapsibleHeader(AppColorsExtension colors, Size size, EdgeInsets padding) {
    return ValueListenableBuilder<double>(
      valueListenable: _scrollOffsetNotifier,
      builder: (context, scrollOffset, _) {
        final collapseProgress = (scrollOffset / _scrollThreshold).clamp(0.0, 1.0);
        final expandedHeight = UmbrellaHeaderMetrics.expandedHeightFor(size);
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
              child: Padding(
                padding: EdgeInsets.fromLTRB(20.w, padding.top + 16.h, 10.w, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Browse',
                            style: TextStyle(fontSize: 24.sp, fontWeight: FontWeight.w700, color: Colors.white),
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            'Discover trending items',
                            style: TextStyle(fontSize: 14.sp, color: Colors.white.withValues(alpha: 0.8)),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => context.push('/search'),
                      child: IconButton(
                        onPressed: () => context.push('/search'),
                        icon: SvgPicture.asset(
                          Assets.icons.search,
                          package: 'grab_go_shared',
                          width: 20.w,
                          height: 20.h,
                          colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildContent(AppColorsExtension colors, bool isDark, ServiceProvider serviceProvider, Size size) {
    final foodProvider = Provider.of<FoodProvider>(context);
    final bool isFoodUnavailable =
        !foodProvider.isLoading && foodProvider.categories.isEmpty && foodProvider.hasAttemptedFetch;

    if (isFoodUnavailable) {
      return ListView(
        controller: _scrollController,
        padding: EdgeInsets.only(top: UmbrellaHeaderMetrics.contentPaddingFor(size), bottom: 32.h),
        children: const [AreaUnavailableScreen(isAreaUnavailable: true)],
      );
    }

    if (serviceProvider.isFoodService) {
      return Consumer<FoodProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return ListView(
              controller: _scrollController,
              padding: EdgeInsets.only(top: UmbrellaHeaderMetrics.contentPaddingFor(size), bottom: 32.h),
              children: const [BrowsePageSkeleton()],
            );
          }
          return _buildLoadedContent(colors, isDark, serviceProvider, size);
        },
      );
    } else if (serviceProvider.isGroceryService) {
      return Consumer<GroceryProvider>(
        builder: (context, provider, _) {
          if (provider.isLoadingItems || provider.isLoadingCategories) {
            return ListView(
              controller: _scrollController,
              padding: EdgeInsets.only(top: UmbrellaHeaderMetrics.contentPaddingFor(size), bottom: 32.h),
              children: const [BrowsePageSkeleton()],
            );
          }
          return _buildLoadedContent(colors, isDark, serviceProvider, size);
        },
      );
    } else if (serviceProvider.isPharmacyService) {
      return Consumer<PharmacyProvider>(
        builder: (context, provider, _) {
          if (provider.isLoadingItems || provider.isLoadingCategories) {
            return ListView(
              controller: _scrollController,
              padding: EdgeInsets.only(top: UmbrellaHeaderMetrics.contentPaddingFor(size), bottom: 32.h),
              children: const [BrowsePageSkeleton()],
            );
          }
          return _buildLoadedContent(colors, isDark, serviceProvider, size);
        },
      );
    } else if (serviceProvider.isStoresService) {
      return Consumer<GrabMartProvider>(
        builder: (context, provider, _) {
          if (provider.isLoadingItems || provider.isLoadingCategories) {
            return ListView(
              controller: _scrollController,
              padding: EdgeInsets.only(top: UmbrellaHeaderMetrics.contentPaddingFor(size), bottom: 32.h),
              children: const [BrowsePageSkeleton()],
            );
          }
          return _buildLoadedContent(colors, isDark, serviceProvider, size);
        },
      );
    }

    return _buildLoadedContent(colors, isDark, serviceProvider, size);
  }

  Widget _buildLoadedContent(AppColorsExtension colors, bool isDark, ServiceProvider serviceProvider, Size size) {
    return ListView(
      controller: _scrollController,
      padding: EdgeInsets.only(top: UmbrellaHeaderMetrics.contentPaddingFor(size), bottom: 32.h),
      children: [
        // Trending Section
        _buildSectionHeader(colors, 'Trending Now', 'Most ordered this week'),
        SizedBox(height: 12.h),
        _buildTrendingList(colors, isDark, serviceProvider),

        SizedBox(height: KSpacing.lg.h),

        // Popular Categories Section
        _buildSectionHeader(colors, 'Popular Categories', 'Browse by category'),
        SizedBox(height: 12.h),
        _buildCategoriesList(colors, isDark, serviceProvider),

        SizedBox(height: KSpacing.lg.h),

        // Quick Searches Section
        _buildSectionHeader(colors, 'Quick Searches', 'Popular filters'),
        SizedBox(height: 12.h),
        _buildQuickSearches(colors),
      ],
    );
  }

  Widget _buildSectionHeader(AppColorsExtension colors, String title, String subtitle) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w700, color: colors.textPrimary),
          ),
          SizedBox(height: 4.h),
          Text(
            subtitle,
            style: TextStyle(fontSize: 13.sp, color: colors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildTrendingList(AppColorsExtension colors, bool isDark, ServiceProvider serviceProvider) {
    if (serviceProvider.isFoodService) {
      return Consumer<FoodProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const SizedBox.shrink();
          }

          final allItems = <FoodItem>[];
          for (var category in provider.categories) {
            allItems.addAll(category.items);
          }

          allItems.sort((a, b) => b.orderCount.compareTo(a.orderCount));
          final trending = allItems.take(10).toList();

          if (trending.isEmpty) {
            return _buildEmptyState(colors, 'No trending items yet');
          }

          return Column(
            children: trending.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              return _buildTrendingItem(
                colors,
                index + 1,
                item.name,
                '${item.orderCount} orders',
                () => context.push('/foodDetails', extra: item),
              );
            }).toList(),
          );
        },
      );
    } else if (serviceProvider.isGroceryService) {
      return Consumer<GroceryProvider>(
        builder: (context, provider, _) {
          if (provider.isLoadingItems) {
            return const SizedBox.shrink();
          }

          final items = List<GroceryItem>.from(provider.items);
          items.sort((a, b) => b.orderCount.compareTo(a.orderCount));
          final trending = items.take(10).toList();

          if (trending.isEmpty) {
            return _buildEmptyState(colors, 'No trending items yet');
          }

          return Column(
            children: trending.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              return _buildTrendingItem(
                colors,
                index + 1,
                item.name,
                '${item.orderCount} orders',
                () => context.push('/foodDetails', extra: item),
              );
            }).toList(),
          );
        },
      );
    } else if (serviceProvider.isPharmacyService) {
      return Consumer<PharmacyProvider>(
        builder: (context, provider, _) {
          if (provider.isLoadingItems) {
            return const SizedBox.shrink();
          }

          final items = List<PharmacyItem>.from(provider.items);
          items.sort((a, b) => b.orderCount.compareTo(a.orderCount));
          final trending = items.take(10).toList();

          if (trending.isEmpty) {
            return _buildEmptyState(colors, 'No trending items yet');
          }

          return Column(
            children: trending.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              return _buildTrendingItem(
                colors,
                index + 1,
                item.name,
                '${item.orderCount} orders',
                () => context.push('/foodDetails', extra: item),
              );
            }).toList(),
          );
        },
      );
    } else if (serviceProvider.isStoresService) {
      return Consumer<GrabMartProvider>(
        builder: (context, provider, _) {
          if (provider.isLoadingItems) {
            return const SizedBox.shrink();
          }

          final items = List<GrabMartItem>.from(provider.items);
          items.sort((a, b) => b.orderCount.compareTo(a.orderCount));
          final trending = items.take(10).toList();

          if (trending.isEmpty) {
            return _buildEmptyState(colors, 'No trending items yet');
          }

          return Column(
            children: trending.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              return _buildTrendingItem(
                colors,
                index + 1,
                item.name,
                '${item.orderCount} orders',
                () => context.push('/foodDetails', extra: item),
              );
            }).toList(),
          );
        },
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildTrendingItem(AppColorsExtension colors, int rank, String name, String subtitle, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 20.w, vertical: 6.h),
        decoration: BoxDecoration(
          color: colors.backgroundPrimary,
          borderRadius: BorderRadius.circular(KBorderSize.borderMedium),
          border: Border.all(color: colors.inputBorder.withValues(alpha: 0.3), width: 0.5),
        ),
        child: Row(
          children: [
            Container(
              width: 32.w,
              height: 32.h,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: rank <= 3
                      ? [colors.accentOrange, colors.accentOrange]
                      : [colors.backgroundSecondary, colors.backgroundSecondary],
                ),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '$rank',
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                    color: rank <= 3 ? Colors.white : colors.textSecondary,
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
                    name,
                    style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w600, color: colors.textPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12.sp, color: colors.textSecondary),
                  ),
                ],
              ),
            ),
            SvgPicture.asset(
              Assets.icons.navArrowRight,
              package: 'grab_go_shared',
              width: 20.w,
              height: 20.h,
              colorFilter: ColorFilter.mode(colors.textSecondary, BlendMode.srcIn),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoriesList(AppColorsExtension colors, bool isDark, ServiceProvider serviceProvider) {
    if (serviceProvider.isFoodService) {
      return Consumer<FoodProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const SizedBox.shrink();
          }

          final categories = provider.categories.where((cat) => cat.items.isNotEmpty).toList();
          categories.sort((a, b) => b.items.length.compareTo(a.items.length));

          if (categories.isEmpty) {
            return _buildEmptyState(colors, 'No categories available');
          }

          return _buildHorizontalCategoryList<FoodCategoryModel>(
            categories: categories,
            getName: (cat) => cat.name,
            getEmoji: (cat) => cat.emoji,
            onTap: (cat) => context.push(
              '/categoryItems/${cat.id}',
              extra: {
                'categoryId': cat.id,
                'categoryName': cat.name,
                'categoryEmoji': cat.emoji,
                'serviceType': 'food',
                'isFood': true,
              },
            ),
            colors: colors,
          );
        },
      );
    } else if (serviceProvider.isGroceryService) {
      return Consumer<GroceryProvider>(
        builder: (context, provider, _) {
          if (provider.isLoadingCategories) {
            return const SizedBox.shrink();
          }

          final categories = provider.categories.where((cat) {
            final count = provider.items.where((item) => item.categoryId == cat.id).length;
            return count > 0;
          }).toList();

          categories.sort((a, b) {
            final countA = provider.items.where((item) => item.categoryId == a.id).length;
            final countB = provider.items.where((item) => item.categoryId == b.id).length;
            return countB.compareTo(countA);
          });

          if (categories.isEmpty) {
            return _buildEmptyState(colors, 'No categories available');
          }

          return _buildHorizontalCategoryList<GroceryCategory>(
            categories: categories,
            getName: (cat) => cat.name,
            getEmoji: (cat) => cat.emoji,
            onTap: (cat) => context.push(
              '/categoryItems/${cat.id}',
              extra: {
                'categoryId': cat.id,
                'categoryName': cat.name,
                'categoryEmoji': cat.emoji,
                'serviceType': 'groceries',
                'isFood': false,
              },
            ),
            colors: colors,
          );
        },
      );
    } else if (serviceProvider.isPharmacyService) {
      return Consumer<PharmacyProvider>(
        builder: (context, provider, _) {
          if (provider.isLoadingCategories) {
            return const SizedBox.shrink();
          }

          final categories = provider.categories.where((cat) {
            final count = provider.items.where((item) => item.categoryId == cat.id).length;
            return count > 0;
          }).toList();

          categories.sort((a, b) {
            final countA = provider.items.where((item) => item.categoryId == a.id).length;
            final countB = provider.items.where((item) => item.categoryId == b.id).length;
            return countB.compareTo(countA);
          });

          if (categories.isEmpty) {
            return _buildEmptyState(colors, 'No categories available');
          }

          return _buildHorizontalCategoryList<PharmacyCategory>(
            categories: categories,
            getName: (cat) => cat.name,
            getEmoji: (cat) => cat.emoji,
            onTap: (cat) => context.push(
              '/categoryItems/${cat.id}',
              extra: {
                'categoryId': cat.id,
                'categoryName': cat.name,
                'categoryEmoji': cat.emoji,
                'serviceType': 'pharmacy',
                'isFood': false,
              },
            ),
            colors: colors,
          );
        },
      );
    } else if (serviceProvider.isStoresService) {
      return Consumer<GrabMartProvider>(
        builder: (context, provider, _) {
          if (provider.isLoadingCategories) {
            return const SizedBox.shrink();
          }

          final categories = provider.categories.where((cat) {
            final count = provider.items.where((item) => item.categoryId == cat.id).length;
            return count > 0;
          }).toList();

          categories.sort((a, b) {
            final countA = provider.items.where((item) => item.categoryId == a.id).length;
            final countB = provider.items.where((item) => item.categoryId == b.id).length;
            return countB.compareTo(countA);
          });

          if (categories.isEmpty) {
            return _buildEmptyState(colors, 'No categories available');
          }

          return _buildHorizontalCategoryList<GrabMartCategory>(
            categories: categories,
            getName: (cat) => cat.name,
            getEmoji: (cat) => cat.emoji,
            onTap: (cat) => context.push(
              '/categoryItems/${cat.id}',
              extra: {
                'categoryId': cat.id,
                'categoryName': cat.name,
                'categoryEmoji': cat.emoji,
                'serviceType': 'convenience',
                'isFood': false,
              },
            ),
            colors: colors,
          );
        },
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildHorizontalCategoryList<T>({
    required List<T> categories,
    required String Function(T) getName,
    required String Function(T) getEmoji,
    required Function(T) onTap,
    required AppColorsExtension colors,
  }) {
    return SizedBox(
      height: 116.h,
      child: ListView.builder(
        padding: EdgeInsets.symmetric(horizontal: 20.w),
        scrollDirection: Axis.horizontal,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
          return GestureDetector(
            onTap: () => onTap(category),
            child: Padding(
              padding: EdgeInsets.only(right: index == categories.length - 1 ? 0 : 16.w),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: EdgeInsets.all(20.r),
                    decoration: BoxDecoration(
                      color: colors.accentOrange.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Text(getEmoji(category), style: TextStyle(fontSize: 28.sp)),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    getName(category),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w500,
                      color: colors.textPrimary,
                      fontFamily: 'Lato',
                      package: 'grab_go_shared',
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

  Widget _buildQuickSearches(AppColorsExtension colors) {
    final searches = [
      {'label': 'Fast delivery', 'subtitle': 'Under 30 minutes'},
      {'label': 'Under ₵20', 'subtitle': 'Budget-friendly options'},
      {'label': 'Top rated', 'subtitle': '4.5+ stars'},
      {'label': 'On sale', 'subtitle': 'Special discounts'},
    ];

    return Column(
      children: searches.map((search) {
        return GestureDetector(
          onTap: () => context.push('/search'),
          child: Container(
            margin: EdgeInsets.symmetric(horizontal: 20.w, vertical: 6.h),
            decoration: BoxDecoration(
              color: colors.backgroundPrimary,
              borderRadius: BorderRadius.circular(KBorderSize.borderMedium),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        search['label']!,
                        style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w600, color: colors.textPrimary),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        search['subtitle']!,
                        style: TextStyle(fontSize: 12.sp, color: colors.textSecondary),
                      ),
                    ],
                  ),
                ),
                // Arrow
                SvgPicture.asset(
                  Assets.icons.navArrowRight,
                  package: 'grab_go_shared',
                  width: 20.w,
                  height: 20.h,
                  colorFilter: ColorFilter.mode(colors.textSecondary, BlendMode.srcIn),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildEmptyState(AppColorsExtension colors, String message) {
    return Container(
      padding: EdgeInsets.all(40.r),
      child: Column(
        children: [
          Icon(Icons.search_off, size: 48.sp, color: colors.textSecondary.withValues(alpha: 0.5)),
          SizedBox(height: 16.h),
          Text(
            message,
            style: TextStyle(fontSize: 14.sp, color: colors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
