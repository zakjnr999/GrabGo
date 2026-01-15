import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_customer/features/groceries/model/grocery_category.dart';
import 'package:grab_go_customer/features/groceries/model/grocery_item.dart';
import 'package:grab_go_customer/features/groceries/viewmodel/grocery_provider.dart';
import 'package:grab_go_customer/features/home/model/food_category.dart';
import 'package:grab_go_customer/features/home/model/filter_model.dart';
import 'package:grab_go_customer/features/home/model/service_model.dart';
import 'package:grab_go_customer/features/home/viewmodel/food_provider.dart';
import 'package:grab_go_customer/shared/viewmodels/service_provider.dart';
import 'package:grab_go_customer/shared/widgets/browse_category_skeleton.dart';
import 'package:grab_go_customer/shared/widgets/browse_grid_skeleton.dart';
import 'package:grab_go_customer/shared/widgets/home_search.dart';
import 'package:grab_go_customer/shared/widgets/popular_item_card.dart';
import 'package:grab_go_customer/shared/widgets/umbrella_header.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:provider/provider.dart';

class BrowsePage extends StatefulWidget {
  const BrowsePage({super.key});

  @override
  State<BrowsePage> createState() => _BrowsePageState();
}

class _BrowsePageState extends State<BrowsePage> with AutomaticKeepAliveClientMixin {
  String _selectedCategoryId = 'all'; // Use 'all' for All category
  final Set<String> _selectedQuickFilters = {}; // Support multiple filter selection
  String _sortBy = 'Recommended';
  final bool _isGridView = true;
  String? _previousServiceId; // Track service changes
  String? _selectedPriceRange;
  String? _selectedRating;
  String? _selectedDeliveryTime;
  String? _selectedDietary;
  String? _selectedDistance;
  FilterModel _comprehensiveFilter = FilterModel(); // Comprehensive filter from bottom sheet

  // Scroll tracking for collapsing header
  final ValueNotifier<double> _scrollOffsetNotifier = ValueNotifier<double>(0.0);
  static const double _collapsedHeight = 70.0;
  static const double _scrollThreshold = 150.0;

  final List<Map<String, dynamic>> _quickFilters = [
    {'icon': Assets.icons.dollar, 'label': 'Price', 'hasOptions': true},
    {'icon': Assets.icons.badgePercent, 'label': 'On Sale', 'hasOptions': false},
    {'icon': Assets.icons.star, 'label': 'Rating', 'hasOptions': true},
    {'icon': Assets.icons.flame, 'label': 'Popular', 'hasOptions': false},
    {'icon': Assets.icons.clock, 'label': 'Delivery', 'hasOptions': true},
    {'icon': Assets.icons.utensilsCrossed, 'label': 'Dietary', 'hasOptions': true},
    {'icon': Assets.icons.mapPin, 'label': 'Distance', 'hasOptions': true},
    {'icon': Assets.icons.sparkles, 'label': 'New', 'hasOptions': false},
    {'icon': Assets.icons.deliveryTruck, 'label': 'Fast', 'hasOptions': false},
  ];

  final List<String> _priceRanges = ['Under GH₵20', 'GH₵20 - GH₵50', 'GH₵50 - GH₵100', 'Over GH₵100'];

  final List<String> _ratingOptions = ['4.5+ Stars', '4.0+ Stars', '3.5+ Stars', 'Any Rating'];

  final List<String> _deliveryTimeOptions = ['Under 20 min', '20-30 min', '30-45 min', 'Any Time'];

  final List<String> _dietaryOptions = ['Vegetarian', 'Vegan', 'Halal', 'Gluten-Free'];

  final List<String> _distanceOptions = ['Under 1 km', '1-3 km', '3-5 km', 'Any Distance'];

  final List<String> _sortOptions = [
    'Recommended',
    'Price: Low to High',
    'Price: High to Low',
    'Rating: High to Low',
    'Delivery Time',
    'Popularity',
  ];

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _scrollOffsetNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final serviceProvider = Provider.of<ServiceProvider>(context);
    Size size = MediaQuery.sizeOf(context);

    final systemUiOverlayStyle = SystemUiOverlayStyle(
      statusBarColor: colors.accentOrange,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: colors.backgroundSecondary,
      systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
    );

