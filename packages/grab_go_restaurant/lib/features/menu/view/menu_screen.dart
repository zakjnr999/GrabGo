// ignore_for_file: deprecated_member_use

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:grab_go_shared/shared/utils/app_colors_extension.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/image_upload.dart';
import '../../../shared/widgets/svg_icon.dart';
import '../../../shared/widgets/text_input.dart';
import 'package:grab_go_shared/shared/utils/colors.dart';
import 'package:grab_go_shared/shared/widgets/responsive.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/shared/widgets/animated_tab_bar.dart';

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  int selectedCategoryIndex = 0;

  final List<String> categories = ['All', 'Quick Bites', 'Protein', 'Main Meals', 'Breakfast', 'Drinks', 'Healthy'];

  final List<Map<String, dynamic>> menuItems = [
    {
      'id': '1',
      'name': 'Grilled Chicken',
      'category': 'Main Meals',
      'price': 'GHC 18.99',
      'description': 'Tender grilled chicken breast with herbs',
      'image': Assets.images.sampleOne.path,
      'isAvailable': true,
      'rating': 4.5,
    },
    {
      'id': '2',
      'name': 'Caesar Salad',
      'category': 'Healthy',
      'price': 'GHC 12.99',
      'description': 'Fresh romaine lettuce with caesar dressing',
      'image': Assets.images.sampleTwo.path,
      'isAvailable': true,
      'rating': 4.2,
    },
    {
      'id': '3',
      'name': 'Chocolate Cake',
      'category': 'Quick Bites',
      'price': 'GHC 8.99',
      'description': 'Rich chocolate cake with cream frosting',
      'image': Assets.images.sampleThree.path,
      'isAvailable': false,
      'rating': 4.8,
    },
    {
      'id': '4',
      'name': 'Fresh Juice',
      'category': 'Drinks',
      'price': 'GHC 6.99',
      'description': 'Freshly squeezed orange juice',
      'image': Assets.images.sampleFour.path,
      'isAvailable': true,
      'rating': 4.3,
    },
    {
      'id': '5',
      'name': 'Pancakes',
      'category': 'Breakfast',
      'price': 'GHC 15.99',
      'description': 'Fluffy pancakes with maple syrup',
      'image': Assets.images.sampleOne.path,
      'isAvailable': true,
      'rating': 4.7,
    },
    {
      'id': '6',
      'name': 'Gourmet Burger',
      'category': 'Main Meals',
      'price': 'GHC 14.99',
      'description': 'Juicy beef burger with premium toppings',
      'image': Assets.images.sampleThree.path,
      'isAvailable': true,
      'rating': 4.6,
    },
    {
      'id': '7',
      'name': 'Fresh Smoothie',
      'category': 'Drinks',
      'price': 'GHC 7.99',
      'description': 'Mixed berry smoothie with yogurt',
      'image': Assets.images.sampleFour.path,
      'isAvailable': true,
      'rating': 4.4,
    },
  ];

  // Add dish dialog controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  File? _selectedImage;
  Uint8List? _selectedImageBytes;
  String? _nameError;
  String? _priceError;
  String? _imageError;

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _clearErrors() {
    setState(() {
      _nameError = null;
      _priceError = null;
      _imageError = null;
    });
  }

  bool _validateDishForm() {
    _clearErrors();
    bool hasErrors = false;

    // Validate name
    if (_nameController.text.trim().isEmpty) {
      _nameError = 'Name is required';
      hasErrors = true;
    }

    // Validate price
    final priceText = _priceController.text.trim();
    if (priceText.isEmpty) {
      _priceError = 'Price is required';
      hasErrors = true;
    } else {
      final price = double.tryParse(priceText);
      if (price == null) {
        _priceError = 'Please enter a valid price';
        hasErrors = true;
      } else if (price <= 0) {
        _priceError = 'Price must be greater than 0';
        hasErrors = true;
      }
    }

    // Validate image
    if (_selectedImage == null && _selectedImageBytes == null) {
      _imageError = 'Dish image is required';
      hasErrors = true;
    }

    if (hasErrors) {
      setState(() {});
    }

    return !hasErrors;
  }

  void _addDish() {
    if (_validateDishForm()) {
      final newItem = {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'name': _nameController.text.trim(),
        'category': 'Main Meals',
        'price': 'GHC ${_priceController.text.trim()}',
        'description': _descriptionController.text.trim().isNotEmpty
            ? _descriptionController.text.trim()
            : 'No description provided',
        'image': Assets.images.sampleOne.path,
        'isAvailable': true,
        'rating': 0.0,
      };

      setState(() {
        menuItems.add(newItem);
      });

      // Clear form
      _nameController.clear();
      _priceController.clear();
      _descriptionController.clear();
      _selectedImage = null;
      _selectedImageBytes = null;
      _clearErrors();

      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Dish "${newItem['name']}" added successfully!'),
          backgroundColor: AppColors.accentOrange,
        ),
      );
    }
  }

  void _showAddDishDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _AddDishDialog(
        nameController: _nameController,
        priceController: _priceController,
        descriptionController: _descriptionController,
        selectedImage: _selectedImage,
        selectedImageBytes: _selectedImageBytes,
        nameError: _nameError,
        priceError: _priceError,
        imageError: _imageError,
        onImageSelected: (File? image) {
          setState(() {
            _selectedImage = image;
            if (image != null) {
              _imageError = null;
              // For web images, set dummy bytes
              if (image.path.startsWith('web_image_')) {
                _selectedImageBytes = Uint8List.fromList([1]);
              }
            }
          });
        },
        onAddDish: _addDish,
        onClearErrors: _clearErrors,
      ),
    );
  }

  void _showDeleteConfirmation(Map<String, dynamic> item) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isMobile = Responsive.isMobile(context);
    final colors = context.appColors;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.white,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: SvgIcon(svgImage: Assets.icons.binMinusIn, width: 20, height: 20, color: colors.error),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Delete Menu Item',
                style: GoogleFonts.lato(
                  fontSize: Responsive.getFontSize(context, isMobile ? 16 : 18),
                  fontWeight: FontWeight.bold,
                  color: colors.textPrimary,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to delete "${item['name']}"?',
              style: GoogleFonts.lato(
                fontSize: Responsive.getFontSize(context, isMobile ? 14 : 16),
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'This action cannot be undone.',
              style: GoogleFonts.lato(
                fontSize: Responsive.getFontSize(context, isMobile ? 12 : 14),
                color: colors.textPrimary,
              ),
            ),
          ],
        ),
        actions: [
          AppButton(
            buttonText: 'Cancel',
            onPressed: () => Navigator.pop(context),
            backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightSurface,
            textColor: isDark ? AppColors.white : AppColors.primary,
            borderRadius: 8,
            padding: EdgeInsets.symmetric(vertical: isMobile ? 12 : 14, horizontal: 20),
          ),
          AppButton(
            buttonText: 'Delete',
            onPressed: () {
              setState(() {
                menuItems.removeWhere((menuItem) => menuItem['id'] == item['id']);
              });
              Navigator.pop(context);

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Menu item "${item['name']}" deleted successfully'),
                  backgroundColor: colors.error,
                  action: SnackBarAction(
                    label: 'Undo',
                    textColor: AppColors.white,
                    onPressed: () {
                      setState(() {
                        menuItems.add(item);
                      });
                    },
                  ),
                ),
              );
            },
            backgroundColor: colors.error,
            textColor: AppColors.white,
            borderRadius: 8,
            padding: EdgeInsets.symmetric(vertical: isMobile ? 12 : 14, horizontal: 20),
          ),
        ],
      ),
    );
  }

  void _toggleItemAvailability(String itemId) {
    setState(() {
      final index = menuItems.indexWhere((item) => item['id'] == itemId);
      if (index != -1) {
        menuItems[index]['isAvailable'] = !menuItems[index]['isAvailable'];
      }
    });
  }

  List<Map<String, dynamic>> get filteredItems {
    if (selectedCategoryIndex == 0) {
      return menuItems;
    }
    return menuItems.where((item) => item['category'] == categories[selectedCategoryIndex]).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isMobile = Responsive.isMobile(context);
    final isTablet = Responsive.isTablet(context);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.secondaryBackground,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header
            Container(
              padding: EdgeInsets.fromLTRB(
                isMobile ? 16 : 24,
                isMobile ? 16 : 24,
                isMobile ? 16 : 24,
                isMobile ? 8 : 12,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Manage your restaurant\'s menu items',
                  style: GoogleFonts.lato(
                    fontSize: Responsive.getFontSize(context, isMobile ? 12 : 14),
                    color: isDark ? AppColors.grey : AppColors.grey,
                  ),
                ),
              ),
            ),

            // Content
            Padding(
              padding: EdgeInsets.all(isMobile ? 16 : 24),
              child: Column(
                children: [
                  // Add Item Button and Tab Bar Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Expanded(
                        child: AnimatedTabBar(
                          tabs: categories,
                          selectedIndex: selectedCategoryIndex,
                          onTabChanged: (index) {
                            setState(() {
                              selectedCategoryIndex = index;
                            });
                          },
                        ),
                      ),
                      SizedBox(width: isMobile ? 12 : 16),
                      AppButton(
                        buttonText: 'Add Item',
                        onPressed: () => _showAddDishDialog(),
                        borderRadius: 8,
                        padding: EdgeInsets.symmetric(vertical: isMobile ? 12 : 14, horizontal: isMobile ? 16 : 20),
                        icon: SvgIcon(
                          svgImage: Assets.icons.packageDelivered.path,
                          width: 20,
                          height: 20,
                          color: AppColors.white,
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: isMobile ? 24 : 32),

                  // Menu Items Grid
                  _buildMenuItemsGrid(isDark, isMobile, isTablet),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItemsGrid(bool isDark, bool isMobile, bool isTablet) {
    final filteredItems = this.filteredItems;

    if (filteredItems.isEmpty) {
      return _buildEmptyState(isDark, isMobile);
    }

    return GridView.builder(
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isMobile ? 1 : (isTablet ? 2 : 4),
        childAspectRatio: isMobile ? 1.3 : 0.85,
        crossAxisSpacing: isMobile ? 12 : 16,
        mainAxisSpacing: isMobile ? 12 : 16,
      ),
      itemCount: filteredItems.length,
      itemBuilder: (context, index) {
        final item = filteredItems[index];
        return _buildMenuItemCard(item, isDark, isMobile);
      },
    );
  }

  Widget _buildMenuItemCard(Map<String, dynamic> item, bool isDark, bool isMobile) {
    final colors = context.appColors;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withValues(alpha: 0.3) : Colors.grey.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image
          Expanded(
            flex: 3,
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                image: DecorationImage(image: AssetImage(item['image']), fit: BoxFit.cover),
              ),
              child: Stack(
                children: [
                  // Availability overlay
                  if (!item['isAvailable'])
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                      ),
                      child: Center(
                        child: Text(
                          'Unavailable',
                          style: GoogleFonts.lato(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ),
                    ),

                  // Rating badge
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star, color: Colors.amber, size: 12),
                          const SizedBox(width: 2),
                          Text(
                            item['rating'].toString(),
                            style: GoogleFonts.lato(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Content
          Expanded(
            flex: 2,
            child: Padding(
              padding: EdgeInsets.all(isMobile ? 12 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name
                  Text(
                    item['name'],
                    style: GoogleFonts.lato(
                      fontSize: isMobile ? 14 : 16,
                      fontWeight: FontWeight.bold,
                      color: colors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const SizedBox(height: 4),

                  // Description
                  Text(
                    item['description'],
                    style: GoogleFonts.lato(fontSize: isMobile ? 10 : 12, color: colors.textSecondary),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const Spacer(),

                  // Price and Actions
                  Row(
                    children: [
                      Text(
                        item['price'],
                        style: GoogleFonts.lato(
                          fontSize: isMobile ? 14 : 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.accentOrange,
                        ),
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          // Availability toggle
                          GestureDetector(
                            onTap: () => _toggleItemAvailability(item['id']),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: item['isAvailable']
                                    ? colors.error.withValues(alpha: 0.1)
                                    : colors.success.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: SvgIcon(
                                svgImage: item['isAvailable'] ? Assets.icons.eyeClosed : Assets.icons.eye,
                                width: 16,
                                height: 16,
                                color: item['isAvailable'] ? colors.error : colors.success,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          // Edit button
                          GestureDetector(
                            onTap: () {
                              // Edit functionality
                            },
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: AppColors.accentOrange.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: SvgIcon(
                                svgImage: Assets.icons.editPencil,
                                width: 16,
                                height: 16,
                                color: AppColors.accentOrange,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          // Delete button
                          GestureDetector(
                            onTap: () => _showDeleteConfirmation(item),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: colors.error.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: SvgIcon(
                                svgImage: Assets.icons.binMinusIn,
                                width: 16,
                                height: 16,
                                color: colors.error,
                              ),
                            ),
                          ),
                        ],
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
  }

  Widget _buildEmptyState(bool isDark, bool isMobile) {
    final colors = context.appColors;

    return Center(
      child: Container(
        padding: EdgeInsets.all(isMobile ? 24 : 32),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: isDark ? Colors.black.withValues(alpha: 0.3) : Colors.grey.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            SvgIcon(
              svgImage: Assets.icons.utensilsCrossed,
              width: isMobile ? 48 : 64,
              height: isMobile ? 48 : 64,
              color: colors.textSecondary,
            ),
            SizedBox(height: isMobile ? 16 : 20),
            Text(
              'No dishes found',
              style: GoogleFonts.lato(
                fontSize: isMobile ? 18 : 20,
                fontWeight: FontWeight.bold,
                color: colors.textPrimary,
              ),
            ),
            SizedBox(height: isMobile ? 8 : 12),
            Text(
              'Add your first dish to get started',
              style: GoogleFonts.lato(fontSize: isMobile ? 12 : 14, color: colors.textSecondary),
            ),
            SizedBox(height: isMobile ? 20 : 24),
            AppButton(
              buttonText: 'Add First Dish',
              onPressed: () => _showAddDishDialog(),
              borderRadius: 8,
              padding: EdgeInsets.symmetric(vertical: isMobile ? 12 : 14, horizontal: isMobile ? 20 : 24),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddDishDialog extends StatefulWidget {
  final TextEditingController nameController;
  final TextEditingController priceController;
  final TextEditingController descriptionController;
  final File? selectedImage;
  final Uint8List? selectedImageBytes;
  final String? nameError;
  final String? priceError;
  final String? imageError;
  final Function(File?) onImageSelected;
  final VoidCallback onAddDish;
  final VoidCallback onClearErrors;

  const _AddDishDialog({
    required this.nameController,
    required this.priceController,
    required this.descriptionController,
    required this.selectedImage,
    required this.selectedImageBytes,
    required this.nameError,
    required this.priceError,
    required this.imageError,
    required this.onImageSelected,
    required this.onAddDish,
    required this.onClearErrors,
  });

  @override
  State<_AddDishDialog> createState() => _AddDishDialogState();
}

class _AddDishDialogState extends State<_AddDishDialog> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isMobile = Responsive.isMobile(context);
    final colors = context.appColors;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.white,
      contentPadding: EdgeInsets.all(24),
      content: SizedBox(
        width: isMobile ? 320 : 400,
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Add New Dish',
                style: GoogleFonts.lato(
                  fontSize: Responsive.getFontSize(context, isMobile ? 18 : 20),
                  fontWeight: FontWeight.bold,
                  color: colors.textPrimary,
                ),
              ),
              Text(
                'Enter the dish details below to add it to your restaurant\'s menu.',
                style: GoogleFonts.lato(
                  fontSize: Responsive.getFontSize(context, isMobile ? 10 : 12),
                  color: AppColors.grey,
                ),
              ),
              SizedBox(height: isMobile ? 24 : 32),

              // Name field
              TextInput(
                controller: widget.nameController,
                label: 'Name *',
                hintText: 'e.g., Grilled Chicken',
                borderColor: colors.border.withValues(alpha: 1),
                fillColor: isDark ? AppColors.darkBackground : AppColors.white,
                borderRadius: 12,
                contentPadding: EdgeInsets.all(isMobile ? 12 : 16),
                keyboardType: TextInputType.text,
                errorText: widget.nameError,
                onChanged: (value) {
                  if (widget.nameError != null && value.trim().isNotEmpty) {
                    widget.onClearErrors();
                  }
                },
              ),
              SizedBox(height: isMobile ? 16 : 20),

              // Price field
              TextInput(
                controller: widget.priceController,
                label: 'Price *',
                hintText: 'e.g., 18.99',
                borderColor: colors.border.withValues(alpha: 1),
                fillColor: isDark ? AppColors.darkBackground : AppColors.white,
                borderRadius: 12,
                contentPadding: EdgeInsets.all(isMobile ? 12 : 16),
                keyboardType: TextInputType.number,
                errorText: widget.priceError,
                onChanged: (value) {
                  if (widget.priceError != null && value.trim().isNotEmpty) {
                    widget.onClearErrors();
                  }
                },
              ),
              SizedBox(height: isMobile ? 16 : 20),

              // Description field
              TextInput(
                controller: widget.descriptionController,
                label: 'Description',
                hintText: 'e.g., Tender grilled chicken breast with herbs',
                borderColor: colors.border.withValues(alpha: 1),
                fillColor: isDark ? AppColors.darkBackground : AppColors.white,
                borderRadius: 12,
                maxLines: 4,
                contentPadding: EdgeInsets.all(isMobile ? 12 : 16),
                keyboardType: TextInputType.text,
              ),
              SizedBox(height: isMobile ? 24 : 32),

              // Image upload
              ImageUploadWidget(
                label: "Dish Image *",
                hintText: "Upload an image of the dish",
                height: 180,
                initialImage: widget.selectedImage,
                onImageSelected: widget.onImageSelected,
                successMessage: "Image uploaded successfully",
              ),
              if (widget.imageError != null) ...[
                SizedBox(height: 4),
                Text(
                  widget.imageError!,
                  style: TextStyle(fontSize: 10, color: colors.error, fontWeight: FontWeight.w500),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        AppButton(
          buttonText: 'Cancel',
          onPressed: () => Navigator.pop(context),
          backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightSurface,
          textColor: isDark ? AppColors.white : AppColors.primary,
          borderRadius: 8,
          padding: EdgeInsets.symmetric(vertical: isMobile ? 16 : 18, horizontal: 25),
        ),
        AppButton(
          buttonText: "Add",
          onPressed: widget.onAddDish,
          borderRadius: 8,
          padding: EdgeInsets.symmetric(vertical: isMobile ? 16 : 18, horizontal: 25),
        ),
      ],
    );
  }
}
