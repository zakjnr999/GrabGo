import 'dart:async';
import 'dart:convert';

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
import 'package:grab_go_customer/features/home/model/catalog_search_models.dart';
import 'package:grab_go_customer/features/home/model/filter_model.dart';
import 'package:grab_go_customer/features/home/model/food_category.dart';
import 'package:grab_go_customer/features/home/repository/catalog_search_repository.dart';
import 'package:grab_go_customer/features/home/viewmodel/food_provider.dart';
import 'package:grab_go_customer/features/pharmacy/model/pharmacy_item.dart';
import 'package:grab_go_customer/features/pharmacy/viewmodel/pharmacy_provider.dart';
import 'package:grab_go_customer/features/vendors/model/vendor_model.dart';
import 'package:grab_go_customer/features/vendors/widgets/vendor_card.dart';
import 'package:grab_go_customer/shared/viewmodels/native_location_provider.dart';
import 'package:grab_go_customer/shared/viewmodels/service_provider.dart';
import 'package:grab_go_customer/shared/widgets/filter_bottom_sheet.dart';
import 'package:grab_go_customer/shared/widgets/food_item_card.dart';
import 'package:grab_go_customer/shared/widgets/grocery_item_card.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

class SearchPage extends StatefulWidget {
  final String initialQuery;

  const SearchPage({super.key, this.initialQuery = ''});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

enum _SearchSortOption {
  relevance('relevance', 'Best match'),
  rating('rating', 'Top rated'),
  fastest('fastest', 'Fastest'),
  priceLow('price_low', 'Price low'),
  priceHigh('price_high', 'Price high'),
  newest('newest', 'Newest');

  final String apiValue;
  final String label;

  const _SearchSortOption(this.apiValue, this.label);
}

class _SearchPageState extends State<SearchPage> {
  final CatalogSearchRepository _searchRepository = CatalogSearchRepository();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  static const Duration _searchDebounceDuration = Duration(milliseconds: 320);
  static const List<String> _quickFilters = [
    'Fast delivery',
    'Under ₵20',
    'Top rated',
    'On sale',
  ];

  Timer? _searchDebounceTimer;
  String _searchQuery = '';
  String? _activeQuickFilterLabel;
  String _resolvedSearchKey = '';
  int _requestSerial = 0;
  bool _isSearching = false;
  FilterModel _activeFilter = FilterModel();
  _SearchSortOption _sortOption = _SearchSortOption.relevance;
  CatalogSearchResponse? _searchResponse;
  String? _searchError;
  List<String> _searchHistory = [];
  String? _lastServiceId;

