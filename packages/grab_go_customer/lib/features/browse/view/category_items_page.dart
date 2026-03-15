import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_customer/features/cart/viewmodel/cart_provider.dart';
import 'package:grab_go_customer/features/groceries/model/grocery_item.dart';
import 'package:grab_go_customer/features/groceries/viewmodel/grocery_provider.dart';
import 'package:grab_go_customer/features/home/model/filter_model.dart';
import 'package:grab_go_customer/features/home/model/food_category.dart';
import 'package:grab_go_customer/features/home/viewmodel/food_provider.dart';
import 'package:grab_go_customer/features/pharmacy/model/pharmacy_item.dart';
import 'package:grab_go_customer/features/pharmacy/viewmodel/pharmacy_provider.dart';
import 'package:grab_go_customer/features/grabmart/viewmodel/grabmart_provider.dart';
import 'package:grab_go_customer/shared/widgets/browse_grid_skeleton.dart';
import 'package:grab_go_customer/shared/widgets/deal_card.dart';
import 'package:grab_go_customer/shared/widgets/home_search.dart';
import 'package:grab_go_customer/shared/widgets/food_item_card.dart';
import 'package:grab_go_customer/shared/widgets/grocery_product_card.dart';
import 'package:grab_go_customer/shared/widgets/pharmacy_product_card.dart';
import 'package:grab_go_customer/shared/widgets/section_header.dart';
import 'package:grab_go_customer/shared/widgets/umbrella_header.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:provider/provider.dart';

class CategoryItemsPage extends StatefulWidget {
  final String categoryId;
  final String categoryName;
  final String categoryEmoji;
  final String serviceType;

  const CategoryItemsPage({
    super.key,
    required this.categoryId,
    required this.categoryName,
    required this.categoryEmoji,
    required this.serviceType,
  });

  bool get isFood => serviceType == 'food';
  bool get isGrocery => serviceType == 'grocery';
  bool get isPharmacy => serviceType == 'pharmacy';
  bool get isGrabMart => serviceType == 'convenience';

  @override
  State<CategoryItemsPage> createState() => _CategoryItemsPageState();
}

class _CategoryItemsPageState extends State<CategoryItemsPage> {
  final Set<String> _selectedQuickFilters = {};
  String _sortBy = 'Recommended';
  final bool _isGridView = false;
  String? _selectedPriceRange;
  String? _selectedRating;
  String? _selectedDeliveryTime;
  String? _selectedDietary;
  FilterModel _comprehensiveFilter = FilterModel();

  late ScrollController _scrollController;

  final ValueNotifier<double> _scrollOffsetNotifier = ValueNotifier<double>(
    0.0,
  );
  static const double _collapsedHeight = 80.0;
  static const double _scrollThreshold = 100.0;
  static const double _headerExtraHeight = 24.0;

  final List<Map<String, dynamic>> _quickFilters = [
    {'icon': Assets.icons.dollar, 'label': 'Price', 'hasOptions': true},
    {
      'icon': Assets.icons.badgePercent,
      'label': 'On Sale',
      'hasOptions': false,
    },
    {'icon': Assets.icons.star, 'label': 'Rating', 'hasOptions': true},
    {'icon': Assets.icons.flame, 'label': 'Popular', 'hasOptions': false},
    {'icon': Assets.icons.clock, 'label': 'Delivery', 'hasOptions': true},
    {
      'icon': Assets.icons.utensilsCrossed,
      'label': 'Dietary',
      'hasOptions': true,
    },
    {'icon': Assets.icons.sparkles, 'label': 'New', 'hasOptions': false},
    {'icon': Assets.icons.deliveryTruck, 'label': 'Fast', 'hasOptions': false},
  ];

  final List<String> _priceRanges = [
    'Under GH₵20',
    'GH₵20 - GH₵50',
    'GH₵50 - GH₵100',
    'Over GH₵100',
  ];
  final List<String> _ratingOptions = [
    '4.5+ Stars',
    '4.0+ Stars',
    '3.5+ Stars',
    'Any Rating',
  ];
  final List<String> _deliveryTimeOptions = [
    'Under 20 min',
    '20-30 min',
    '30-45 min',
    'Any Time',
  ];
  final List<String> _dietaryOptions = [
    'Vegetarian',
    'Vegan',
    'Halal',
    'Gluten-Free',
  ];

