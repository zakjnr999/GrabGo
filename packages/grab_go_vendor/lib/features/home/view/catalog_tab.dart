import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:grab_go_vendor/features/auth/model/vendor_service_option.dart';
import 'package:grab_go_vendor/features/catalog/model/vendor_catalog_models.dart';
import 'package:grab_go_vendor/features/catalog/view/catalog_item_form_page.dart';
import 'package:grab_go_vendor/features/catalog/view/category_management_page.dart';
import 'package:grab_go_vendor/features/catalog/viewmodel/catalog_viewmodel.dart';
import 'package:grab_go_vendor/features/store_context/viewmodel/store_context_viewmodel.dart';
import 'package:grab_go_vendor/shared/viewmodel/vendor_preview_session_viewmodel.dart';
import 'package:grab_go_vendor/shared/widgets/vendor_store_context_chip.dart';
import 'package:provider/provider.dart';

class CatalogTab extends StatelessWidget {
  const CatalogTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => CatalogViewModel(),
      child: const _CatalogTabView(),
    );
  }
}

class _CatalogTabView extends StatelessWidget {
  const _CatalogTabView();

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Consumer3<
      CatalogViewModel,
      VendorStoreContextViewModel,
      VendorPreviewSessionViewModel
    >(
      builder: (context, viewModel, storeContext, previewSession, _) {
        final visibleServices = _visibleVendorServices(storeContext);
        final orderedVisibleServices = visibleServices.toList()
          ..sort((a, b) => a.index.compareTo(b.index));
        if (viewModel.serviceFilter != null &&
            !visibleServices.contains(viewModel.serviceFilter)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!context.mounted) return;
            viewModel.setServiceFilter(null);
          });
        }

        final visibleCategoryIds = viewModel.categories
            .where((category) => visibleServices.contains(category.serviceType))
            .map((category) => category.id)
            .toSet();
        if (viewModel.categoryFilterId != null &&
            !visibleCategoryIds.contains(viewModel.categoryFilterId)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!context.mounted) return;
            viewModel.setCategoryFilter(null);
          });
        }

        final items = viewModel.filteredItems
            .where((item) => visibleServices.contains(item.serviceType))
            .toList();
        final visibleCategories = viewModel.visibleCategories
            .where((category) => visibleServices.contains(category.serviceType))
            .toList();

        return SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 14.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Catalog',
                      style: TextStyle(
                        fontSize: 28.sp,
                        fontWeight: FontWeight.w900,
                        color: colors.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    OutlinedButton.icon(
                      onPressed: visibleServices.isEmpty
                          ? null
                          : () =>
                                _openCategoryManager(context, visibleServices),
                      icon: Icon(Icons.category_outlined, size: 15.sp),
                      label: Text(
                        'Categories',
                        style: TextStyle(
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colors.textPrimary,
                        side: BorderSide(color: colors.inputBorder),
                        padding: EdgeInsets.symmetric(
                          horizontal: 10.w,
                          vertical: 8.h,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10.r),
                        ),
                      ),
                    ),
                    SizedBox(width: 8.w),
                    ElevatedButton.icon(
                      onPressed: visibleServices.isEmpty
                          ? null
                          : () => _openAddItem(context, visibleServices),
                      icon: Icon(Icons.add_rounded, size: 16.sp),
                      label: Text(
                        'Add Item',
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.vendorPrimaryBlue,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: EdgeInsets.symmetric(
                          horizontal: 12.w,
                          vertical: 10.h,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8.h),
                Text(
                  visibleServices.isEmpty
                      ? 'No services are active for this profile and store context.'
                      : 'Showing ${previewSession.servicesLabel(visibleServices)} catalog.',
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w500,
                    color: colors.textSecondary,
                  ),
                ),
                SizedBox(height: 8.h),
                const Align(
                  alignment: Alignment.centerRight,
                  child: VendorStoreContextChip(),
                ),
                SizedBox(height: 12.h),
                TextField(
                  controller: viewModel.searchController,
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search by item or category',
                    hintStyle: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w500,
                      color: colors.textSecondary,
                    ),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      size: 18.sp,
                      color: colors.textSecondary,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.r),
                      borderSide: BorderSide(color: colors.inputBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.r),
                      borderSide: BorderSide(color: colors.vendorPrimaryBlue),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.r),
                      borderSide: BorderSide(color: colors.inputBorder),
                    ),
                    filled: true,
                    fillColor: colors.backgroundPrimary,
                  ),
                ),
                SizedBox(height: 10.h),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _FilterChip(
                        label: 'All Services',
                        selected: viewModel.serviceFilter == null,
                        color: colors.vendorPrimaryBlue,
                        onTap: () => viewModel.setServiceFilter(null),
                      ),
                      ...orderedVisibleServices.map((service) {
                        final color = _serviceColor(colors, service);
                        return _FilterChip(
                          label: service.label,
                          selected: viewModel.serviceFilter == service,
                          color: color,
                          onTap: () => viewModel.setServiceFilter(service),
                        );
                      }),
                    ],
                  ),
                ),
                SizedBox(height: 8.h),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _FilterChip(
                        label: 'All Categories',
                        selected: viewModel.categoryFilterId == null,
                        color: colors.vendorPrimaryBlue,
                        onTap: () => viewModel.setCategoryFilter(null),
                      ),
                      ...visibleCategories.map((category) {
                        final color = _serviceColor(
                          colors,
                          category.serviceType,
                        );
                        return _FilterChip(
                          label: category.name,
                          selected: viewModel.categoryFilterId == category.id,
                          color: color,
                          onTap: () => viewModel.setCategoryFilter(category.id),
                        );
                      }),
                    ],
                  ),
                ),
                SizedBox(height: 8.h),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _FilterChip(
                        label: 'All',
                        selected: viewModel.availabilityFilter == null,
                        color: colors.vendorPrimaryBlue,
                        onTap: () => viewModel.setAvailabilityFilter(null),
                      ),
                      _FilterChip(
                        label: 'Available',
                        selected: viewModel.availabilityFilter == true,
                        color: colors.success,
                        onTap: () => viewModel.setAvailabilityFilter(true),
                      ),
                      _FilterChip(
                        label: 'Unavailable',
                        selected: viewModel.availabilityFilter == false,
                        color: colors.error,
                        onTap: () => viewModel.setAvailabilityFilter(false),
                      ),
                    ],
                  ),
                ),
                if (viewModel.selectedCount > 0) ...[
                  SizedBox(height: 10.h),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(10.r),
                    decoration: BoxDecoration(
                      color: colors.vendorPrimaryBlue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${viewModel.selectedCount} selected',
                            style: TextStyle(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w700,
                              color: colors.vendorPrimaryBlue,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () =>
                              viewModel.setSelectedItemsAvailability(true),
                          child: Text(
                            'Mark Available',
                            style: TextStyle(
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w700,
                              color: colors.success,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () =>
                              viewModel.setSelectedItemsAvailability(false),
                          child: Text(
                            'Mark Unavailable',
                            style: TextStyle(
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w700,
                              color: colors.error,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () => _openBulkStockAdjust(context),
                          child: Text(
                            'Stock +/-',
                            style: TextStyle(
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w700,
                              color: colors.vendorPrimaryBlue,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: viewModel.clearSelection,
                          icon: Icon(Icons.close_rounded, size: 18.sp),
                          color: colors.textSecondary,
                        ),
                      ],
                    ),
                  ),
                ],
                SizedBox(height: 12.h),
                if (visibleServices.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(18.r),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14.r),
                      border: Border.all(color: colors.border),
                      color: colors.backgroundPrimary,
                    ),
                    child: Text(
                      'No services are active for this vendor profile on the selected branch.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w600,
                        color: colors.textSecondary,
                      ),
                    ),
                  )
                else if (items.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(18.r),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14.r),
                      border: Border.all(color: colors.border),
                      color: colors.backgroundPrimary,
                    ),
                    child: Text(
                      'No catalog items match current filters.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w600,
                        color: colors.textSecondary,
                      ),
                    ),
                  )
                else
                  ...items.map((item) {
                    return _CatalogItemCard(
                      item: item,
                      categoryName: viewModel.categoryNameFor(item.categoryId),
                      isSelected: viewModel.selectedItemIds.contains(item.id),
                      onSelect: () => viewModel.toggleItemSelection(item.id),
                      onEdit: () =>
                          _openEditItem(context, item, visibleServices),
                      onDelete: () => _confirmDeleteItem(context, item),
                      onStockAdjust: () => _openStockAdjust(context, item),
                      onAvailabilityChanged: (value) =>
                          viewModel.toggleItemAvailability(item.id, value),
                    );
                  }),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openAddItem(
    BuildContext context,
    Set<VendorServiceType> visibleServices,
  ) async {
    final viewModel = context.read<CatalogViewModel>();
    final categories = viewModel.categories
        .where((category) => visibleServices.contains(category.serviceType))
        .toList();
    if (categories.isEmpty) return;
    final draft = await Navigator.push<VendorCatalogItemDraft>(
      context,
      MaterialPageRoute(
        builder: (_) => CatalogItemFormPage(
          title: 'Add Catalog Item',
          categories: categories,
        ),
      ),
    );
    if (draft == null) return;
    viewModel.addItem(draft);
  }

  Future<void> _openEditItem(
    BuildContext context,
    VendorCatalogItem item,
    Set<VendorServiceType> visibleServices,
  ) async {
    final viewModel = context.read<CatalogViewModel>();
    final categories = viewModel.categories
        .where((category) => visibleServices.contains(category.serviceType))
        .toList();
    if (categories.isEmpty) return;
    final draft = await Navigator.push<VendorCatalogItemDraft>(
      context,
      MaterialPageRoute(
        builder: (_) => CatalogItemFormPage(
          title: 'Edit Item',
          categories: categories,
          initialItem: item,
        ),
      ),
    );
    if (draft == null) return;
    viewModel.updateItem(item.id, draft);
  }

  Future<void> _openCategoryManager(
    BuildContext context,
    Set<VendorServiceType> visibleServices,
  ) async {
    final viewModel = context.read<CatalogViewModel>();
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: viewModel,
          child: CategoryManagementPage(allowedServices: visibleServices),
        ),
      ),
    );
  }

  Future<void> _confirmDeleteItem(
    BuildContext context,
    VendorCatalogItem item,
  ) async {
    final colors = context.appColors;
    final viewModel = context.read<CatalogViewModel>();
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: colors.backgroundPrimary,
          title: const Text('Delete Item'),
          content: Text(
            'Delete "${item.name}" from catalog?',
            style: TextStyle(
              fontSize: 13.sp,
              fontWeight: FontWeight.w500,
              color: colors.textSecondary,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text('Delete', style: TextStyle(color: colors.error)),
            ),
          ],
        );
      },
    );
    if (shouldDelete != true) return;
    viewModel.removeItem(item.id);
  }

  Future<void> _openBulkStockAdjust(BuildContext context) async {
    final viewModel = context.read<CatalogViewModel>();
    if (viewModel.selectedCount == 0) return;

    final colors = context.appColors;
    final valueController = TextEditingController(text: '1');
    var increase = true;

    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: colors.backgroundPrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(18.r)),
        ),
        builder: (sheetContext) {
          return StatefulBuilder(
            builder: (sheetContext, setSheetState) {
              var amount = int.tryParse(valueController.text.trim()) ?? 1;
              if (amount < 1) amount = 1;

              return Padding(
                padding: EdgeInsets.fromLTRB(
                  16.w,
                  12.h,
                  16.w,
                  20.h + MediaQuery.viewInsetsOf(sheetContext).bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bulk Stock Update',
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w800,
                        color: colors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      '${viewModel.selectedCount} selected items',
                      style: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w600,
                        color: colors.textSecondary,
                      ),
                    ),
                    SizedBox(height: 12.h),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () =>
                                setSheetState(() => increase = true),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: increase
                                  ? colors.success
                                  : colors.textSecondary,
                              side: BorderSide(
                                color: increase
                                    ? colors.success
                                    : colors.inputBorder,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10.r),
                              ),
                            ),
                            child: const Text('Increase'),
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () =>
                                setSheetState(() => increase = false),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: !increase
                                  ? colors.error
                                  : colors.textSecondary,
                              side: BorderSide(
                                color: !increase
                                    ? colors.error
                                    : colors.inputBorder,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10.r),
                              ),
                            ),
                            child: const Text('Decrease'),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 10.h),
                    Row(
                      children: [
                        IconButton(
                          onPressed: () {
                            if (amount <= 1) return;
                            amount -= 1;
                            valueController.text = '$amount';
                            setSheetState(() {});
                          },
                          icon: const Icon(Icons.remove_circle_outline_rounded),
                        ),
                        Expanded(
                          child: TextField(
                            controller: valueController,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            onChanged: (_) => setSheetState(() {}),
                            decoration: InputDecoration(
                              labelText: 'Units',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.r),
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            amount += 1;
                            valueController.text = '$amount';
                            setSheetState(() {});
                          },
                          icon: const Icon(Icons.add_circle_outline_rounded),
                        ),
                      ],
                    ),
                    SizedBox(height: 12.h),
                    SizedBox(
                      width: double.infinity,
                      child: AppButton(
                        buttonText: increase
                            ? 'Apply Increase'
                            : 'Apply Decrease',
                        onPressed: () {
                          final parsed = int.tryParse(
                            valueController.text.trim(),
                          );
                          if (parsed == null || parsed < 1) return;
                          viewModel.adjustSelectedItemsStockBy(
                            increase ? parsed : -parsed,
                          );
                          Navigator.pop(sheetContext);
                        },
                        backgroundColor: colors.vendorPrimaryBlue,
                        borderRadius: KBorderSize.borderRadius12,
                        textStyle: TextStyle(
                          color: Colors.white,
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      );
    } finally {
      valueController.dispose();
    }
  }

  Future<void> _openStockAdjust(
    BuildContext context,
    VendorCatalogItem item,
  ) async {
    final viewModel = context.read<CatalogViewModel>();
    final colors = context.appColors;
    final stockController = TextEditingController(text: item.stock.toString());

    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: colors.backgroundPrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(18.r)),
        ),
        builder: (sheetContext) {
          return StatefulBuilder(
            builder: (sheetContext, setSheetState) {
              int stock =
                  int.tryParse(stockController.text.trim()) ?? item.stock;
              return Padding(
                padding: EdgeInsets.fromLTRB(
                  16.w,
                  12.h,
                  16.w,
                  20.h + MediaQuery.viewInsetsOf(sheetContext).bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Adjust Stock',
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w800,
                        color: colors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      item.name,
                      style: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w700,
                        color: colors.textSecondary,
                      ),
                    ),
                    SizedBox(height: 12.h),
                    Row(
                      children: [
                        IconButton(
                          onPressed: () {
                            if (stock <= 0) return;
                            stock -= 1;
                            stockController.text = '$stock';
                            setSheetState(() {});
                          },
                          icon: const Icon(Icons.remove_circle_outline_rounded),
                        ),
                        Expanded(
                          child: TextField(
                            controller: stockController,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            onChanged: (_) => setSheetState(() {}),
                            decoration: InputDecoration(
                              labelText: 'Stock Quantity',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.r),
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            stock += 1;
                            stockController.text = '$stock';
                            setSheetState(() {});
                          },
                          icon: const Icon(Icons.add_circle_outline_rounded),
                        ),
                      ],
                    ),
                    SizedBox(height: 12.h),
                    SizedBox(
                      width: double.infinity,
                      child: AppButton(
                        buttonText: 'Update Stock',
                        onPressed: () {
                          final parsed = int.tryParse(
                            stockController.text.trim(),
                          );
                          if (parsed == null || parsed < 0) return;
                          viewModel.adjustItemStock(item.id, parsed);
                          Navigator.pop(sheetContext);
                        },
                        backgroundColor: colors.vendorPrimaryBlue,
                        borderRadius: KBorderSize.borderRadius12,
                        textStyle: TextStyle(
                          color: Colors.white,
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      );
    } finally {
      stockController.dispose();
    }
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999.r),
      child: Container(
        margin: EdgeInsets.only(right: 8.w),
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 7.h),
        decoration: BoxDecoration(
          color: selected ? color : color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999.r),
          border: Border.all(color: selected ? color : colors.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.sp,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : colors.textPrimary,
          ),
        ),
      ),
    );
  }
}

