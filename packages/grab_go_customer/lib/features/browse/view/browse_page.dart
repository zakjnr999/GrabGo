import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_customer/features/cart/model/cart_item_interface.dart';
import 'package:grab_go_customer/features/cart/viewmodel/cart_provider.dart';
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
import 'package:grab_go_customer/shared/widgets/food_item_card.dart';
import 'package:grab_go_customer/shared/widgets/grocery_item_card.dart';
import 'package:grab_go_customer/shared/widgets/umbrella_header.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:provider/provider.dart';

class BrowsePage extends StatefulWidget {
  const BrowsePage({super.key});

  @override
  State<BrowsePage> createState() => _BrowsePageState();
}

class _BrowseCategoryEntry {
  final String id;
  final String name;
  final String emoji;
  final String serviceType;
  final bool isFood;
  final int itemCount;

  const _BrowseCategoryEntry({
    required this.id,
    required this.name,
    required this.emoji,
    required this.serviceType,
    required this.isFood,
    required this.itemCount,
  });
}

class _BrowseItemEntry {
  final FoodItem displayItem;
  final Object sourceItem;

  const _BrowseItemEntry({required this.displayItem, required this.sourceItem});
}

class _ScoredCategoryMatch {
  final _BrowseCategoryEntry category;
  final double score;

  const _ScoredCategoryMatch({required this.category, required this.score});
}

class _ScoredItemMatch {
  final _BrowseItemEntry item;
  final double score;

  const _ScoredItemMatch({required this.item, required this.score});
}

class _BrowsePageState extends State<BrowsePage> {
  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<double> _scrollOffsetNotifier = ValueNotifier<double>(0.0);
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  static const double _collapsedHeight = 70.0;
  static const double _scrollThreshold = 150.0;
  static const double _searchHeaderContentHeight = 64.0;
  static const Duration _modeTransitionDuration = Duration(milliseconds: 260);
  static const int _searchItemsPageSize = 12;
  static const Duration _searchDebounceDuration = Duration(milliseconds: 280);
  static const List<Map<String, String>> _quickSearches = [
    {'label': 'Fast delivery', 'subtitle': 'Under 30 minutes'},
    {'label': 'Under ₵20', 'subtitle': 'Budget-friendly options'},
    {'label': 'Top rated', 'subtitle': '4.5+ stars'},
    {'label': 'On sale', 'subtitle': 'Special discounts'},
  ];
  static const Map<String, List<String>> _tokenSynonyms = {
    'cheap': ['budget', 'affordable', 'low', 'discount'],
    'budget': ['cheap', 'affordable', 'low'],
    'fast': ['quick', 'express'],
    'quick': ['fast', 'express'],
    'sale': ['discount', 'deal', 'promo'],
    'discount': ['sale', 'deal', 'promo'],
    'medicine': ['drug', 'tablet', 'capsule', 'pharmacy'],
    'grocery': ['groceries', 'foodstuff'],
    'drink': ['beverage', 'juice', 'water', 'soda'],
    'snack': ['snacks'],
  };

  bool _isSearchMode = false;
  String _searchQuery = '';
  String? _activeQuickFilter;
  List<String> _recentSearches = [];
  int _visibleSearchItemCount = _searchItemsPageSize;
  bool _isLoadingMoreSearchItems = false;
  Timer? _searchDebounceTimer;

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

  void _onSearchTextChanged(String rawQuery) {
    _searchDebounceTimer?.cancel();
    _searchDebounceTimer = Timer(_searchDebounceDuration, () {
      if (!mounted) return;
      _applySearchQuery(rawQuery);
    });
  }

  void _applySearchQuery(String rawQuery) {
    final nextQuery = rawQuery.trim();
    if (nextQuery == _searchQuery) return;

    setState(() {
      _searchQuery = nextQuery;
      if (_searchQuery.isNotEmpty) {
        _activeQuickFilter = null;
      }
      _visibleSearchItemCount = _searchItemsPageSize;
      _isLoadingMoreSearchItems = false;
    });

    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
  }

