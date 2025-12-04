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
import 'package:grab_go_customer/shared/widgets/home_search.dart';
import 'package:grab_go_customer/shared/widgets/home_banner.dart';
import 'package:grab_go_customer/shared/widgets/food_item_card.dart';
import 'package:grab_go_customer/features/home/model/filter_model.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  FoodCategoryModel? _selectedCategory;
  late ScrollController _scrollController;
  bool _isFabVisible = true;
  double _lastScrollOffset = 0.0;
  FilterModel _activeFilter = FilterModel();

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
    _initializeData();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;

    final currentOffset = _scrollController.offset;
    final scrollDelta = currentOffset - _lastScrollOffset;

    if (currentOffset <= 0) {
      if (!_isFabVisible) {
        setState(() {
          _isFabVisible = true;
        });
      }
      _lastScrollOffset = currentOffset;
      return;
    }

    if (scrollDelta > 5 && currentOffset > 50) {
      if (_isFabVisible) {
        setState(() {
          _isFabVisible = false;
        });
      }
    } else if (scrollDelta < -5) {
      if (!_isFabVisible) {
        setState(() {
          _isFabVisible = true;
        });
      }
    }

    _lastScrollOffset = currentOffset;
  }

  void _initializeData() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<LocationProvider>(context, listen: false).fetchAddress();
      final provider = Provider.of<FoodProvider>(context, listen: false);
      if (provider.categories.isEmpty) {
        provider.fetchCategories();
      } else {
        if (provider.categories.isNotEmpty) {
          setState(() {
            _selectedCategory = provider.categories.first;
          });
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Size size = MediaQuery.sizeOf(context);

    final locationProvider = Provider.of<LocationProvider>(context);
    final itemsProvider = Provider.of<FoodProvider>(context);

    if (itemsProvider.categories.isNotEmpty && _selectedCategory == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _selectedCategory = itemsProvider.categories.first;
          });
        }
      });
    }

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          controller: _scrollController,
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHomeHeader(context, size, colors, isDark, locationProvider),
              SizedBox(height: 8.h),
              _buildHomeSearch(itemsProvider),
              SizedBox(height: KSpacing.lg.h),
              HomeBanner(size: size),
              SizedBox(height: KSpacing.lg.h),
              _buildCategoriesShimer(itemsProvider, isDark, size, colors),
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
                            color: colors.accentViolet.withValues(alpha: 0.1),
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
                          style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w700, color: colors.textPrimary),
                        ),
                      ],
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                      decoration: BoxDecoration(
                        color: colors.accentOrange.withValues(alpha: 0.1),
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
              _buildRecommendedFoodItems(itemsProvider, size, colors, isDark),
            ],
          ),
        ),
      ),

      floatingActionButton: Provider.of<CartProvider>(context, listen: true).cartItems.isNotEmpty
          ? AnimatedOpacity(
              opacity: _isFabVisible ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              child: IgnorePointer(
                ignoring: !_isFabVisible,
                child: Consumer<CartProvider>(
                  builder: (context, cartProvider, child) {
                    return FloatingActionButton.extended(
                      onPressed: () => context.push("/cart"),
                      extendedPadding: EdgeInsets.all(10.r),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(KBorderSize.border)),
                      backgroundColor: colors.accentOrange,
                      label: Text(
                        "${cartProvider.cartItems.length} ${cartProvider.cartItems.length > 1 ? "items in cart" : "item in cart"}",
                        style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w500, color: colors.backgroundPrimary),
                      ),
                      icon: Container(
                        padding: EdgeInsets.all(8.r),
                        decoration: BoxDecoration(color: colors.backgroundPrimary, shape: BoxShape.circle),
                        child: SvgPicture.asset(
                          Assets.icons.cart,
                          height: 20.h,
                          width: 20.w,
                          package: 'grab_go_shared',
                          colorFilter: ColorFilter.mode(colors.textPrimary, BlendMode.srcIn),
                        ),
                      ),
                    );
                  },
                ),
              ),
            )
          : const SizedBox.shrink(),
    );
  }

  Builder _buildRecommendedFoodItems(FoodProvider itemsProvider, Size size, AppColorsExtension colors, bool isDark) {
    return Builder(
      builder: (context) {
        List<FoodItem> recommendedFoods = [];

        List<FoodItem> allFoods = [];

        if (itemsProvider.categories.isEmpty) {
          return Shimmer.fromColors(
            baseColor: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
            highlightColor: isDark ? Colors.grey.shade700 : Colors.grey.shade100,
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: Column(
                children: List.generate(4, (index) {
                  return Container(
                    margin: EdgeInsets.only(left: 20.w, right: 20.w, bottom: 12.h),
                    decoration: BoxDecoration(
                      border: Border.all(color: isDark ? Colors.grey.shade800 : Colors.grey.shade300, width: 0.5),
                      borderRadius: BorderRadius.circular(KBorderSize.borderRadius15),
                    ),
                    child: Row(
                      children: [
                        // Image placeholder
                        Container(
                          height: size.height * 0.14,
                          width: size.width * 0.32,
                          decoration: BoxDecoration(
                            color: isDark ? Colors.grey.shade700 : Colors.grey.shade200,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(KBorderSize.borderRadius15),
                              bottomLeft: Radius.circular(KBorderSize.borderRadius15),
                            ),
                          ),
                        ),

                        // Itemname placeholder
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12.r, vertical: 8.h),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 140.w,
                                  height: 16.h,
                                  decoration: BoxDecoration(
                                    color: isDark ? Colors.grey.shade700 : Colors.grey.shade200,
                                    borderRadius: BorderRadius.circular(4.r),
                                  ),
                                ),
                                SizedBox(height: 6.h),
                                // Rating and delivery time placeholder
                                Container(
                                  width: 120.w,
                                  height: 16.h,
                                  decoration: BoxDecoration(
                                    color: isDark ? Colors.grey.shade700 : Colors.grey.shade200,
                                    borderRadius: BorderRadius.circular(4.r),
                                  ),
                                ),
                                SizedBox(height: 10.h),
                                // Price and cart placeholder
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    //Price placeholder
                                    Container(
                                      width: 100.w,
                                      height: 25.h,
                                      decoration: BoxDecoration(
                                        color: isDark ? Colors.grey.shade700 : Colors.grey.shade200,
                                        borderRadius: BorderRadius.circular(4.r),
                                      ),
                                    ),

                                    // Cart icon placeholder
                                    Container(
                                      height: 32.h,
                                      width: 32.w,
                                      decoration: BoxDecoration(
                                        color: isDark ? Colors.grey.shade700 : Colors.grey.shade200,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ),
            ),
          );
        }

        List<FoodCategoryModel> categoriesToProcess = itemsProvider.categories;

        // Priority 1: If a category is manually selected, show items from that category
        // (This takes precedence over filter categories - user's manual selection should be respected)
        if (_selectedCategory != null) {
          // Check if selected category still exists in the list
          final categoryExists = categoriesToProcess.any((cat) => cat.id == _selectedCategory!.id);
          if (categoryExists) {
            categoriesToProcess = categoriesToProcess
                .where((category) => category.id == _selectedCategory!.id)
                .toList();
          } else {
            // Selected category no longer exists, use first category
            if (categoriesToProcess.isNotEmpty) {
              final firstCategory = categoriesToProcess.first;
              categoriesToProcess = [firstCategory];
              // Update selected category to match only if different
              if (_selectedCategory?.id != firstCategory.id) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    setState(() {
                      _selectedCategory = firstCategory;
                    });
                  }
                });
              }
            }
          }
        }
        // Priority 2: If categories are selected in filter (and no manual selection), use those
        else if (_activeFilter.isActive && _activeFilter.selectedCategories.isNotEmpty) {
          // Validate that selected category IDs actually exist
          final validCategoryIds = itemsProvider.categories.map((cat) => cat.id).where((id) => id.isNotEmpty).toSet();

          final validSelectedCategories = _activeFilter.selectedCategories
              .where((id) => id.isNotEmpty && validCategoryIds.contains(id))
              .toList();

          if (validSelectedCategories.isNotEmpty) {
            categoriesToProcess = itemsProvider.categories
                .where((category) => validSelectedCategories.contains(category.id))
                .toList();
          } else {
            // Selected categories no longer exist, fall back to first category
            if (categoriesToProcess.isNotEmpty) {
              categoriesToProcess = [categoriesToProcess.first];
            }
            // Clear invalid categories from filter
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                setState(() {
                  _activeFilter.selectedCategories.clear();
                });
              }
            });
          }
        }
        // Priority 3: No category selected and no filter, default to first category
        else if (categoriesToProcess.isNotEmpty) {
          final firstCategory = categoriesToProcess.first;
          categoriesToProcess = [firstCategory];
          // Only update if category is actually different
          if (_selectedCategory?.id != firstCategory.id) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                setState(() {
                  _selectedCategory = firstCategory;
                });
              }
            });
          }
        }

        // Collect all food items from categories and remove duplicates immediately
        final Set<String> seenItemKeys = {};
        for (var category in categoriesToProcess) {
          if (category.items.isNotEmpty) {
            for (var item in category.items) {
              // Use a unique key to identify duplicates
              final key = '${item.id}_${item.sellerId}';
              if (!seenItemKeys.contains(key)) {
                seenItemKeys.add(key);
                allFoods.add(item);
              }
            }
          }
        }

        if (_activeFilter.isActive && allFoods.isNotEmpty) {
          allFoods = _applyFilter(allFoods, itemsProvider.categories, _activeFilter);
        }

        if (allFoods.isNotEmpty) {
          recommendedFoods = allFoods.take(5).toList();
        }

        if (recommendedFoods.isEmpty) {
          _activeFilter.isActive
              ? Container(
                  height: size.height * 0.15,
                  margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
                  decoration: BoxDecoration(
                    color: colors.backgroundPrimary,
                    borderRadius: BorderRadius.circular(KBorderSize.borderMedium),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "No items match your filters",
                          style: TextStyle(color: colors.textSecondary, fontSize: 16.sp, fontWeight: FontWeight.w500),
                        ),
                        if (_activeFilter.isActive) ...[
                          SizedBox(height: 8.h),
                          Text(
                            "Try adjusting your filter criteria",
                            style: TextStyle(color: colors.textTertiary, fontSize: 12.sp),
                          ),
                        ],
                      ],
                    ),
                  ),
                )
              : Shimmer.fromColors(
                  baseColor: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                  highlightColor: isDark ? Colors.grey.shade700 : Colors.grey.shade100,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.vertical,
                    child: Column(
                      children: List.generate(4, (index) {
                        return Container(
                          margin: EdgeInsets.only(left: 20.w, right: 20.w, bottom: 12.h),
                          decoration: BoxDecoration(
                            border: Border.all(color: isDark ? Colors.grey.shade800 : Colors.grey.shade300, width: 0.5),
                            borderRadius: BorderRadius.circular(KBorderSize.borderRadius15),
                          ),
                          child: Row(
                            children: [
                              // Image placeholder
                              Container(
                                height: size.height * 0.14,
                                width: size.width * 0.32,
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.grey.shade700 : Colors.grey.shade200,
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(KBorderSize.borderRadius15),
                                    bottomLeft: Radius.circular(KBorderSize.borderRadius15),
                                  ),
                                ),
                              ),

                              // Itemname placeholder
                              Expanded(
                                child: Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 12.r, vertical: 8.h),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        width: 140.w,
                                        height: 16.h,
                                        decoration: BoxDecoration(
                                          color: isDark ? Colors.grey.shade700 : Colors.grey.shade200,
                                          borderRadius: BorderRadius.circular(4.r),
                                        ),
                                      ),
                                      SizedBox(height: 6.h),
                                      // Rating and delivery time placeholder
                                      Container(
                                        width: 120.w,
                                        height: 16.h,
                                        decoration: BoxDecoration(
                                          color: isDark ? Colors.grey.shade700 : Colors.grey.shade200,
                                          borderRadius: BorderRadius.circular(4.r),
                                        ),
                                      ),
                                      SizedBox(height: 10.h),
                                      // Price and cart placeholder
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          //Price placeholder
                                          Container(
                                            width: 100.w,
                                            height: 16.h,
                                            decoration: BoxDecoration(
                                              color: isDark ? Colors.grey.shade700 : Colors.grey.shade200,
                                              borderRadius: BorderRadius.circular(4.r),
                                            ),
                                          ),

                                          // Cart icon placeholder
                                          Container(
                                            height: 32.h,
                                            width: 32.w,
                                            decoration: BoxDecoration(
                                              color: isDark ? Colors.grey.shade700 : Colors.grey.shade200,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ),
                  ),
                );
        }

        return ListView.builder(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          itemCount: recommendedFoods.length,
          itemBuilder: (context, index) {
            final item = recommendedFoods[index];

            return Consumer<CartProvider>(
              builder: (context, provider, _) {
                final bool isInCart = provider.cartItems.containsKey(item);

                return FoodItemCard(
                  item: item,
                  onTap: () => context.push("/foodDetails", extra: item),
                  trailing: GestureDetector(
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
                        border: Border.all(color: isInCart ? colors.accentOrange : colors.inputBorder, width: 1),
                      ),
                      child: SvgPicture.asset(
                        Assets.icons.cart,
                        package: 'grab_go_shared',
                        height: 16.h,
                        width: 16.w,
                        colorFilter: ColorFilter.mode(isInCart ? Colors.white : colors.textPrimary, BlendMode.srcIn),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Builder _buildCategoriesShimer(FoodProvider itemsProvider, bool isDark, Size size, AppColorsExtension colors) {
    return Builder(
      builder: (context) {
        if (itemsProvider.isLoading) {
          return Shimmer.fromColors(
            baseColor: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
            highlightColor: isDark ? Colors.grey.shade700 : Colors.grey.shade100,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.only(left: 10.w),
              child: Row(
                children: List.generate(4, (index) {
                  return Container(
                    margin: EdgeInsets.symmetric(horizontal: 10.w),
                    height: 95.h,
                    width: size.width * 0.22,
                    decoration: BoxDecoration(
                      border: Border.all(color: isDark ? Colors.grey.shade800 : Colors.grey.shade300, width: 0.5),
                      borderRadius: BorderRadius.circular(KBorderSize.borderRadius15),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        //Emoji placeholder
                        Container(
                          height: 40.h,
                          width: 40.w,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isDark ? Colors.grey.shade700 : Colors.grey.shade200,
                          ),
                        ),
                        SizedBox(height: KSpacing.md.h),

                        //Category name placeholder
                        Container(
                          height: 16.h,
                          width: 50.w,
                          decoration: BoxDecoration(
                            color: isDark ? Colors.grey.shade700 : Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(4.r),
                          ),
                        ),
                      ],
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
              padding: EdgeInsets.only(left: 10.w),
              child: Row(
                children: List.generate(4, (index) {
                  return Container(
                    margin: EdgeInsets.symmetric(horizontal: 10.w),
                    height: 95.h,
                    width: size.width * 0.22,
                    decoration: BoxDecoration(
                      border: Border.all(color: isDark ? Colors.grey.shade800 : Colors.grey.shade300, width: 0.5),
                      borderRadius: BorderRadius.circular(KBorderSize.borderRadius15),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        //Emoji placeholder
                        Container(
                          height: 40.h,
                          width: 40.w,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isDark ? Colors.grey.shade700 : Colors.grey.shade200,
                          ),
                        ),
                        SizedBox(height: KSpacing.md.h),

                        //Category name placeholder
                        Container(
                          height: 16.h,
                          width: 50.w,
                          decoration: BoxDecoration(
                            color: isDark ? Colors.grey.shade700 : Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(4.r),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ),
            ),
          );
        } else if (itemsProvider.categories.isEmpty) {
          return Shimmer.fromColors(
            baseColor: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
            highlightColor: isDark ? Colors.grey.shade700 : Colors.grey.shade100,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.only(left: 10.w),
              child: Row(
                children: List.generate(4, (index) {
                  return Container(
                    margin: EdgeInsets.symmetric(horizontal: 10.w),
                    height: 95.h,
                    width: size.width * 0.22,
                    decoration: BoxDecoration(
                      border: Border.all(color: isDark ? Colors.grey.shade800 : Colors.grey.shade300, width: 0.5),
                      borderRadius: BorderRadius.circular(KBorderSize.borderRadius15),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        //Emoji placeholder
                        Container(
                          height: 40.h,
                          width: 40.w,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isDark ? Colors.grey.shade700 : Colors.grey.shade200,
                          ),
                        ),
                        SizedBox(height: KSpacing.md.h),

                        //Category name placeholder
                        Container(
                          height: 16.h,
                          width: 50.w,
                          decoration: BoxDecoration(
                            color: isDark ? Colors.grey.shade700 : Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(4.r),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ),
            ),
          );
        }

        List<FoodCategoryModel> categoriesToShow = itemsProvider.categories;
        if (_activeFilter.isActive && _activeFilter.selectedCategories.isNotEmpty) {
          final validCategoryIds = itemsProvider.categories.map((cat) => cat.id).where((id) => id.isNotEmpty).toSet();

          final validSelectedCategories = _activeFilter.selectedCategories
              .where((id) => id.isNotEmpty && validCategoryIds.contains(id))
              .toList();

          if (validSelectedCategories.isNotEmpty) {
            categoriesToShow = itemsProvider.categories
                .where((category) => validSelectedCategories.contains(category.id))
                .toList();
          } else {
            categoriesToShow = itemsProvider.categories;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                setState(() {
                  _activeFilter.selectedCategories.clear();
                });
              }
            });
          }

          if (categoriesToShow.isEmpty) {
            return Container(
              height: 95.h,
              width: double.infinity,
              margin: EdgeInsets.only(left: 10.w, right: 20.w),
              decoration: BoxDecoration(
                color: colors.backgroundPrimary,
                borderRadius: BorderRadius.circular(KBorderSize.borderMedium),
              ),
              child: Center(
                child: Text(
                  "No categories match your filter",
                  style: TextStyle(color: colors.textSecondary, fontSize: 14.sp, fontWeight: FontWeight.w500),
                ),
              ),
            );
          }
        }

        return FoodCategoryList(
          categories: categoriesToShow,
          initialSelectedCategory: _selectedCategory,
          onCategorySelected: (FoodCategoryModel category) {
            setState(() {
              _selectedCategory = category;
            });
          },
        );
      },
    );
  }

  HomeSearch _buildHomeSearch(FoodProvider itemsProvider) {
    return HomeSearch(
      categories: itemsProvider.categories,
      activeFilter: _activeFilter,
      onFilterApplied: (FilterModel filter) {
        setState(() {
          _activeFilter = filter.copyWith();
          if (filter.isActive && filter.selectedCategories.isNotEmpty) {
            final validCategoryIds = itemsProvider.categories.map((cat) => cat.id).where((id) => id.isNotEmpty).toSet();

            final validSelectedCategories = filter.selectedCategories
                .where((id) => id.isNotEmpty && validCategoryIds.contains(id))
                .toList();

            if (validSelectedCategories.isNotEmpty) {
              final filteredCategories = itemsProvider.categories
                  .where((cat) => validSelectedCategories.contains(cat.id))
                  .toList();

              if (_selectedCategory != null && !validSelectedCategories.contains(_selectedCategory!.id)) {
                _selectedCategory = filteredCategories.first;
              } else {
                _selectedCategory ??= filteredCategories.first;
              }
            } else {
              _activeFilter.selectedCategories.clear();
              if (_selectedCategory == null && itemsProvider.categories.isNotEmpty) {
                _selectedCategory = itemsProvider.categories.first;
              }
            }
          } else {
            if (itemsProvider.categories.isNotEmpty) {
              if (_selectedCategory == null ||
                  !itemsProvider.categories.any((cat) => cat.id == _selectedCategory!.id)) {
                _selectedCategory = itemsProvider.categories.first;
              }
            }
          }
        });
      },
    );
  }

  Padding _buildHomeHeader(
    BuildContext context,
    Size size,
    AppColorsExtension colors,
    bool isDark,
    LocationProvider locationProvider,
  ) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                context.push("/paymentComplete");
              },
              child: Container(
                height: size.height * 0.08,
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                decoration: BoxDecoration(
                  color: colors.backgroundPrimary,
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(color: colors.inputBorder.withValues(alpha: 0.3), width: 0.5),
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
                        color: colors.accentOrange.withValues(alpha: 0.1),
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
                            locationProvider.address.isEmpty ? "Fetching location..." : locationProvider.address,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700, color: colors.textPrimary),
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
            height: size.height * 0.08,
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
            decoration: BoxDecoration(
              color: colors.backgroundPrimary,
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: colors.inputBorder.withValues(alpha: 0.3), width: 0.5),
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
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      context.push("/notification");
                    },
                    customBorder: const CircleBorder(),
                    child: Padding(
                      padding: EdgeInsets.all(10.r),
                      child: SvgPicture.asset(
                        Assets.icons.bellNotification,
                        package: 'grab_go_shared',
                        colorFilter: ColorFilter.mode(colors.textPrimary, BlendMode.srcIn),
                      ),
                    ),
                  ),
                ),

                Material(
                  color: Colors.transparent,
                  child: Builder(
                    builder: (context) => InkWell(
                      onTap: () {
                        context.push("/status");
                      },
                      customBorder: const CircleBorder(),
                      child: Padding(
                        padding: EdgeInsets.all(10.r),
                        child: SvgPicture.asset(
                          Assets.icons.styleBorder,
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
    );
  }

  /// Apply filter to food items
  /// This applies price, rating, and restaurant filters
  /// Category filtering is handled separately when collecting items
  List<FoodItem> _applyFilter(List<FoodItem> items, List<FoodCategoryModel> categories, FilterModel filter) {
    if (items.isEmpty) return [];

    // Validate filter values
    final validMinPrice = filter.minPrice.isNaN || filter.minPrice.isInfinite || filter.minPrice < 0
        ? 0.0
        : filter.minPrice;
    final validMaxPrice = filter.maxPrice.isNaN || filter.maxPrice.isInfinite || filter.maxPrice < validMinPrice
        ? 10000.0
        : filter.maxPrice;
    final validMinRating =
        filter.minRating != null &&
            (filter.minRating!.isNaN || filter.minRating!.isInfinite || filter.minRating! < 0 || filter.minRating! > 5)
        ? null
        : filter.minRating;

    // Get all available restaurant names for validation
    final availableRestaurants = <String>{};
    for (var category in categories) {
      for (var item in category.items) {
        if (item.sellerName.isNotEmpty) {
          availableRestaurants.add(item.sellerName);
        }
      }
    }

    // Filter out invalid restaurant selections
    final validSelectedRestaurants = filter.selectedRestaurants
        .where((restaurant) => restaurant.isNotEmpty && availableRestaurants.contains(restaurant))
        .toList();

    return items.where((item) {
      // Price filter - check if price is within range
      // Only apply if price range is different from default (0-10000)
      final isPriceFilterActive = validMinPrice != 0 || validMaxPrice != 10000;
      if (isPriceFilterActive) {
        // Ensure price is valid and within range
        if (item.price.isNaN || item.price.isInfinite || item.price < 0) return false;
        if (item.price < validMinPrice || item.price > validMaxPrice) {
          return false;
        }
      }

      // Rating filter - check if rating meets minimum requirement
      if (validMinRating != null) {
        // Ensure rating is valid (0-5 range)
        if (item.rating.isNaN || item.rating.isInfinite || item.rating < 0 || item.rating > 5) return false;
        if (item.rating < validMinRating) {
          return false;
        }
      }

      // Restaurant filter - check if restaurant is selected
      if (validSelectedRestaurants.isNotEmpty) {
        // Ensure sellerName is not empty and matches
        if (item.sellerName.isEmpty || !validSelectedRestaurants.contains(item.sellerName)) {
          return false;
        }
      }

      // Note: Category filtering is handled earlier when collecting items
      // to avoid processing items from unselected categories

      return true;
    }).toList();
  }
}
