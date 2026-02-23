import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:grab_go_vendor/features/auth/model/vendor_service_option.dart';
import 'package:grab_go_vendor/features/catalog/model/vendor_catalog_models.dart';

class CatalogItemFormPage extends StatefulWidget {
  final List<VendorCatalogCategory> categories;
  final VendorCatalogItem? initialItem;
  final String title;

  const CatalogItemFormPage({super.key, required this.categories, required this.title, this.initialItem});

  @override
  State<CatalogItemFormPage> createState() => _CatalogItemFormPageState();
}

class _CatalogItemFormPageState extends State<CatalogItemFormPage> {
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _ingredientsController;
  late final TextEditingController _categoryController;
  late final TextEditingController _priceController;
  late final TextEditingController _stockController;
  final ScrollController _contentScrollController = ScrollController();

  String? _nameError;
  String? _priceError;
  String? _stockError;
  String? _categoryError;
  late final List<VendorServiceType> _availableServiceTypes;
  late VendorServiceType _serviceType;
  String? _categoryId;
  String? _itemImagePath;
  bool _isAvailable = true;
  bool _requiresPrescription = false;
  bool _showTopDivider = false;

  bool get _showServiceSelector => _availableServiceTypes.length > 1;

  @override
  void initState() {
    super.initState();
    final item = widget.initialItem;
    _nameController = TextEditingController(text: item?.name ?? '');
    _descriptionController = TextEditingController(text: item?.description ?? '');
    _ingredientsController = TextEditingController(text: item?.ingredients ?? '');
    _categoryController = TextEditingController();
    _priceController = TextEditingController(text: item == null ? '' : item.price.toStringAsFixed(2));
    _stockController = TextEditingController(text: item == null ? '' : item.stock.toString());
    _availableServiceTypes = widget.categories.map((entry) => entry.serviceType).toSet().toList()
      ..sort((a, b) => a.index.compareTo(b.index));
    final fallbackService = _availableServiceTypes.isEmpty ? VendorServiceType.food : _availableServiceTypes.first;
    final initialService = item?.serviceType ?? fallbackService;
    _serviceType = _availableServiceTypes.contains(initialService) ? initialService : fallbackService;
    _categoryId = item?.categoryId;
    _isAvailable = item?.isAvailable ?? true;
    _requiresPrescription = item?.requiresPrescription ?? false;

    if (_categoryId == null) {
      final first = _filteredCategoriesFor(_serviceType).firstOrNull;
      _categoryId = first?.id;
    }
    _syncCategoryController();
    _contentScrollController.addListener(_handleScroll);
  }

  void _handleScroll() {
    if (!_contentScrollController.hasClients) return;
    final shouldShow = _contentScrollController.offset > 0.5;
    if (shouldShow == _showTopDivider) return;
    setState(() => _showTopDivider = shouldShow);
  }

