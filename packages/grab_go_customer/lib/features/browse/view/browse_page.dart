import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_customer/features/groceries/model/grocery_category.dart';
import 'package:grab_go_customer/features/groceries/viewmodel/grocery_provider.dart';
import 'package:grab_go_customer/features/pharmacy/model/pharmacy_category.dart';
import 'package:grab_go_customer/features/pharmacy/viewmodel/pharmacy_provider.dart';
import 'package:grab_go_customer/features/grabmart/model/grabmart_category.dart';
import 'package:grab_go_customer/features/grabmart/model/grabmart_item.dart';
import 'package:grab_go_customer/features/grabmart/viewmodel/grabmart_provider.dart';
import 'package:grab_go_customer/features/home/model/food_category.dart';
import 'package:grab_go_customer/features/home/viewmodel/food_provider.dart';
import 'package:grab_go_customer/features/groceries/model/grocery_item.dart';
import 'package:grab_go_customer/shared/viewmodels/service_provider.dart';
import 'package:grab_go_customer/shared/widgets/area_unavailable_screen.dart';
import 'package:grab_go_customer/shared/widgets/browse_page_skeleton.dart';
import 'package:grab_go_customer/shared/widgets/umbrella_header.dart';
import 'package:grab_go_customer/features/pharmacy/model/pharmacy_item.dart';
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

  List<String> _recentSearches = [];

  @override
  void initState() {
    super.initState();
    _loadRecentSearches();
    _scrollController.addListener(_onScroll);
  }

  void _loadRecentSearches() {
    _recentSearches = CacheService.getSearchHistory();
    if (mounted) {
      setState(() {});
    }
  }

  void _persistRecentSearch(String term) {
    final value = term.trim();
    if (value.isEmpty) return;
    CacheService.addSearchTerm(value);
    _loadRecentSearches();
  }

  void _clearRecentSearches() {
    CacheService.clearSearchHistory();
    _loadRecentSearches();
  }

  Future<void> _removeRecentSearch(String term) async {
    final updatedSearches = List<String>.from(_recentSearches)..removeWhere((entry) => entry == term);
    await CacheService.saveSearchHistory(updatedSearches);
    _loadRecentSearches();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    _scrollOffsetNotifier.value = _scrollController.offset;
  }

  void _openSearch({String? term}) {
    final normalized = term?.trim() ?? '';
    if (normalized.isNotEmpty) {
      _persistRecentSearch(normalized);
    }
    final route = Uri(path: '/search', queryParameters: normalized.isNotEmpty ? {'q': normalized} : null).toString();
    context.push(route);
  }

  void _startSearchFromTerm(String term) => _openSearch(term: term);

  double _contentTopPadding(Size size, double topInset) {
    return UmbrellaHeaderMetrics.contentPaddingFor(size);
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
    final content = AppRefreshIndicator(
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
      child: _buildContent(colors, isDark, serviceProvider, size, padding.top),
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: systemUiOverlayStyle,
      child: Scaffold(
        backgroundColor: colors.backgroundPrimary,
        body: SafeArea(
          top: false,
          child: Stack(
            children: [
              content,
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
                    IconButton(
                      onPressed: _openSearch,
                      icon: SvgPicture.asset(
                        Assets.icons.search,
                        package: 'grab_go_shared',
                        width: 20.w,
                        height: 20.h,
                        colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
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

  Widget _buildContent(
    AppColorsExtension colors,
    bool isDark,
    ServiceProvider serviceProvider,
    Size size,
    double topInset,
  ) {
    final foodProvider = Provider.of<FoodProvider>(context);
    final bool isFoodUnavailable =
        !foodProvider.isLoading && foodProvider.categories.isEmpty && foodProvider.hasAttemptedFetch;

    if (isFoodUnavailable) {
      return ListView(
        controller: _scrollController,
        padding: EdgeInsets.only(top: _contentTopPadding(size, topInset), bottom: 32.h),
        children: const [AreaUnavailableScreen(isAreaUnavailable: true)],
      );
    }

    if (serviceProvider.isFoodService) {
      return Consumer<FoodProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return ListView(
              controller: _scrollController,
              padding: EdgeInsets.only(top: _contentTopPadding(size, topInset), bottom: 32.h),
              children: const [BrowsePageSkeleton()],
            );
          }
          return _buildLoadedContent(colors, isDark, serviceProvider, size, topInset);
        },
      );
    } else if (serviceProvider.isGroceryService) {
      return Consumer<GroceryProvider>(
        builder: (context, provider, _) {
          if (provider.isLoadingItems || provider.isLoadingCategories) {
            return ListView(
              controller: _scrollController,
              padding: EdgeInsets.only(top: _contentTopPadding(size, topInset), bottom: 32.h),
              children: const [BrowsePageSkeleton()],
            );
          }
          return _buildLoadedContent(colors, isDark, serviceProvider, size, topInset);
        },
      );
    } else if (serviceProvider.isPharmacyService) {
      return Consumer<PharmacyProvider>(
        builder: (context, provider, _) {
          if (provider.isLoadingItems || provider.isLoadingCategories) {
            return ListView(
              controller: _scrollController,
              padding: EdgeInsets.only(top: _contentTopPadding(size, topInset), bottom: 32.h),
              children: const [BrowsePageSkeleton()],
            );
          }
          return _buildLoadedContent(colors, isDark, serviceProvider, size, topInset);
        },
      );
    } else if (serviceProvider.isStoresService) {
      return Consumer<GrabMartProvider>(
        builder: (context, provider, _) {
          if (provider.isLoadingItems || provider.isLoadingCategories) {
            return ListView(
              controller: _scrollController,
              padding: EdgeInsets.only(top: _contentTopPadding(size, topInset), bottom: 32.h),
              children: const [BrowsePageSkeleton()],
            );
          }
          return _buildLoadedContent(colors, isDark, serviceProvider, size, topInset);
        },
      );
    }

    return _buildLoadedContent(colors, isDark, serviceProvider, size, topInset);
  }

  Widget _buildLoadedContent(
    AppColorsExtension colors,
    bool isDark,
    ServiceProvider serviceProvider,
    Size size,
    double topInset,
  ) {
    return ListView(
      controller: _scrollController,
      padding: EdgeInsets.only(top: _contentTopPadding(size, topInset), bottom: 32.h),
      children: [
        _buildSectionHeader(colors, 'Top Categories', 'Browse by category'),
        SizedBox(height: 12.h),
        _buildCategoriesList(colors, isDark, serviceProvider),

        SizedBox(height: KSpacing.lg.h),

        _buildSectionHeader(colors, 'Trending Dishes', 'Tap the search icon to explore a dish'),
        SizedBox(height: 12.h),
        _buildTrendingList(colors, isDark, serviceProvider),

        SizedBox(height: KSpacing.lg.h),

        if (_recentSearches.isNotEmpty) ...[
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Recent Searches',
                        style: TextStyle(
                          fontSize: 18.sp,
                          fontFamily: 'Lato',
                          package: 'grab_go_shared',
                          fontWeight: FontWeight.w700,
                          color: colors.textPrimary,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        'Pick up where you left off',
                        style: TextStyle(fontSize: 13.sp, color: colors.textSecondary),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: _clearRecentSearches,
                  child: Padding(
                    padding: EdgeInsets.only(top: 2.h, left: 12.w),
                    child: Text(
                      'Clear all',
                      style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w700, color: colors.accentOrange),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 12.h),
          _buildRecentSearches(colors),
        ],
      ],
    );
  }

  Widget _buildSectionHeader(AppColorsExtension colors, String title, String subtitle, {String? highlightedText}) {
    final titleStyle = TextStyle(
      fontSize: 18.sp,
      fontFamily: 'Lato',
      package: 'grab_go_shared',
      fontWeight: FontWeight.w700,
      color: colors.textPrimary,
    );
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: TextSpan(
              style: titleStyle,
              children: _buildHighlightedTitleSpans(
                title: title,
                highlightedText: highlightedText,
                baseStyle: titleStyle,
                highlightColor: colors.accentOrange,
              ),
            ),
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

  List<InlineSpan> _buildHighlightedTitleSpans({
    required String title,
    required String? highlightedText,
    required TextStyle baseStyle,
    required Color highlightColor,
  }) {
    final query = highlightedText?.trim() ?? '';
    if (query.isEmpty) return [TextSpan(text: title, style: baseStyle)];

    final lowerTitle = title.toLowerCase();
    final lowerQuery = query.toLowerCase();
    final start = lowerTitle.indexOf(lowerQuery);
    if (start < 0) return [TextSpan(text: title, style: baseStyle)];

    final end = start + query.length;
    return [
      if (start > 0) TextSpan(text: title.substring(0, start), style: baseStyle),
      TextSpan(
        text: title.substring(start, end),
        style: baseStyle.copyWith(color: highlightColor),
      ),
      if (end < title.length) TextSpan(text: title.substring(end), style: baseStyle),
    ];
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
              final item = entry.value;
              return _buildTrendingItem(
                colors,
                item.name,
                '${item.orderCount} orders',
                () => _startSearchFromTerm(item.name),
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
              final item = entry.value;
              return _buildTrendingItem(
                colors,
                item.name,
                '${item.orderCount} orders',
                () => _startSearchFromTerm(item.name),
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
              final item = entry.value;
              return _buildTrendingItem(
                colors,
                item.name,
                '${item.orderCount} orders',
                () => _startSearchFromTerm(item.name),
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
              final item = entry.value;
              return _buildTrendingItem(
                colors,
                item.name,
                '${item.orderCount} orders',
                () => _startSearchFromTerm(item.name),
              );
            }).toList(),
          );
        },
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildTrendingItem(AppColorsExtension colors, String name, String subtitle, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 20.w, vertical: 6.h),
        decoration: BoxDecoration(
          color: colors.backgroundPrimary,
          borderRadius: BorderRadius.circular(KBorderSize.borderMedium),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: SvgPicture.asset(
                Assets.icons.search,
                package: 'grab_go_shared',
                width: 22.w,
                height: 22.h,
                colorFilter: ColorFilter.mode(colors.textSecondary, BlendMode.srcIn),
              ),
            ),
            SizedBox(width: 10.w),
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
      height: 110.h,
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
                    padding: EdgeInsets.all(18.r),
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

  Widget _buildRecentSearches(AppColorsExtension colors) {
    if (_recentSearches.isEmpty) {
      return _buildEmptyState(colors, 'No recent searches yet');
    }

    return Column(
      children: _recentSearches.map((term) {
        return GestureDetector(
          onTap: () => _startSearchFromTerm(term),
          child: Container(
            margin: EdgeInsets.symmetric(horizontal: 20.w, vertical: 8.h),
            decoration: BoxDecoration(color: colors.backgroundPrimary),
            child: Row(
              children: [
                Center(
                  child: SvgPicture.asset(
                    Assets.icons.history,
                    package: 'grab_go_shared',
                    width: 22.w,
                    height: 22.h,
                    colorFilter: ColorFilter.mode(colors.textSecondary, BlendMode.srcIn),
                  ),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: Text(
                    term,
                    style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w600, color: colors.textPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                GestureDetector(
                  onTap: () => _removeRecentSearch(term),
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 4.h),
                    child: Icon(Icons.close, size: 18.sp, color: colors.textSecondary),
                  ),
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
