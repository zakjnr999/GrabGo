import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:grab_go_vendor/features/auth/model/vendor_service_option.dart';
import 'package:grab_go_vendor/features/catalog/model/vendor_catalog_models.dart';

class CatalogItemFormPage extends StatefulWidget {
  final List<VendorCatalogCategory> categories;
  final VendorCatalogItem? initialItem;
  final String title;

  const CatalogItemFormPage({
    super.key,
    required this.categories,
    required this.title,
    this.initialItem,
  });

  @override
  State<CatalogItemFormPage> createState() => _CatalogItemFormPageState();
}

class _CatalogItemFormPageState extends State<CatalogItemFormPage> {
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _priceController;
  late final TextEditingController _stockController;

  String? _nameError;
  String? _priceError;
  String? _stockError;
  String? _categoryError;
  late final List<VendorServiceType> _availableServiceTypes;
  late VendorServiceType _serviceType;
  String? _categoryId;
  bool _isAvailable = true;
  bool _requiresPrescription = false;

  @override
  void initState() {
    super.initState();
    final item = widget.initialItem;
    _nameController = TextEditingController(text: item?.name ?? '');
    _descriptionController = TextEditingController(
      text: item?.description ?? '',
    );
    _priceController = TextEditingController(
      text: item == null ? '' : item.price.toStringAsFixed(2),
    );
    _stockController = TextEditingController(
      text: item == null ? '' : item.stock.toString(),
    );
    _availableServiceTypes =
        widget.categories.map((entry) => entry.serviceType).toSet().toList()
          ..sort((a, b) => a.index.compareTo(b.index));
    final fallbackService = _availableServiceTypes.isEmpty
        ? VendorServiceType.food
        : _availableServiceTypes.first;
    final initialService = item?.serviceType ?? fallbackService;
    _serviceType = _availableServiceTypes.contains(initialService)
        ? initialService
        : fallbackService;
    _categoryId = item?.categoryId;
    _isAvailable = item?.isAvailable ?? true;
    _requiresPrescription = item?.requiresPrescription ?? false;

    if (_categoryId == null) {
      final first = _filteredCategoriesFor(_serviceType).firstOrNull;
      _categoryId = first?.id;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
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
      appBar: AppBar(
        backgroundColor: colors.backgroundPrimary,
        elevation: 0,
        title: Text(
          widget.title,
          style: TextStyle(
            fontSize: 17.sp,
            fontWeight: FontWeight.w800,
            color: colors.textPrimary,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Service',
              style: TextStyle(
                fontSize: 13.sp,
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
              ),
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
                      if (_categoryId == null ||
                          filtered.every((entry) => entry.id != _categoryId)) {
                        _categoryId = filtered.firstOrNull?.id;
                      }
                    });
                  },
                  borderRadius: BorderRadius.circular(999.r),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 10.w,
                      vertical: 7.h,
                    ),
                    decoration: BoxDecoration(
                      color: selected
                          ? color.withValues(alpha: 0.16)
                          : colors.backgroundSecondary,
                      borderRadius: BorderRadius.circular(999.r),
                      border: Border.all(
                        color: selected ? color : colors.border,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          service.icon,
                          size: 14.sp,
                          color: selected ? color : colors.textSecondary,
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
            AppTextInput(
              controller: _nameController,
              label: 'Item Name',
              hintText: 'Enter item name',
              errorText: _nameError,
              fillColor: colors.backgroundPrimary,
              borderColor: colors.inputBorder,
              borderActiveColor: colors.vendorPrimaryBlue,
              borderRadius: KBorderSize.borderRadius12,
              cursorColor: colors.vendorPrimaryBlue,
            ),
            SizedBox(height: 12.h),
            AppTextInput(
              controller: _descriptionController,
              label: 'Description',
              hintText: 'Short item description',
              fillColor: colors.backgroundPrimary,
              borderColor: colors.inputBorder,
              borderActiveColor: colors.vendorPrimaryBlue,
              borderRadius: KBorderSize.borderRadius12,
              cursorColor: colors.vendorPrimaryBlue,
            ),
            SizedBox(height: 12.h),
            DropdownButtonFormField<String>(
              key: ValueKey<String?>(
                'category_${_serviceType.name}_${_categoryId ?? 'none'}',
              ),
              initialValue: _categoryId,
              decoration: InputDecoration(
                labelText: 'Category',
                errorText: _categoryError,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                  borderSide: BorderSide(color: colors.inputBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                  borderSide: BorderSide(color: colors.inputBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                  borderSide: BorderSide(color: colors.vendorPrimaryBlue),
                ),
              ),
              items: categories.map((category) {
                return DropdownMenuItem<String>(
                  value: category.id,
                  child: Text(category.name),
                );
              }).toList(),
              onChanged: (value) => setState(() => _categoryId = value),
            ),
            SizedBox(height: 12.h),
            Row(
              children: [
                Expanded(
                  child: AppTextInput(
                    controller: _priceController,
                    label: 'Price (GHS)',
                    hintText: '0.00',
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    errorText: _priceError,
                    fillColor: colors.backgroundPrimary,
                    borderColor: colors.inputBorder,
                    borderActiveColor: colors.vendorPrimaryBlue,
                    borderRadius: KBorderSize.borderRadius12,
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
                    fillColor: colors.backgroundPrimary,
                    borderColor: colors.inputBorder,
                    borderActiveColor: colors.vendorPrimaryBlue,
                    borderRadius: KBorderSize.borderRadius12,
                    cursorColor: colors.vendorPrimaryBlue,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12.h),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: _isAvailable,
              onChanged: (value) => setState(() => _isAvailable = value),
              title: Text(
                'Available',
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
              ),
              subtitle: Text(
                'Show item in customer catalog',
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w500,
                  color: colors.textSecondary,
                ),
              ),
              activeTrackColor: colors.vendorPrimaryBlue,
            ),
            if (_serviceType == VendorServiceType.pharmacy)
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: _requiresPrescription,
                onChanged: (value) =>
                    setState(() => _requiresPrescription = value),
                title: Text(
                  'Requires Prescription',
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                  ),
                ),
                subtitle: Text(
                  'Customer must upload prescription for this item',
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w500,
                    color: colors.textSecondary,
                  ),
                ),
                activeTrackColor: colors.servicePharmacy,
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
                  style: TextStyle(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w600,
                    color: colors.servicePharmacy,
                  ),
                ),
              ),
            SizedBox(height: 16.h),
            SizedBox(
              width: double.infinity,
              child: AppButton(
                buttonText: widget.initialItem == null
                    ? 'Add Item'
                    : 'Save Changes',
                onPressed: () => _submit(context),
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
      ),
    );
  }

  List<VendorCatalogCategory> _filteredCategoriesFor(
    VendorServiceType serviceType,
  ) {
    return widget.categories
        .where((category) => category.serviceType == serviceType)
        .toList();
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
        serviceType: _serviceType,
        categoryId: _categoryId!,
        price: price!,
        stock: stock!,
        isAvailable: _isAvailable,
        requiresPrescription: _serviceType == VendorServiceType.pharmacy
            ? _requiresPrescription
            : false,
      ),
    );
  }

  Color _serviceColor(
    AppColorsExtension colors,
    VendorServiceType serviceType,
  ) {
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
