import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_customer/features/cart/model/cart_item_interface.dart';
import 'package:grab_go_customer/features/cart/viewmodel/cart_provider.dart';
import 'package:grab_go_customer/features/grabmart/model/grabmart_item.dart';
import 'package:grab_go_customer/features/grabmart/viewmodel/grabmart_provider.dart';
import 'package:grab_go_customer/features/groceries/model/grocery_item.dart';
import 'package:grab_go_customer/features/groceries/viewmodel/grocery_provider.dart';
import 'package:grab_go_customer/features/home/model/food_category.dart';
import 'package:grab_go_customer/features/home/viewmodel/food_provider.dart';
import 'package:grab_go_customer/features/pharmacy/model/pharmacy_item.dart';
import 'package:grab_go_customer/features/pharmacy/viewmodel/pharmacy_provider.dart';
import 'package:grab_go_customer/shared/viewmodels/service_provider.dart';
import 'package:grab_go_customer/shared/widgets/food_item_card.dart';
import 'package:grab_go_customer/shared/widgets/grocery_item_card.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:provider/provider.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchCategoryEntry {
  final String id;
  final String name;
  final String emoji;
  final String serviceType;
  final bool isFood;
  final int itemCount;

  const _SearchCategoryEntry({
    required this.id,
    required this.name,
    required this.emoji,
    required this.serviceType,
    required this.isFood,
    required this.itemCount,
  });
}

class _SearchItemEntry {
  final FoodItem displayItem;
  final Object sourceItem;

  const _SearchItemEntry({required this.displayItem, required this.sourceItem});
}

class _ScoredCategoryMatch {
  final _SearchCategoryEntry category;
  final double score;

  const _ScoredCategoryMatch({required this.category, required this.score});
}

class _ScoredItemMatch {
  final _SearchItemEntry item;
  final double score;

  const _ScoredItemMatch({required this.item, required this.score});
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  static const int _searchItemsPageSize = 12;
  static const Duration _searchDebounceDuration = Duration(milliseconds: 280);
  static const List<String> _quickFilters = ['Fast delivery', 'Under ₵20', 'Top rated', 'On sale'];
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

  List<String> _searchHistory = [];
  String _searchQuery = '';
  String? _activeQuickFilter;
  int _visibleSearchItemCount = _searchItemsPageSize;
  bool _isLoadingMoreSearchItems = false;
  Timer? _searchDebounceTimer;