  @override
  void dispose() {
    _contentScrollController
      ..removeListener(_handleScroll)
      ..dispose();
    _nameController.dispose();
    _descriptionController.dispose();
    _ingredientsController.dispose();
    _categoryController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final categories = _filteredCategoriesFor(_serviceType);

    return Scaffold(
      backgroundColor: colors.backgroundPrimary,
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
                    widget.title,
                    style: TextStyle(
                      fontSize: 24.sp,
                      fontWeight: FontWeight.w900,
                      color: colors.textPrimary,
                      height: 1.15,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    widget.initialItem == null
                        ? 'Add catalog details, pricing and stock availability.'
                        : 'Update catalog details, pricing and stock availability.',
                    style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w500,
                      color: colors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              height: _showTopDivider ? 1.h : 0,
              color: colors.backgroundSecondary,
            ),
            Expanded(
              child: SingleChildScrollView(
                controller: _contentScrollController,
                padding: EdgeInsets.fromLTRB(20.w, 10.h, 20.w, 6.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Item Image',
                      style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700, color: colors.textPrimary),
                    ),
                    SizedBox(height: 8.h),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _openItemImagePicker(context),
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: colors.backgroundSecondary,
                          borderRadius: BorderRadius.circular(12.r),
                          border: Border.all(color: colors.inputBorder),
                        ),
                        child: _itemImagePath == null
                            ? Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SvgPicture.asset(
                                    Assets.icons.mediaImagePlus,
                                    package: 'grab_go_shared',
                                    width: 24.w,
                                    height: 24.w,
                                    colorFilter: ColorFilter.mode(colors.textSecondary, BlendMode.srcIn),
                                  ),
                                ],
                              )
                            : Stack(
                                fit: StackFit.expand,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12.r),
                                    child: Image.file(File(_itemImagePath!), fit: BoxFit.cover),
                                  ),
                                  Positioned(
                                    top: 10.h,
                                    right: 10.w,
                                    child: GestureDetector(
                                      onTap: () => setState(() => _itemImagePath = null),
                                      child: Container(
                                        padding: EdgeInsets.all(6.r),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withValues(alpha: 0.55),
                                          shape: BoxShape.circle,
                                        ),
                                        child: SvgPicture.asset(
                                          Assets.icons.xmark,
                                          package: 'grab_go_shared',
                                          width: 14.w,
                                          height: 14.w,
                                          colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),

                    SizedBox(height: 10.h),
                    if (_showServiceSelector) ...[
                      Text(
                        'Service',
                        style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700, color: colors.textPrimary),
                      ),
                      SizedBox(height: 8.h),
                      Wrap(
                        spacing: 8.w,
                        runSpacing: 8.h,
                        children: _availableServiceTypes.map((service) {
                          final selected = _serviceType == service;
                          final color = _serviceColor(colors, service);
                          return InkWell(
                            onTap: () {
                              setState(() {
                                _serviceType = service;
                                final filtered = _filteredCategoriesFor(_serviceType);
                                if (_categoryId == null || filtered.every((entry) => entry.id != _categoryId)) {
                                  _categoryId = filtered.firstOrNull?.id;
                                }
                                _categoryError = null;
                                _syncCategoryController();
                              });
                            },
                            borderRadius: BorderRadius.circular(999.r),
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 7.h),
                              decoration: BoxDecoration(
                                color: selected ? color.withValues(alpha: 0.16) : colors.backgroundSecondary,
                                borderRadius: BorderRadius.circular(999.r),
                                border: Border.all(color: selected ? color : colors.border),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SvgPicture.asset(
                                    service.icon,
                                    width: 14.w,
                                    height: 14.w,
                                    colorFilter: selected
                                        ? ColorFilter.mode(color, BlendMode.srcIn)
                                        : ColorFilter.mode(colors.textSecondary, BlendMode.srcIn),
                                  ),
                                  SizedBox(width: 5.w),
                                  Text(
                                    service.label,
                                    style: TextStyle(
                                      fontSize: 11.sp,
                                      fontWeight: FontWeight.w700,
                                      color: selected ? color : colors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      SizedBox(height: 14.h),
                    ],
                    AppTextInput(
                      controller: _nameController,
                      label: 'Item Name',
                      hintText: 'Enter item name',
                      errorText: _nameError,
                      fillColor: colors.backgroundSecondary,
                      borderColor: colors.inputBorder,
                      borderActiveColor: colors.vendorPrimaryBlue,
                      borderRadius: KBorderSize.border,
                      cursorColor: colors.vendorPrimaryBlue,
                    ),
                    SizedBox(height: 12.h),
                    AppTextInput(
                      controller: _descriptionController,
                      label: 'Description',
                      hintText: 'Short item description',
                      fillColor: colors.backgroundSecondary,
                      borderColor: colors.inputBorder,
                      borderActiveColor: colors.vendorPrimaryBlue,
                      borderRadius: KBorderSize.border,
                      cursorColor: colors.vendorPrimaryBlue,
                    ),
                    if (_serviceType == VendorServiceType.food) ...[
                      SizedBox(height: 12.h),
                      AppTextInput(
                        controller: _ingredientsController,
                        label: 'Ingredients',
                        hintText: 'Rice, chicken, onion, pepper...',
                        fillColor: colors.backgroundSecondary,
                        borderColor: colors.inputBorder,
                        borderActiveColor: colors.vendorPrimaryBlue,
                        borderRadius: KBorderSize.border,
                        cursorColor: colors.vendorPrimaryBlue,
                      ),
                    ],
                    SizedBox(height: 12.h),
                    AppTextInput(
                      controller: _categoryController,
                      label: 'Category',
                      hintText: categories.isEmpty ? 'No categories available' : 'Select category',
                      readOnly: true,
                      onTap: categories.isEmpty ? null : () => _showCategoryPickerSheet(context, categories),
                      errorText: _categoryError,
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
                    SizedBox(height: 12.h),
                    Row(
                      children: [
                        Expanded(
                          child: AppTextInput(
                            controller: _priceController,
                            label: 'Price (GHS)',
                            hintText: '0.00',
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            errorText: _priceError,
                            fillColor: colors.backgroundSecondary,
                            borderColor: colors.inputBorder,
                            borderActiveColor: colors.vendorPrimaryBlue,
                            borderRadius: KBorderSize.border,
                            cursorColor: colors.vendorPrimaryBlue,
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: AppTextInput(
                            controller: _stockController,
                            label: 'Stock',
                            hintText: '0',
                            keyboardType: TextInputType.number,
                            errorText: _stockError,
                            fillColor: colors.backgroundSecondary,
                            borderColor: colors.inputBorder,
                            borderActiveColor: colors.vendorPrimaryBlue,
                            borderRadius: KBorderSize.border,
                            cursorColor: colors.vendorPrimaryBlue,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16.h),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Available',
                                style: TextStyle(
                                  fontSize: 13.sp,
                                  fontWeight: FontWeight.w700,
                                  color: colors.textPrimary,
                                ),
                              ),
                              SizedBox(height: 2.h),
                              Text(
                                'Show item in customer catalog',
                                style: TextStyle(
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w500,
                                  color: colors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: 8.w),
                        CustomSwitch(
                          value: _isAvailable,
                          onChanged: (value) => setState(() => _isAvailable = value),
                          activeColor: colors.vendorPrimaryBlue,
                          inactiveColor: colors.inputBorder,
                          thumbColor: colors.backgroundPrimary,
                        ),
                      ],
                    ),
                    if (_serviceType == VendorServiceType.pharmacy)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Requires Prescription',
                                  style: TextStyle(
                                    fontSize: 13.sp,
                                    fontWeight: FontWeight.w700,
                                    color: colors.textPrimary,
                                  ),
                                ),
                                SizedBox(height: 2.h),
                                Text(
                                  'Customer must upload prescription for this item',
                                  style: TextStyle(
                                    fontSize: 12.sp,
                                    fontWeight: FontWeight.w500,
                                    color: colors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: 8.w),
                          CustomSwitch(
                            value: _requiresPrescription,
                            onChanged: (value) => setState(() => _requiresPrescription = value),
                            activeColor: colors.vendorPrimaryBlue,
                            inactiveColor: colors.inputBorder,
                            thumbColor: colors.backgroundPrimary,
                          ),
                        ],
                      ),
                    if (_serviceType == VendorServiceType.pharmacy)
                      Container(
                        width: double.infinity,
                        margin: EdgeInsets.only(top: 4.h),
                        padding: EdgeInsets.all(10.r),
                        decoration: BoxDecoration(
                          color: colors.servicePharmacy.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10.r),
                        ),
                        child: Text(
                          'Compliance note: enable prescription only for products that legally require one.',
                          style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w600, color: colors.servicePharmacy),
                        ),
                      ),
                    SizedBox(height: 12.h),
                  ],
                ),
              ),
            ),
            AnimatedPadding(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              padding: EdgeInsets.fromLTRB(20.w, 10.h, 20.w, 12.h + MediaQuery.viewInsetsOf(context).bottom),
              child: SizedBox(
                width: double.infinity,
                child: AppButton(
                  buttonText: widget.initialItem == null ? 'Add Item' : 'Save Changes',
                  onPressed: () => _submit(context),
                  backgroundColor: colors.vendorPrimaryBlue,
                  borderRadius: KBorderSize.border,
                  textStyle: TextStyle(color: Colors.white, fontSize: 14.sp, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<VendorCatalogCategory> _filteredCategoriesFor(VendorServiceType serviceType) {
    return widget.categories.where((category) => category.serviceType == serviceType).toList();
  }

  Future<void> _openItemImagePicker(BuildContext context) async {
    await ImagePickerSheet.show(
      context,
      maxImages: 1,
      onImagesSelected: (paths) {
        if (!mounted || paths.isEmpty) return;
        setState(() => _itemImagePath = paths.first);
      },
    );
  }

  void _syncCategoryController() {
    final categories = _filteredCategoriesFor(_serviceType);
    final category = categories.cast<VendorCatalogCategory?>().firstWhere(
      (entry) => entry?.id == _categoryId,
      orElse: () => null,
    );
    _categoryController.text = category?.name ?? '';
  }

  Future<void> _showCategoryPickerSheet(BuildContext context, List<VendorCatalogCategory> categories) async {
    final colors = context.appColors;
    final selected = await showModalBottomSheet<String>(
      context: context,
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
                  'Select Category',
                  style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w800, color: colors.textPrimary),
                ),
                SizedBox(height: 4.h),
                Text(
                  'Choose where this item should appear in your catalog.',
                  style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w500, color: colors.textSecondary),
                ),
                SizedBox(height: 12.h),
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: 300.h),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: categories.length,
                    separatorBuilder: (_, index) => SizedBox(height: 8.h),
                    itemBuilder: (context, index) {
                      final category = categories[index];
                      final isSelected = _categoryId == category.id;
                      return InkWell(
                        onTap: () => Navigator.pop(sheetContext, category.id),
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
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  category.name,
                                  style: TextStyle(
                                    fontSize: 13.sp,
                                    fontWeight: FontWeight.w700,
                                    color: isSelected ? colors.vendorPrimaryBlue : colors.textPrimary,
                                  ),
                                ),
                              ),
                              if (isSelected) Icon(Icons.check_rounded, size: 18.sp, color: colors.vendorPrimaryBlue),
                            ],
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

    if (selected == null || !mounted) return;
    setState(() {
      _categoryId = selected;
      _categoryError = null;
      _syncCategoryController();
    });
  }

  void _submit(BuildContext context) {
    setState(() {
      _nameError = null;
      _priceError = null;
      _stockError = null;
      _categoryError = null;
    });

    final name = _nameController.text.trim();
    final price = double.tryParse(_priceController.text.trim());
    final stock = int.tryParse(_stockController.text.trim());

    var hasError = false;
    if (name.isEmpty) {
      _nameError = 'Enter an item name';
      hasError = true;
    }
    if (price == null || price < 0) {
      _priceError = 'Enter a valid price';
      hasError = true;
    }
    if (stock == null || stock < 0) {
      _stockError = 'Enter valid stock';
      hasError = true;
    }
    if (_categoryId == null) {
      _categoryError = 'Select a category';
      hasError = true;
    }

    if (hasError) {
      setState(() {});
      return;
    }

    Navigator.pop(
      context,
      VendorCatalogItemDraft(
        name: name,
        description: _descriptionController.text.trim(),
        ingredients: _serviceType == VendorServiceType.food ? _ingredientsController.text.trim() : '',
        serviceType: _serviceType,
        categoryId: _categoryId!,
        price: price!,
        stock: stock!,
        isAvailable: _isAvailable,
        requiresPrescription: _serviceType == VendorServiceType.pharmacy ? _requiresPrescription : false,
      ),
    );
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

extension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
