import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:grab_go_vendor/features/auth/model/vendor_service_option.dart';
import 'package:grab_go_vendor/features/catalog/model/vendor_catalog_models.dart';
import 'package:grab_go_vendor/features/catalog/viewmodel/catalog_viewmodel.dart';
import 'package:provider/provider.dart';

class CategoryManagementPage extends StatelessWidget {
  final Set<VendorServiceType>? allowedServices;

  const CategoryManagementPage({super.key, this.allowedServices});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final scopedServices = _scopedServices();

    return Scaffold(
      backgroundColor: colors.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: colors.backgroundPrimary,
        elevation: 0,
        title: Text(
          'Category Management',
          style: TextStyle(
            fontSize: 17.sp,
            fontWeight: FontWeight.w800,
            color: colors.textPrimary,
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: colors.vendorPrimaryBlue,
        foregroundColor: Colors.white,
        onPressed: () =>
            _showCategoryDialog(context, allowedServices: scopedServices),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Category'),
      ),
      body: Consumer<CatalogViewModel>(
        builder: (context, viewModel, _) {
          final categories = viewModel.categories
              .where((entry) => scopedServices.contains(entry.serviceType))
              .toList();
          if (categories.isEmpty) {
            return Center(
              child: Text(
                'No categories yet',
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                  color: colors.textSecondary,
                ),
              ),
            );
          }
          return ListView.builder(
            padding: EdgeInsets.fromLTRB(20.w, 14.h, 20.w, 90.h),
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final category = categories[index];
              final serviceColor = _serviceColor(colors, category.serviceType);
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
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 8.w,
                        vertical: 4.h,
                      ),
                      decoration: BoxDecoration(
                        color: serviceColor.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(999.r),
                      ),
                      child: Text(
                        category.serviceType.label,
                        style: TextStyle(
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w700,
                          color: serviceColor,
                        ),
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Text(
                        category.name,
                        style: TextStyle(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w800,
                          color: colors.textPrimary,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => _showCategoryDialog(
                        context,
                        category: category,
                        allowedServices: scopedServices,
                      ),
                      icon: Icon(
                        Icons.edit_outlined,
                        color: colors.textSecondary,
                      ),
                    ),
                    IconButton(
                      onPressed: () => _confirmDelete(context, category),
                      icon: Icon(
                        Icons.delete_outline_rounded,
                        color: colors.error,
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    VendorCatalogCategory category,
  ) async {
    final colors = context.appColors;
    final viewModel = context.read<CatalogViewModel>();
    final shouldDelete = await AppDialog.show(
      context: context,
      type: AppDialogType.error,
      title: 'Delete Category',
      message:
          'Delete "${category.name}"? Items in this category will be reassigned.',
      primaryButtonColor: colors.error,
    );
    if (shouldDelete != true) return;
    viewModel.removeCategory(category.id);
  }

  Future<void> _showCategoryDialog(
    BuildContext context, {
    VendorCatalogCategory? category,
    required Set<VendorServiceType> allowedServices,
  }) async {
    final colors = context.appColors;
    final viewModel = context.read<CatalogViewModel>();
    final nameController = TextEditingController(text: category?.name ?? '');
    final orderedServices = allowedServices.toList()
      ..sort((a, b) => a.index.compareTo(b.index));
    if (orderedServices.isEmpty) return;

    var selectedService = category?.serviceType ?? orderedServices.first;
    if (!orderedServices.contains(selectedService)) {
      selectedService = orderedServices.first;
    }
    String? error;

    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (context, setLocalState) {
              return Dialog(
                backgroundColor: Colors.transparent,
                insetPadding: EdgeInsets.symmetric(
                  horizontal: 20.w,
                  vertical: 24.h,
                ),
                child: Container(
                  padding: EdgeInsets.all(16.r),
                  decoration: BoxDecoration(
                    color: colors.backgroundPrimary,
                    borderRadius: BorderRadius.circular(20.r),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          category == null ? 'Add Category' : 'Edit Category',
                          style: TextStyle(
                            fontSize: 18.sp,
                            fontWeight: FontWeight.w800,
                            color: colors.textPrimary,
                          ),
                        ),
                        SizedBox(height: 12.h),
                        TextField(
                          controller: nameController,
                          decoration: InputDecoration(
                            labelText: 'Category Name',
                            errorText: error,
                          ),
                        ),
                        SizedBox(height: 12.h),
                        DropdownButtonFormField<VendorServiceType>(
                          key: ValueKey<VendorServiceType>(selectedService),
                          initialValue: selectedService,
                          decoration: const InputDecoration(
                            labelText: 'Service',
                          ),
                          disabledHint: Text(selectedService.label),
                          items: orderedServices.map((service) {
                            return DropdownMenuItem(
                              value: service,
                              child: Text(service.label),
                            );
                          }).toList(),
                          onChanged: category == null
                              ? (value) {
                                  if (value == null) return;
                                  setLocalState(() => selectedService = value);
                                }
                              : null,
                        ),
                        SizedBox(height: 16.h),
                        Row(
                          children: [
                            Expanded(
                              child: AppButton(
                                buttonText: 'Cancel',
                                onPressed: () => Navigator.pop(dialogContext),
                                backgroundColor: colors.backgroundSecondary,
                                borderRadius: KBorderSize.borderMedium,
                                textStyle: TextStyle(
                                  color: colors.textPrimary,
                                  fontSize: 13.sp,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            SizedBox(width: 10.w),
                            Expanded(
                              child: AppButton(
                                buttonText: category == null ? 'Add' : 'Save',
                                onPressed: () {
                                  final name = nameController.text.trim();
                                  if (name.isEmpty) {
                                    setLocalState(
                                      () => error = 'Enter category name',
                                    );
                                    return;
                                  }
                                  if (category == null) {
                                    viewModel.addCategory(
                                      name: name,
                                      serviceType: selectedService,
                                    );
                                  } else {
                                    viewModel.renameCategory(category.id, name);
                                  }
                                  Navigator.pop(dialogContext);
                                },
                                backgroundColor: colors.vendorPrimaryBlue,
                                borderRadius: KBorderSize.borderMedium,
                                textStyle: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13.sp,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
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
      nameController.dispose();
    }
  }

  Set<VendorServiceType> _scopedServices() {
    final allowed = allowedServices;
    if (allowed == null || allowed.isEmpty) {
      return VendorServiceType.values.toSet();
    }
    return allowed.toSet();
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