  void _openInlineSearch() {
    if (_isSearchMode) return;
    setState(() {
      _isSearchMode = true;
      _activeQuickFilter = null;
      _visibleSearchItemCount = _searchItemsPageSize;
      _isLoadingMoreSearchItems = false;
    });
    _loadRecentSearches();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(0);
        }
        _searchFocusNode.requestFocus();
      }
    });
  }

  void _startSearchFromTerm(String term) {
    final value = term.trim();
    if (value.isEmpty) return;

    _searchDebounceTimer?.cancel();
    _persistRecentSearch(value);
    setState(() {
      _isSearchMode = true;
      _searchQuery = value;
      _activeQuickFilter = null;
      _visibleSearchItemCount = _searchItemsPageSize;
      _isLoadingMoreSearchItems = false;
      _searchController.text = value;
      _searchController.selection = TextSelection.collapsed(offset: value.length);
    });

    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _searchFocusNode.requestFocus();
      }
    });
  }

  void _closeInlineSearch() {
    _searchDebounceTimer?.cancel();
    _searchFocusNode.unfocus();
    setState(() {
      _isSearchMode = false;
      _searchQuery = '';
      _activeQuickFilter = null;
      _searchController.clear();
      _visibleSearchItemCount = _searchItemsPageSize;
      _isLoadingMoreSearchItems = false;
    });
  }

  void _setQuickFilter(String label) {
    _searchDebounceTimer?.cancel();
    _searchFocusNode.unfocus();
    setState(() {
      _isSearchMode = true;
      _activeQuickFilter = label;
      _searchQuery = '';
      _searchController.clear();
      _visibleSearchItemCount = _searchItemsPageSize;
      _isLoadingMoreSearchItems = false;
    });

    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
  }

  double _contentTopPadding(Size size, double topInset) {
    if (_isSearchMode) {
      return topInset + _searchHeaderContentHeight.h + 10.h;
    }
    return UmbrellaHeaderMetrics.contentPaddingFor(size);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _searchDebounceTimer?.cancel();
    _scrollController.dispose();
    _scrollOffsetNotifier.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
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
      statusBarColor: _isSearchMode ? colors.backgroundPrimary : colors.accentOrange,
      statusBarIconBrightness: _isSearchMode ? (isDark ? Brightness.light : Brightness.dark) : Brightness.light,
      systemNavigationBarColor: colors.backgroundPrimary,
      systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
    );
    final content = _buildContent(colors, isDark, serviceProvider, size, padding.top);
    final scrollContent = _isSearchMode
        ? content
        : AppRefreshIndicator(
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
            child: content,
          );
    final animatedContent = AnimatedSwitcher(
      duration: _modeTransitionDuration,
      switchInCurve: Curves.easeOutQuart,
      switchOutCurve: Curves.easeInQuart,
      layoutBuilder: (currentChild, previousChildren) => currentChild ?? const SizedBox.shrink(),
      transitionBuilder: (child, animation) {
        final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutQuart);
        final slide = Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero).animate(curved);
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(position: slide, child: child),
        );
      },
      child: KeyedSubtree(key: ValueKey(_isSearchMode ? 'search_content' : 'browse_content'), child: scrollContent),
    );
    final animatedHeader = AnimatedSwitcher(
      duration: _modeTransitionDuration,
      switchInCurve: Curves.easeOutQuart,
      switchOutCurve: Curves.easeInQuart,
      layoutBuilder: (currentChild, previousChildren) => currentChild ?? const SizedBox.shrink(),
      transitionBuilder: (child, animation) {
        final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutQuart);
        final offsetAnimation = Tween<Offset>(begin: const Offset(0, -0.06), end: Offset.zero).animate(curved);
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(position: offsetAnimation, child: child),
        );
      },
      child: KeyedSubtree(
        key: ValueKey(_isSearchMode ? 'search_header' : 'browse_header'),
        child: _buildCollapsibleHeader(colors, size, padding),
      ),
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: systemUiOverlayStyle,
      child: Scaffold(
        backgroundColor: colors.backgroundPrimary,
        body: SafeArea(
          top: false,
          child: Stack(
            children: [
              animatedContent,
              Positioned(top: 0, left: 0, right: 0, child: animatedHeader),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCollapsibleHeader(AppColorsExtension colors, Size size, EdgeInsets padding) {
    if (_isSearchMode) {
      final headerHeight = padding.top + _searchHeaderContentHeight.h;
      return Container(
        height: headerHeight,
        color: colors.backgroundPrimary,
        padding: EdgeInsets.fromLTRB(16.w, padding.top + 10.h, 16.w, 10.h),
        child: Row(
          children: [
            Container(
              height: 44,
              width: 44,
              decoration: BoxDecoration(color: colors.backgroundSecondary, shape: BoxShape.circle),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _closeInlineSearch,
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
            SizedBox(width: 10.w),
            Expanded(
              child: Container(
                height: 44,
                padding: EdgeInsets.symmetric(horizontal: 12.w),
                decoration: BoxDecoration(
                  color: colors.backgroundSecondary,
                  borderRadius: BorderRadius.circular(KBorderSize.border),
                ),
                child: Row(
                  children: [
                    SvgPicture.asset(
                      Assets.icons.search,
                      package: 'grab_go_shared',
                      width: 18.w,
                      height: 18.h,
                      colorFilter: ColorFilter.mode(colors.textTertiary, BlendMode.srcIn),
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        focusNode: _searchFocusNode,
                        autofocus: true,
                        onChanged: _onSearchTextChanged,
                        onSubmitted: (value) {
                          _applySearchQuery(value);
                          _persistRecentSearch(value);
                        },
                        style: TextStyle(color: colors.textPrimary, fontSize: 14.sp, fontWeight: FontWeight.w500),
                        textInputAction: TextInputAction.search,
                        decoration: InputDecoration(
                          isCollapsed: true,
                          border: InputBorder.none,
                          hintText: 'Search items or categories',
                          hintStyle: TextStyle(color: colors.textTertiary, fontSize: 13.sp),
                        ),
                      ),
                    ),
                    if (_searchQuery.isNotEmpty)
                      GestureDetector(
                        onTap: () {
                          _searchDebounceTimer?.cancel();
                          _searchController.clear();
                          _applySearchQuery('');
                          _searchFocusNode.requestFocus();
                        },
                        child: SvgPicture.asset(
                          Assets.icons.xmark,
                          package: 'grab_go_shared',
                          width: 18.w,
                          height: 18.h,
                          colorFilter: ColorFilter.mode(colors.textTertiary, BlendMode.srcIn),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

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
                      onPressed: _openInlineSearch,
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
    if (_isSearchMode) {
      return _buildSearchModeContent(colors, serviceProvider, size, topInset);
    }

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

  Widget _buildSearchModeContent(
    AppColorsExtension colors,
    ServiceProvider serviceProvider,
    Size size,
    double topInset,
  ) {
    final categoryMatches = _findCategoryMatches(serviceProvider);
    final itemMatches = _findItemMatches(serviceProvider);
    final visibleItemCount = math.min(_visibleSearchItemCount, itemMatches.length);
    final visibleItemMatches = itemMatches.take(visibleItemCount).toList(growable: false);

    final hasQuery = _searchQuery.isNotEmpty;
    final hasQuickFilter = _activeQuickFilter != null;
    final hasResults = categoryMatches.isNotEmpty || itemMatches.isNotEmpty;

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.metrics.pixels >= notification.metrics.maxScrollExtent - 220) {
          _loadMoreSearchItems(itemMatches.length);
        }
        return false;
      },
      child: ListView(
        controller: _scrollController,
        padding: EdgeInsets.only(top: _contentTopPadding(size, topInset), bottom: 32.h),
        children: [
          if (hasQuickFilter)
            _buildSectionHeader(colors, '$_activeQuickFilter', 'Showing matches for this quick filter')
          else if (hasQuery)
            _buildSectionHeader(
              colors,
              'Results for "$_searchQuery"',
              '${itemMatches.length + categoryMatches.length} matches found',
              highlightedText: _searchQuery,
            )
          else
            _buildSectionHeader(colors, 'Search', 'Find items or categories'),
          SizedBox(height: 12.h),
          if (!hasQuery && !hasQuickFilter) ...[
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.w),
              child: Text(
                'Try a quick filter',
                style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600, color: colors.textPrimary),
              ),
            ),
            SizedBox(height: 10.h),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.w),
              child: Wrap(
                spacing: 8.w,
                runSpacing: 2.h,
                children: _quickSearches.map((search) {
                  return ActionChip(
                    label: Text(search['label']!),
                    padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 6.h),
                    onPressed: () => _setQuickFilter(search['label']!),
                    backgroundColor: colors.backgroundSecondary,
                    labelStyle: TextStyle(fontSize: 12.sp, color: colors.textPrimary, fontWeight: FontWeight.w600),
                    shape: RoundedRectangleBorder(
                      side: BorderSide(color: colors.inputBorder.withValues(alpha: 0.35)),
                      borderRadius: BorderRadius.circular(KBorderSize.border),
                    ),
                  );
                }).toList(),
              ),
            ),
          ] else if (!hasResults) ...[
            _buildSearchNoResultsState(colors, 'No matches found. Try another term or quick filter.'),
          ] else ...[
            if (categoryMatches.isNotEmpty) ...[
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.w),
                child: Text(
                  'Categories',
                  style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700, color: colors.textPrimary),
                ),
              ),
              SizedBox(height: 8.h),
              ...categoryMatches.map((category) => _buildCategorySearchResult(colors, category)),
              SizedBox(height: 14.h),
            ],
            if (itemMatches.isNotEmpty) ...[
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.w),
                child: Text(
                  'Items',
                  style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700, color: colors.textPrimary),
                ),
              ),
              SizedBox(height: 8.h),
              ...visibleItemMatches.map((item) => _buildItemSearchResult(colors, item)),
              if (_isLoadingMoreSearchItems)
                Padding(
                  padding: EdgeInsets.only(top: 8.h),
                  child: Center(
                    child: SizedBox(
                      width: 20.w,
                      height: 20.w,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(colors.accentOrange),
                      ),
                    ),
                  ),
                ),
              if (!_isLoadingMoreSearchItems && visibleItemCount < itemMatches.length)
                Padding(
                  padding: EdgeInsets.only(top: 8.h),
                  child: Center(
                    child: Text(
                      'Scroll to load more',
                      style: TextStyle(fontSize: 12.sp, color: colors.textSecondary),
                    ),
                  ),
                ),
            ],
          ],
        ],
      ),
    );
  }

  void _loadMoreSearchItems(int totalCount) {
    if (_isLoadingMoreSearchItems) return;
    if (_visibleSearchItemCount >= totalCount) return;

    setState(() {
      _isLoadingMoreSearchItems = true;
    });

    Future.delayed(const Duration(milliseconds: 120), () {
      if (!mounted) return;
      setState(() {
        _visibleSearchItemCount = math.min(_visibleSearchItemCount + _searchItemsPageSize, totalCount);
        _isLoadingMoreSearchItems = false;
      });
    });
  }

  List<_BrowseItemEntry> _collectSearchableItems(ServiceProvider serviceProvider) {
    if (serviceProvider.isFoodService) {
      final provider = Provider.of<FoodProvider>(context, listen: false);
      final items = <_BrowseItemEntry>[];
      final seen = <String>{};
      for (final category in provider.categories) {
        for (final item in category.items) {
          final key = '${item.id}_${item.sellerId}';
          if (seen.add(key)) {
            items.add(_BrowseItemEntry(displayItem: item, sourceItem: item));
          }
        }
      }
      return items;
    }

    if (serviceProvider.isGroceryService) {
      final provider = Provider.of<GroceryProvider>(context, listen: false);
      return provider.items.map((item) => _BrowseItemEntry(displayItem: item.toFoodItem(), sourceItem: item)).toList();
    }

    if (serviceProvider.isPharmacyService) {
      final provider = Provider.of<PharmacyProvider>(context, listen: false);
      return provider.items.map((item) => _BrowseItemEntry(displayItem: item.toFoodItem(), sourceItem: item)).toList();
    }

    if (serviceProvider.isStoresService) {
      final provider = Provider.of<GrabMartProvider>(context, listen: false);
      return provider.items.map((item) => _BrowseItemEntry(displayItem: item.toFoodItem(), sourceItem: item)).toList();
    }

    return [];
  }

  List<_BrowseCategoryEntry> _collectSearchableCategories(ServiceProvider serviceProvider) {
    if (serviceProvider.isFoodService) {
      final provider = Provider.of<FoodProvider>(context, listen: false);
      return provider.categories
          .where((category) => category.items.isNotEmpty)
          .map(
            (category) => _BrowseCategoryEntry(
              id: category.id,
              name: category.name,
              emoji: category.emoji,
              serviceType: 'food',
              isFood: true,
              itemCount: category.items.length,
            ),
          )
          .toList();
    }

    if (serviceProvider.isGroceryService) {
      final provider = Provider.of<GroceryProvider>(context, listen: false);
      return provider.categories
          .map(
            (category) => _BrowseCategoryEntry(
              id: category.id,
              name: category.name,
              emoji: category.emoji,
              serviceType: 'groceries',
              isFood: false,
              itemCount: provider.items.where((item) => item.categoryId == category.id).length,
            ),
          )
          .where((category) => category.itemCount > 0)
          .toList();
    }

    if (serviceProvider.isPharmacyService) {
      final provider = Provider.of<PharmacyProvider>(context, listen: false);
      return provider.categories
          .map(
            (category) => _BrowseCategoryEntry(
              id: category.id,
              name: category.name,
              emoji: category.emoji,
              serviceType: 'pharmacy',
              isFood: false,
              itemCount: provider.items.where((item) => item.categoryId == category.id).length,
            ),
          )
          .where((category) => category.itemCount > 0)
          .toList();
    }

    if (serviceProvider.isStoresService) {
      final provider = Provider.of<GrabMartProvider>(context, listen: false);
      return provider.categories
          .map(
            (category) => _BrowseCategoryEntry(
              id: category.id,
              name: category.name,
              emoji: category.emoji,
              serviceType: 'convenience',
              isFood: false,
              itemCount: provider.items.where((item) => item.categoryId == category.id).length,
            ),
          )
          .where((category) => category.itemCount > 0)
          .toList();
    }

    return [];
  }

  List<_BrowseCategoryEntry> _findCategoryMatches(ServiceProvider serviceProvider) {
    if (_searchQuery.isEmpty || _activeQuickFilter != null) {
      return [];
    }

    final normalizedQuery = _normalizeText(_searchQuery);
    final queryTokens = _expandedQueryTokens(_searchQuery);
    final scoredCategories = <_ScoredCategoryMatch>[];

    for (final category in _collectSearchableCategories(serviceProvider)) {
      final score = _scoreCategoryMatch(category: category, normalizedQuery: normalizedQuery, queryTokens: queryTokens);
      if (score > 0) {
        scoredCategories.add(_ScoredCategoryMatch(category: category, score: score));
      }
    }

    scoredCategories.sort((a, b) => b.score.compareTo(a.score));
    return scoredCategories.take(12).map((match) => match.category).toList(growable: false);
  }

  List<_BrowseItemEntry> _findItemMatches(ServiceProvider serviceProvider) {
    final items = _collectSearchableItems(serviceProvider);

    if (_activeQuickFilter != null) {
      return _applyQuickFilter(items, _activeQuickFilter!);
    }

    if (_searchQuery.isEmpty) {
      return [];
    }

    final normalizedQuery = _normalizeText(_searchQuery);
    final queryTokens = _expandedQueryTokens(_searchQuery);
    final numericQuery = _extractNumericValue(_searchQuery);
    final categoryLookup = _buildCategoryNameLookup(serviceProvider);
    final scoredMatches = <_ScoredItemMatch>[];

    for (final item in items) {
      final score = _scoreItemMatch(
        item: item,
        normalizedQuery: normalizedQuery,
        queryTokens: queryTokens,
        categoryName: categoryLookup[_itemCategoryId(item.sourceItem)],
        numericQuery: numericQuery,
      );
      if (score > 0) {
        scoredMatches.add(_ScoredItemMatch(item: item, score: score));
      }
    }

    scoredMatches.sort((a, b) {
      final scoreCompare = b.score.compareTo(a.score);
      if (scoreCompare != 0) return scoreCompare;
      return b.item.displayItem.orderCount.compareTo(a.item.displayItem.orderCount);
    });

    return scoredMatches.take(120).map((match) => match.item).toList(growable: false);
  }

  List<_BrowseItemEntry> _applyQuickFilter(List<_BrowseItemEntry> items, String filterLabel) {
    List<_BrowseItemEntry> filtered;
    switch (filterLabel) {
      case 'Fast delivery':
        filtered = items
            .where((item) => item.displayItem.deliveryTimeMinutes > 0 && item.displayItem.deliveryTimeMinutes <= 30)
            .toList();
        break;
      case 'Under ₵20':
        filtered = items.where((item) => item.displayItem.price <= 20).toList();
        break;
      case 'Top rated':
        filtered = items.where((item) => item.displayItem.rating >= 4.5).toList();
        break;
      case 'On sale':
        filtered = items.where((item) => item.displayItem.discountPercentage > 0).toList();
        break;
      default:
        filtered = items;
        break;
    }

    filtered.sort((a, b) => b.displayItem.orderCount.compareTo(a.displayItem.orderCount));
    return filtered;
  }

  String _normalizeText(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9\s]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  List<String> _expandedQueryTokens(String query) {
    final normalized = _normalizeText(query);
    if (normalized.isEmpty) return const [];

    final expanded = <String>{};
    for (final token in normalized.split(' ')) {
      if (token.isEmpty) continue;
      expanded.add(token);
      final synonyms = _tokenSynonyms[token];
      if (synonyms != null) {
        expanded.addAll(synonyms.map(_normalizeText).where((value) => value.isNotEmpty));
      }
    }
    return expanded.toList(growable: false);
  }

  String _firstWord(String text) {
    final normalized = _normalizeText(text);
    if (normalized.isEmpty) return '';
    return normalized.split(' ').first;
  }

  Set<String> _bigrams(String input) {
    final normalized = _normalizeText(input).replaceAll(' ', '');
    if (normalized.isEmpty) return const {};
    if (normalized.length == 1) return {normalized};

    final grams = <String>{};
    for (var i = 0; i < normalized.length - 1; i++) {
      grams.add(normalized.substring(i, i + 2));
    }
    return grams;
  }

  double _diceCoefficient(String a, String b) {
    final gramsA = _bigrams(a);
    final gramsB = _bigrams(b);
    if (gramsA.isEmpty || gramsB.isEmpty) return 0;

    final intersection = gramsA.intersection(gramsB).length.toDouble();
    return (2 * intersection) / (gramsA.length + gramsB.length);
  }

  bool _startsWithAnyToken(String target, List<String> tokens) {
    if (target.isEmpty || tokens.isEmpty) return false;
    final words = target.split(' ');
    for (final token in tokens) {
      if (token.length < 2) continue;
      if (words.any((word) => word.startsWith(token))) {
        return true;
      }
    }
    return false;
  }

  bool _containsAllTokens(String target, List<String> tokens) {
    if (target.isEmpty || tokens.isEmpty) return false;
    for (final token in tokens) {
      if (token.length < 2) continue;
      if (!target.contains(token)) return false;
    }
    return true;
  }

  double _scoreCategoryMatch({
    required _BrowseCategoryEntry category,
    required String normalizedQuery,
    required List<String> queryTokens,
  }) {
    if (normalizedQuery.isEmpty) return 0;
    final name = _normalizeText(category.name);
    if (name.isEmpty) return 0;

    var score = 0.0;
    if (name == normalizedQuery) score += 220;
    if (name.startsWith(normalizedQuery)) score += 150;
    if (name.contains(normalizedQuery)) score += 120;
    if (_startsWithAnyToken(name, queryTokens)) score += 45;
    if (_containsAllTokens(name, queryTokens)) score += 35;

    final similarity = _diceCoefficient(normalizedQuery, name);
    if (similarity >= 0.45) {
      score += similarity * 60;
    }

    score += math.min(category.itemCount.toDouble(), 50) * 0.4;
    return score >= 40 ? score : 0;
  }

  double _scoreItemMatch({
    required _BrowseItemEntry item,
    required String normalizedQuery,
    required List<String> queryTokens,
    required String? categoryName,
    required double? numericQuery,
  }) {
    if (normalizedQuery.isEmpty) return 0;

    final display = item.displayItem;
    final name = _normalizeText(display.name);
    final description = _normalizeText(display.description);
    final seller = _normalizeText(display.sellerName);
    final category = _normalizeText(categoryName ?? '');
    final tags = _normalizeText(display.dietaryTags.join(' '));
    final searchable = '$name $description $seller $category $tags';

    var score = 0.0;
    var hasQuerySignal = false;
    if (name == normalizedQuery) {
      score += 260;
      hasQuerySignal = true;
    }
    if (name.startsWith(normalizedQuery)) {
      score += 180;
      hasQuerySignal = true;
    }
    if (name.contains(normalizedQuery)) {
      score += 145;
      hasQuerySignal = true;
    }
    if (seller.contains(normalizedQuery)) {
      score += 100;
      hasQuerySignal = true;
    }
    if (category.contains(normalizedQuery)) {
      score += 95;
      hasQuerySignal = true;
    }
    if (description.contains(normalizedQuery)) {
      score += 75;
      hasQuerySignal = true;
    }
    if (tags.contains(normalizedQuery)) {
      score += 60;
      hasQuerySignal = true;
    }

    if (_containsAllTokens(searchable, queryTokens)) {
      score += 70;
      hasQuerySignal = true;
    } else if (_startsWithAnyToken(name, queryTokens)) {
      score += 45;
      hasQuerySignal = true;
    } else if (_startsWithAnyToken(searchable, queryTokens)) {
      score += 25;
      hasQuerySignal = true;
    }

    if (normalizedQuery.length >= 3) {
      final similarity = _diceCoefficient(normalizedQuery, name);
      if (similarity >= 0.42) {
        score += similarity * 55;
        hasQuerySignal = true;
      }
    }

    final queryFirstWord = _firstWord(normalizedQuery);
    if (queryFirstWord.length >= 2 && seller.startsWith(queryFirstWord)) {
      score += 25;
      hasQuerySignal = true;
    }

    if (numericQuery != null) {
      final priceDelta = (display.price - numericQuery).abs();
      if (priceDelta <= 1) {
        score += 45;
      } else if (display.price <= numericQuery) {
        score += 22;
      }
    }

    if (!hasQuerySignal && numericQuery == null) {
      return 0;
    }

    if (display.isAvailable) score += 10;
    score += math.min(display.orderCount.toDouble(), 100) * 0.25;

    return score >= 35 ? score : 0;
  }

  Map<String, String> _buildCategoryNameLookup(ServiceProvider serviceProvider) {
    if (serviceProvider.isFoodService) {
      final provider = Provider.of<FoodProvider>(context, listen: false);
      return {for (final category in provider.categories) category.id: category.name};
    }

    if (serviceProvider.isGroceryService) {
      final provider = Provider.of<GroceryProvider>(context, listen: false);
      return {for (final category in provider.categories) category.id: category.name};
    }

    if (serviceProvider.isPharmacyService) {
      final provider = Provider.of<PharmacyProvider>(context, listen: false);
      return {for (final category in provider.categories) category.id: category.name};
    }

    if (serviceProvider.isStoresService) {
      final provider = Provider.of<GrabMartProvider>(context, listen: false);
      return {for (final category in provider.categories) category.id: category.name};
    }

    return const {};
  }

  String? _itemCategoryId(Object sourceItem) {
    if (sourceItem is GroceryItem) return sourceItem.categoryId;
    if (sourceItem is PharmacyItem) return sourceItem.categoryId;
    if (sourceItem is GrabMartItem) return sourceItem.categoryId;
    return null;
  }

  double? _extractNumericValue(String query) {
    final match = RegExp(r'\d+(\.\d+)?').firstMatch(query);
    if (match == null) return null;
    return double.tryParse(match.group(0) ?? '');
  }

  void _openCategoryFromSearch(_BrowseCategoryEntry category) {
    context.push(
      '/categoryItems/${category.id}',
      extra: {
        'categoryId': category.id,
        'categoryName': category.name,
        'categoryEmoji': category.emoji,
        'serviceType': category.serviceType,
        'isFood': category.isFood,
      },
    );
  }

  Widget _buildCategorySearchResult(AppColorsExtension colors, _BrowseCategoryEntry category) {
    return GestureDetector(
      onTap: () => _openCategoryFromSearch(category),
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
              width: 40.w,
              height: 40.h,
              decoration: BoxDecoration(color: colors.accentOrange.withValues(alpha: 0.14), shape: BoxShape.circle),
              child: Center(
                child: Text(category.emoji.isNotEmpty ? category.emoji : '📦', style: TextStyle(fontSize: 16.sp)),
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category.name,
                    style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w600, color: colors.textPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    '${category.itemCount} items',
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

  Widget _buildItemSearchResult(AppColorsExtension colors, _BrowseItemEntry item) {
    final source = item.sourceItem;

    if (source is FoodItem) {
      return FoodItemCard(
        item: source,
        margin: EdgeInsets.symmetric(horizontal: 20.w, vertical: 6.h),
        onTap: () => context.push('/foodDetails', extra: source),
        trailing: _buildSearchCardTrailing(colors, source),
      );
    }

    if (source is GroceryItem) {
      return GroceryItemCard(
        item: source,
        margin: EdgeInsets.symmetric(horizontal: 20.w, vertical: 6.h),
        onTap: () => context.push('/foodDetails', extra: source),
        trailing: _buildSearchCardTrailing(colors, source),
      );
    }

    if (source is PharmacyItem) {
      return GroceryItemCard(
        item: _pharmacyItemToCardModel(source),
        margin: EdgeInsets.symmetric(horizontal: 20.w, vertical: 6.h),
        onTap: () => context.push('/foodDetails', extra: source),
        trailing: _buildSearchCardTrailing(colors, source),
      );
    }

    if (source is GrabMartItem) {
      return GroceryItemCard(
        item: _grabMartItemToCardModel(source),
        margin: EdgeInsets.symmetric(horizontal: 20.w, vertical: 6.h),
        onTap: () => context.push('/foodDetails', extra: source),
        trailing: _buildSearchCardTrailing(colors, source),
      );
    }

    return FoodItemCard(
      item: item.displayItem,
      margin: EdgeInsets.symmetric(horizontal: 20.w, vertical: 6.h),
      onTap: () => context.push('/foodDetails', extra: source),
      trailing: _buildSearchCardTrailing(colors, item.displayItem),
    );
  }

  Widget _buildSearchCardTrailing(AppColorsExtension colors, CartItem cartItem) {
    return Consumer<CartProvider>(
      builder: (context, provider, _) {
        final includeFoodCustomizations = cartItem is FoodItem;
        final isInCart = provider.hasItemInCart(cartItem, includeFoodCustomizations: includeFoodCustomizations);
        final isItemPending = provider.isItemOperationPendingForDisplay(
          cartItem,
          includeFoodCustomizations: includeFoodCustomizations,
        );
        final itemForAction = provider.resolveItemForCartAction(
          cartItem,
          includeFoodCustomizations: includeFoodCustomizations,
        );

        return GestureDetector(
          onTap: () {
            if (isItemPending) return;
            if (isInCart && itemForAction != null) {
              provider.removeItemCompletely(itemForAction);
            } else {
              provider.addToCart(cartItem, context: context);
            }
          },
          child: Container(
            padding: EdgeInsets.all(8.r),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isInCart ? colors.accentOrange : colors.backgroundSecondary,
              border: Border.all(color: isInCart ? colors.accentOrange : colors.inputBorder, width: 1),
            ),
            child: isItemPending
                ? SizedBox(
                    width: 16.w,
                    height: 16.w,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(isInCart ? Colors.white : colors.accentOrange),
                    ),
                  )
                : SvgPicture.asset(
                    isInCart ? Assets.icons.check : Assets.icons.cart,
                    package: 'grab_go_shared',
                    height: 16.h,
                    width: 16.w,
                    colorFilter: ColorFilter.mode(isInCart ? Colors.white : colors.textPrimary, BlendMode.srcIn),
                  ),
          ),
        );
      },
    );
  }

  GroceryItem _pharmacyItemToCardModel(PharmacyItem item) {
    return GroceryItem(
      id: item.id,
      name: item.name,
      description: item.description,
      image: item.image,
      price: item.price,
      unit: item.unit,
      categoryId: item.categoryId,
      categoryName: item.categoryName,
      categoryEmoji: item.categoryEmoji,
      storeId: item.storeId,
      storeName: item.storeName ?? 'Pharmacy',
      storeLogo: item.storeLogo,
      brand: item.brand,
      stock: item.stock,
      isAvailable: item.isAvailable,
      discountPercentage: item.discountPercentage,
      discountEndDate: item.discountEndDate,
      tags: item.tags,
      rating: item.rating,
      reviewCount: item.reviewCount,
      orderCount: item.orderCount,
      createdAt: item.createdAt,
    );
  }

  GroceryItem _grabMartItemToCardModel(GrabMartItem item) {
    return GroceryItem(
      id: item.id,
      name: item.name,
      description: item.description,
      image: item.image,
      price: item.price,
      unit: item.unit,
      categoryId: item.categoryId,
      categoryName: item.categoryName,
      categoryEmoji: item.categoryEmoji,
      storeId: item.storeId,
      storeName: item.storeName ?? 'GrabMart',
      storeLogo: item.storeLogo,
      brand: item.brand,
      stock: item.stock,
      isAvailable: item.isAvailable,
      discountPercentage: item.discountPercentage,
      discountEndDate: item.discountEndDate,
      tags: item.tags,
      rating: item.rating,
      reviewCount: item.reviewCount,
      orderCount: item.orderCount,
      createdAt: item.createdAt,
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

  Widget _buildSearchNoResultsState(AppColorsExtension colors, String message) {
    final minHeight = (MediaQuery.sizeOf(context).height * 0.58).clamp(300.0, 520.0).toDouble();
    return Container(
      constraints: BoxConstraints(minHeight: minHeight),
      alignment: Alignment.center,
      padding: EdgeInsets.symmetric(horizontal: 40.w, vertical: 12.h),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset(Assets.icons.emptySearchIcon, package: 'grab_go_shared', width: 180.w, height: 180.w),
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
