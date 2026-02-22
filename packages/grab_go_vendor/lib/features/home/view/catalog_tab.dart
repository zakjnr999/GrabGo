import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_swipe_action_cell/core/cell.dart';
import 'package:flutter_svg/svg.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:grab_go_vendor/features/auth/model/vendor_service_option.dart';
import 'package:grab_go_vendor/features/catalog/model/vendor_catalog_models.dart';
import 'package:grab_go_vendor/features/catalog/view/catalog_item_form_page.dart';
import 'package:grab_go_vendor/features/catalog/view/category_management_page.dart';
import 'package:grab_go_vendor/features/catalog/viewmodel/catalog_viewmodel.dart';
import 'package:grab_go_vendor/features/store_context/viewmodel/store_context_viewmodel.dart';
import 'package:grab_go_vendor/shared/viewmodel/vendor_preview_session_viewmodel.dart';
import 'package:grab_go_vendor/shared/widgets/app_filter_chip.dart';
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
        final hasMultipleServices = orderedVisibleServices.length > 1;
        final canCreateCatalogEntries = visibleServices.isNotEmpty;
        final isSelectionMode = viewModel.selectedCount > 0;
        final allVisibleSelected =
            items.isNotEmpty &&
            items.every((item) => viewModel.selectedItemIds.contains(item.id));

        return SafeArea(
          child: Stack(
            children: [
              Positioned.fill(
                child: SingleChildScrollView(
                  child: AnimatedPadding(
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeOutCubic,
                    padding: EdgeInsets.fromLTRB(
                      0,
                      14.h,
                      0,
                      isSelectionMode ? 164.h : 110.h,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 20.w),
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 240),
                            switchInCurve: Curves.easeOutCubic,
                            switchOutCurve: Curves.easeInCubic,
                            transitionBuilder: (child, animation) {
                              return FadeTransition(
                                opacity: animation,
                                child: SizeTransition(
                                  sizeFactor: animation,
                                  axisAlignment: -1,
                                  child: child,
                                ),
                              );
                            },
                            child: isSelectionMode
                                ? Column(
                                    key: const ValueKey(
                                      'catalog_selection_header',
                                    ),
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: AnimatedSwitcher(
                                              duration: const Duration(
                                                milliseconds: 180,
                                              ),
                                              layoutBuilder:
                                                  (
                                                    currentChild,
                                                    previousChildren,
                                                  ) {
                                                    return Stack(
                                                      alignment:
                                                          Alignment.centerLeft,
                                                      children: [
                                                        ...previousChildren,
                                                        if (currentChild !=
                                                            null)
                                                          currentChild,
                                                      ],
                                                    );
                                                  },
                                              transitionBuilder:
                                                  (child, animation) {
                                                    return FadeTransition(
                                                      opacity: animation,
                                                      child: SlideTransition(
                                                        position: Tween<Offset>(
                                                          begin: const Offset(
                                                            0.04,
                                                            0,
                                                          ),
                                                          end: Offset.zero,
                                                        ).animate(animation),
                                                        child: child,
                                                      ),
                                                    );
                                                  },
                                              child: Text(
                                                '${viewModel.selectedCount} selected',
                                                key: ValueKey(
                                                  viewModel.selectedCount,
                                                ),
                                                style: TextStyle(
                                                  fontSize: 24.sp,
                                                  fontWeight: FontWeight.w900,
                                                  color: colors.textPrimary,
                                                ),
                                              ),
                                            ),
                                          ),
                                          TextButton(
                                            onPressed:
                                                items.isEmpty ||
                                                    allVisibleSelected
                                                ? null
                                                : () => viewModel.selectItems(
                                                    items
                                                        .map((item) => item.id)
                                                        .toSet(),
                                                  ),
                                            style: TextButton.styleFrom(
                                              padding: EdgeInsets.symmetric(
                                                horizontal: 8.w,
                                                vertical: 2.h,
                                              ),
                                              minimumSize: Size.zero,
                                              tapTargetSize:
                                                  MaterialTapTargetSize
                                                      .shrinkWrap,
                                            ),
                                            child: Text(
                                              'Select all',
                                              style: TextStyle(
                                                fontSize: 13.sp,
                                                fontWeight: FontWeight.w700,
                                                color: colors.textSecondary,
                                              ),
                                            ),
                                          ),
                                          TextButton(
                                            onPressed: viewModel.clearSelection,
                                            style: TextButton.styleFrom(
                                              padding: EdgeInsets.symmetric(
                                                horizontal: 8.w,
                                                vertical: 2.h,
                                              ),
                                              minimumSize: Size.zero,
                                              tapTargetSize:
                                                  MaterialTapTargetSize
                                                      .shrinkWrap,
                                            ),
                                            child: Text(
                                              'Clear',
                                              style: TextStyle(
                                                fontSize: 13.sp,
                                                fontWeight: FontWeight.w700,
                                                color: colors.textSecondary,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      Text(
                                        'Tap items to select or deselect.',
                                        style: TextStyle(
                                          fontSize: 12.sp,
                                          fontWeight: FontWeight.w500,
                                          color: colors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  )
                                : Column(
                                    key: const ValueKey(
                                      'catalog_default_header',
                                    ),
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Catalog',
                                        style: TextStyle(
                                          fontSize: 24.sp,
                                          fontWeight: FontWeight.w900,
                                          color: colors.textPrimary,
                                        ),
                                      ),
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
                                    ],
                                  ),
                          ),
                        ),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOutCubic,
                          height: isSelectionMode ? 10.h : 14.h,
                        ),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 240),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeInCubic,
                          transitionBuilder: (child, animation) {
                            return FadeTransition(
                              opacity: animation,
                              child: SizeTransition(
                                sizeFactor: animation,
                                axisAlignment: -1,
                                child: child,
                              ),
                            );
                          },
                          child: isSelectionMode
                              ? const SizedBox(
                                  key: ValueKey('catalog_filters_hidden'),
                                )
                              : Column(
                                  key: const ValueKey(
                                    'catalog_filters_visible',
                                  ),
                                  children: [
                                    Padding(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 20.w,
                                      ),
                                      child: AppTextInput(
                                        controller: viewModel.searchController,
                                        prefixIcon: Padding(
                                          padding: EdgeInsets.all(10.r),
                                          child: SvgPicture.asset(
                                            Assets.icons.search,
                                            package: 'grab_go_shared',
                                            width: 18.w,
                                            height: 18.w,
                                            colorFilter: ColorFilter.mode(
                                              colors.textSecondary,
                                              BlendMode.srcIn,
                                            ),
                                          ),
                                        ),
                                        hintText: 'Search by item or category',
                                        fillColor: colors.backgroundSecondary,
                                        borderActiveColor:
                                            colors.vendorPrimaryBlue,
                                        borderRadius: KBorderSize.border,
                                        cursorColor: colors.vendorPrimaryBlue,
                                      ),
                                    ),
                                    SizedBox(height: 14.h),
                                    if (hasMultipleServices) ...[
                                      SingleChildScrollView(
                                        scrollDirection: Axis.horizontal,
                                        child: Row(
                                          children: [
                                            SizedBox(width: 20.w),
                                            AppFilterChip(
                                              label: 'All Services',
                                              selected:
                                                  viewModel.serviceFilter ==
                                                  null,
                                              onTap: () => viewModel
                                                  .setServiceFilter(null),
                                            ),
                                            SizedBox(width: 8.w),
                                            ...orderedVisibleServices.map((
                                              service,
                                            ) {
                                              return Padding(
                                                padding: EdgeInsets.only(
                                                  right: 8.w,
                                                ),
                                                child: AppFilterChip(
                                                  label: service.label,
                                                  selected:
                                                      viewModel.serviceFilter ==
                                                      service,
                                                  onTap: () => viewModel
                                                      .setServiceFilter(
                                                        service,
                                                      ),
                                                ),
                                              );
                                            }),
                                            SizedBox(width: 20.w),
                                          ],
                                        ),
                                      ),
                                      SizedBox(height: 8.h),
                                    ],
                                    SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: Row(
                                        children: [
                                          SizedBox(width: 20.w),
                                          AppFilterChip(
                                            label: 'All Categories',
                                            selected:
                                                viewModel.categoryFilterId ==
                                                null,
                                            onTap: () => viewModel
                                                .setCategoryFilter(null),
                                          ),
                                          SizedBox(width: 8.w),
                                          ...visibleCategories.map((category) {
                                            return Padding(
                                              padding: EdgeInsets.only(
                                                right: 8.w,
                                              ),
                                              child: AppFilterChip(
                                                label: category.name,
                                                selected:
                                                    viewModel
                                                        .categoryFilterId ==
                                                    category.id,
                                                onTap: () =>
                                                    viewModel.setCategoryFilter(
                                                      category.id,
                                                    ),
                                              ),
                                            );
                                          }),
                                          SizedBox(width: 4.w),
                                          Container(
                                            width: 1.w,
                                            height: 20.h,
                                            color: colors.border,
                                          ),
                                          SizedBox(width: 12.w),
                                          AppFilterChip(
                                            label: 'All Status',
                                            selected:
                                                viewModel.availabilityFilter ==
                                                null,
                                            onTap: () => viewModel
                                                .setAvailabilityFilter(null),
                                          ),
                                          SizedBox(width: 8.w),
                                          AppFilterChip(
                                            label: 'Available',
                                            selected:
                                                viewModel.availabilityFilter ==
                                                true,
                                            onTap: () => viewModel
                                                .setAvailabilityFilter(true),
                                          ),
                                          SizedBox(width: 8.w),
                                          AppFilterChip(
                                            label: 'Unavailable',
                                            selected:
                                                viewModel.availabilityFilter ==
                                                false,
                                            onTap: () => viewModel
                                                .setAvailabilityFilter(false),
                                          ),
                                          SizedBox(width: 20.w),
                                        ],
                                      ),
                                    ),
                                    SizedBox(height: 12.h),
                                  ],
                                ),
                        ),
                        if (visibleServices.isEmpty)
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 20.w),
                            child: Container(
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
                            ),
                          )
                        else if (items.isEmpty)
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 20.w),
                            child: Container(
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
                            ),
                          )
                        else
                          ...items.map((item) {
                            final isSelected = viewModel.selectedItemIds
                                .contains(item.id);
                            return Padding(
                              padding: EdgeInsets.only(bottom: 12.h),
                              child: SwipeActionCell(
                                key: ValueKey(item.id),
                                backgroundColor: Colors.transparent,
                                isDraggable: !isSelectionMode,
                                trailingActions: [
                                  SwipeAction(
                                    color: Colors.transparent,
                                    widthSpace: 102.w,
                                    onTap: (handler) =>
                                        _confirmDeleteItem(context, item),
                                    content: Align(
                                      alignment: Alignment.centerRight,
                                      child: Container(
                                        width: 78.w,
                                        margin: EdgeInsets.only(right: 20.w),
                                        decoration: BoxDecoration(
                                          color: colors.error,
                                          borderRadius: BorderRadius.circular(
                                            12.r,
                                          ),
                                        ),
                                        child: Center(
                                          child: Text(
                                            'Delete',
                                            style: TextStyle(
                                              fontSize: 12.sp,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onLongPress: () =>
                                      viewModel.toggleItemSelection(item.id),
                                  onTap: isSelectionMode
                                      ? () => viewModel.toggleItemSelection(
                                          item.id,
                                        )
                                      : () => _showCatalogItemActionsSheet(
                                          context,
                                          item,
                                          visibleServices,
                                        ),
                                  child: _CatalogItemCard(
                                    item: item,
                                    categoryName: viewModel.categoryNameFor(
                                      item.categoryId,
                                    ),
                                    showServiceChip: hasMultipleServices,
                                    isSelectionMode: isSelectionMode,
                                    isSelected: isSelected,
                                  ),
                                ),
                              ),
                            );
                          }),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 20.w,
                right: 20.w,
                bottom: 14.h,
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    IgnorePointer(
                      ignoring: isSelectionMode,
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        opacity: isSelectionMode ? 0 : 1,
                        child: AnimatedSlide(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOutCubic,
                          offset: isSelectionMode
                              ? const Offset(0, 0.25)
                              : Offset.zero,
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: FloatingActionButton(
                              heroTag: 'catalogFab',
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  KBorderSize.border,
                                ),
                              ),
                              onPressed: () {
                                if (!canCreateCatalogEntries) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'No active service available for catalog actions.',
                                      ),
                                    ),
                                  );
                                  return;
                                }
                                _showCatalogActions(context, visibleServices);
                              },
                              backgroundColor: canCreateCatalogEntries
                                  ? colors.vendorPrimaryBlue
                                  : colors.inputBorder,
                              foregroundColor: Colors.white,
                              elevation: 2,
                              child: SvgPicture.asset(
                                Assets.icons.plus,
                                package: 'grab_go_shared',
                                width: 24.w,
                                height: 24.w,
                                colorFilter: ColorFilter.mode(
                                  Colors.white,
                                  BlendMode.srcIn,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    IgnorePointer(
                      ignoring: !isSelectionMode,
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 240),
                        curve: Curves.easeOutCubic,
                        opacity: isSelectionMode ? 1 : 0,
                        child: AnimatedSlide(
                          duration: const Duration(milliseconds: 240),
                          curve: Curves.easeOutCubic,
                          offset: isSelectionMode
                              ? Offset.zero
                              : const Offset(0, 0.2),
                          child: _SelectionActionBar(
                            key: const ValueKey('catalog_selection_action_bar'),
                            selectedCount: viewModel.selectedCount,
                            onMarkAvailable: () =>
                                viewModel.setSelectedItemsAvailability(true),
                            onMarkUnavailable: () =>
                                viewModel.setSelectedItemsAvailability(false),
                            onAdjustStock: () => _openBulkStockAdjust(context),
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
      },
    );
  }
}

Future<void> _showCatalogActions(
  BuildContext context,
  Set<VendorServiceType> visibleServices,
) async {
  final colors = context.appColors;
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: colors.backgroundPrimary,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18.r)),
    ),
    builder: (sheetContext) {
      return SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 18.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Align(
                alignment: Alignment.center,
                child: Container(
                  width: 40.w,
                  height: 4.h,
                  margin: EdgeInsets.only(bottom: 12.h),
                  decoration: BoxDecoration(
                    color: colors.border,
                    borderRadius: BorderRadius.circular(KBorderSize.border),
                  ),
                ),
              ),
              Text(
                'Catalog Actions',
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w800,
                  color: colors.textPrimary,
                ),
              ),
              SizedBox(height: 4.h),
              Text(
                'Choose what you want to create.',
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w500,
                  color: colors.textSecondary,
                ),
              ),
              SizedBox(height: 12.h),
              _CatalogQuickActionTile(
                title: 'Add Item',
                subtitle: 'Create a new product and assign a category.',
                icon: Assets.icons.cart,
                color: colors.vendorPrimaryBlue,
                onTap: () {
                  Navigator.pop(sheetContext);
                  _openAddItem(context, visibleServices);
                },
              ),
              SizedBox(height: 10.h),
              _CatalogQuickActionTile(
                title: 'Manage Categories',
                subtitle: 'Create, rename or organize service categories.',
                icon: Assets.icons.tag,
                color: colors.vendorPrimaryBlue,
                onTap: () {
                  Navigator.pop(sheetContext);
                  _openCategoryManager(context, visibleServices);
                },
              ),
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
    CupertinoPageRoute(
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
    CupertinoPageRoute(
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
    CupertinoPageRoute(
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
  final shouldDelete = await AppDialog.show(
    context: context,
    type: AppDialogType.error,
    title: 'Delete Item',
    message: 'Delete "${item.name}" from catalog?',
    primaryButtonColor: colors.error,
  );
  if (shouldDelete != true) return;
  viewModel.removeItem(item.id);
}

Future<void> _showCatalogItemActionsSheet(
  BuildContext context,
  VendorCatalogItem item,
  Set<VendorServiceType> visibleServices,
) async {
  final colors = context.appColors;
  final viewModel = context.read<CatalogViewModel>();
  var isAvailable = item.isAvailable;
  final categoryName = viewModel.categoryNameFor(item.categoryId);

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: colors.backgroundPrimary,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(KBorderSize.borderRadius20),
      ),
    ),
    builder: (sheetContext) {
      return StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          final currentItem = viewModel.itemById(item.id) ?? item;
          final stockColor = currentItem.stock == 0
              ? colors.error
              : currentItem.stock < 5
              ? colors.warning
              : colors.success;
          return SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                16.w,
                8.h,
                16.w,
                16.h + MediaQuery.viewInsetsOf(sheetContext).bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Align(
                    alignment: Alignment.center,
                    child: Container(
                      width: 40.w,
                      height: 4.h,
                      margin: EdgeInsets.only(bottom: 12.h),
                      decoration: BoxDecoration(
                        color: colors.border,
                        borderRadius: BorderRadius.circular(KBorderSize.border),
                      ),
                    ),
                  ),
                  Text(
                    currentItem.name,
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w800,
                      color: colors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    '$categoryName • ${currentItem.serviceType.label}',
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w500,
                      color: colors.textSecondary,
                    ),
                  ),
                  SizedBox(height: 14.h),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(
                      horizontal: 12.w,
                      vertical: 12.h,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(color: colors.border),
                      color: colors.backgroundPrimary,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Availability',
                            style: TextStyle(
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w700,
                              color: colors.textPrimary,
                            ),
                          ),
                        ),
                        CustomSwitch(
                          value: isAvailable,
                          onChanged: (value) {
                            setSheetState(() => isAvailable = value);
                            viewModel.toggleItemAvailability(item.id, value);
                          },
                          activeColor: colors.vendorPrimaryBlue,
                          inactiveColor: colors.inputBorder,
                          thumbColor: colors.backgroundPrimary,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 10.h),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(
                      horizontal: 12.w,
                      vertical: 10.h,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(color: colors.border),
                      color: colors.backgroundPrimary,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'GHS ${currentItem.price.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w800,
                              color: colors.textPrimary,
                            ),
                          ),
                        ),
                        Text(
                          currentItem.stock == 0
                              ? 'Out of stock'
                              : currentItem.stock < 5
                              ? 'Low stock: ${currentItem.stock}'
                              : 'In stock: ${currentItem.stock}',
                          style: TextStyle(
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w700,
                            color: stockColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 14.h),
                  SizedBox(
                    width: double.infinity,
                    child: AppButton(
                      buttonText: 'Adjust Stock',
                      onPressed: () async {
                        final actionItem = viewModel.itemById(item.id) ?? item;
                        Navigator.pop(sheetContext);
                        if (!context.mounted) return;
                        await _openStockAdjust(context, actionItem);
                      },
                      backgroundColor: colors.backgroundSecondary,
                      borderColor: colors.inputBorder,
                      borderRadius: KBorderSize.border,
                      textStyle: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  SizedBox(height: 8.h),
                  SizedBox(
                    width: double.infinity,
                    child: AppButton(
                      buttonText: 'Delete Item',
                      onPressed: () async {
                        final actionItem = viewModel.itemById(item.id) ?? item;
                        Navigator.pop(sheetContext);
                        if (!context.mounted) return;
                        await _confirmDeleteItem(context, actionItem);
                      },
                      backgroundColor: colors.error.withValues(alpha: 0.2),
                      borderRadius: KBorderSize.border,
                      textStyle: TextStyle(
                        color: colors.error,
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  SizedBox(height: 8.h),
                  SizedBox(
                    width: double.infinity,
                    child: AppButton(
                      buttonText: 'Edit Item',
                      onPressed: () async {
                        final actionItem = viewModel.itemById(item.id) ?? item;
                        Navigator.pop(sheetContext);
                        if (!context.mounted) return;
                        await _openEditItem(
                          context,
                          actionItem,
                          visibleServices,
                        );
                      },
                      backgroundColor: colors.vendorPrimaryBlue,
                      borderRadius: KBorderSize.border,
                      textStyle: TextStyle(
                        color: Colors.white,
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
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
                          onPressed: () => setSheetState(() => increase = true),
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
                        child: AppTextInput(
                          controller: valueController,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          onChanged: (_) => setSheetState(() {}),
                          hintText: 'Units',
                          fillColor: colors.backgroundSecondary,
                          borderColor: colors.inputBorder,
                          borderActiveColor: colors.vendorPrimaryBlue,
                          borderRadius: KBorderSize.border,
                          cursorColor: colors.vendorPrimaryBlue,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12.w,
                            vertical: 12.h,
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
    _disposeTextControllerSafely(valueController);
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
            int stock = int.tryParse(stockController.text.trim()) ?? item.stock;
            return Padding(
              padding: EdgeInsets.fromLTRB(
                16.w,
                12.h,
                16.w,
                20.h + MediaQuery.viewInsetsOf(sheetContext).bottom,
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Align(
                      alignment: Alignment.center,
                      child: Container(
                        width: 40.w,
                        height: 4.h,
                        margin: EdgeInsets.only(bottom: 12.h),
                        decoration: BoxDecoration(
                          color: colors.border,
                          borderRadius: BorderRadius.circular(
                            KBorderSize.border,
                          ),
                        ),
                      ),
                    ),
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
                          icon: Icon(Icons.remove, color: colors.textSecondary),
                        ),
                        Expanded(
                          child: AppTextInput(
                            controller: stockController,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            onChanged: (_) => setSheetState(() {}),
                            hintText: 'Stock quantity',
                            fillColor: colors.backgroundSecondary,
                            borderColor: colors.inputBorder,
                            borderActiveColor: colors.vendorPrimaryBlue,
                            borderRadius: KBorderSize.border,
                            cursorColor: colors.vendorPrimaryBlue,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12.w,
                              vertical: 12.h,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            stock += 1;
                            stockController.text = '$stock';
                            setSheetState(() {});
                          },
                          icon: Icon(
                            Icons.add,
                            color: colors.vendorPrimaryBlue,
                          ),
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
                        borderRadius: KBorderSize.border,
                        textStyle: TextStyle(
                          color: Colors.white,
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  } finally {
    _disposeTextControllerSafely(stockController);
  }
}

void _disposeTextControllerSafely(TextEditingController controller) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    controller.dispose();
  });
}

class _CatalogQuickActionTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final String icon;
  final Color color;
  final VoidCallback onTap;

  const _CatalogQuickActionTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12.r),
      child: Ink(
        width: double.infinity,
        padding: EdgeInsets.all(12.r),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: colors.border),
          color: colors.backgroundPrimary,
        ),
        child: Row(
          children: [
            Container(
              width: 38.w,
              height: 38.w,
              padding: EdgeInsets.all(10.r),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: SvgPicture.asset(
                icon,
                package: 'grab_go_shared',
                colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
                width: 20.w,
                height: 20.w,
              ),
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w800,
                      color: colors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w500,
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            SvgPicture.asset(
              Assets.icons.navArrowRight,
              package: 'grab_go_shared',
              colorFilter: ColorFilter.mode(
                colors.textSecondary,
                BlendMode.srcIn,
              ),
              width: 20.w,
              height: 20.w,
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectionActionBar extends StatelessWidget {
  final int selectedCount;
  final VoidCallback onMarkAvailable;
  final VoidCallback onMarkUnavailable;
  final VoidCallback onAdjustStock;

  const _SelectionActionBar({
    super.key,
    required this.selectedCount,
    required this.onMarkAvailable,
    required this.onMarkUnavailable,
    required this.onAdjustStock,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: colors.backgroundPrimary,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(10.w, 10.h, 10.w, 0),
            child: Text(
              'Bulk actions ($selectedCount)',
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.w700,
                color: colors.textSecondary,
              ),
            ),
          ),
          SizedBox(height: 8.h),
          SingleChildScrollView(
            padding: EdgeInsets.zero,
            scrollDirection: Axis.horizontal,
            child: Padding(
              padding: EdgeInsets.fromLTRB(10.w, 0, 10.w, 10.h),
              child: Row(
                children: [
                  AppFilterChip(
                    label: 'Mark Available',
                    selected: false,
                    onTap: onMarkAvailable,
                    unselectedColor: colors.backgroundSecondary,
                    unselectedTextColor: colors.textPrimary,
                  ),
                  SizedBox(width: 8.w),
                  AppFilterChip(
                    label: 'Mark Unavailable',
                    selected: false,
                    onTap: onMarkUnavailable,
                    unselectedColor: colors.backgroundSecondary,
                    unselectedTextColor: colors.textPrimary,
                  ),
                  SizedBox(width: 8.w),
                  AppFilterChip(
                    label: 'Adjust Stock',
                    selected: true,
                    onTap: onAdjustStock,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CatalogItemCard extends StatelessWidget {
  final VendorCatalogItem item;
  final String categoryName;
  final bool showServiceChip;
  final bool isSelectionMode;
  final bool isSelected;

  const _CatalogItemCard({
    required this.item,
    required this.categoryName,
    required this.showServiceChip,
    required this.isSelectionMode,
    required this.isSelected,
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

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      margin: EdgeInsets.symmetric(horizontal: 20.w),
      padding: EdgeInsets.all(12.r),
      decoration: BoxDecoration(
        color: isSelected
            ? colors.vendorPrimaryBlue.withValues(alpha: 0.08)
            : colors.backgroundPrimary,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(
          color: isSelected ? colors.vendorPrimaryBlue : colors.border,
          width: isSelected ? 1.3 : 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                padding: EdgeInsets.all(12.r),
                decoration: BoxDecoration(
                  color: colors.backgroundSecondary,
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: SvgPicture.asset(
                  item.serviceType.icon,
                  package: 'grab_go_shared',
                  colorFilter: ColorFilter.mode(
                    colors.textSecondary,
                    BlendMode.srcIn,
                  ),
                  width: 20.w,
                  height: 20.w,
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
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: ScaleTransition(scale: animation, child: child),
                  );
                },
                child: isSelectionMode
                    ? AnimatedContainer(
                        key: const ValueKey('catalog_selection_indicator'),
                        duration: const Duration(milliseconds: 160),
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected
                              ? colors.vendorPrimaryBlue
                              : colors.backgroundPrimary,
                          border: Border.all(
                            color: colors.vendorPrimaryBlue,
                            width: 1.4,
                          ),
                        ),
                        child: isSelected
                            ? SvgPicture.asset(
                                Assets.icons.check,
                                package: 'grab_go_shared',
                                colorFilter: ColorFilter.mode(
                                  Colors.white,
                                  BlendMode.srcIn,
                                ),
                                width: 12.w,
                                height: 12.w,
                              )
                            : null,
                      )
                    : SvgPicture.asset(
                        key: const ValueKey('catalog_item_open_indicator'),
                        Assets.icons.navArrowRight,
                        package: 'grab_go_shared',
                        colorFilter: ColorFilter.mode(
                          colors.textSecondary,
                          BlendMode.srcIn,
                        ),
                        width: 20.w,
                        height: 20.w,
                      ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Row(
            children: [
              if (showServiceChip) ...[
                AppFilterChip(
                  label: item.serviceType.label,
                  selected: true,
                  onTap: null,
                  selectedColor: serviceColor.withValues(alpha: 0.14),
                  selectedTextColor: serviceColor,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 8.w,
                    vertical: 4.h,
                  ),
                ),
                SizedBox(width: 8.w),
              ],
              AppFilterChip(
                label: item.isAvailable ? 'Available' : 'Unavailable',
                selected: true,
                onTap: null,
                selectedColor:
                    (item.isAvailable ? colors.success : colors.error)
                        .withValues(alpha: 0.14),
                selectedTextColor: item.isAvailable
                    ? colors.success
                    : colors.error,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 8.w,
                  vertical: 4.h,
                ),
              ),
              if (item.requiresPrescription) ...[
                SizedBox(width: 8.w),
                AppFilterChip(
                  label: 'Rx Required',
                  selected: true,
                  onTap: null,
                  selectedColor: colors.servicePharmacy.withValues(alpha: 0.14),
                  selectedTextColor: colors.servicePharmacy,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 8.w,
                    vertical: 4.h,
                  ),
                ),
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
        ],
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
