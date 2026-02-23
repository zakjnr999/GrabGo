import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:grab_go_vendor/features/auth/model/vendor_service_option.dart';
import 'package:grab_go_vendor/features/catalog/model/vendor_catalog_models.dart';
import 'package:grab_go_vendor/features/catalog/viewmodel/catalog_viewmodel.dart';
import 'package:provider/provider.dart';

class CategoryManagementPage extends StatefulWidget {
  final Set<VendorServiceType>? allowedServices;

  const CategoryManagementPage({super.key, this.allowedServices});

  @override
  State<CategoryManagementPage> createState() => _CategoryManagementPageState();
}

class _CategoryManagementPageState extends State<CategoryManagementPage> {
  late List<VendorServiceType> _serviceOptions;
  late TextEditingController _serviceController;
  VendorServiceType? _serviceFilter;

  @override
  void initState() {
    super.initState();
    _syncServiceOptions();
    _serviceController = TextEditingController(text: _serviceFilter?.label ?? '');
  }

  @override
  void didUpdateWidget(covariant CategoryManagementPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.allowedServices != widget.allowedServices) {
      _syncServiceOptions();
      _serviceController.text = _serviceFilter?.label ?? '';
    }
  }

  void _syncServiceOptions() {
    _serviceOptions = _scopedServices().toList()..sort((a, b) => a.index.compareTo(b.index));
    if (_serviceOptions.isEmpty) {
      _serviceFilter = null;
      return;
    }
    if (_serviceFilter == null || !_serviceOptions.contains(_serviceFilter)) {
      _serviceFilter = _serviceOptions.first;
    }
  }

  @override
  void dispose() {
    _serviceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final scopedServices = _scopedServices();
    final hasMultipleServices = _serviceOptions.length > 1;

    return Scaffold(
      backgroundColor: colors.backgroundPrimary,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: colors.vendorPrimaryBlue,
        foregroundColor: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(KBorderSize.border)),
        onPressed: () => _showRequestCategorySheet(context, allowedServices: scopedServices),
        label: Text(
          'Request Category',
          style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700, color: Colors.white),
        ),
        icon: SvgPicture.asset(
          Assets.icons.plus,
          package: 'grab_go_shared',
          width: 24.w,
          height: 24.w,
          colorFilter: ColorFilter.mode(Colors.white, BlendMode.srcIn),
        ),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(20.w, 6.h, 20.w, 8.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextButton.icon(
                    onPressed: () => Navigator.of(context).maybePop(),
                    style: TextButton.styleFrom(padding: EdgeInsets.zero, foregroundColor: colors.textSecondary),
                    icon: SvgPicture.asset(
                      Assets.icons.navArrowLeft,
                      package: 'grab_go_shared',
                      width: 18.w,
                      height: 18.w,
                      colorFilter: ColorFilter.mode(colors.textSecondary, BlendMode.srcIn),
                    ),
                    label: Text(
                      'Back',
                      style: TextStyle(color: colors.textSecondary, fontSize: 14.sp, fontWeight: FontWeight.w500),
                    ),
                  ),
                  SizedBox(height: 6.h),
                  Text(
                    'Category Management',
                    style: TextStyle(
                      fontSize: 24.sp,
                      fontWeight: FontWeight.w900,
                      color: colors.textPrimary,
                      height: 1.15,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    'Explore standard categories for each service.',
                    style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w500,
                      color: colors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                  if (hasMultipleServices) ...[
                    SizedBox(height: 12.h),
                    AppTextInput(
                      controller: _serviceController,
                      label: 'Service',
                      hintText: 'Select service',
                      readOnly: true,
                      onTap: () async {
                        final selected = await _showServicePickerSheet(
                          context,
                          _serviceOptions,
                          _serviceFilter ?? _serviceOptions.first,
                        );
                        if (selected == null) return;
                        setState(() {
                          _serviceFilter = selected;
                          _serviceController.text = selected.label;
                        });
                      },
                      fillColor: colors.backgroundSecondary,
                      borderColor: colors.inputBorder,
                      borderActiveColor: colors.vendorPrimaryBlue,
                      borderRadius: KBorderSize.border,
                      cursorColor: colors.vendorPrimaryBlue,
                      suffixIcon: Padding(
                        padding: EdgeInsets.all(10.r),
                        child: SvgPicture.asset(
                          Assets.icons.navArrowDown,
                          package: 'grab_go_shared',
                          width: 18.w,
                          height: 18.w,
                          colorFilter: ColorFilter.mode(colors.textSecondary, BlendMode.srcIn),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              child: Consumer<CatalogViewModel>(
                builder: (context, viewModel, _) {
                  final categories = viewModel.categories
                      .where(
                        (entry) =>
                            scopedServices.contains(entry.serviceType) &&
                            (_serviceFilter == null || entry.serviceType == _serviceFilter),
                      )
                      .toList();
                  if (categories.isEmpty) {
                    return Center(
                      child: Text(
                        'No categories yet',
                        style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600, color: colors.textSecondary),
                      ),
                    );
                  }
                  return ListView.builder(
                    padding: EdgeInsets.fromLTRB(20.w, 6.h, 20.w, 90.h),
                    itemCount: categories.length,
                    itemBuilder: (context, index) {
                      final category = categories[index];
                      final serviceColor = _serviceColor(colors, category.serviceType);
                      final itemCount = viewModel.itemCountForCategory(category.id);
                      final itemCountLabel = itemCount == 1 ? '1 item' : '$itemCount items';
                      return Container(
                        margin: EdgeInsets.only(bottom: 10.h),
                        padding: EdgeInsets.all(12.r),
                        decoration: BoxDecoration(
                          color: colors.backgroundPrimary,
                          borderRadius: BorderRadius.circular(14.r),
                          border: Border.all(color: colors.border),
                        ),
                        child: Row(
                          children: [
                            if (hasMultipleServices) ...[
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                                decoration: BoxDecoration(
                                  color: serviceColor.withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(999.r),
                                ),
                                child: Text(
                                  category.serviceType.label,
                                  style: TextStyle(fontSize: 10.sp, fontWeight: FontWeight.w700, color: serviceColor),
                                ),
                              ),
                              SizedBox(width: 8.w),
                            ],
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    category.name,
                                    style: TextStyle(
                                      fontSize: 13.sp,
                                      fontWeight: FontWeight.w800,
                                      color: colors.textPrimary,
                                    ),
                                  ),
                                  SizedBox(height: 2.h),
                                  Text(
                                    itemCountLabel,
                                    style: TextStyle(
                                      fontSize: 11.sp,
                                      fontWeight: FontWeight.w600,
                                      color: colors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () => _showCategoryInfoSheet(context, category),
                              icon: SvgPicture.asset(
                                Assets.icons.infoCircle,
                                package: 'grab_go_shared',
                                width: 18.w,
                                height: 18.w,
                                colorFilter: ColorFilter.mode(colors.textSecondary, BlendMode.srcIn),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showCategoryInfoSheet(BuildContext context, VendorCatalogCategory category) async {
    final colors = context.appColors;
    final serviceColor = _serviceColor(colors, category.serviceType);
    final hasMultipleServices = _scopedServices().length > 1;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.backgroundPrimary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18.r))),
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 20.h + MediaQuery.viewInsetsOf(sheetContext).bottom),
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
                      borderRadius: BorderRadius.circular(KBorderSize.border),
                    ),
                  ),
                ),
                Row(
                  children: [
                    if (hasMultipleServices) ...[
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                        decoration: BoxDecoration(
                          color: serviceColor.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(999.r),
                        ),
                        child: Text(
                          category.serviceType.label,
                          style: TextStyle(fontSize: 10.sp, fontWeight: FontWeight.w700, color: serviceColor),
                        ),
                      ),
                      SizedBox(width: 8.w),
                    ],
                    Expanded(
                      child: Text(
                        category.name,
                        style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w800, color: colors.textPrimary),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 10.h),
                Text(
                  'This category is managed by GrabGo to keep catalogs consistent. '
                  'If you need a new category, kindly submit a request.',
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w500,
                    color: colors.textSecondary,
                    height: 1.4,
                  ),
                ),
                SizedBox(height: 14.h),
                AppButton(
                  width: double.infinity,
                  buttonText: 'Request New Category',
                  onPressed: () {
                    Navigator.of(sheetContext).pop();
                    _showRequestCategorySheet(context, allowedServices: _scopedServices());
                  },
                  backgroundColor: colors.vendorPrimaryBlue,
                  borderRadius: KBorderSize.border,
                  textStyle: TextStyle(color: Colors.white, fontSize: 13.sp, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showRequestCategorySheet(
    BuildContext context, {
    required Set<VendorServiceType> allowedServices,
  }) async {
    final colors = context.appColors;
    final nameController = TextEditingController();
    final orderedServices = allowedServices.toList()..sort((a, b) => a.index.compareTo(b.index));
    if (orderedServices.isEmpty) return;
    var selectedService = orderedServices.first;
    final serviceController = TextEditingController(text: selectedService.label);
    final hasMultipleServices = orderedServices.length > 1;
    String? error;

    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: colors.backgroundPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18.r))),
        builder: (sheetContext) {
          return StatefulBuilder(
            builder: (context, setLocalState) {
              return Padding(
                padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 20.h + MediaQuery.viewInsetsOf(sheetContext).bottom),
                child: SingleChildScrollView(
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
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
                              borderRadius: BorderRadius.circular(KBorderSize.border),
                            ),
                          ),
                        ),
                        Text(
                          'Request Category',
                          style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w800, color: colors.textPrimary),
                        ),
                        SizedBox(height: 6.h),
                        Text(
                          'Suggest a new category for review.',
                          style: TextStyle(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w500,
                            color: colors.textSecondary,
                            height: 1.4,
                          ),
                        ),
                        SizedBox(height: 14.h),
                        AppTextInput(
                          controller: nameController,
                          label: 'Category Name',
                          hintText: 'Enter requested category',
                          errorText: error,
                          fillColor: colors.backgroundSecondary,
                          borderColor: colors.inputBorder,
                          borderActiveColor: colors.vendorPrimaryBlue,
                          borderRadius: KBorderSize.border,
                          cursorColor: colors.vendorPrimaryBlue,
                        ),
                        SizedBox(height: 12.h),
                        AppTextInput(
                          controller: serviceController,
                          label: 'Service',
                          hintText: hasMultipleServices ? 'Select service' : selectedService.label,
                          readOnly: true,
                          onTap: hasMultipleServices
                              ? () async {
                                  final result = await _showServicePickerSheet(
                                    context,
                                    orderedServices,
                                    selectedService,
                                  );
                                  if (result == null) return;
                                  setLocalState(() {
                                    selectedService = result;
                                    serviceController.text = result.label;
                                  });
                                }
                              : null,
                          fillColor: colors.backgroundSecondary,
                          borderColor: colors.inputBorder,
                          borderActiveColor: colors.vendorPrimaryBlue,
                          borderRadius: KBorderSize.border,
                          cursorColor: colors.vendorPrimaryBlue,
                          suffixIcon: hasMultipleServices
                              ? Padding(
                                  padding: EdgeInsets.all(10.r),
                                  child: SvgPicture.asset(
                                    Assets.icons.navArrowDown,
                                    package: 'grab_go_shared',
                                    width: 18.w,
                                    height: 18.w,
                                    colorFilter: ColorFilter.mode(colors.textSecondary, BlendMode.srcIn),
                                  ),
                                )
                              : null,
                        ),
                        SizedBox(height: 16.h),
                        AppButton(
                          width: double.infinity,
                          buttonText: 'Submit Request',
                          onPressed: () {
                            final name = nameController.text.trim();
                            if (name.isEmpty) {
                              setLocalState(() => error = 'Category name is required');
                              return;
                            }
                            Navigator.of(sheetContext).pop();
                            ScaffoldMessenger.of(
                              context,
                            ).showSnackBar(const SnackBar(content: Text('Category request submitted for review.')));
                          },
                          backgroundColor: colors.vendorPrimaryBlue,
                          borderRadius: KBorderSize.border,
                          textStyle: TextStyle(color: Colors.white, fontSize: 13.sp, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      );
    } finally {
      Future.delayed(const Duration(milliseconds: 250), () {
        nameController.dispose();
        serviceController.dispose();
      });
    }
  }

  Future<VendorServiceType?> _showServicePickerSheet(
    BuildContext context,
    List<VendorServiceType> services,
    VendorServiceType selected,
  ) async {
    final colors = context.appColors;
    final result = await showModalBottomSheet<VendorServiceType>(
      context: context,
      useRootNavigator: true,
      backgroundColor: colors.backgroundPrimary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(KBorderSize.borderRadius20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 16.h),
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
                  'Select Service',
                  style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w800, color: colors.textPrimary),
                ),
                SizedBox(height: 4.h),
                Text(
                  'Choose the service this category request applies to.',
                  style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w500, color: colors.textSecondary),
                ),
                SizedBox(height: 12.h),
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: 300.h),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: services.length,
                    separatorBuilder: (context, index) => SizedBox(height: 8.h),
                    itemBuilder: (context, index) {
                      final service = services[index];
                      final isSelected = service == selected;
                      return InkWell(
                        onTap: () => Navigator.pop(sheetContext, service),
                        borderRadius: BorderRadius.circular(12.r),
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12.r),
                            border: Border.all(color: isSelected ? colors.vendorPrimaryBlue : colors.border),
                            color: isSelected
                                ? colors.vendorPrimaryBlue.withValues(alpha: 0.08)
                                : colors.backgroundPrimary,
                          ),
                          child: Text(
                            service.label,
                            style: TextStyle(
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w700,
                              color: isSelected ? colors.vendorPrimaryBlue : colors.textPrimary,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    return result;
  }

  Set<VendorServiceType> _scopedServices() {
    final allowed = widget.allowedServices;
    if (allowed == null || allowed.isEmpty) {
      return VendorServiceType.values.toSet();
    }
    return allowed.toSet();
  }

  Color _serviceColor(AppColorsExtension colors, VendorServiceType serviceType) {
    return switch (serviceType) {
      VendorServiceType.food => colors.serviceFood,
      VendorServiceType.grocery => colors.serviceGrocery,
      VendorServiceType.pharmacy => colors.servicePharmacy,
      VendorServiceType.grabMart => colors.serviceGrabMart,
    };
  }
}
