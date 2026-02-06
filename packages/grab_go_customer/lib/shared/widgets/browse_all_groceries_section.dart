import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:grab_go_customer/features/groceries/model/grocery_item.dart';
import 'package:grab_go_customer/shared/widgets/popular_item_card.dart';
import 'package:grab_go_customer/shared/widgets/section_header.dart';
import 'package:grab_go_shared/grub_go_shared.dart';

class BrowseAllGroceriesSection extends StatefulWidget {
  final List<GroceryItem> items;
  final Function(GroceryItem) onItemTap;
  final bool isLoading;

  const BrowseAllGroceriesSection({super.key, required this.items, required this.onItemTap, this.isLoading = false});

  @override
  State<BrowseAllGroceriesSection> createState() => _BrowseAllGroceriesSectionState();
}

class _BrowseAllGroceriesSectionState extends State<BrowseAllGroceriesSection> {
  static const int _itemsPerPage = 20;
  int _displayedItemsCount = _itemsPerPage;

  @override
  void didUpdateWidget(BrowseAllGroceriesSection oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Reset pagination when items change
    if (widget.items.length != oldWidget.items.length) {
      _displayedItemsCount = _itemsPerPage;
    }

    // Automatically load more when loading indicator is shown
    if (!widget.isLoading && widget.items.length > _displayedItemsCount) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted && widget.items.length > _displayedItemsCount) {
          _loadMore();
        }
      });
    }
  }

  void _loadMore() {
    setState(() {
      _displayedItemsCount = (_displayedItemsCount + _itemsPerPage).clamp(0, widget.items.length);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: 'Browse All Groceries', sectionTotal: widget.items.length, accentColor: colors.accentBlue),
        SizedBox(height: 16.h),

        if (widget.items.isNotEmpty) _buildItemsGrid(),

        // Loading more indicator
        if (!widget.isLoading && widget.items.length > _displayedItemsCount) ...[
          SizedBox(height: 24.h),
          LoadingMore(colors: colors, spinnerColor: colors.accentBlue, borderColor: colors.accentBlue),
          SizedBox(height: 16.h),
        ],
      ],
    );
  }

  Widget _buildItemsGrid() {
    final displayedItems = widget.items.take(_displayedItemsCount).toList();

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.68,
          crossAxisSpacing: 12.w,
          mainAxisSpacing: 16.h,
        ),
        itemCount: displayedItems.length,
        itemBuilder: (context, index) {
          final item = displayedItems[index];

          return PopularItemCard(
            item: item.toFoodItem(),
            cartItem: item,
            orderCount: item.orderCount,
            onTap: () => widget.onItemTap(item),
          );
        },
      ),
    );
  }
}