  @override
  void initState() {
    super.initState();
    _loadSearchHistory();
    final initialQuery = widget.initialQuery.trim();
    if (initialQuery.isNotEmpty) {
      _searchQuery = initialQuery;
      _searchController.text = initialQuery;
      _searchController.selection = TextSelection.collapsed(
        offset: initialQuery.length,
      );
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (initialQuery.isNotEmpty) {
        _performSearch();
      } else {
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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final serviceId = context.read<ServiceProvider>().currentService.id;
    if (_lastServiceId == null) {
      _lastServiceId = serviceId;
      return;
    }
    if (_lastServiceId != serviceId) {
      _lastServiceId = serviceId;
      _handleServiceChanged();
    }
  }

  void _loadSearchHistory() {
    _searchHistory = CacheService.getSearchHistory();
    if (mounted) {
      setState(() {});
    }
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

  String _serviceLabel(ServiceProvider serviceProvider) {
    if (serviceProvider.isFoodService) return 'Food';
    if (serviceProvider.isGroceryService) return 'Groceries';
    if (serviceProvider.isPharmacyService) return 'Pharmacy';
    if (serviceProvider.isStoresService) return 'GrabMart';
    return 'Items';
  }

  String _serviceType(ServiceProvider serviceProvider) {
    if (serviceProvider.isFoodService) return 'food';
    if (serviceProvider.isGroceryService) return 'groceries';
    if (serviceProvider.isPharmacyService) return 'pharmacy';
    return 'convenience';
  }

  String _vendorLabel(ServiceProvider serviceProvider) {
    if (serviceProvider.isFoodService) return 'Restaurants';
    if (serviceProvider.isGroceryService) return 'Grocery Stores';
    if (serviceProvider.isPharmacyService) return 'Pharmacies';
    return 'Stores';
  }

  bool get _hasSearchContext =>
      _searchQuery.trim().isNotEmpty || _activeFilter.isActive;

  String _currentSearchKey() {
    return jsonEncode({
      'query': _searchQuery.trim(),
      'sort': _sortOption.apiValue,
      'filter': _activeFilter.toJson(),
    });
  }

  void _onSearchChanged(String rawQuery) {
    setState(() {});
    _searchDebounceTimer?.cancel();
    _searchDebounceTimer = Timer(_searchDebounceDuration, () {
      if (!mounted) return;
      _applySearchQuery(rawQuery);
    });
  }

  void _applySearchQuery(
    String rawQuery, {
    bool persist = false,
    bool immediate = false,
  }) {
    final nextQuery = rawQuery.trim();
    if (nextQuery == _searchQuery && !immediate) return;

    setState(() {
      _searchQuery = nextQuery;
      if (_searchQuery.isEmpty && !_activeFilter.isActive) {
        _searchResponse = null;
        _searchError = null;
      }
    });

    if (persist && nextQuery.isNotEmpty) {
      _persistSearchTerm(nextQuery);
    }

    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }

    if (_hasSearchContext) {
      _performSearch();
    }
  }

  void _applyQuickFilter(String label) {
    _searchDebounceTimer?.cancel();
    setState(() {
      _activeQuickFilterLabel = label;
      _activeFilter = switch (label) {
        'Fast delivery' => FilterModel(fast: true),
        'Under ₵20' => FilterModel(maxPrice: 20),
        'Top rated' => FilterModel(minRating: 4.5),
        'On sale' => FilterModel(onSale: true),
        _ => FilterModel(),
      };
    });
    _performSearch();
  }

  Future<void> _openFilterBottomSheet(ServiceProvider serviceProvider) async {
    final categories = _filterCategoriesForService(serviceProvider);
    final vendorNames = _filterVendorNames(serviceProvider);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (_) => FilterBottomSheet(
        initialFilter: _activeFilter,
        categories: categories,
        restaurants: vendorNames,
        vendorLabel: _vendorLabel(serviceProvider),
        isFood: serviceProvider.isFoodService,
        onApply: (filter) {
          setState(() {
            _activeQuickFilterLabel = null;
            _activeFilter = filter.copyWith();
          });
          if (_hasSearchContext) {
            _performSearch();
          }
        },
      ),
    );
  }

  Future<void> _performSearch() async {
    if (!_hasSearchContext) return;

    final requestId = ++_requestSerial;
    final serviceProvider = context.read<ServiceProvider>();
    final locationProvider = context.read<NativeLocationProvider>();
    final confirmedAddress = locationProvider.confirmedAddress;
    final searchKey = _currentSearchKey();

    setState(() {
      _isSearching = true;
      _searchError = null;
    });

    try {
      final response = await _searchRepository.search(
        serviceType: _serviceType(serviceProvider),
        query: _searchQuery,
        filter: _activeFilter,
        sort: _sortOption.apiValue,
        userLat: confirmedAddress?.latitude ?? locationProvider.latitude,
        userLng: confirmedAddress?.longitude ?? locationProvider.longitude,
      );

      if (!mounted || requestId != _requestSerial) return;

      setState(() {
        _searchResponse = response;
        _resolvedSearchKey = searchKey;
        _searchError = null;
        _isSearching = false;
      });
    } catch (error) {
      if (!mounted || requestId != _requestSerial) return;
      final message = _humanizeSearchError(error);
      setState(() {
        _searchResponse = null;
        _resolvedSearchKey = searchKey;
        _searchError = message;
        _isSearching = false;
      });
      AppToastMessage.show(
        context: context,
        message: message,
        backgroundColor: context.appColors.error,
        maxLines: 3,
      );
    }
  }

  String _humanizeSearchError(Object error) {
    final raw = error.toString().replaceFirst('Exception: ', '').trim();
    if (raw.isEmpty) {
      return 'Search is unavailable right now. Please try again.';
    }
    if (raw.toLowerCase().contains('failed host lookup') ||
        raw.toLowerCase().contains('socketexception')) {
      return 'No internet connection. Check your network and try again.';
    }
    return raw;
  }

  void _handleServiceChanged() {
    _searchDebounceTimer?.cancel();
    _requestSerial++;
    setState(() {
      _activeQuickFilterLabel = null;
      _activeFilter = FilterModel();
      _searchResponse = null;
      _searchError = null;
      _resolvedSearchKey = '';
      _isSearching = false;
    });
    if (_searchQuery.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _performSearch();
        }
      });
    }
  }

  void _selectSuggestion(String value) {
    _searchController.text = value;
    _searchController.selection = TextSelection.collapsed(offset: value.length);
    _applySearchQuery(value, persist: true, immediate: true);
    _searchFocusNode.requestFocus();
  }

  void _clearSearchInput() {
    _searchDebounceTimer?.cancel();
    _searchController.clear();
    _applySearchQuery('', immediate: true);
    _searchFocusNode.requestFocus();
  }

  void _clearFilters() {
    setState(() {
      _activeQuickFilterLabel = null;
      _activeFilter = FilterModel();
      if (_searchQuery.trim().isEmpty) {
        _searchResponse = null;
        _searchError = null;
      }
    });

    if (_hasSearchContext) {
      _performSearch();
    }
  }

  List<FoodCategoryModel> _filterCategoriesForService(
    ServiceProvider serviceProvider,
  ) {
    if (serviceProvider.isFoodService) {
      return context.read<FoodProvider>().categories;
    }
    if (serviceProvider.isGroceryService) {
      return context
          .read<GroceryProvider>()
          .categories
          .map(
            (category) => FoodCategoryModel(
              id: category.id,
              name: category.name,
              description: '',
              emoji: category.emoji,
              isActive: true,
              items: const [],
            ),
          )
          .toList(growable: false);
    }
    if (serviceProvider.isPharmacyService) {
      return context
          .read<PharmacyProvider>()
          .categories
          .map(
            (category) => FoodCategoryModel(
              id: category.id,
              name: category.name,
              description: '',
              emoji: category.emoji,
              isActive: true,
              items: const [],
            ),
          )
          .toList(growable: false);
    }
    return context
        .read<GrabMartProvider>()
        .categories
        .map(
          (category) => FoodCategoryModel(
            id: category.id,
            name: category.name,
            description: '',
            emoji: category.emoji,
            isActive: true,
            items: const [],
          ),
        )
        .toList(growable: false);
  }

  List<String> _filterVendorNames(ServiceProvider serviceProvider) {
    final names = <String>{};

    if (serviceProvider.isFoodService) {
      final provider = context.read<FoodProvider>();
      for (final category in provider.categories) {
        for (final item in category.items) {
          if (item.sellerName.trim().isNotEmpty) {
            names.add(item.sellerName.trim());
          }
        }
      }
      for (final vendor in provider.nearbyVendors) {
        if (vendor.displayName.trim().isNotEmpty) {
          names.add(vendor.displayName.trim());
        }
      }
      for (final vendor in provider.exclusiveVendors) {
        if (vendor.displayName.trim().isNotEmpty) {
          names.add(vendor.displayName.trim());
        }
      }
    } else if (serviceProvider.isGroceryService) {
      for (final item in context.read<GroceryProvider>().items) {
        if ((item.storeName ?? '').trim().isNotEmpty) {
          names.add(item.storeName!.trim());
        }
      }
    } else if (serviceProvider.isPharmacyService) {
      for (final item in context.read<PharmacyProvider>().items) {
        if ((item.storeName ?? '').trim().isNotEmpty) {
          names.add(item.storeName!.trim());
        }
      }
    } else {
      for (final item in context.read<GrabMartProvider>().items) {
        if ((item.storeName ?? '').trim().isNotEmpty) {
          names.add(item.storeName!.trim());
        }
      }
    }

    final sorted = names.toList(growable: false)..sort();
    return sorted;
  }

  List<CatalogSearchItemResult> _buildSuggestedItems(
    ServiceProvider serviceProvider,
  ) {
    final items = <CatalogSearchItemResult>[];
    final seen = <String>{};

    if (serviceProvider.isFoodService) {
      final provider = context.read<FoodProvider>();
      for (final category in provider.categories) {
        for (final item in category.items) {
          final key = '${item.id}_${item.restaurantId}';
          if (seen.add(key)) {
            items.add(
              CatalogSearchItemResult(
                displayItem: item,
                sourceItem: item,
                serviceType: 'food',
              ),
            );
          }
        }
      }
    } else if (serviceProvider.isGroceryService) {
      for (final item in context.read<GroceryProvider>().items) {
        if (seen.add('grocery_${item.id}_${item.storeId}')) {
          items.add(
            CatalogSearchItemResult(
              displayItem: item.toFoodItem(),
              sourceItem: item,
              serviceType: 'groceries',
            ),
          );
        }
      }
    } else if (serviceProvider.isPharmacyService) {
      for (final item in context.read<PharmacyProvider>().items) {
        if (seen.add('pharmacy_${item.id}_${item.storeId}')) {
          items.add(
            CatalogSearchItemResult(
              displayItem: item.toFoodItem(),
              sourceItem: item,
              serviceType: 'pharmacy',
            ),
          );
        }
      }
    } else {
      for (final item in context.read<GrabMartProvider>().items) {
        if (seen.add('grabmart_${item.id}_${item.storeId}')) {
          items.add(
            CatalogSearchItemResult(
              displayItem: item.toFoodItem(),
              sourceItem: item,
              serviceType: 'convenience',
            ),
          );
        }
      }
    }

    items.sort((a, b) {
      final availabilityCompare = (b.displayItem.isAvailable ? 1 : 0).compareTo(
        a.displayItem.isAvailable ? 1 : 0,
      );
      if (availabilityCompare != 0) return availabilityCompare;
      final orderCompare = b.displayItem.orderCount.compareTo(
        a.displayItem.orderCount,
      );
      if (orderCompare != 0) return orderCompare;
      return b.displayItem.rating.compareTo(a.displayItem.rating);
    });

    return items.take(8).toList(growable: false);
  }

  List<FoodCategoryModel> _recoveryCategories(ServiceProvider serviceProvider) {
    final categories = _filterCategoriesForService(serviceProvider);
    if (serviceProvider.isFoodService) {
      final sorted = [...categories]
        ..sort((a, b) => b.items.length.compareTo(a.items.length));
      return sorted.take(6).toList(growable: false);
    }
    return categories.take(6).toList(growable: false);
  }

  void _openCategory(
    FoodCategoryModel category,
    ServiceProvider serviceProvider,
  ) {
    context.push(
      '/categoryItems/${category.id}',
      extra: {
        'categoryId': category.id,
        'categoryName': category.name,
        'categoryEmoji': category.emoji,
        'serviceType': _serviceType(serviceProvider),
        'isFood': serviceProvider.isFoodService,
      },
    );
  }

  void _openSearchCategory(CatalogSearchCategory category) {
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

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final serviceProvider = context.watch<ServiceProvider>();
    final suggestedItems = _buildSuggestedItems(serviceProvider);
    final recoveryCategories = _recoveryCategories(serviceProvider);
    final response = _searchResponse;
    final vendors = response?.vendors ?? const <VendorModel>[];
    final categories = response?.categories ?? const <CatalogSearchCategory>[];
    final items = response?.items ?? const <CatalogSearchItemResult>[];
    final suggestions =
        response?.suggestions ?? const <CatalogSearchSuggestion>[];
    final hasResults =
        vendors.isNotEmpty || categories.isNotEmpty || items.isNotEmpty;
    final showLoadingSkeleton =
        _hasSearchContext &&
        _isSearching &&
        _currentSearchKey() != _resolvedSearchKey;
    final totalMatches = vendors.length + categories.length + items.length;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final systemUiOverlayStyle = SystemUiOverlayStyle(
      statusBarColor: isDark ? colors.backgroundPrimary : colors.accentOrange,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      systemNavigationBarColor: colors.backgroundPrimary,
      systemNavigationBarIconBrightness: isDark
          ? Brightness.light
          : Brightness.dark,
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
                child: ListView(
                  controller: _scrollController,
                  padding: EdgeInsets.only(bottom: 28.h),
                  children: [
                    if (_hasSearchContext)
                      _buildSectionHeader(
                        colors,
                        _searchQuery.isNotEmpty
                            ? 'Results for "$_searchQuery"'
                            : (_activeQuickFilterLabel ?? 'Filtered results'),
                        _searchError != null
                            ? _searchError!
                            : '$totalMatches matches across vendors, items and categories',
                        highlightedText: _searchQuery.isNotEmpty
                            ? _searchQuery
                            : null,
                      )
                    else
                      _buildSectionHeader(
                        colors,
                        'Search ${_serviceLabel(serviceProvider)}',
                        'Search vendors, items, categories and offers',
                      ),
                    SizedBox(height: 12.h),
                    if (!_hasSearchContext) ...[
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
                            children: _searchHistory
                                .map((term) {
                                  return ActionChip(
                                    label: Text(term),
                                    onPressed: () => _selectSuggestion(term),
                                    backgroundColor: colors.backgroundSecondary,
                                    labelStyle: TextStyle(
                                      fontSize: 12.sp,
                                      color: colors.textPrimary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      side: BorderSide(
                                        color: colors.inputBorder.withValues(
                                          alpha: 0.35,
                                        ),
                                      ),
                                      borderRadius: BorderRadius.circular(
                                        KBorderSize.border,
                                      ),
                                    ),
                                  );
                                })
                                .toList(growable: false),
                          ),
                        ),
                        SizedBox(height: 20.h),
                      ],
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20.w),
                        child: Text(
                          'Suggested for you',
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w700,
                            color: colors.textPrimary,
                          ),
                        ),
                      ),
                      SizedBox(height: 8.h),
                      if (suggestedItems.isEmpty)
                        _buildEmptyState(
                          colors,
                          'No items available to suggest yet.',
                        )
                      else
                        ...suggestedItems.map(
                          (item) => _buildItemSearchResult(
                            colors,
                            item,
                            persistQuery: false,
                          ),
                        ),
                    ] else if (showLoadingSkeleton) ...[
                      _buildSortControls(colors),
                      SizedBox(height: 12.h),
                      _buildSearchLoadingState(colors),
                    ] else if (_searchError != null && !hasResults) ...[
                      _buildSearchNoResultsState(
                        colors,
                        title: 'Search unavailable',
                        message: _searchError!,
                        serviceProvider: serviceProvider,
                        suggestedItems: suggestedItems,
                        recoveryCategories: recoveryCategories,
                        showRetry: true,
                      ),
                    ] else if (!hasResults) ...[
                      _buildSortControls(colors),
                      SizedBox(height: 12.h),
                      _buildSearchNoResultsState(
                        colors,
                        title: 'No matches found',
                        message:
                            'Try another term, clear filters, or explore nearby categories.',
                        serviceProvider: serviceProvider,
                        suggestedItems: suggestedItems,
                        recoveryCategories: recoveryCategories,
                        showRetry: false,
                      ),
                    ] else ...[
                      _buildSortControls(colors),
                      SizedBox(height: 12.h),
                      if (suggestions.isNotEmpty &&
                          _searchQuery.trim().isNotEmpty) ...[
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 20.w),
                          child: Text(
                            'Suggestions',
                            style: TextStyle(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w700,
                              color: colors.textPrimary,
                            ),
                          ),
                        ),
                        SizedBox(height: 8.h),
                        ...suggestions.map(
                          (suggestion) =>
                              _buildSuggestionTile(colors, suggestion),
                        ),
                        SizedBox(height: 14.h),
                      ],
                      if (vendors.isNotEmpty) ...[
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 20.w),
                          child: Text(
                            _vendorLabel(serviceProvider),
                            style: TextStyle(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w700,
                              color: colors.textPrimary,
                            ),
                          ),
                        ),
                        SizedBox(height: 8.h),
                        ...vendors.map(
                          (vendor) => VendorCard(
                            vendor: vendor,
                            onTap: () =>
                                context.push('/vendorDetails', extra: vendor),
                            showClosedOnImage: true,
                            highlightExclusiveBadge: true,
                            margin: EdgeInsets.symmetric(
                              horizontal: 20.w,
                              vertical: 6.h,
                            ),
                          ),
                        ),
                        SizedBox(height: 14.h),
                      ],
                      if (items.isNotEmpty) ...[
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 20.w),
                          child: Text(
                            'Items',
                            style: TextStyle(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w700,
                              color: colors.textPrimary,
                            ),
                          ),
                        ),
                        SizedBox(height: 8.h),
                        ...items.map(
                          (item) => _buildItemSearchResult(
                            colors,
                            item,
                            persistQuery: true,
                          ),
                        ),
                        SizedBox(height: 14.h),
                      ],
                      if (categories.isNotEmpty) ...[
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 20.w),
                          child: Text(
                            'Categories',
                            style: TextStyle(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w700,
                              color: colors.textPrimary,
                            ),
                          ),
                        ),
                        SizedBox(height: 8.h),
                        ...categories.map(
                          (category) =>
                              _buildCategorySearchResult(colors, category),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchHeader(
    AppColorsExtension colors,
    ServiceProvider serviceProvider,
  ) {
    return Container(
      color: colors.backgroundPrimary,
      padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 10.h),
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
                    colorFilter: ColorFilter.mode(
                      colors.textTertiary,
                      BlendMode.srcIn,
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      focusNode: _searchFocusNode,
                      autofocus: true,
                      onChanged: _onSearchChanged,
                      onSubmitted: (value) => _applySearchQuery(
                        value,
                        persist: true,
                        immediate: true,
                      ),
                      textInputAction: TextInputAction.search,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w500,
                      ),
                      decoration: InputDecoration(
                        isCollapsed: true,
                        border: InputBorder.none,
                        hintText:
                            'Search ${_serviceLabel(serviceProvider).toLowerCase()}',
                        hintStyle: TextStyle(
                          color: colors.textTertiary,
                          fontSize: 13.sp,
                        ),
                      ),
                    ),
                  ),
                  if (_searchController.text.isNotEmpty)
                    GestureDetector(
                      onTap: _clearSearchInput,
                      child: Icon(
                        Icons.close,
                        color: colors.textTertiary,
                        size: 18.sp,
                      ),
                    ),
                ],
              ),
            ),
          ),
          SizedBox(width: 10.w),
          GestureDetector(
            onTap: () => _openFilterBottomSheet(serviceProvider),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  height: 44,
                  width: 44,
                  decoration: BoxDecoration(
                    color: colors.backgroundSecondary,
                    shape: BoxShape.circle,
                  ),
                  padding: EdgeInsets.all(12.r),
                  child: SvgPicture.asset(
                    Assets.icons.slidersHorizontal,
                    package: 'grab_go_shared',
                    colorFilter: ColorFilter.mode(
                      colors.textPrimary,
                      BlendMode.srcIn,
                    ),
                  ),
                ),
                if (_activeFilter.isActive)
                  Positioned(
                    right: 2.w,
                    top: 2.h,
                    child: Container(
                      width: 10.w,
                      height: 10.w,
                      decoration: BoxDecoration(
                        color: colors.accentOrange,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: colors.backgroundPrimary,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(
    AppColorsExtension colors,
    String title,
    String subtitle, {
    String? highlightedText,
  }) {
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
      if (start > 0)
        TextSpan(text: title.substring(0, start), style: baseStyle),
      TextSpan(
        text: title.substring(start, end),
        style: baseStyle.copyWith(color: highlightColor),
      ),
      if (end < title.length)
        TextSpan(text: title.substring(end), style: baseStyle),
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
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w700,
              color: colors.textPrimary,
            ),
          ),
          SizedBox(height: 10.h),
          Wrap(
            spacing: 8.w,
            runSpacing: 8.h,
            children: _quickFilters
                .map((label) {
                  final isActive = _activeQuickFilterLabel == label;
                  return ActionChip(
                    label: Text(label),
                    padding: EdgeInsets.symmetric(
                      horizontal: 8.w,
                      vertical: 6.h,
                    ),
                    onPressed: () => _applyQuickFilter(label),
                    backgroundColor: isActive
                        ? colors.accentOrange
                        : colors.backgroundSecondary,
                    labelStyle: TextStyle(
                      fontSize: 12.sp,
                      color: isActive ? Colors.white : colors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                    shape: RoundedRectangleBorder(
                      side: BorderSide(
                        color: isActive
                            ? colors.accentOrange
                            : colors.inputBorder.withValues(alpha: 0.35),
                      ),
                      borderRadius: BorderRadius.circular(KBorderSize.border),
                    ),
                  );
                })
                .toList(growable: false),
          ),
        ],
      ),
    );
  }

  Widget _buildSortControls(AppColorsExtension colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 20.w),
          child: Row(
            children: [
              Text(
                'Sort by',
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
              ),
              const Spacer(),
              if (_activeFilter.isActive)
                TextButton(
                  onPressed: _clearFilters,
                  child: Text(
                    'Clear filters',
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w700,
                      color: colors.accentOrange,
                    ),
                  ),
                ),
            ],
          ),
        ),
        SizedBox(height: 8.h),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.symmetric(horizontal: 20.w),
          child: Row(
            children: _SearchSortOption.values
                .map((option) {
                  final isSelected = _sortOption == option;
                  return Padding(
                    padding: EdgeInsets.only(right: 8.w),
                    child: ChoiceChip(
                      label: Text(option.label),
                      selected: isSelected,
                      onSelected: (_) {
                        if (_sortOption == option) return;
                        setState(() {
                          _sortOption = option;
                        });
                        if (_hasSearchContext) {
                          _performSearch();
                        }
                      },
                      selectedColor: colors.accentOrange,
                      backgroundColor: colors.backgroundSecondary,
                      labelStyle: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? Colors.white : colors.textPrimary,
                      ),
                      side: BorderSide(
                        color: isSelected
                            ? colors.accentOrange
                            : colors.inputBorder.withValues(alpha: 0.35),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(KBorderSize.border),
                      ),
                    ),
                  );
                })
                .toList(growable: false),
          ),
        ),
      ],
    );
  }

  Widget _buildSuggestionTile(
    AppColorsExtension colors,
    CatalogSearchSuggestion suggestion,
  ) {
    return GestureDetector(
      onTap: () => _selectSuggestion(suggestion.value),
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 20.w, vertical: 5.h),
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
        decoration: BoxDecoration(
          color: colors.backgroundPrimary,
          borderRadius: BorderRadius.circular(KBorderSize.borderMedium),
          border: Border.all(
            color: colors.inputBorder.withValues(alpha: 0.3),
            width: 0.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 34.w,
              height: 34.w,
              decoration: BoxDecoration(
                color: colors.accentOrange.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.north_west_rounded,
                color: colors.accentOrange,
                size: 18.sp,
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    suggestion.value,
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary,
                    ),
                  ),
                  if (suggestion.subtitle.trim().isNotEmpty) ...[
                    SizedBox(height: 4.h),
                    Text(
                      suggestion.subtitle,
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Text(
              suggestion.type.toUpperCase(),
              style: TextStyle(
                fontSize: 10.sp,
                fontWeight: FontWeight.w700,
                color: colors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategorySearchResult(
    AppColorsExtension colors,
    CatalogSearchCategory category,
  ) {
    return GestureDetector(
      onTap: () => _openSearchCategory(category),
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 20.w, vertical: 6.h),
        decoration: BoxDecoration(
          color: colors.backgroundPrimary,
          borderRadius: BorderRadius.circular(KBorderSize.borderMedium),
          border: Border.all(
            color: colors.inputBorder.withValues(alpha: 0.3),
            width: 0.5,
          ),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
          child: Row(
            children: [
              Container(
                width: 40.w,
                height: 40.h,
                decoration: BoxDecoration(
                  color: colors.accentOrange.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    category.emoji.isNotEmpty ? category.emoji : '📦',
                    style: TextStyle(fontSize: 16.sp),
                  ),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category.name,
                      style: TextStyle(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      '${category.itemCount} items',
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              SvgPicture.asset(
                Assets.icons.navArrowRight,
                package: 'grab_go_shared',
                width: 20.w,
                height: 20.h,
                colorFilter: ColorFilter.mode(
                  colors.textSecondary,
                  BlendMode.srcIn,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildItemSearchResult(
    AppColorsExtension colors,
    CatalogSearchItemResult item, {
    required bool persistQuery,
  }) {
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

  Widget _buildSearchCardTrailing(
    AppColorsExtension colors,
    CartItem cartItem,
  ) {
    return Consumer<CartProvider>(
      builder: (context, provider, _) {
        final includeFoodCustomizations = cartItem is FoodItem;
        final isInCart = provider.hasItemInCart(
          cartItem,
          includeFoodCustomizations: includeFoodCustomizations,
        );
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
              color: isInCart
                  ? colors.accentOrange
                  : colors.backgroundSecondary,
              border: Border.all(
                color: isInCart ? colors.accentOrange : colors.inputBorder,
                width: 1,
              ),
            ),
            child: isItemPending
                ? SizedBox(
                    width: 16.w,
                    height: 16.w,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isInCart ? Colors.white : colors.accentOrange,
                      ),
                    ),
                  )
                : SvgPicture.asset(
                    isInCart ? Assets.icons.check : Assets.icons.cart,
                    package: 'grab_go_shared',
                    height: 16.h,
                    width: 16.h,
                    colorFilter: ColorFilter.mode(
                      isInCart ? Colors.white : colors.textPrimary,
                      BlendMode.srcIn,
                    ),
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

  Widget _buildEmptyState(AppColorsExtension colors, String message) {
    return Container(
      padding: EdgeInsets.all(40.r),
      child: Column(
        children: [
          SvgPicture.asset(
            Assets.icons.emptySearchIcon,
            package: 'grab_go_shared',
            width: 180.w,
            height: 180.h,
          ),
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

  Widget _buildSearchNoResultsState(
    AppColorsExtension colors, {
    required String title,
    required String message,
    required ServiceProvider serviceProvider,
    required List<CatalogSearchItemResult> suggestedItems,
    required List<FoodCategoryModel> recoveryCategories,
    required bool showRetry,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 24.h),
            decoration: BoxDecoration(
              color: colors.backgroundPrimary,
              borderRadius: BorderRadius.circular(KBorderSize.borderMedium),
              border: Border.all(
                color: colors.inputBorder.withValues(alpha: 0.25),
              ),
            ),
            child: Column(
              children: [
                SvgPicture.asset(
                  Assets.icons.emptySearchIcon,
                  package: 'grab_go_shared',
                  width: 160.w,
                  height: 160.h,
                ),
                SizedBox(height: 12.h),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  message,
                  style: TextStyle(
                    fontSize: 13.sp,
                    color: colors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 16.h),
                Wrap(
                  spacing: 8.w,
                  runSpacing: 8.h,
                  alignment: WrapAlignment.center,
                  children: [
                    if (showRetry)
                      AppButton(
                        onPressed: _performSearch,
                        backgroundColor: colors.accentOrange,
                        borderRadius: KBorderSize.borderRadius15,
                        buttonText: 'Retry',
                        width: 116.w,
                        height: 42.h,
                        textStyle: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13.sp,
                        ),
                      ),
                    if (_activeFilter.isActive)
                      AppButton(
                        onPressed: _clearFilters,
                        backgroundColor: colors.backgroundSecondary,
                        borderRadius: KBorderSize.borderRadius15,
                        buttonText: 'Clear filters',
                        width: 124.w,
                        height: 42.h,
                        textStyle: TextStyle(
                          color: colors.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 13.sp,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          if (recoveryCategories.isNotEmpty) ...[
            SizedBox(height: 20.h),
            Text(
              'Try these categories',
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
              ),
            ),
            SizedBox(height: 10.h),
            Wrap(
              spacing: 8.w,
              runSpacing: 8.h,
              children: recoveryCategories
                  .map((category) {
                    return ActionChip(
                      label: Text(
                        category.emoji.isNotEmpty
                            ? '${category.emoji} ${category.name}'
                            : category.name,
                      ),
                      onPressed: () => _openCategory(category, serviceProvider),
                      backgroundColor: colors.backgroundSecondary,
                      labelStyle: TextStyle(
                        fontSize: 12.sp,
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                      shape: RoundedRectangleBorder(
                        side: BorderSide(
                          color: colors.inputBorder.withValues(alpha: 0.35),
                        ),
                        borderRadius: BorderRadius.circular(KBorderSize.border),
                      ),
                    );
                  })
                  .toList(growable: false),
            ),
          ],
          if (suggestedItems.isNotEmpty) ...[
            SizedBox(height: 20.h),
            Text(
              'Popular right now',
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
              ),
            ),
            SizedBox(height: 8.h),
            ...suggestedItems
                .take(4)
                .map(
                  (item) =>
                      _buildItemSearchResult(colors, item, persistQuery: false),
                ),
          ],
        ],
      ),
    );
  }

  Widget _buildSearchLoadingState(AppColorsExtension colors) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: Column(
        children: List.generate(4, (index) {
          final showImage = index == 0;
          return Container(
            margin: EdgeInsets.only(bottom: 14.h),
            padding: EdgeInsets.all(12.r),
            decoration: BoxDecoration(
              color: colors.backgroundPrimary,
              borderRadius: BorderRadius.circular(KBorderSize.borderMedium),
              border: Border.all(
                color: colors.inputBorder.withValues(alpha: 0.18),
              ),
            ),
            child: Shimmer.fromColors(
              baseColor: isDark
                  ? colors.backgroundSecondary.withValues(alpha: 0.8)
                  : colors.inputBorder.withValues(alpha: 0.35),
              highlightColor: isDark
                  ? colors.backgroundSecondary.withValues(alpha: 0.45)
                  : colors.backgroundPrimary,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (showImage) ...[
                    Container(
                      height: 118.h,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(
                          KBorderSize.borderMedium,
                        ),
                      ),
                    ),
                    SizedBox(height: 12.h),
                  ],
                  _buildShimmerBox(width: 180.w, height: 16.h, radius: 6.r),
                  SizedBox(height: 10.h),
                  Row(
                    children: [
                      Expanded(
                        child: _buildShimmerBox(
                          width: double.infinity,
                          height: 12.h,
                          radius: 6.r,
                        ),
                      ),
                      SizedBox(width: 12.w),
                      _buildShimmerBox(width: 64.w, height: 12.h, radius: 6.r),
                    ],
                  ),
                  SizedBox(height: 12.h),
                  Row(
                    children: [
                      _buildShimmerBox(width: 96.w, height: 12.h, radius: 6.r),
                      SizedBox(width: 12.w),
                      _buildShimmerBox(width: 88.w, height: 12.h, radius: 6.r),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildShimmerBox({
    required double width,
    required double height,
    required double radius,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