  @override
  void initState() {
    super.initState();
    _loadSearchHistory();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _searchFocusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _searchDebounceTimer?.cancel();
    _scrollController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _loadSearchHistory() {
    _searchHistory = CacheService.getSearchHistory();
    if (mounted) setState(() {});
  }

  void _persistSearchTerm(String term) {
    final value = term.trim();
    if (value.isEmpty) return;
    CacheService.addSearchTerm(value);
    _loadSearchHistory();
  }

  void _clearSearchHistory() {
    CacheService.clearSearchHistory();
    _loadSearchHistory();
  }

  void _onSearchChanged(String rawQuery) {
    if (mounted) {
      setState(() {});
    }
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

  void _setQuickFilter(String label) {
    _searchDebounceTimer?.cancel();
    _searchFocusNode.unfocus();
    setState(() {
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

  void _clearSearchInput() {
    _searchDebounceTimer?.cancel();
    _searchController.clear();
    _applySearchQuery('');
    _searchFocusNode.requestFocus();
  }

  bool _isCurrentServiceLoading(ServiceProvider serviceProvider) {
    if (serviceProvider.isFoodService) {
      final provider = Provider.of<FoodProvider>(context, listen: false);
      return provider.isLoading;
    }
    if (serviceProvider.isGroceryService) {
      final provider = Provider.of<GroceryProvider>(context, listen: false);
      return provider.isLoadingItems || provider.isLoadingCategories;
    }
    if (serviceProvider.isPharmacyService) {
      final provider = Provider.of<PharmacyProvider>(context, listen: false);
      return provider.isLoadingItems || provider.isLoadingCategories;
    }
    if (serviceProvider.isStoresService) {
      final provider = Provider.of<GrabMartProvider>(context, listen: false);
      return provider.isLoadingItems || provider.isLoadingCategories;
    }
    return false;
  }

  String _serviceLabel(ServiceProvider serviceProvider) {
    if (serviceProvider.isFoodService) return 'Food';
    if (serviceProvider.isGroceryService) return 'Groceries';
    if (serviceProvider.isPharmacyService) return 'Pharmacy';
    if (serviceProvider.isStoresService) return 'GrabMart';
    return 'Items';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final serviceProvider = Provider.of<ServiceProvider>(context);
    final categoryMatches = _findCategoryMatches(serviceProvider);
    final itemMatches = _findItemMatches(serviceProvider);
    final visibleItemCount = math.min(_visibleSearchItemCount, itemMatches.length);
    final visibleItemMatches = itemMatches.take(visibleItemCount).toList(growable: false);
    final hasQuery = _searchQuery.isNotEmpty;
    final hasQuickFilter = _activeQuickFilter != null;
    final hasSearchContext = hasQuery || hasQuickFilter;
    final hasResults = categoryMatches.isNotEmpty || itemMatches.isNotEmpty;
    final allItems = _collectSearchableItems(serviceProvider);
    final suggestedItems = _buildSuggestedItems(allItems);
    final isLoading = _isCurrentServiceLoading(serviceProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final systemUiOverlayStyle = SystemUiOverlayStyle(
      statusBarColor: isDark ? colors.backgroundPrimary : colors.accentOrange,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      systemNavigationBarColor: colors.backgroundPrimary,
      systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: systemUiOverlayStyle,
      child: Scaffold(
        backgroundColor: colors.backgroundPrimary,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _buildSearchHeader(colors, serviceProvider),
              Expanded(
                child: NotificationListener<ScrollNotification>(
                  onNotification: (notification) {
                    if (!hasSearchContext) return false;
                    if (notification.metrics.pixels >= notification.metrics.maxScrollExtent - 220) {
                      _loadMoreSearchItems(itemMatches.length);
                    }
                    return false;
                  },
                  child: ListView(
                    controller: _scrollController,
                    padding: EdgeInsets.only(bottom: 28.h),
                    children: [
                      if (_activeQuickFilter != null)
                        _buildSectionHeader(colors, _activeQuickFilter!, 'Showing matches for this quick filter')
                      else if (_searchQuery.isNotEmpty)
                        _buildSectionHeader(
                          colors,
                          'Results for "$_searchQuery"',
                          '${itemMatches.length + categoryMatches.length} matches found',
                          highlightedText: _searchQuery,
                        )
                      else
                        _buildSectionHeader(
                          colors,
                          'Search ${_serviceLabel(serviceProvider)}',
                          'Find items or categories',
                        ),
                      SizedBox(height: 12.h),
                      if (!hasSearchContext) ...[
                        _buildQuickFilters(colors),
                        SizedBox(height: 20.h),
                        if (_searchHistory.isNotEmpty) ...[
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 20.w),
                            child: Row(
                              children: [
                                Text(
                                  'Recent searches',
                                  style: TextStyle(
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.w700,
                                    color: colors.textPrimary,
                                  ),
                                ),
                                const Spacer(),
                                TextButton(
                                  onPressed: _clearSearchHistory,
                                  child: Text(
                                    'Clear',
                                    style: TextStyle(
                                      fontSize: 12.sp,
                                      fontWeight: FontWeight.w600,
                                      color: colors.accentOrange,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 6.h),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 20.w),
                            child: Wrap(
                              spacing: 8.w,
                              runSpacing: 8.h,
                              children: _searchHistory.map((term) {
                                return ActionChip(
                                  label: Text(term),
                                  onPressed: () {
                                    _searchController.text = term;
                                    _searchController.selection = TextSelection.collapsed(offset: term.length);
                                    _applySearchQuery(term);
                                    _searchFocusNode.requestFocus();
                                  },
                                  backgroundColor: colors.backgroundSecondary,
                                  labelStyle: TextStyle(
                                    fontSize: 12.sp,
                                    color: colors.textPrimary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    side: BorderSide(color: colors.inputBorder.withValues(alpha: 0.35)),
                                    borderRadius: BorderRadius.circular(KBorderSize.border),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                          SizedBox(height: 20.h),
                        ],
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 20.w),
                          child: Text(
                            'Suggested for you',
                            style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700, color: colors.textPrimary),
                          ),
                        ),
                        SizedBox(height: 8.h),
                        if (isLoading && suggestedItems.isEmpty)
                          Padding(
                            padding: EdgeInsets.only(top: 18.h),
                            child: Center(
                              child: SizedBox(
                                width: 22.w,
                                height: 22.h,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(colors.accentOrange),
                                ),
                              ),
                            ),
                          )
                        else if (suggestedItems.isEmpty)
                          _buildEmptyState(colors, 'No items available to suggest yet.')
                        else
                          ...suggestedItems.map((item) => _buildItemSearchResult(colors, item, persistQuery: false)),
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
                          ...visibleItemMatches.map((item) => _buildItemSearchResult(colors, item, persistQuery: true)),
                          if (_isLoadingMoreSearchItems)
                            Padding(
                              padding: EdgeInsets.only(top: 8.h),
                              child: Center(
                                child: SizedBox(
                                  width: 20.w,
                                  height: 20.h,
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
                ),
              ),
            ],
          ),
        ),
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

  List<_SearchItemEntry> _buildSuggestedItems(List<_SearchItemEntry> allItems) {
    final sorted = [...allItems];
    sorted.sort((a, b) {
      final availabilityCompare = (b.displayItem.isAvailable ? 1 : 0).compareTo(a.displayItem.isAvailable ? 1 : 0);
      if (availabilityCompare != 0) return availabilityCompare;
      final orderCompare = b.displayItem.orderCount.compareTo(a.displayItem.orderCount);
      if (orderCompare != 0) return orderCompare;
      return b.displayItem.rating.compareTo(a.displayItem.rating);
    });
    return sorted.take(8).toList(growable: false);
  }

  List<_SearchItemEntry> _collectSearchableItems(ServiceProvider serviceProvider) {
    if (serviceProvider.isFoodService) {
      final provider = Provider.of<FoodProvider>(context, listen: false);
      final items = <_SearchItemEntry>[];
      final seen = <String>{};
      for (final category in provider.categories) {
        for (final item in category.items) {
          final key = '${item.id}_${item.sellerId}';
          if (seen.add(key)) {
            items.add(_SearchItemEntry(displayItem: item, sourceItem: item));
          }
        }
      }
      return items;
    }

    if (serviceProvider.isGroceryService) {
      final provider = Provider.of<GroceryProvider>(context, listen: false);
      return provider.items.map((item) => _SearchItemEntry(displayItem: item.toFoodItem(), sourceItem: item)).toList();
    }

    if (serviceProvider.isPharmacyService) {
      final provider = Provider.of<PharmacyProvider>(context, listen: false);
      return provider.items.map((item) => _SearchItemEntry(displayItem: item.toFoodItem(), sourceItem: item)).toList();
    }

    if (serviceProvider.isStoresService) {
      final provider = Provider.of<GrabMartProvider>(context, listen: false);
      return provider.items.map((item) => _SearchItemEntry(displayItem: item.toFoodItem(), sourceItem: item)).toList();
    }

    return [];
  }

  List<_SearchCategoryEntry> _collectSearchableCategories(ServiceProvider serviceProvider) {
    if (serviceProvider.isFoodService) {
      final provider = Provider.of<FoodProvider>(context, listen: false);
      return provider.categories
          .where((category) => category.items.isNotEmpty)
          .map(
            (category) => _SearchCategoryEntry(
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
            (category) => _SearchCategoryEntry(
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
            (category) => _SearchCategoryEntry(
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
            (category) => _SearchCategoryEntry(
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

  List<_SearchCategoryEntry> _findCategoryMatches(ServiceProvider serviceProvider) {
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

  List<_SearchItemEntry> _findItemMatches(ServiceProvider serviceProvider) {
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

  List<_SearchItemEntry> _applyQuickFilter(List<_SearchItemEntry> items, String filterLabel) {
    List<_SearchItemEntry> filtered;
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
    required _SearchCategoryEntry category,
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
    required _SearchItemEntry item,
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

  void _openCategoryFromSearch(_SearchCategoryEntry category) {
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

  Widget _buildCategorySearchResult(AppColorsExtension colors, _SearchCategoryEntry category) {
    return GestureDetector(
      onTap: () => _openCategoryFromSearch(category),
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 20.w, vertical: 6.h),
        decoration: BoxDecoration(
          color: colors.backgroundPrimary,
          borderRadius: BorderRadius.circular(KBorderSize.borderMedium),
          border: Border.all(color: colors.inputBorder.withValues(alpha: 0.3), width: 0.5),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
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
      ),
    );
  }

  Widget _buildItemSearchResult(AppColorsExtension colors, _SearchItemEntry item, {required bool persistQuery}) {
    final source = item.sourceItem;

    void onTap() {
      if (persistQuery && _searchQuery.isNotEmpty) {
        _persistSearchTerm(_searchQuery);
      }
      context.push('/foodDetails', extra: source);
    }

    if (source is FoodItem) {
      return FoodItemCard(
        item: source,
        margin: EdgeInsets.symmetric(horizontal: 20.w, vertical: 6.h),
        onTap: onTap,
        trailing: _buildSearchCardTrailing(colors, source),
      );
    }

    if (source is GroceryItem) {
      return GroceryItemCard(
        item: source,
        margin: EdgeInsets.symmetric(horizontal: 20.w, vertical: 6.h),
        onTap: onTap,
        trailing: _buildSearchCardTrailing(colors, source),
      );
    }

    if (source is PharmacyItem) {
      return GroceryItemCard(
        item: _pharmacyItemToCardModel(source),
        margin: EdgeInsets.symmetric(horizontal: 20.w, vertical: 6.h),
        onTap: onTap,
        trailing: _buildSearchCardTrailing(colors, source),
      );
    }

    if (source is GrabMartItem) {
      return GroceryItemCard(
        item: _grabMartItemToCardModel(source),
        margin: EdgeInsets.symmetric(horizontal: 20.w, vertical: 6.h),
        onTap: onTap,
        trailing: _buildSearchCardTrailing(colors, source),
      );
    }

    return FoodItemCard(
      item: item.displayItem,
      margin: EdgeInsets.symmetric(horizontal: 20.w, vertical: 6.h),
      onTap: onTap,
      trailing: _buildSearchCardTrailing(colors, item.displayItem),
    );
  }

  Widget _buildSearchCardTrailing(AppColorsExtension colors, CartItem cartItem) {
    return Consumer<CartProvider>(
      builder: (context, provider, _) {
        final isInCart = provider.cartItems.containsKey(cartItem);
        final isItemPending = provider.isItemOperationPending(cartItem);

        return GestureDetector(
          onTap: () {
            if (isItemPending) return;
            if (isInCart) {
              provider.removeItemCompletely(cartItem);
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
                    width: 16.h,
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

  Widget _buildSearchHeader(AppColorsExtension colors, ServiceProvider serviceProvider) {
    return Container(
      color: colors.backgroundPrimary,
      padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 10.h),
      child: Row(
        children: [
          Container(
            height: 44,
            width: 44,
            decoration: BoxDecoration(color: colors.backgroundSecondary, shape: BoxShape.circle),
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
                      onChanged: _onSearchChanged,
                      onSubmitted: (value) => _persistSearchTerm(value),
                      textInputAction: TextInputAction.search,
                      style: TextStyle(color: colors.textPrimary, fontSize: 14.sp, fontWeight: FontWeight.w500),
                      decoration: InputDecoration(
                        isCollapsed: true,
                        border: InputBorder.none,
                        hintText: 'Search ${_serviceLabel(serviceProvider).toLowerCase()}',
                        hintStyle: TextStyle(color: colors.textTertiary, fontSize: 13.sp),
                      ),
                    ),
                  ),
                  if (_searchController.text.isNotEmpty)
                    GestureDetector(
                      onTap: _clearSearchInput,
                      child: Icon(Icons.close, color: colors.textTertiary, size: 18.sp),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
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

  Widget _buildQuickFilters(AppColorsExtension colors) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick filters',
            style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700, color: colors.textPrimary),
          ),
          SizedBox(height: 10.h),
          Wrap(
            spacing: 8.w,
            runSpacing: 2.h,
            children: _quickFilters.map((label) {
              return ActionChip(
                label: Text(label),
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 6.h),
                onPressed: () => _setQuickFilter(label),
                backgroundColor: colors.backgroundSecondary,
                labelStyle: TextStyle(fontSize: 12.sp, color: colors.textPrimary, fontWeight: FontWeight.w600),
                shape: RoundedRectangleBorder(
                  side: BorderSide(color: colors.inputBorder.withValues(alpha: 0.35)),
                  borderRadius: BorderRadius.circular(KBorderSize.border),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(AppColorsExtension colors, String message) {
    return Container(
      padding: EdgeInsets.all(40.r),
      child: Column(
        children: [
          SvgPicture.asset(Assets.icons.emptySearchIcon, package: 'grab_go_shared', width: 180.w, height: 180.h),
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
          SvgPicture.asset(Assets.icons.emptySearchIcon, package: 'grab_go_shared', width: 180.w, height: 180.h),
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
