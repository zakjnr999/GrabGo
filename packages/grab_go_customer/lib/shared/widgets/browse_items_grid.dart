import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:grab_go_customer/features/cart/model/cart_item_interface.dart';
import 'package:grab_go_customer/shared/widgets/popular_item_card.dart';
import 'package:grab_go_customer/shared/widgets/section_header.dart';
import 'package:grab_go_shared/grub_go_shared.dart';

class BrowseItemsGrid extends StatefulWidget {
  final List<CartItem> items;
  final Function(CartItem) onItemTap;
  final bool isLoading;
  final String title;
  final String icon;
  final Color? accentColor;

  const BrowseItemsGrid({
    super.key,
    required this.items,
    required this.onItemTap,
    this.isLoading = false,
    required this.title,
    required this.icon,
    this.accentColor,
  });

  @override
  State<BrowseItemsGrid> createState() => _BrowseItemsGridState();
}

class _BrowseItemsGridState extends State<BrowseItemsGrid> {
  static const int _itemsPerPage = 20;
  int _displayedItemsCount = _itemsPerPage;

  @override
  void didUpdateWidget(BrowseItemsGrid oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.items.length != oldWidget.items.length) {
      _displayedItemsCount = _itemsPerPage;
    }

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
        SectionHeader(
          title: widget.title,
          sectionTotal: widget.items.length,
          accentColor: widget.accentColor ?? colors.accentOrange,
        ),
        SizedBox(height: 16.h),

        if (widget.items.isNotEmpty) _buildItemsGrid(),

        if (!widget.isLoading && widget.items.length > _displayedItemsCount) ...[
          SizedBox(height: 24.h),
          LoadingMore(
            colors: colors,
            spinnerColor: widget.accentColor ?? colors.accentOrange,
            borderColor: widget.accentColor ?? colors.accentOrange,
          ),
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
        padding: EdgeInsets.zero,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.7,
          crossAxisSpacing: 12.w,
          mainAxisSpacing: 16.h,
        ),
        itemCount: displayedItems.length,
        itemBuilder: (context, index) {
          final item = displayedItems[index];

          return PopularItemCard(
            item: item,
            orderCount: (item as dynamic).orderCount ?? 0,
            onTap: () => widget.onItemTap(item),
          );
        },
      ),
    );
  }
}