    if (_previousServiceId != null && _previousServiceId != serviceProvider.currentService.id) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _selectedCategoryId = 'all';
            _selectedQuickFilters.clear();
            _selectedPriceRange = null;
            _selectedRating = null;
            _selectedDeliveryTime = null;
            _selectedDietary = null;
            _selectedDistance = null;
            _comprehensiveFilter.reset();
          });
        }
      });
    }
    _previousServiceId = serviceProvider.currentService.id;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: systemUiOverlayStyle,
      child: Scaffold(
        backgroundColor: colors.backgroundSecondary,
        body: SafeArea(
          top: false,
          child: ClipRect(
            child: Stack(
              children: [
                NotificationListener<ScrollNotification>(
                  onNotification: (notification) {
                    _scrollOffsetNotifier.value = notification.metrics.pixels;
                    return false;
                  },
                  child: SingleChildScrollView(
                    padding: EdgeInsets.only(top: size.height * 0.20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Search and chips
                        Container(
                          color: colors.backgroundSecondary,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Padding(
                                padding: EdgeInsets.only(top: 20.h, bottom: 8.h),
                                child: serviceProvider.isFoodService
                                    ? Consumer<FoodProvider>(
                                        builder: (context, foodProvider, _) {
                                          return HomeSearch(
                                            categories: foodProvider.categories,
                                            activeFilter: _comprehensiveFilter,
                                            hintText: "Search by name or category...",
                                            onFilterApplied: (FilterModel filter) {
                                              setState(() {
                                                _comprehensiveFilter = filter.copyWith();
                                              });
                                            },
                                            isFood: true,
                                          );
                                        },
                                      )
                                    : Consumer<GroceryProvider>(
                                        builder: (context, groceryProvider, _) {
                                          final groceryCategories = groceryProvider.categories
                                              .map(
                                                (cat) => FoodCategoryModel(
                                                  id: cat.id,
                                                  name: cat.name,
                                                  emoji: cat.emoji,
                                                  description: cat.description,
                                                  isActive: cat.isActive,
                                                  items: groceryProvider.items
                                                      .where((item) => item.categoryId == cat.id)
                                                      .map(
                                                        (item) => FoodItem(
                                                          id: item.id,
                                                          name: item.name,
                                                          description: item.description,
                                                          price: item.price,
                                                          discountPercentage: item.discountPercentage,
                                                          image: item.image,
                                                          rating: item.rating,
                                                          deliveryTimeMinutes: 30,
                                                          sellerName: item.storeName ?? 'Unknown Store',
                                                          sellerId: item.storeId.hashCode % 1000000,
                                                          restaurantId: item.storeId,
                                                          restaurantImage: '',
                                                          orderCount: item.orderCount,
                                                        ),
                                                      )
                                                      .toList(),
                                                ),
                                              )
                                              .toList();
                                          return HomeSearch(
                                            categories: groceryCategories,
                                            activeFilter: _comprehensiveFilter,
                                            hintText: "Search by name or category...",
                                            onFilterApplied: (FilterModel filter) {
                                              setState(() {
                                                _comprehensiveFilter = filter.copyWith();
                                              });
                                            },
                                            isFood: false,
                                          );
                                        },
                                      ),
                              ),
                              _buildQuickFilters(colors),
                              if (_selectedQuickFilters.isNotEmpty || _comprehensiveFilter.isActive)
                                _buildResultsBar(colors),
                            ],
                          ),
                        ),

                        SizedBox(height: 16.h),
                        _selectedQuickFilters.isNotEmpty || _comprehensiveFilter.isActive
                            ? _buildItemGrid(colors, serviceProvider)
                            : _buildCategoryList(colors, serviceProvider),
                      ],
                    ),
                  ),
                ),

                Positioned(top: 0, left: 0, right: 0, child: _buildCollapsibleUmbrellaHeader(colors, size)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCollapsibleUmbrellaHeader(AppColorsExtension colors, Size size) {
    return ValueListenableBuilder<double>(
      valueListenable: _scrollOffsetNotifier,
      builder: (context, scrollOffset, _) {
        final collapseProgress = (scrollOffset / _scrollThreshold).clamp(0.0, 1.0);

        final expandedHeight = size.height * 0.20;

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
              child: _buildHeader(colors),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(AppColorsExtension colors) {
    final serviceProvider = Provider.of<ServiceProvider>(context);
    final currentService = serviceProvider.currentService;

    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, MediaQuery.of(context).padding.top + 10.h, 20.w, 16.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Browse Title
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Browse',
                  style: TextStyle(fontSize: 24.sp, fontWeight: FontWeight.w700, color: Colors.white),
                ),
                Text(
                  "What are you craving today?",
                  style: TextStyle(
                    fontFamily: "Lato",
                    package: 'grab_go_shared',
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          // Service Indicator Badge
          GestureDetector(
            onTap: _showServiceSwitcher,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20.r),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(currentService.emoji, style: TextStyle(fontSize: 14.sp)),
                  SizedBox(width: 6.w),
                  Flexible(
                    child: Text(
                      currentService.name,
                      style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600, color: Colors.white),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SizedBox(width: 4.w),

                  SvgPicture.asset(
                    Assets.icons.navArrowDown,
                    package: 'grab_go_shared',
                    colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                    width: 16.w,
                    height: 16.h,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showServiceSwitcher() {
    final colors = context.appColors;
    final serviceProvider = Provider.of<ServiceProvider>(context, listen: false);
    final foodProvider = Provider.of<FoodProvider>(context, listen: false);
    final groceryProvider = Provider.of<GroceryProvider>(context, listen: false);

    showModalBottomSheet(
      context: context,
      backgroundColor: colors.backgroundPrimary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20.r))),
      builder: (context) {
        return Container(
          padding: EdgeInsets.all(20.r),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Switch Service',
                style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w700, color: colors.textPrimary),
              ),
              SizedBox(height: 16.h),
              ...AppServices.all.map((service) {
                final isSelected = serviceProvider.currentService.id == service.id;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    width: 40.w,
                    height: 40.h,
                    decoration: BoxDecoration(
                      color: isSelected ? colors.accentOrange.withValues(alpha: 0.1) : colors.backgroundSecondary,
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Center(
                      child: Text(service.emoji, style: TextStyle(fontSize: 20.sp)),
                    ),
                  ),
                  title: Text(
                    service.name,
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                      color: isSelected ? colors.accentOrange : colors.textPrimary,
                    ),
                  ),
                  trailing: isSelected
                      ? Container(
                          height: 25.h,
                          width: 25.w,
                          padding: EdgeInsets.all(4.r),
                          decoration: BoxDecoration(color: colors.accentOrange, shape: BoxShape.circle),
                          child: SvgPicture.asset(
                            Assets.icons.check,
                            package: "grab_go_shared",
                            colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                          ),
                        )
                      : null,
                  onTap: () {
                    serviceProvider.selectService(service);

                    // Load data for the selected service if needed
                    if (service.id == 'groceries' && groceryProvider.categories.isEmpty) {
                      groceryProvider.fetchCategories();
                      groceryProvider.fetchStores();
                      groceryProvider.fetchItems();
                      groceryProvider.fetchDeals();
                    } else if (service.id == 'food' && foodProvider.categories.isEmpty) {
                      foodProvider.fetchCategories();
                      foodProvider.fetchRecentOrderItems();
                      foodProvider.fetchPromotionalBanners();
                      foodProvider.fetchDeals();
                    }

                    Navigator.pop(context);
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Widget _buildQuickFilters(AppColorsExtension colors) {
    final serviceProvider = Provider.of<ServiceProvider>(context, listen: false);
    final isFoodService = serviceProvider.isFoodService;

    // Filter out Dietary chip for Groceries service
    final visibleFilters = _quickFilters.where((filter) {
      if (filter['label'] == 'Dietary' && !isFoodService) {
        return false; // Hide Dietary for Groceries
      }
      return true;
    }).toList();

    return Container(
      height: 40.h,
      margin: EdgeInsets.only(top: 8.h),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.only(left: 20.w),
        physics: const BouncingScrollPhysics(),
        itemCount: visibleFilters.length,
        itemBuilder: (context, index) {
          final filter = visibleFilters[index];
          final isSelected = _selectedQuickFilters.contains(filter['label']);

          return GestureDetector(
            onTap: () {
              // Show bottom sheet for filters with options
              if (filter['hasOptions'] == true) {
                _showFilterOptions(filter['label']!, colors);
              } else {
                // Toggle selection for simple filters
                setState(() {
                  if (isSelected) {
                    _selectedQuickFilters.remove(filter['label']!);
                  } else {
                    _selectedQuickFilters.add(filter['label']!);
                  }
                });
              }
            },
            child: Padding(
              padding: EdgeInsets.only(right: 20.w),
              child: AnimatedContainer(
                key: ValueKey('filter_${filter['label']}'),
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isSelected
                        ? [colors.accentOrange, colors.accentOrange.withValues(alpha: 0.8)]
                        : [colors.backgroundPrimary, colors.backgroundPrimary],
                  ),
                  borderRadius: BorderRadius.circular(KBorderSize.borderMedium),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(10),
                      spreadRadius: 1,
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SvgPicture.asset(
                      filter['icon']!,
                      package: 'grab_go_shared',
                      height: 16.h,
                      width: 16.w,
                      colorFilter: ColorFilter.mode(
                        isSelected ? colors.backgroundSecondary : colors.textPrimary,
                        BlendMode.srcIn,
                      ),
                    ),
                    SizedBox(width: 6.w),
                    AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOut,
                      style: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w500,
                        color: isSelected ? colors.backgroundPrimary : colors.textPrimary,
                      ),
                      child: Text(
                        filter['label']!,
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          fontFamily: "Lato",
                          package: 'grab_go_shared',
                        ),
                      ),
                    ),
                    // Show dropdown arrow for filters with options
                    if (filter['hasOptions'] == true) ...[
                      SizedBox(width: 4.w),
                      SvgPicture.asset(
                        Assets.icons.navArrowDown,
                        package: 'grab_go_shared',
                        colorFilter: ColorFilter.mode(
                          isSelected ? Colors.white : colors.textSecondary,
                          BlendMode.srcIn,
                        ),
                        width: 16.w,
                        height: 16.h,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showFilterOptions(String filterType, AppColorsExtension colors) {
    List<String> options = [];
    String? currentSelection;

    switch (filterType) {
      case 'Price':
        options = _priceRanges;
        currentSelection = _selectedPriceRange;
        break;
      case 'Rating':
        options = _ratingOptions;
        currentSelection = _selectedRating;
        break;
      case 'Delivery':
        options = _deliveryTimeOptions;
        currentSelection = _selectedDeliveryTime;
        break;
      case 'Dietary':
        options = _dietaryOptions;
        currentSelection = _selectedDietary;
        break;
      case 'Distance':
        options = _distanceOptions;
        currentSelection = _selectedDistance;
        break;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: colors.backgroundPrimary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20.r))),
      builder: (context) {
        return Container(
          padding: EdgeInsets.all(20.r),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  margin: EdgeInsets.only(bottom: 8.h),
                  width: 40.w,
                  height: 4.h,
                  decoration: BoxDecoration(color: colors.inputBorder, borderRadius: BorderRadius.circular(2.r)),
                ),
              ),
              SizedBox(height: KSpacing.md.h),

              Text(
                'Select $filterType',
                style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w700, color: colors.textPrimary),
              ),
              SizedBox(height: 16.h),
              ...options.map((option) {
                final isSelected = currentSelection == option;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    option,
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                      color: isSelected ? colors.accentOrange : colors.textPrimary,
                    ),
                  ),
                  trailing: isSelected ? Icon(Icons.check_circle, color: colors.accentOrange, size: 24.sp) : null,
                  onTap: () {
                    setState(() {
                      switch (filterType) {
                        case 'Price':
                          _selectedPriceRange = isSelected ? null : option;
                          if (_selectedPriceRange != null) {
                            _selectedQuickFilters.add('Price');
                          } else {
                            _selectedQuickFilters.remove('Price');
                          }
                          break;
                        case 'Rating':
                          _selectedRating = isSelected ? null : option;
                          if (_selectedRating != null) {
                            _selectedQuickFilters.add('Rating');
                          } else {
                            _selectedQuickFilters.remove('Rating');
                          }
                          break;
                        case 'Delivery':
                          _selectedDeliveryTime = isSelected ? null : option;
                          if (_selectedDeliveryTime != null) {
                            _selectedQuickFilters.add('Delivery');
                          } else {
                            _selectedQuickFilters.remove('Delivery');
                          }
                          break;
                        case 'Dietary':
                          _selectedDietary = isSelected ? null : option;
                          if (_selectedDietary != null) {
                            _selectedQuickFilters.add('Dietary');
                          } else {
                            _selectedQuickFilters.remove('Dietary');
                          }
                          break;
                        case 'Distance':
                          _selectedDistance = isSelected ? null : option;
                          if (_selectedDistance != null) {
                            _selectedQuickFilters.add('Distance');
                          } else {
                            _selectedQuickFilters.remove('Distance');
                          }
                          break;
                      }
                    });
                    Navigator.pop(context);
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Widget _buildVerticalCategoryCards(AppColorsExtension colors, List<Map<String, dynamic>> categories) {
    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final category = categories[index];
        final categoryId = category['id'] as String;
        final categoryName = category['name'] as String;
        final categoryEmoji = category['emoji'] as String;
        final itemCount = category['itemCount'] as int;

        return GestureDetector(
          onTap: () {
            // TODO: Navigate to category items page
            setState(() {
              _selectedCategoryId = categoryId;
            });
          },
          child: Container(
            margin: EdgeInsets.only(bottom: 12.h),
            padding: EdgeInsets.all(16.r),
            decoration: BoxDecoration(
              color: colors.backgroundPrimary,
              borderRadius: BorderRadius.circular(KBorderSize.borderMedium),
              boxShadow: [BoxShadow(color: Colors.black.withAlpha(5), blurRadius: 8, offset: const Offset(0, 2))],
            ),
            child: Row(
              children: [
                // Category Icon/Emoji
                Container(
                  width: 56.w,
                  height: 56.h,
                  decoration: BoxDecoration(
                    color: colors.accentOrange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(KBorderSize.borderSmall),
                  ),
                  child: Center(
                    child: Text(categoryEmoji, style: TextStyle(fontSize: 28.sp)),
                  ),
                ),
                SizedBox(width: 16.w),
                // Category Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        categoryName,
                        style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600, color: colors.textPrimary),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        '$itemCount items',
                        style: TextStyle(fontSize: 13.sp, color: colors.textSecondary),
                      ),
                    ],
                  ),
                ),
                // Arrow Icon
                SvgPicture.asset(
                  Assets.icons.navArrowRight,
                  package: 'grab_go_shared',
                  colorFilter: ColorFilter.mode(colors.textSecondary, BlendMode.srcIn),
                  width: 24.w,
                  height: 24.h,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildResultsBar(AppColorsExtension colors) {
    final serviceProvider = Provider.of<ServiceProvider>(context, listen: false);
    int itemCount = 0;

    if (serviceProvider.isFoodService) {
      final foodProvider = Provider.of<FoodProvider>(context, listen: false);
      itemCount = _getFilteredFoodItems(foodProvider).length;
    } else {
      final groceryProvider = Provider.of<GroceryProvider>(context, listen: false);
      itemCount = _getFilteredGroceryItems(groceryProvider).length;
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 12.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '$itemCount results',
            style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w700, color: colors.textPrimary),
          ),
          GestureDetector(
            onTap: () {
              setState(() {
                _selectedQuickFilters.clear();
                _selectedCategoryId = 'all';
                _selectedPriceRange = null;
                _selectedRating = null;
                _selectedDeliveryTime = null;
                _selectedDietary = null;
                _selectedDistance = null;
                _comprehensiveFilter.reset();
              });
            },
            child: Text(
              'Reset',
              style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600, color: colors.accentOrange),
            ),
          ),
        ],
      ),
    );
  }

  List<FoodItem> _getFilteredFoodItems(FoodProvider provider) {
    List<FoodItem> items = [];

    // Filter by category
    if (_selectedCategoryId == 'all') {
      // Show all items from all categories
      for (var category in provider.categories) {
        items.addAll(category.items);
      }
    } else {
      // Show items from selected category only
      try {
        final selectedCategory = provider.categories.firstWhere((cat) => cat.id == _selectedCategoryId);
        items = List.from(selectedCategory.items);
      } catch (e) {
        // Category not found, return empty list
        items = [];
      }
    }

    // Apply comprehensive filter from bottom sheet (if active)
    if (_comprehensiveFilter.isActive) {
      // Price range filter
      if (_comprehensiveFilter.minPrice > 0 || _comprehensiveFilter.maxPrice < 10000) {
        items = items.where((item) {
          return item.price >= _comprehensiveFilter.minPrice && item.price <= _comprehensiveFilter.maxPrice;
        }).toList();
      }

      // Rating filter
      if (_comprehensiveFilter.minRating != null) {
        items = items.where((item) => item.rating >= _comprehensiveFilter.minRating!).toList();
      }

      // Quick filters from comprehensive filter
      if (_comprehensiveFilter.onSale) {
        items = items.where((item) => item.discountPercentage > 0).toList();
      }
      if (_comprehensiveFilter.popular) {
        items = items.where((item) => item.orderCount >= 50).toList();
      }
      if (_comprehensiveFilter.isNew) {
        items = items.where((item) => item.orderCount < 10).toList();
      }
      if (_comprehensiveFilter.fast) {
        items = items.where((item) => item.deliveryTimeMinutes <= 30).toList();
      }

      // Delivery time filter
      if (_comprehensiveFilter.deliveryTime != null) {
        items = items.where((item) {
          switch (_comprehensiveFilter.deliveryTime) {
            case 'Under 20 min':
              return item.deliveryTimeMinutes < 20;
            case '20-30 min':
              return item.deliveryTimeMinutes >= 20 && item.deliveryTimeMinutes <= 30;
            case '30-45 min':
              return item.deliveryTimeMinutes > 30 && item.deliveryTimeMinutes <= 45;
            case 'Any Time':
            default:
              return true;
          }
        }).toList();
      }

      // Dietary filter
      if (_comprehensiveFilter.dietary != null) {
        items = items.where((item) {
          // Safe access in case dietaryTags doesn't exist
          try {
            return item.dietaryTags.contains(_comprehensiveFilter.dietary);
          } catch (e) {
            return false; // If property doesn't exist, exclude item
          }
        }).toList();
      }

      // Restaurant filter
      if (_comprehensiveFilter.selectedRestaurants.isNotEmpty) {
        items = items.where((item) {
          return _comprehensiveFilter.selectedRestaurants.contains(item.sellerName);
        }).toList();
      }
    }

    // Apply quick filters - iterate through all selected filters
    for (final filterName in _selectedQuickFilters) {
      switch (filterName) {
        case 'On Sale':
          items = items.where((item) => item.discountPercentage > 0).toList();
          break;
        case 'Top Rated':
          items = items.where((item) => item.rating >= 4.5).toList();
          break;
        case 'New':
          items = items.where((item) => item.orderCount < 10).toList();
          break;
        case 'Fast':
          items = items.where((item) => item.deliveryTimeMinutes <= 30).toList();
          break;
        case 'Popular':
          items = items.where((item) => item.orderCount >= 50).toList();
          break;
        case 'Price':
          if (_selectedPriceRange != null) {
            items = items.where((item) {
              switch (_selectedPriceRange) {
                case 'Under GH₵20':
                  return item.price < 20;
                case 'GH₵20 - GH₵50':
                  return item.price >= 20 && item.price <= 50;
                case 'GH₵50 - GH₵100':
                  return item.price > 50 && item.price <= 100;
                case 'Over GH₵100':
                  return item.price > 100;
                default:
                  return true;
              }
            }).toList();
          }
          break;
        case 'Rating':
          if (_selectedRating != null) {
            items = items.where((item) {
              switch (_selectedRating) {
                case '4.5+ Stars':
                  return item.rating >= 4.5;
                case '4.0+ Stars':
                  return item.rating >= 4.0;
                case '3.5+ Stars':
                  return item.rating >= 3.5;
                case 'Any Rating':
                default:
                  return true;
              }
            }).toList();
          }
          break;
        case 'Delivery':
          if (_selectedDeliveryTime != null) {
            items = items.where((item) {
              switch (_selectedDeliveryTime) {
                case 'Under 20 min':
                  return item.deliveryTimeMinutes < 20;
                case '20-30 min':
                  return item.deliveryTimeMinutes >= 20 && item.deliveryTimeMinutes <= 30;
                case '30-45 min':
                  return item.deliveryTimeMinutes > 30 && item.deliveryTimeMinutes <= 45;
                case 'Any Time':
                default:
                  return true;
              }
            }).toList();
          }
          break;
      }
    }

    // Apply sort
    _applySortToFoodItems(items);

    return items;
  }

  List<GroceryItem> _getFilteredGroceryItems(GroceryProvider provider) {
    List<GroceryItem> items = List.from(provider.items);

    // Apply category filter
    if (_selectedCategoryId != 'all') {
      items = items.where((item) => item.categoryId == _selectedCategoryId).toList();
    }

    // Apply comprehensive filter from bottom sheet (if active)
    if (_comprehensiveFilter.isActive) {
      // Price range filter
      if (_comprehensiveFilter.minPrice > 0 || _comprehensiveFilter.maxPrice < 10000) {
        items = items.where((item) {
          return item.price >= _comprehensiveFilter.minPrice && item.price <= _comprehensiveFilter.maxPrice;
        }).toList();
      }

      // Rating filter
      if (_comprehensiveFilter.minRating != null) {
        items = items.where((item) => item.rating >= _comprehensiveFilter.minRating!).toList();
      }

      // Quick filters from comprehensive filter
      if (_comprehensiveFilter.onSale) {
        items = items.where((item) => item.discountPercentage > 0).toList();
      }
      if (_comprehensiveFilter.popular) {
        items = items.where((item) => item.orderCount >= 100).toList();
      }
      if (_comprehensiveFilter.isNew) {
        final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
        items = items.where((item) => item.createdAt.isAfter(sevenDaysAgo)).toList();
      }

      // Store filter
      if (_comprehensiveFilter.selectedRestaurants.isNotEmpty) {
        items = items.where((item) {
          return _comprehensiveFilter.selectedRestaurants.contains(item.storeName);
        }).toList();
      }
    }

    // Apply quick filters - iterate through all selected filters
    for (final filterName in _selectedQuickFilters) {
      switch (filterName) {
        case 'On Sale':
          items = items.where((item) => item.discountPercentage > 0).toList();
          break;
        case 'Top Rated':
          items = items.where((item) => item.rating >= 4.5).toList();
          break;
        case 'New':
          final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
          items = items.where((item) => item.createdAt.isAfter(sevenDaysAgo)).toList();
          break;
        case 'Fast':
          // For groceries, all items are relatively fast delivery
          break;
        case 'Popular':
          items = items.where((item) => item.orderCount >= 100).toList();
          break;
        case 'Price':
          if (_selectedPriceRange != null) {
            items = items.where((item) {
              switch (_selectedPriceRange) {
                case 'Under GH₵20':
                  return item.price < 20;
                case 'GH₵20 - GH₵50':
                  return item.price >= 20 && item.price <= 50;
                case 'GH₵50 - GH₵100':
                  return item.price > 50 && item.price <= 100;
                case 'Over GH₵100':
                  return item.price > 100;
                default:
                  return true;
              }
            }).toList();
          }
          break;
        case 'Rating':
          if (_selectedRating != null) {
            items = items.where((item) {
              switch (_selectedRating) {
                case '4.5+ Stars':
                  return item.rating >= 4.5;
                case '4.0+ Stars':
                  return item.rating >= 4.0;
                case '3.5+ Stars':
                  return item.rating >= 3.5;
                case 'Any Rating':
                default:
                  return true;
              }
            }).toList();
          }
          break;
        case 'Delivery':
          // For groceries, delivery time filtering can be skipped or customized
          break;
      }
    }

    // Apply sort
    _applySortToGroceryItems(items);

    return items;
  }

  void _applySortToFoodItems(List<FoodItem> items) {
    switch (_sortBy) {
      case 'Price: Low to High':
        items.sort((a, b) => a.price.compareTo(b.price));
        break;
      case 'Price: High to Low':
        items.sort((a, b) => b.price.compareTo(a.price));
        break;
      case 'Rating: High to Low':
        items.sort((a, b) => b.rating.compareTo(a.rating));
        break;
      case 'Popularity':
        items.sort((a, b) => b.orderCount.compareTo(a.orderCount));
        break;
      case 'Delivery Time':
        items.sort((a, b) => a.deliveryTimeMinutes.compareTo(b.deliveryTimeMinutes));
        break;
    }
  }

  void _applySortToGroceryItems(List<GroceryItem> items) {
    switch (_sortBy) {
      case 'Price: Low to High':
        items.sort((a, b) => a.price.compareTo(b.price));
        break;
      case 'Price: High to Low':
        items.sort((a, b) => b.price.compareTo(a.price));
        break;
      case 'Rating: High to Low':
        items.sort((a, b) => b.rating.compareTo(a.rating));
        break;
      case 'Popularity':
        items.sort((a, b) => b.orderCount.compareTo(a.orderCount));
        break;
    }
  }

  void _showSortOptions() {
    final colors = context.appColors;

    showModalBottomSheet(
      context: context,
      backgroundColor: colors.backgroundPrimary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20.r))),
      builder: (context) {
        return Container(
          padding: EdgeInsets.all(20.r),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Sort by',
                style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w700, color: colors.textPrimary),
              ),
              SizedBox(height: 16.h),
              ..._sortOptions.map((option) {
                final isSelected = _sortBy == option;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    option,
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                      color: isSelected ? colors.accentOrange : colors.textPrimary,
                    ),
                  ),
                  trailing: isSelected ? Icon(Icons.check, color: colors.accentOrange, size: 20.sp) : null,
                  onTap: () {
                    setState(() => _sortBy = option);
                    Navigator.pop(context);
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }

  // Non-sliver version for SingleChildScrollView
  Widget _buildCategoryList(AppColorsExtension colors, ServiceProvider serviceProvider) {
    final isFood = serviceProvider.isFoodService;

    if (isFood) {
      return Selector<FoodProvider, List<FoodCategoryModel>>(
        selector: (_, provider) => provider.categories,
        builder: (context, categories, _) {
          if (categories.isEmpty) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            return BrowseCategorySkeleton(colors: colors, isDark: isDark);
          }

          final categoryData = categories
              .map((cat) => {'id': cat.id, 'name': cat.name, 'emoji': cat.emoji, 'itemCount': cat.items.length})
              .toList();

          return Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w),
            child: Column(children: categoryData.map((cat) => _buildCategoryCard(cat, colors)).toList()),
          );
        },
      );
    } else {
      return Selector<GroceryProvider, List<GroceryCategory>>(
        selector: (_, provider) => provider.categories,
        builder: (context, categories, child) {
          if (categories.isEmpty) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            return BrowseCategorySkeleton(colors: colors, isDark: isDark);
          }

          final groceryProvider = Provider.of<GroceryProvider>(context, listen: false);
          final categoryData = categories.map((cat) {
            final itemCount = groceryProvider.items.where((item) => item.categoryId == cat.id).length;
            return {'id': cat.id, 'name': cat.name, 'emoji': cat.emoji, 'itemCount': itemCount};
          }).toList();

          return Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w),
            child: Column(children: categoryData.map((cat) => _buildCategoryCard(cat, colors)).toList()),
          );
        },
      );
    }
  }

  Widget _buildItemGrid(AppColorsExtension colors, ServiceProvider serviceProvider) {
    if (serviceProvider.isFoodService) {
      return Consumer<FoodProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            return BrowseGridSkeleton(colors: colors, isDark: isDark, isGridView: _isGridView);
          }

          final items = _getFilteredFoodItems(provider);

          if (items.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.search_off, size: 64.sp, color: colors.textSecondary),
                  SizedBox(height: 16.h),
                  Text(
                    'No items found',
                    style: TextStyle(fontSize: 16.sp, color: colors.textSecondary),
                  ),
                ],
              ),
            );
          }

          return Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.75,
                crossAxisSpacing: 12.w,
                mainAxisSpacing: 12.h,
              ),
              itemCount: items.length,
              itemBuilder: (context, index) {
                return PopularItemCard(
                  item: items[index],
                  orderCount: items[index].orderCount,
                  onTap: () => context.push('/food-details', extra: items[index]),
                );
              },
            ),
          );
        },
      );
    } else {
      return Consumer<GroceryProvider>(
        builder: (context, provider, _) {
          if (provider.isLoadingItems) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            return BrowseGridSkeleton(colors: colors, isDark: isDark, isGridView: _isGridView);
          }

          final items = _getFilteredGroceryItems(provider);

          if (items.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.search_off, size: 64.sp, color: colors.textSecondary),
                  SizedBox(height: 16.h),
                  Text(
                    'No items found',
                    style: TextStyle(fontSize: 16.sp, color: colors.textSecondary),
                  ),
                ],
              ),
            );
          }

          return Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.75,
                crossAxisSpacing: 12.w,
                mainAxisSpacing: 12.h,
              ),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final groceryItem = items[index];
                return PopularItemCard(
                  item: FoodItem(
                    id: groceryItem.id,
                    name: groceryItem.name,
                    description: groceryItem.description,
                    price: groceryItem.price,
                    discountPercentage: groceryItem.discountPercentage,
                    image: groceryItem.image,
                    rating: groceryItem.rating,
                    deliveryTimeMinutes: 30,
                    sellerName: groceryItem.storeName ?? 'Unknown Store',
                    sellerId: groceryItem.storeId.hashCode % 1000000,
                    restaurantId: groceryItem.storeId,
                    restaurantImage: '',
                    orderCount: groceryItem.orderCount,
                  ),
                  orderCount: groceryItem.orderCount,
                  onTap: () => context.push('/grocery-details', extra: groceryItem),
                );
              },
            ),
          );
        },
      );
    }
  }

  Widget _buildCategoryCard(Map<String, dynamic> category, AppColorsExtension colors) {
    final categoryId = category['id'] as String;
    final categoryName = category['name'] as String;
    final categoryEmoji = category['emoji'] as String;
    final itemCount = category['itemCount'] as int;

    return GestureDetector(
      onTap: () {
        final serviceProvider = Provider.of<ServiceProvider>(context, listen: false);
        context.push(
          '/categoryItems',
          extra: {
            'categoryId': categoryId,
            'categoryName': categoryName,
            'categoryEmoji': categoryEmoji,
            'isFood': serviceProvider.isFoodService,
          },
        );
      },
      child: Container(
        margin: EdgeInsets.only(bottom: 12.h),
        padding: EdgeInsets.all(16.r),
        decoration: BoxDecoration(
          color: colors.backgroundPrimary,
          borderRadius: BorderRadius.circular(KBorderSize.borderMedium),
          boxShadow: [BoxShadow(color: Colors.black.withAlpha(5), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Row(
          children: [
            // Category Icon/Emoji
            Container(
              width: 56.w,
              height: 56.h,
              decoration: BoxDecoration(
                color: colors.accentOrange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(KBorderSize.borderSmall),
              ),
              child: Center(
                child: Text(categoryEmoji, style: TextStyle(fontSize: 28.sp)),
              ),
            ),
            SizedBox(width: 16.w),
            // Category Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    categoryName,
                    style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600, color: colors.textPrimary),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    '$itemCount items',
                    style: TextStyle(fontSize: 13.sp, color: colors.textSecondary),
                  ),
                ],
              ),
            ),
            // Arrow Icon
            SvgPicture.asset(
              Assets.icons.navArrowRight,
              package: 'grab_go_shared',
              colorFilter: ColorFilter.mode(colors.textSecondary, BlendMode.srcIn),
              width: 24.w,
              height: 24.h,
            ),
          ],
        ),
      ),
    );
  }
}