class _CatalogItemCard extends StatelessWidget {
  final VendorCatalogItem item;
  final String categoryName;
  final bool isSelected;
  final VoidCallback onSelect;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onStockAdjust;
  final ValueChanged<bool> onAvailabilityChanged;

  const _CatalogItemCard({
    required this.item,
    required this.categoryName,
    required this.isSelected,
    required this.onSelect,
    required this.onEdit,
    required this.onDelete,
    required this.onStockAdjust,
    required this.onAvailabilityChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final serviceColor = _serviceColor(colors, item.serviceType);
    final stockColor = item.stock == 0
        ? colors.error
        : item.stock < 5
        ? colors.warning
        : colors.success;

    return GestureDetector(
      onLongPress: onSelect,
      child: Container(
        margin: EdgeInsets.only(bottom: 12.h),
        padding: EdgeInsets.all(12.r),
        decoration: BoxDecoration(
          color: colors.backgroundPrimary,
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(
            color: isSelected ? colors.vendorPrimaryBlue : colors.border,
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Checkbox(
                  value: isSelected,
                  onChanged: (_) => onSelect(),
                  fillColor: WidgetStateProperty.resolveWith<Color?>((states) {
                    if (states.contains(WidgetState.selected)) {
                      return colors.vendorPrimaryBlue;
                    }
                    return null;
                  }),
                  side: BorderSide(color: colors.inputBorder),
                ),
                Container(
                  width: 42.w,
                  height: 42.w,
                  decoration: BoxDecoration(
                    color: serviceColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Icon(
                    item.serviceType.icon,
                    color: serviceColor,
                    size: 20.sp,
                  ),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w800,
                          color: colors.textPrimary,
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        categoryName,
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w500,
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch.adaptive(
                  value: item.isAvailable,
                  onChanged: onAvailabilityChanged,
                  activeTrackColor: colors.vendorPrimaryBlue,
                ),
              ],
            ),
            SizedBox(height: 8.h),
            Row(
              children: [
                _Tag(label: item.serviceType.label, color: serviceColor),
                SizedBox(width: 8.w),
                _Tag(
                  label: item.isAvailable ? 'Available' : 'Unavailable',
                  color: item.isAvailable ? colors.success : colors.error,
                ),
                if (item.requiresPrescription) ...[
                  SizedBox(width: 8.w),
                  _Tag(label: 'Rx Required', color: colors.servicePharmacy),
                ],
              ],
            ),
            SizedBox(height: 10.h),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'GHS ${item.price.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w800,
                      color: colors.textPrimary,
                    ),
                  ),
                ),
                Text(
                  item.stock == 0
                      ? 'Out of stock'
                      : item.stock < 5
                      ? 'Low stock: ${item.stock}'
                      : 'In stock: ${item.stock}',
                  style: TextStyle(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w700,
                    color: stockColor,
                  ),
                ),
              ],
            ),
            SizedBox(height: 10.h),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onStockAdjust,
                    icon: Icon(Icons.inventory_2_outlined, size: 16.sp),
                    label: Text(
                      'Stock',
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colors.textPrimary,
                      side: BorderSide(color: colors.inputBorder),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onEdit,
                    icon: Icon(Icons.edit_outlined, size: 16.sp),
                    label: Text(
                      'Edit',
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.vendorPrimaryBlue,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 8.w),
                SizedBox(
                  width: 44.w,
                  child: OutlinedButton(
                    onPressed: onDelete,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colors.error,
                      side: BorderSide(
                        color: colors.error.withValues(alpha: 0.4),
                      ),
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                    ),
                    child: Icon(Icons.delete_outline_rounded, size: 18.sp),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String label;
  final Color color;

  const _Tag({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999.r),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10.sp,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

Set<VendorServiceType> _visibleVendorServices(
  VendorStoreContextViewModel storeContext,
) {
  final scope = storeContext.serviceScope;
  if (scope != null) return {scope};
  return storeContext.availableServicesForSelectedBranch.toSet();
}

Color _serviceColor(AppColorsExtension colors, VendorServiceType serviceType) {
  return switch (serviceType) {
    VendorServiceType.food => colors.serviceFood,
    VendorServiceType.grocery => colors.serviceGrocery,
    VendorServiceType.pharmacy => colors.servicePharmacy,
    VendorServiceType.grabMart => colors.serviceGrabMart,
  };
}