  final List<String> _sortOptions = ['Popularity'];

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.isPharmacy) {
        final provider = Provider.of<PharmacyProvider>(context, listen: false);
        if (provider.items.isEmpty) {
          provider.fetchItems();
        }
      } else if (widget.isGrabMart) {
        final provider = Provider.of<GrabMartProvider>(context, listen: false);
        if (provider.items.isEmpty) {
          provider.fetchItems();
        }
      } else if (widget.isFood) {
        final provider = Provider.of<FoodProvider>(context, listen: false);
        if (provider.categories.isEmpty) {
          provider.fetchCategories();
        }
      } else if (widget.isGrocery) {
        final provider = Provider.of<GroceryProvider>(context, listen: false);
        if (provider.items.isEmpty) {
          provider.fetchItems();
        }
      }
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _scrollOffsetNotifier.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;

    final currentOffset = _scrollController.offset;

    _scrollOffsetNotifier.value = currentOffset;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.sizeOf(context);
    final hasCart = context.watch<CartProvider>().cartItems.isNotEmpty;

    final systemUiOverlayStyle = SystemUiOverlayStyle(
      statusBarColor: colors.accentOrange,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: hasCart
          ? colors.accentOrange
          : colors.backgroundPrimary,
      systemNavigationBarDividerColor: hasCart
          ? colors.accentOrange
          : colors.backgroundPrimary,
      systemNavigationBarIconBrightness: isDark
          ? Brightness.light
          : Brightness.dark,
    );

    SystemChrome.setSystemUIOverlayStyle(systemUiOverlayStyle);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: systemUiOverlayStyle,
      child: Scaffold(
        backgroundColor: colors.backgroundPrimary,
        body: SafeArea(
          top: false,
          child: ClipRect(
            child: Stack(
              children: [
                CustomScrollView(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: SizedBox(
                        height: UmbrellaHeaderMetrics.expandedHeightFor(
                          size,
                          extra: _headerExtraHeight,
                        ),
                      ),
                    ),
                    if (widget.isFood)
                      _buildFoodDealsSliver(colors)
                    else if (widget.isGrocery)
                      _buildGroceryDealsSliver(colors)
                    else if (widget.isPharmacy)
                      _buildPharmacyDealsSliver(colors)
                    else if (widget.isGrabMart)
                      _buildGrabMartDealsSliver(colors),

                    if (widget.isFood)
                      _buildFoodItemsHeaderSliver(colors)
                    else if (widget.isGrocery)
                      _buildGroceryItemsHeaderSliver(colors)
                    else if (widget.isPharmacy)
                      _buildPharmacyItemsHeaderSliver(colors)
                    else if (widget.isGrabMart)
                      _buildGrabMartItemsHeaderSliver(colors),

                    if (widget.isFood)
                      _buildFoodItemsSliver(colors, isDark)
                    else if (widget.isGrocery)
                      _buildGroceryItemsSliver(colors, isDark)
                    else if (widget.isPharmacy)
                      _buildPharmacyItemsSliver(colors, isDark)
                    else if (widget.isGrabMart)
                      _buildGrabMartItemsSliver(colors, isDark),
                  ],
                ),

                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: _buildCollapsibleCategoryHeader(colors, size, isDark),
                ),
              ],
            ),
          ),
        ),
        bottomNavigationBar: _buildCartBar(colors),
      ),
    );
  }

  Widget _buildCartBar(AppColorsExtension colors) {
    return Consumer<CartProvider>(
      builder: (context, cartProvider, _) {
        if (cartProvider.cartItems.isEmpty) return const SizedBox.shrink();

        final itemCount = cartProvider.totalQuantity;
        final totalAmount = cartProvider.total;
        final isLocked = cartProvider.isCartInteractionLocked;

        final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              color: colors.backgroundPrimary,
              child: SizedBox(
                height: 64.h,
                child: ClipRRect(
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(18.r),
                  ),
                  child: IgnorePointer(
                    ignoring: isLocked,
                    child: GestureDetector(
                      onTap: () => context.push("/cart"),
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 180),
                        opacity: isLocked ? 0.82 : 1,
                        child: Container(
                          width: double.infinity,
                          padding: EdgeInsets.symmetric(
                            horizontal: 16.w,
                            vertical: 8.h,
                          ),
                          decoration: BoxDecoration(
                            color: colors.accentOrange,
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(18.r),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: EdgeInsets.all(8.r),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: SvgPicture.asset(
                                  Assets.icons.cart,
                                  height: 18.h,
                                  width: 18.w,
                                  package: 'grab_go_shared',
                                  colorFilter: const ColorFilter.mode(
                                    Colors.white,
                                    BlendMode.srcIn,
                                  ),
                                ),
                              ),
                              SizedBox(width: 12.w),
                              Expanded(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      isLocked
                                          ? "Updating cart..."
                                          : "View cart",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 14.sp,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    SizedBox(height: 2.h),
                                    Text(
                                      "$itemCount ${itemCount == 1 ? "item" : "items"} in cart",
                                      style: TextStyle(
                                        color: Colors.white.withValues(
                                          alpha: 0.9,
                                        ),
                                        fontSize: 12.sp,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (isLocked)
                                Padding(
                                  padding: EdgeInsets.only(right: 12.w),
                                  child: SizedBox(
                                    width: 18.w,
                                    height: 18.w,
                                    child: const CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              Text(
                                "${AppStrings.currencySymbol} ${totalAmount.toStringAsFixed(2)}",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (bottomInset > 0)
              Container(height: bottomInset, color: colors.accentOrange),
          ],
        );
      },
    );
  }

  SliverToBoxAdapter _buildFoodDealsSliver(AppColorsExtension colors) {
    return SliverToBoxAdapter(
      child: Consumer<FoodProvider>(
        builder: (context, provider, _) {
          final items = _getFilteredFoodItems(provider);
          final dealItems = items
              .where((item) => item.discountPercentage > 0)
              .take(10)
              .toList();
          if (dealItems.isEmpty) return const SizedBox.shrink();

          return _buildDealsSection(
            colors: colors,
            title: '${widget.categoryName} Deals',
            dealItems: dealItems,
            onItemTap: (item) => context.push('/foodDetails', extra: item),
          );
        },
      ),
    );
  }

  SliverToBoxAdapter _buildGroceryDealsSliver(AppColorsExtension colors) {
    return SliverToBoxAdapter(
      child: Consumer<GroceryProvider>(
        builder: (context, provider, _) {
          final items = _getFilteredGroceryItems(provider);
          final deals = items
              .where((item) => item.discountPercentage > 0)
              .take(10)
              .toList();
          if (deals.isEmpty) return const SizedBox.shrink();

          final size = MediaQuery.sizeOf(context);
          final cardWidth = (size.width * 0.38).clamp(138.0, 170.0);
          final sectionHeight = (cardWidth + 88.h).clamp(228.0, 248.0);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 16.h),
              SectionHeader(
                title: '${widget.categoryName} Deals',
                accentColor: colors.serviceGrocery,
                sectionTotal: deals.length,
                onSeeAll: () {},
              ),
              SizedBox(height: 12.h),
              SizedBox(
                height: sectionHeight,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.only(left: 20.w),
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: deals.length,
                  itemBuilder: (context, index) {
                    final item = deals[index];
                    return GroceryProductCard(
                      item: item,
                      width: cardWidth,
                      compactLayout: true,
                      showStoreName: true,
                      showDiscountBadge: true,
                      margin: EdgeInsets.only(right: 12.w),
                      onTap: () => context.push('/foodDetails', extra: item),
                    );
                  },
                ),
              ),
              SizedBox(height: 20.h),
            ],
          );
        },
      ),
    );
  }

  SliverToBoxAdapter _buildPharmacyDealsSliver(AppColorsExtension colors) {
    return SliverToBoxAdapter(
      child: Consumer<PharmacyProvider>(
        builder: (context, provider, _) {
          final items = _getFilteredPharmacyItems(provider);
          final deals = items
              .where((item) => item.discountPercentage > 0)
              .take(10)
              .toList();
          if (deals.isEmpty) return const SizedBox.shrink();

          final size = MediaQuery.sizeOf(context);
          final cardWidth = (size.width * 0.38).clamp(138.0, 170.0);
          final sectionHeight = (cardWidth + 88.h).clamp(228.0, 248.0);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 16.h),
              SectionHeader(
                title: '${widget.categoryName} Deals',
                accentColor: colors.servicePharmacy,
                sectionTotal: deals.length,
                onSeeAll: () {},
              ),
              SizedBox(height: 12.h),
              SizedBox(
                height: sectionHeight,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.only(left: 20.w),
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: deals.length,
                  itemBuilder: (context, index) {
                    final item = deals[index];
                    return PharmacyProductCard(
                      item: item,
                      width: cardWidth,
                      compactLayout: true,
                      showStoreName: true,
                      showDiscountBadge: true,
                      margin: EdgeInsets.only(right: 12.w),
                      onTap: () => context.push('/foodDetails', extra: item),
                    );
                  },
                ),
              ),
              SizedBox(height: 20.h),
            ],
          );
        },
      ),
    );
  }

  SliverToBoxAdapter _buildGrabMartDealsSliver(AppColorsExtension colors) {
    return SliverToBoxAdapter(
      child: Consumer<GrabMartProvider>(
        builder: (context, provider, _) {
          final items = provider.items
              .where((item) => item.categoryId == widget.categoryId)
              .toList();
          final deals = items
              .where((item) => item.discountPercentage > 0)
              .take(10)
              .toList();
          if (deals.isEmpty) return const SizedBox.shrink();

          final dealItems = deals.map((item) => item.toFoodItem()).toList();
          return _buildDealsSection(
            colors: colors,
            title: '${widget.categoryName} Deals',
            dealItems: dealItems,
            onItemTap: (item) {
              dynamic originalItem;
              try {
                originalItem = deals.firstWhere((d) => d.id == item.id);
              } catch (_) {}
              context.push('/foodDetails', extra: originalItem ?? item);
            },
          );
        },
      ),
    );
  }

  Widget _buildDealsSection({
    required AppColorsExtension colors,
    required String title,
    required List<FoodItem> dealItems,
    required void Function(FoodItem) onItemTap,
  }) {
    final size = MediaQuery.sizeOf(context);
    final cardWidth = (size.width * 0.78).clamp(230.0, 320.0);
    final imageHeight = (cardWidth * 0.45).clamp(90.0, 125.0);
    final cardHeight = (imageHeight + 110.h).clamp(208.0, 250.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 16.h),
        SectionHeader(
          title: title,
          accentColor: colors.accentOrange,
          sectionTotal: dealItems.length,
          onSeeAll: () {},
        ),
        SizedBox(height: 10.h),
        SizedBox(
          height: cardHeight,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.only(left: 20.w),
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: dealItems.length,
            itemBuilder: (context, index) {
              final item = dealItems[index];
              return Padding(
                padding: EdgeInsets.only(right: 15.w),
                child: DealCard(
                  item: item,
                  discountPercent: item.discountPercentage.toInt(),
                  deliveryTime: item.estimatedDeliveryTime,
                  onTap: () => onItemTap(item),
                ),
              );
            },
          ),
        ),
        SizedBox(height: 20.h),
      ],
    );
  }

  SliverToBoxAdapter _buildFoodItemsHeaderSliver(AppColorsExtension colors) {
    return SliverToBoxAdapter(
      child: Consumer<FoodProvider>(
        builder: (context, provider, _) {
          final items = _getFilteredFoodItems(
            provider,
          ).where((item) => item.discountPercentage <= 0).toList();
          return SectionHeader(
            title: '${widget.categoryName} Items',
            accentColor: colors.accentOrange,
            sectionTotal: items.length,
            onSeeAll: () {},
          );
        },
      ),
    );
  }

  SliverToBoxAdapter _buildGroceryItemsHeaderSliver(AppColorsExtension colors) {
    return SliverToBoxAdapter(
      child: Consumer<GroceryProvider>(
        builder: (context, provider, _) {
          final items = _getFilteredGroceryItems(
            provider,
          ).where((item) => item.discountPercentage <= 0).toList();
          return SectionHeader(
            title: '${widget.categoryName} Items',
            accentColor: colors.serviceGrocery,
            sectionTotal: items.length,
            onSeeAll: () {},
          );
        },
      ),
    );
  }

  SliverToBoxAdapter _buildPharmacyItemsHeaderSliver(
    AppColorsExtension colors,
  ) {
    return SliverToBoxAdapter(
      child: Consumer<PharmacyProvider>(
        builder: (context, provider, _) {
          final items = _getFilteredPharmacyItems(
            provider,
          ).where((item) => item.discountPercentage <= 0).toList();
          return SectionHeader(
            title: '${widget.categoryName} Items',
            accentColor: colors.servicePharmacy,
            sectionTotal: items.length,
            onSeeAll: () {},
          );
        },
      ),
    );
  }

  SliverToBoxAdapter _buildGrabMartItemsHeaderSliver(
    AppColorsExtension colors,
  ) {
    return SliverToBoxAdapter(
      child: Consumer<GrabMartProvider>(
        builder: (context, provider, _) {
          final items = provider.items
              .where(
                (item) =>
                    item.categoryId == widget.categoryId &&
                    item.discountPercentage <= 0,
              )
              .toList();
          return SectionHeader(
            title: '${widget.categoryName} GrabMart Items',
            accentColor: colors.accentOrange,
            sectionTotal: items.length,
            onSeeAll: () {},
          );
        },
      ),
    );
  }

  Widget _buildFoodItemsSliver(AppColorsExtension colors, bool isDark) {
    final padding = MediaQuery.paddingOf(context);
    return Consumer<FoodProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading) {
          return SliverToBoxAdapter(
            child: BrowseGridSkeleton(
              colors: colors,
              isDark: isDark,
              isGridView: _isGridView,
            ),
          );
        }

        final items = _getFilteredFoodItems(
          provider,
        ).where((item) => item.discountPercentage <= 0).toList();

        if (items.isEmpty) {
          return SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'No items found',
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    'Try adjusting your filters',
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return SliverPadding(
          padding: EdgeInsets.only(
            left: 20.w,
            right: 20.w,
            top: 8.h,
            bottom: padding.bottom + 16.h,
          ),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              final item = items[index];
              return Consumer<CartProvider>(
                builder: (context, provider, _) {
                  final bool isInCart = provider.hasItemInCart(
                    item,
                    includeFoodCustomizations: true,
                  );
                  final bool isItemPending = provider
                      .isItemOperationPendingForDisplay(
                        item,
                        includeFoodCustomizations: true,
                      );
                  final itemForAction = provider.resolveItemForCartAction(
                    item,
                    includeFoodCustomizations: true,
                  );
                  return Padding(
                    padding: EdgeInsets.only(bottom: 16.h),
                    child: FoodItemCard(
                      item: item,
                      margin: EdgeInsets.zero,
                      onTap: () => context.push('/foodDetails', extra: item),
                      trailing: GestureDetector(
                        onTap: () {
                          if (isItemPending) return;
                          if (isInCart && itemForAction != null) {
                            provider.removeItemCompletely(itemForAction);
                          } else {
                            provider.addToCart(item, context: context);
                          }
                        },
                        child: Container(
                          padding: EdgeInsets.all(8.r),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isInCart
                                ? colors.accentOrange
                                : colors.backgroundSecondary,
                          ),
                          child: isItemPending
                              ? SizedBox(
                                  width: 16.w,
                                  height: 16.w,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      isInCart
                                          ? Colors.white
                                          : colors.accentOrange,
                                    ),
                                  ),
                                )
                              : SvgPicture.asset(
                                  Assets.icons.cart,
                                  package: 'grab_go_shared',
                                  height: 16.h,
                                  width: 16.w,
                                  colorFilter: ColorFilter.mode(
                                    isInCart
                                        ? Colors.white
                                        : colors.textPrimary,
                                    BlendMode.srcIn,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  );
                },
              );
            }, childCount: items.length),
          ),
        );
      },
    );
  }

  Widget _buildGroceryItemsSliver(AppColorsExtension colors, bool isDark) {
    final padding = MediaQuery.paddingOf(context);
    return Consumer<GroceryProvider>(
      builder: (context, provider, _) {
        if (provider.isLoadingItems) {
          return SliverToBoxAdapter(
            child: BrowseGridSkeleton(
              colors: colors,
              isDark: isDark,
              isGridView: _isGridView,
            ),
          );
        }

        final items = _getFilteredGroceryItems(
          provider,
        ).where((item) => item.discountPercentage <= 0).toList();

        if (items.isEmpty) {
          return _buildEmptyState(colors);
        }

        return SliverPadding(
          padding: EdgeInsets.only(
            left: 20.w,
            right: 20.w,
            top: 8.h,
            bottom: padding.bottom + 16.h,
          ),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: kGroceryProductGridAspectRatio,
              crossAxisSpacing: KSpacing.sm.w,
              mainAxisSpacing: KSpacing.sm.h,
            ),
            delegate: SliverChildBuilderDelegate((context, index) {
              final item = items[index];
              return GroceryProductCard(
                item: item,
                showStoreName: true,
                onTap: () => context.push('/foodDetails', extra: item),
              );
            }, childCount: items.length),
          ),
        );
      },
    );
  }

  Widget _buildPharmacyItemsSliver(AppColorsExtension colors, bool isDark) {
    final padding = MediaQuery.paddingOf(context);
    return Consumer<PharmacyProvider>(
      builder: (context, provider, _) {
        if (provider.isLoadingItems) {
          return SliverToBoxAdapter(
            child: BrowseGridSkeleton(
              colors: colors,
              isDark: isDark,
              isGridView: _isGridView,
            ),
          );
        }

        final items = _getFilteredPharmacyItems(
          provider,
        ).where((item) => item.discountPercentage <= 0).toList();

        if (items.isEmpty) {
          return _buildEmptyState(colors);
        }

        return SliverPadding(
          padding: EdgeInsets.only(
            left: 20.w,
            right: 20.w,
            top: 8.h,
            bottom: padding.bottom + 16.h,
          ),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: kGroceryProductGridAspectRatio,
              crossAxisSpacing: KSpacing.sm.w,
              mainAxisSpacing: KSpacing.sm.h,
            ),
            delegate: SliverChildBuilderDelegate((context, index) {
              final item = items[index];
              return PharmacyProductCard(
                item: item,
                showStoreName: true,
                onTap: () => context.push('/foodDetails', extra: item),
              );
            }, childCount: items.length),
          ),
        );
      },
    );
  }

  Widget _buildGrabMartItemsSliver(AppColorsExtension colors, bool isDark) {
    final padding = MediaQuery.paddingOf(context);
    return Consumer<GrabMartProvider>(
      builder: (context, provider, _) {
        if (provider.isLoadingItems) {
          return SliverToBoxAdapter(
            child: BrowseGridSkeleton(
              colors: colors,
              isDark: isDark,
              isGridView: _isGridView,
            ),
          );
        }

        final items = provider.items
            .where(
              (item) =>
                  item.categoryId == widget.categoryId &&
                  item.discountPercentage <= 0,
            )
            .toList();

        if (items.isEmpty) {
          return _buildEmptyState(colors);
        }

        return SliverPadding(
          padding: EdgeInsets.only(
            left: 20.w,
            right: 20.w,
            top: 8.h,
            bottom: padding.bottom + 16.h,
          ),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              final item = items[index];
              return Padding(
                padding: EdgeInsets.only(bottom: 16.h),
                child: FoodItemCard(
                  item: item.toFoodItem(),
                  margin: EdgeInsets.zero,
                  onTap: () => context.push('/foodDetails', extra: item),
                ),
              );
            }, childCount: items.length),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(AppColorsExtension colors) {
    final accentColor = widget.isGrocery
        ? colors.serviceGrocery
        : widget.isPharmacy
        ? colors.servicePharmacy
        : colors.accentOrange;
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(20.r),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.shopping_basket_outlined,
                size: 40.sp,
                color: accentColor,
              ),
            ),
            SizedBox(height: 16.h),
            Text(
              'No items found',
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              'Try adjusting your filters',
              style: TextStyle(fontSize: 14.sp, color: colors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  List<FoodItem> _getFilteredFoodItems(FoodProvider provider) {
    List<FoodItem> items = [];

    // Get items from the selected category
    try {
      final selectedCategory = provider.categories.firstWhere(
        (cat) => cat.id == widget.categoryId,
      );
      items = List.from(selectedCategory.items);
    } catch (e) {
      items = [];
    }

    // Apply comprehensive filter from HomeSearch
    if (_comprehensiveFilter.isActive) {
      // Apply price filter
      if (_comprehensiveFilter.minPrice != 0 ||
          _comprehensiveFilter.maxPrice != 10000) {
        items = items.where((item) {
          return item.price >= _comprehensiveFilter.minPrice &&
              item.price <= _comprehensiveFilter.maxPrice;
        }).toList();
      }

      // Apply rating filter
      if (_comprehensiveFilter.minRating != null) {
        items = items
            .where((item) => item.rating >= _comprehensiveFilter.minRating!)
            .toList();
      }

      // Apply on sale filter
      if (_comprehensiveFilter.onSale) {
        items = items.where((item) => item.discountPercentage > 0).toList();
      }

      // Apply new items filter
      if (_comprehensiveFilter.isNew) {
        items = items.where((item) => item.orderCount < 10).toList();
      }

      // Apply fast delivery filter
      if (_comprehensiveFilter.fast) {
        items = items.where((item) => item.deliveryTimeMinutes <= 30).toList();
      }

      // Apply dietary filter
      if (_comprehensiveFilter.dietary != null &&
          _comprehensiveFilter.dietary!.isNotEmpty) {
        items = items
            .where(
              (item) => item.dietaryTags.contains(_comprehensiveFilter.dietary),
            )
            .toList();
      }
    }

    // Apply quick filters
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
          items = items
              .where((item) => item.deliveryTimeMinutes <= 30)
              .toList();
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
                  return item.deliveryTimeMinutes >= 20 &&
                      item.deliveryTimeMinutes <= 30;
                case '30-45 min':
                  return item.deliveryTimeMinutes > 30 &&
                      item.deliveryTimeMinutes <= 45;
                case 'Any Time':
                default:
                  return true;
              }
            }).toList();
          }
          break;
        case 'Dietary':
          if (_selectedDietary != null) {
            items = items.where((item) {
              try {
                return item.dietaryTags.contains(_selectedDietary);
              } catch (e) {
                return false;
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
    List<GroceryItem> items = provider.items
        .where((item) => item.categoryId == widget.categoryId)
        .toList();

    // Apply comprehensive filter from HomeSearch
    if (_comprehensiveFilter.isActive) {
      // Apply price filter
      if (_comprehensiveFilter.minPrice != 0 ||
          _comprehensiveFilter.maxPrice != 10000) {
        items = items.where((item) {
          return item.price >= _comprehensiveFilter.minPrice &&
              item.price <= _comprehensiveFilter.maxPrice;
        }).toList();
      }

      // Apply rating filter
      if (_comprehensiveFilter.minRating != null) {
        items = items
            .where((item) => item.rating >= _comprehensiveFilter.minRating!)
            .toList();
      }

      // Apply on sale filter
      if (_comprehensiveFilter.onSale) {
        items = items.where((item) => item.discountPercentage > 0).toList();
      }

      // Apply new items filter
      if (_comprehensiveFilter.isNew) {
        final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
        items = items
            .where((item) => item.createdAt.isAfter(sevenDaysAgo))
            .toList();
      }
    }

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
          items = items
              .where((item) => item.createdAt.isAfter(sevenDaysAgo))
              .toList();
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
      }
    }

    // Apply sort
    _applySortToGroceryItems(items);

    return items;
  }

  List<PharmacyItem> _getFilteredPharmacyItems(PharmacyProvider provider) {
    List<PharmacyItem> items = provider.items
        .where((item) => item.categoryId == widget.categoryId)
        .toList();

    if (_comprehensiveFilter.isActive) {
      if (_comprehensiveFilter.minPrice != 0 ||
          _comprehensiveFilter.maxPrice != 10000) {
        items = items.where((item) {
          return item.price >= _comprehensiveFilter.minPrice &&
              item.price <= _comprehensiveFilter.maxPrice;
        }).toList();
      }

      if (_comprehensiveFilter.minRating != null) {
        items = items
            .where((item) => item.rating >= _comprehensiveFilter.minRating!)
            .toList();
      }

      if (_comprehensiveFilter.onSale) {
        items = items.where((item) => item.discountPercentage > 0).toList();
      }

      if (_comprehensiveFilter.isNew) {
        final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
        items = items
            .where((item) => item.createdAt.isAfter(sevenDaysAgo))
            .toList();
      }
    }

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
          items = items
              .where((item) => item.createdAt.isAfter(sevenDaysAgo))
              .toList();
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
      }
    }

    _applySortToPharmacyItems(items);

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
        items.sort(
          (a, b) => a.deliveryTimeMinutes.compareTo(b.deliveryTimeMinutes),
        );
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

  void _applySortToPharmacyItems(List<PharmacyItem> items) {
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
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: colors.backgroundPrimary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
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
                  decoration: BoxDecoration(
                    color: colors.inputBorder,
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
              ),
              SizedBox(height: KSpacing.md.h),
              Text(
                'Select $filterType',
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
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
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w400,
                      color: isSelected
                          ? colors.accentOrange
                          : colors.textPrimary,
                    ),
                  ),
                  trailing: isSelected
                      ? Icon(
                          Icons.check_circle,
                          color: colors.accentOrange,
                          size: 24.sp,
                        )
                      : null,
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

  void _showSortOptions() {
    final colors = context.appColors;

    showModalBottomSheet(
      context: context,
      backgroundColor: colors.backgroundPrimary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (context) {
        return Container(
          padding: EdgeInsets.all(20.r),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Sort by',
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
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
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w400,
                      color: isSelected
                          ? colors.accentOrange
                          : colors.textPrimary,
                    ),
                  ),
                  trailing: isSelected
                      ? Icon(
                          Icons.check,
                          color: colors.accentOrange,
                          size: 20.sp,
                        )
                      : null,
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

  Widget _buildCollapsibleCategoryHeader(
    AppColorsExtension colors,
    Size size,
    bool isDark,
  ) {
    return ValueListenableBuilder<double>(
      valueListenable: _scrollOffsetNotifier,
      builder: (context, scrollOffset, _) {
        final collapseProgress = (scrollOffset / _scrollThreshold).clamp(
          0.0,
          1.0,
        );
        final expandedHeight = UmbrellaHeaderMetrics.expandedHeightFor(
          size,
          extra: _headerExtraHeight,
        );
        final currentHeight =
            expandedHeight -
            ((expandedHeight - _collapsedHeight) * collapseProgress);
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
              child: _buildCategoryHeader(colors, isDark),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCategoryHeader(AppColorsExtension colors, bool isDark) {
    return SizedBox.expand(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          0.w,
          MediaQuery.of(context).padding.top + 6.h,
          0.w,
          20.h,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SizedBox(width: 10.w),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      context.pop();
                    },
                    customBorder: const CircleBorder(),
                    child: Padding(
                      padding: EdgeInsets.all(10.r),
                      child: SvgPicture.asset(
                        Assets.icons.navArrowLeft,
                        package: 'grab_go_shared',
                        colorFilter: const ColorFilter.mode(
                          Colors.white,
                          BlendMode.srcIn,
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.categoryName,
                        style: TextStyle(
                          fontFamily: "Lato",
                          package: 'grab_go_shared',
                          fontSize: 20.sp,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 2.h),
                      if (widget.isFood)
                        Consumer<FoodProvider>(
                          builder: (context, provider, _) {
                            final items = _getFilteredFoodItems(provider);
                            return Text(
                              '${items.length} options available',
                              style: TextStyle(
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w500,
                                color: Colors.white.withValues(alpha: 0.8),
                              ),
                            );
                          },
                        )
                      else if (widget.isGrocery)
                        Consumer<GroceryProvider>(
                          builder: (context, provider, _) {
                            final items = _getFilteredGroceryItems(provider);
                            return Text(
                              '${items.length} options available',
                              style: TextStyle(
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w500,
                                color: Colors.white.withValues(alpha: 0.8),
                              ),
                            );
                          },
                        )
                      else if (widget.isPharmacy)
                        Consumer<PharmacyProvider>(
                          builder: (context, provider, _) {
                            final items = _getFilteredPharmacyItems(provider);
                            return Text(
                              '${items.length} options available',
                              style: TextStyle(
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w500,
                                color: Colors.white.withValues(alpha: 0.8),
                              ),
                            );
                          },
                        )
                      else if (widget.isGrabMart)
                        Consumer<GrabMartProvider>(
                          builder: (context, provider, _) {
                            final items = provider.items
                                .where(
                                  (item) =>
                                      item.categoryId == widget.categoryId,
                                )
                                .toList();
                            return Text(
                              '${items.length} options available',
                              style: TextStyle(
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w500,
                                color: Colors.white.withValues(alpha: 0.8),
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 8.h),
            _buildCategorySearch(colors),
          ],
        ),
      ),
    );
  }

  Widget _buildCategorySearch(AppColorsExtension colors) {
    if (widget.isFood) {
      return Consumer<FoodProvider>(
        builder: (context, foodProvider, _) {
          final categoryList = foodProvider.categories
              .where((cat) => cat.id == widget.categoryId)
              .toList();
          return HomeSearch(
            categories: categoryList,
            activeFilter: _comprehensiveFilter,
            hintText: "Find your food item...",
            onFilterApplied: (FilterModel filter) {
              setState(() {
                _comprehensiveFilter = filter.copyWith();
              });
            },
            isFood: true,
          );
        },
      );
    } else if (widget.isGrocery) {
      return Consumer<GroceryProvider>(
        builder: (context, groceryProvider, _) {
          final groceryCategories = groceryProvider.categories
              .where((cat) => cat.id == widget.categoryId)
              .map(
                (cat) => FoodCategoryModel(
                  id: cat.id,
                  name: cat.name,
                  emoji: cat.emoji,
                  description: cat.description,
                  isActive: cat.isActive,
                  items: groceryProvider.items
                      .where((item) => item.categoryId == cat.id)
                      .map((item) => item.toFoodItem())
                      .toList(),
                ),
              )
              .toList();
          return HomeSearch(
            categories: groceryCategories,
            activeFilter: _comprehensiveFilter,
            hintText: "Find your grocery item...",
            onFilterApplied: (FilterModel filter) {
              setState(() {
                _comprehensiveFilter = filter.copyWith();
              });
            },
            isFood: false,
          );
        },
      );
    } else if (widget.isPharmacy) {
      return Consumer<PharmacyProvider>(
        builder: (context, pharmacyProvider, _) {
          final pharmacyCategories = pharmacyProvider.categories
              .where((cat) => cat.id == widget.categoryId)
              .map(
                (cat) => FoodCategoryModel(
                  id: cat.id,
                  name: cat.name,
                  emoji: cat.emoji,
                  description: '',
                  isActive: true,
                  items: pharmacyProvider.items
                      .where((item) => item.categoryId == cat.id)
                      .map((item) => item.toFoodItem())
                      .toList(),
                ),
              )
              .toList();
          return HomeSearch(
            categories: pharmacyCategories,
            activeFilter: _comprehensiveFilter,
            hintText: "Search medications...",
            onFilterApplied: (FilterModel filter) {
              setState(() {
                _comprehensiveFilter = filter.copyWith();
              });
            },
            isFood: false,
          );
        },
      );
    } else if (widget.isGrabMart) {
      return Consumer<GrabMartProvider>(
        builder: (context, grabMartProvider, _) {
          final grabMartCategories = grabMartProvider.categories
              .where((cat) => cat.id == widget.categoryId)
              .map(
                (cat) => FoodCategoryModel(
                  id: cat.id,
                  name: cat.name,
                  emoji: cat.emoji,
                  description: '',
                  isActive: true,
                  items: grabMartProvider.items
                      .where((item) => item.categoryId == cat.id)
                      .map((item) => item.toFoodItem())
                      .toList(),
                ),
              )
              .toList();
          return HomeSearch(
            categories: grabMartCategories,
            activeFilter: _comprehensiveFilter,
            hintText: "Search essentials...",
            onFilterApplied: (FilterModel filter) {
              setState(() {
                _comprehensiveFilter = filter.copyWith();
              });
            },
            isFood: false,
          );
        },
      );
    }
    return const SizedBox.shrink();
  }
}
