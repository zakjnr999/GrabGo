// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_customer/features/home/model/food_category.dart';
import 'package:grab_go_customer/features/home/viewmodel/food_provider.dart';
import 'package:grab_go_customer/features/cart/viewmodel/cart_provider.dart';
import 'package:grab_go_customer/shared/services/cache_service.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:grab_go_customer/shared/widgets/cached_image_widget.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  late ScrollController _scrollController;
  List<String> _searchHistory = [];
  List<FoodItem> _searchResults = [];
  List<FoodItem> _suggestions = [];
  bool _isSearching = false;
  String _currentSearchQuery = '';
  int _itemsToShow = 10;
  final int _itemsPerPage = 10;
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
    _loadSearchHistory();
    _loadSuggestions();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;

    // Load more when scrolled to 90% of the content
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent * 0.9) {
      if (!_isLoadingMore && _itemsToShow < _searchResults.length) {
        _loadMoreItems();
      }
    }
  }

  void _loadMoreItems() {
    setState(() {
      _isLoadingMore = true;
    });

    // Simulate loading delay for smooth UX
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _itemsToShow = (_itemsToShow + _itemsPerPage).clamp(0, _searchResults.length);
          _isLoadingMore = false;
        });
      }
    });
  }

  void _loadSearchHistory() {
    _searchHistory = CacheService.getSearchHistory();
    setState(() {});
  }

  void _loadSuggestions() {
    final foodProvider = Provider.of<FoodProvider>(context, listen: false);
    final allFoods = <FoodItem>[];
    final Set<String> seenItemKeys = {};

    // Collect items and remove duplicates immediately
    for (var category in foodProvider.categories) {
      for (var item in category.items) {
        // Use a unique key to identify duplicates
        final key = '${item.id}_${item.sellerId}';
        if (!seenItemKeys.contains(key)) {
          seenItemKeys.add(key);
          allFoods.add(item);
        }
      }
    }

    allFoods.sort((a, b) => b.rating.compareTo(a.rating));
    _suggestions = allFoods.take(6).toList();
    setState(() {});
  }

  void _onSearchChanged(String query) {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
        _currentSearchQuery = '';
        _itemsToShow = _itemsPerPage; // Reset items to show
      });
      return;
    }

    _currentSearchQuery = query;
    _isSearching = true;
    _performSearch(query);
  }

  void _performSearch(String query) {
    final foodProvider = Provider.of<FoodProvider>(context, listen: false);
    final results = <FoodItem>[];
    final Set<String> seenItemKeys = {};

    // Search through all categories and remove duplicates immediately
    for (var category in foodProvider.categories) {
      for (var item in category.items) {
        // Use a unique key to identify duplicates
        final key = '${item.id}_${item.sellerId}';

        // Check if item matches search query and hasn't been added yet
        if (!seenItemKeys.contains(key) &&
            (item.name.toLowerCase().contains(query.toLowerCase()) ||
                item.description.toLowerCase().contains(query.toLowerCase()) ||
                item.sellerName.toLowerCase().contains(query.toLowerCase()))) {
          seenItemKeys.add(key);
          results.add(item);
        }
      }
    }

    setState(() {
      _searchResults = results;
      _itemsToShow = _itemsPerPage; // Reset to initial page size when new search
    });
  }

  void _onSearchSubmitted(String query) {
    if (query.trim().isEmpty) return;

    CacheService.addSearchTerm(query.trim());
    _loadSearchHistory();

    if (mounted) {
      context.pop();
    }
  }

  void _onHistoryItemTap(String term) {
    _searchController.text = term;
    _onSearchChanged(term);
    _focusNode.requestFocus();
  }

  void _onResultClicked(FoodItem item) {
    if (_currentSearchQuery.isNotEmpty) {
      CacheService.addSearchTerm(_currentSearchQuery.trim());
      _loadSearchHistory();
    }

    context.push("/foodDetails", extra: item);
  }

  void _clearSearchHistory() {
    CacheService.clearSearchHistory();
    _loadSearchHistory();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: colors.backgroundSecondary,
      appBar: AppBar(
        backgroundColor: colors.backgroundPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        leading: Container(
          margin: EdgeInsets.all(8.r),
          child: GestureDetector(
            onTap: () => context.pop(),
            child: Container(
              decoration: BoxDecoration(color: colors.backgroundSecondary, shape: BoxShape.circle),
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
        title: Container(
          height: 45.h,
          decoration: BoxDecoration(
            color: colors.backgroundSecondary,
            borderRadius: BorderRadius.circular(KBorderSize.border),
            border: Border.all(color: colors.inputBorder, width: 0.5),
          ),
          child: Row(
            children: [
              SizedBox(width: 12.w),
              SvgPicture.asset(
                Assets.icons.search,
                package: 'grab_go_shared',
                height: KIconSize.md,
                width: KIconSize.md,
                colorFilter: ColorFilter.mode(colors.textTertiary, BlendMode.srcIn),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: TextField(
                  cursorOpacityAnimates: true,
                  controller: _searchController,
                  focusNode: _focusNode,
                  autofocus: true,
                  onChanged: _onSearchChanged,
                  onSubmitted: _onSearchSubmitted,
                  style: TextStyle(color: colors.textPrimary, fontSize: 14.sp, fontWeight: FontWeight.w500),
                  decoration: InputDecoration(
                    contentPadding: EdgeInsets.only(bottom: 5.h),
                    border: InputBorder.none,
                    hintText: "Search by food or restaurant...",
                    hintStyle: TextStyle(color: colors.textTertiary, fontSize: 14.sp),
                  ),
                ),
              ),
              if (_searchController.text.isNotEmpty)
                GestureDetector(
                  onTap: () {
                    _searchController.clear();
                    _onSearchChanged('');
                    _focusNode.requestFocus();
                  },
                  child: Padding(
                    padding: EdgeInsets.only(right: 8.w),
                    child: Icon(Icons.clear, size: 20.sp, color: colors.textTertiary),
                  ),
                ),
            ],
          ),
        ),
      ),
      body: ListView(
        controller: _scrollController,
        padding: EdgeInsets.all(20.w),
        children: [
          if (_isSearching && _searchResults.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Search Results",
                      style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w800, color: colors.textPrimary),
                    ),
                    Text(
                      "${_searchResults.length} found",
                      style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w600, color: colors.textSecondary),
                    ),
                  ],
                ),
                SizedBox(height: 16.h),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _itemsToShow.clamp(0, _searchResults.length) + (_isLoadingMore ? 1 : 0),
                  itemBuilder: (context, index) {
                    // Show loading indicator at the end
                    if (index >= _itemsToShow.clamp(0, _searchResults.length)) {
                      return Padding(
                        padding: EdgeInsets.symmetric(vertical: 16.h),
                        child: Center(
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
                            decoration: BoxDecoration(
                              color: colors.backgroundPrimary,
                              borderRadius: BorderRadius.circular(20.r),
                              border: Border.all(color: colors.accentGreen.withOpacity(0.3), width: 1),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 18.w,
                                  height: 18.h,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(colors.accentOrange),
                                  ),
                                ),
                                SizedBox(width: 12.w),
                                Text(
                                  "Loading more...",
                                  style: TextStyle(
                                    fontSize: 13.sp,
                                    fontWeight: FontWeight.w600,
                                    color: colors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }

                    return _buildFoodItem(_searchResults[index], colors, isDark, isFromSearch: true);
                  },
                ),
              ],
            )
          else if (_isSearching && _searchResults.isEmpty)
            SizedBox(
              width: double.infinity,
              height: 500.h,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: EdgeInsets.all(20.r),
                    decoration: BoxDecoration(color: colors.accentOrange.withOpacity(0.1), shape: BoxShape.circle),
                    child: SvgPicture.asset(
                      Assets.icons.utensilsCrossed,
                      package: 'grab_go_shared',
                      colorFilter: ColorFilter.mode(colors.accentOrange, BlendMode.srcIn),
                      width: 40.w,
                      height: 40.h,
                    ),
                  ),
                  SizedBox(height: 16.h),
                  Text(
                    "No results found",
                    style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w700, color: colors.textPrimary),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    "Try searching for something else",
                    style: TextStyle(fontSize: 14.sp, color: colors.textSecondary, height: 1.4),
                  ),
                ],
              ),
            )
          else ...[
            if (_searchHistory.isNotEmpty) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      SvgPicture.asset(
                        Assets.icons.clock,
                        package: 'grab_go_shared',
                        colorFilter: ColorFilter.mode(colors.textSecondary, BlendMode.srcIn),
                        height: 18.h,
                        width: 18.w,
                      ),
                      SizedBox(width: 8.w),
                      Text(
                        "Recent Searches",
                        style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w700, color: colors.textPrimary),
                      ),
                    ],
                  ),
                  TextButton(
                    onPressed: _clearSearchHistory,
                    child: Text(
                      "Clear",
                      style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600, color: colors.accentOrange),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12.h),
              Wrap(
                spacing: 8.w,
                runSpacing: 8.h,
                children: _searchHistory.map((term) {
                  return GestureDetector(
                    onTap: () => _onHistoryItemTap(term),
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
                      decoration: BoxDecoration(
                        color: colors.backgroundPrimary,
                        borderRadius: BorderRadius.circular(KBorderSize.borderMedium),
                        border: Border.all(color: colors.inputBorder.withOpacity(0.3), width: 0.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(5),
                            spreadRadius: 0,
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SvgPicture.asset(
                            Assets.icons.clock,
                            package: 'grab_go_shared',
                            colorFilter: ColorFilter.mode(colors.textSecondary, BlendMode.srcIn),
                            height: 14.h,
                            width: 14.w,
                          ),
                          SizedBox(width: 6.w),
                          Text(
                            term,
                            style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w500, color: colors.textPrimary),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              SizedBox(height: 32.h),
            ],

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
                  "You Might Like",
                  style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w800, color: colors.textPrimary),
                ),
              ],
            ),
            SizedBox(height: 16.h),
            _suggestions.isEmpty
                ? Shimmer.fromColors(
                    baseColor: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                    highlightColor: isDark ? Colors.grey.shade700 : Colors.grey.shade100,
                    child: Column(
                      children: List.generate(3, (index) {
                        return Container(
                          height: 90.h,
                          margin: EdgeInsets.only(bottom: 12.h),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(KBorderSize.borderMedium),
                          ),
                        );
                      }),
                    ),
                  )
                : Column(
                    children: _suggestions
                        .map((item) => _buildFoodItem(item, colors, isDark, isFromSearch: false))
                        .toList(),
                  ),
          ],
        ],
      ),
    );
  }

  Widget _buildFoodItem(FoodItem item, AppColorsExtension colors, bool isDark, {bool isFromSearch = false}) {
    return GestureDetector(
      onTap: () {
        if (isFromSearch) {
          _onResultClicked(item);
        } else {
          context.push("/foodDetails", extra: item);
        }
      },
      child: Container(
        margin: EdgeInsets.only(bottom: 12.h),
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
                        width: 24.w,
                        height: 24.h,
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
                    Text(
                      item.name,
                      style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w700, color: colors.textPrimary),
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
                          style: TextStyle(fontSize: 12.sp, color: colors.textPrimary, fontWeight: FontWeight.w600),
                        ),
                        SizedBox(width: 8.w),
                        Container(
                          width: 3.w,
                          height: 3.h,
                          decoration: BoxDecoration(shape: BoxShape.circle, color: colors.textSecondary),
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
                          style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w500, color: colors.textSecondary),
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
                            style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w800, color: colors.accentOrange),
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
  }
}
