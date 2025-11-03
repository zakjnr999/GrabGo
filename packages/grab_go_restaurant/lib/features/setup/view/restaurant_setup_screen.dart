import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:grab_go_restaurant/shared/app_colors_extension.dart';
import 'package:grab_go_restaurant/shared/app_colors.dart';
import 'package:grab_go_shared/shared/utils/constants.dart';
import 'package:grab_go_shared/shared/widgets/app_text_input_panels.dart';
import 'package:grab_go_shared/shared/widgets/responsive.dart';
import '../../../shared/widgets/image_upload.dart';
import '../../../shared/models/restaurant_setup.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/svg_icon.dart';
import '../../../shared/widgets/food_type_selection.dart';
import '../../../shared/widgets/payment_methods_selection.dart';
import '../../../shared/widgets/opening_hours_selection.dart';
import '../../../shared/widgets/hours_selection_dialog.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import '../../dashboard/view/restaurant_dashboard_comprehensive.dart';

class RestaurantSetupScreen extends StatefulWidget {
  const RestaurantSetupScreen({super.key});

  @override
  State<RestaurantSetupScreen> createState() => _RestaurantSetupScreenState();
}

class _RestaurantSetupScreenState extends State<RestaurantSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _pageController = PageController();
  int _currentPage = 0;
  final int _totalPages = 3;

  final _descriptionController = TextEditingController();
  final _latitudeController = TextEditingController();
  final _longitudeController = TextEditingController();
  final _deliveryTimeController = TextEditingController();
  final _deliveryFeeController = TextEditingController();
  final _minOrderController = TextEditingController();
  final _instagramController = TextEditingController();
  final _facebookController = TextEditingController();
  final _twitterController = TextEditingController();
  final _tiktokController = TextEditingController();
  final Map<String, String> _openingHours = {};
  final Map<String, bool> _closedDays = {};
  final List<String> _selectedPaymentMethods = [];
  final List<String> _availablePaymentMethods = [
    'Cash',
    'Credit Card',
    'Debit Card',
    'Mobile Payment',
    'Bank Transfer',
  ];

  String? _foodTypeError;
  String? _descriptionError;
  String? _deliveryTimeError;
  String? _deliveryFeeError;
  String? _minOrderError;
  String? _paymentMethodsError;
  String? _bannerOneError;
  String? _bannerTwoError;

  File? _selectedBannerImageOne;
  File? _selectedBannerImageTwo;

  final List<String> _selectedFoodTypes = [];
  final List<String> _foodTypes = ['Quick Bites', 'Protein', 'Main Meals', 'Breakfast', 'Drinks', 'Healthy'];

  final List<String> _days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

  @override
  void initState() {
    super.initState();
    _initializeOpeningHours();
  }

  void _initializeOpeningHours() {
    for (String day in _days) {
      _openingHours[day] = '09:00 - 22:00';
      _closedDays[day] = false;
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    _deliveryTimeController.dispose();
    _deliveryFeeController.dispose();
    _minOrderController.dispose();
    _instagramController.dispose();
    _facebookController.dispose();
    _twitterController.dispose();
    _tiktokController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = context.appColors;
    final isMobile = Responsive.isMobile(context);
    final isTablet = Responsive.isTablet(context);

    return _buildOptimizedScaffold(isDark, colors, isMobile, isTablet);
  }

  Widget _buildOptimizedScaffold(bool isDark, AppColorsExtension colors, bool isMobile, bool isTablet) {
    final isLastPage = _currentPage == _totalPages - 1;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.accentOrange.withValues(alpha: 0.05),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: isMobile ? double.infinity : (isTablet ? 600 : 500)),
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : AppColors.white,
                  borderRadius: BorderRadius.circular(KBorderSize.borderRadius15),
                  boxShadow: [
                    BoxShadow(
                      color: isDark
                          ? Colors.black.withValues(alpha: 0.3)
                          : AppColors.accentOrange.withValues(alpha: 0.1),
                      blurRadius: 15,
                      offset: const Offset(0, 6),
                    ),
                    BoxShadow(
                      color: isDark ? Colors.black.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.05),
                      blurRadius: 5,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                padding: EdgeInsets.all(isMobile ? 28 : 32),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(isDark, isMobile),
                      SizedBox(height: isMobile ? 28 : 36),

                      _buildProgressIndicator(isDark, isMobile),
                      SizedBox(height: isMobile ? 28 : 36),

                      SizedBox(
                        height: 400,
                        child: PageView(
                          controller: _pageController,
                          physics: const NeverScrollableScrollPhysics(),
                          onPageChanged: (index) {
                            setState(() {
                              _currentPage = index;
                            });
                          },
                          children: [
                            _OptimizedPage(child: _buildBasicInfoPage(colors, isMobile, isDark)),
                            _OptimizedPage(child: _buildBusinessDetailsPage(colors, isMobile, isDark)),
                            _OptimizedPage(child: _buildSocialMediaPage(colors, isMobile, isDark)),
                          ],
                        ),
                      ),

                      SizedBox(height: isMobile ? 28 : 36),

                      _buildNavigationButtons(isDark, isMobile, isLastPage),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark, bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: EdgeInsets.all(isMobile ? 12 : 16),
              decoration: BoxDecoration(
                color: AppColors.accentOrange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(KBorderSize.borderRadius12),
              ),
              child: SvgIcon(
                svgImage: Assets.icons.chefHat,
                width: isMobile ? 24 : 28,
                height: isMobile ? 24 : 28,
                color: AppColors.accentOrange,
              ),
            ),
            SizedBox(width: isMobile ? 12 : 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Restaurant Setup',
                    style: GoogleFonts.lato(
                      fontSize: Responsive.getFontSize(context, isMobile ? 18 : 22),
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppColors.white : AppColors.primary,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Complete your restaurant profile to start accepting orders',
                    style: GoogleFonts.lato(
                      fontSize: Responsive.getFontSize(context, isMobile ? 10 : 12),
                      color: AppColors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildProgressIndicator(bool isDark, bool isMobile) {
    final progressValue = (_currentPage + 1) / _totalPages;
    final progressPercentage = ((_currentPage + 1) / _totalPages * 100).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Step ${_currentPage + 1} of $_totalPages',
              style: GoogleFonts.lato(
                fontSize: Responsive.getFontSize(context, isMobile ? 12 : 14),
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.white : AppColors.primary,
              ),
            ),
            Text(
              '$progressPercentage% Complete',
              style: GoogleFonts.lato(
                fontSize: Responsive.getFontSize(context, isMobile ? 10 : 12),
                color: AppColors.grey,
              ),
            ),
          ],
        ),
        SizedBox(height: isMobile ? 8 : 12),
        LinearProgressIndicator(
          borderRadius: BorderRadius.circular(KBorderSize.borderRadius8),
          value: progressValue,
          backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightSurface,
          valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accentOrange),
          minHeight: 6,
        ),
      ],
    );
  }

  Widget _buildBasicInfoPage(AppColorsExtension colors, bool isMobile, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Basic Information',
          style: GoogleFonts.lato(
            fontSize: Responsive.getFontSize(context, isMobile ? 20 : 24),
            fontWeight: FontWeight.bold,
            color: colors.text,
          ),
        ),
        Text(
          'Tell us about your restaurant and what you serve',
          style: GoogleFonts.lato(fontSize: Responsive.getFontSize(context, isMobile ? 10 : 12), color: AppColors.grey),
        ),
        SizedBox(height: Responsive.getCardSpacing(context)),

        FoodTypeSelection(
          selectedFoodTypes: _selectedFoodTypes,
          foodTypes: _foodTypes,
          errorText: _foodTypeError,
          onFoodTypeToggled: (foodType) {
            if (_selectedFoodTypes.contains(foodType)) {
              _selectedFoodTypes.remove(foodType);
            } else {
              _selectedFoodTypes.add(foodType);
            }
            _foodTypeError = null;
            setState(() {});
          },
        ),
        SizedBox(height: isMobile ? 16 : 20),

        AppTextInputPanels(
          controller: _descriptionController,
          label: 'Restaurant Description *',
          hintText: 'Describe your restaurant, specialties, and what makes you unique',
          borderColor: colors.border.withValues(alpha: 1),
          fillColor: isDark ? AppColors.darkBackground : AppColors.secondaryBackground,
          borderRadius: KBorderSize.borderRadius12,
          contentPadding: EdgeInsets.all(isMobile ? 12 : 16),
          errorText: _descriptionError,
          maxLines: 4,
          prefixIcon: Padding(
            padding: EdgeInsets.all(isMobile ? 12 : 16),
            child: SvgIcon(svgImage: Assets.icons.infoCircle, width: 20, height: 20, color: colors.textSecondary),
          ),
        ),
        SizedBox(height: isMobile ? 16 : 20),

        Text(
          'Location (Optional)',
          style: GoogleFonts.lato(
            fontSize: Responsive.getFontSize(context, isMobile ? 14 : 16),
            fontWeight: FontWeight.w600,
            color: colors.text,
          ),
        ),
        Text(
          'You can set this later',
          style: GoogleFonts.lato(fontSize: Responsive.getFontSize(context, isMobile ? 10 : 12), color: AppColors.grey),
        ),
        SizedBox(height: isMobile ? 12 : 16),
        Row(
          children: [
            Expanded(
              child: AppTextInputPanels(
                controller: _latitudeController,
                label: 'Latitude',
                hintText: 'e.g., 40.7128',
                borderColor: colors.border.withValues(alpha: 1),
                fillColor: isDark ? AppColors.darkBackground : AppColors.secondaryBackground,
                borderRadius: KBorderSize.borderRadius15,
                contentPadding: EdgeInsets.all(isMobile ? 12 : 16),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                prefixIcon: Padding(
                  padding: EdgeInsets.all(isMobile ? 12 : 16),
                  child: SvgIcon(svgImage: Assets.icons.mapPin, width: 20, height: 20, color: colors.textSecondary),
                ),
              ),
            ),
            SizedBox(width: isMobile ? 12 : 16),
            Expanded(
              child: AppTextInputPanels(
                controller: _longitudeController,
                label: 'Longitude',
                hintText: 'e.g., -74.0060',
                borderColor: colors.border.withValues(alpha: 1),
                fillColor: isDark ? AppColors.darkBackground : AppColors.secondaryBackground,
                borderRadius: KBorderSize.borderRadius15,
                contentPadding: EdgeInsets.all(isMobile ? 12 : 16),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                prefixIcon: Padding(
                  padding: EdgeInsets.all(isMobile ? 12 : 16),
                  child: SvgIcon(svgImage: Assets.icons.mapPin, width: 20, height: 20, color: colors.textSecondary),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBusinessDetailsPage(AppColorsExtension colors, bool isMobile, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Business Details',
          style: GoogleFonts.lato(
            fontSize: Responsive.getFontSize(context, isMobile ? 20 : 24),
            fontWeight: FontWeight.bold,
            color: colors.text,
          ),
        ),
        Text(
          'Set up your delivery and business parameters',
          style: GoogleFonts.lato(fontSize: Responsive.getFontSize(context, isMobile ? 10 : 12), color: AppColors.grey),
        ),
        SizedBox(height: Responsive.getCardSpacing(context)),

        AppTextInputPanels(
          controller: _deliveryTimeController,
          label: 'Average Delivery Time Per KM(minutes) *',
          hintText: 'e.g., 30',
          borderColor: colors.border.withValues(alpha: 1),
          fillColor: isDark ? AppColors.darkBackground : AppColors.secondaryBackground,
          borderRadius: KBorderSize.borderRadius15,
          contentPadding: EdgeInsets.all(isMobile ? 12 : 16),
          keyboardType: TextInputType.number,
          errorText: _deliveryTimeError,
          prefixIcon: Padding(
            padding: EdgeInsets.all(isMobile ? 12 : 16),
            child: SvgIcon(svgImage: Assets.icons.alarm, width: 20, height: 20, color: colors.textSecondary),
          ),
        ),
        SizedBox(height: isMobile ? 16 : 20),

        AppTextInputPanels(
          controller: _deliveryFeeController,
          label: 'Delivery Fee Per KM *',
          hintText: 'e.g., 2.50',
          borderColor: colors.border.withValues(alpha: 1),
          fillColor: isDark ? AppColors.darkBackground : AppColors.secondaryBackground,
          borderRadius: KBorderSize.borderRadius15,
          contentPadding: EdgeInsets.all(isMobile ? 12 : 16),
          keyboardType: TextInputType.numberWithOptions(decimal: true),
          errorText: _deliveryFeeError,
          prefixIcon: Padding(
            padding: EdgeInsets.all(isMobile ? 12 : 16),
            child: SvgIcon(svgImage: Assets.icons.creditCard, width: 20, height: 20, color: colors.textSecondary),
          ),
        ),
        SizedBox(height: isMobile ? 16 : 20),

        AppTextInputPanels(
          controller: _minOrderController,
          label: 'Minimum Order Amount *',
          hintText: 'e.g., 15.00',
          borderColor: colors.border.withValues(alpha: 1),
          fillColor: isDark ? AppColors.darkBackground : AppColors.secondaryBackground,
          borderRadius: KBorderSize.borderRadius15,
          contentPadding: EdgeInsets.all(isMobile ? 12 : 16),
          keyboardType: TextInputType.numberWithOptions(decimal: true),
          errorText: _minOrderError,
          prefixIcon: Padding(
            padding: EdgeInsets.all(isMobile ? 12 : 16),
            child: SvgIcon(svgImage: Assets.icons.cart, width: 20, height: 20, color: colors.textSecondary),
          ),
        ),
        SizedBox(height: Responsive.getCardSpacing(context)),

        PaymentMethodsSelection(
          selectedPaymentMethods: _selectedPaymentMethods,
          availablePaymentMethods: _availablePaymentMethods,
          errorText: _paymentMethodsError,
          onPaymentMethodToggled: (method) {
            if (_selectedPaymentMethods.contains(method)) {
              _selectedPaymentMethods.remove(method);
            } else {
              _selectedPaymentMethods.add(method);
            }
            setState(() {});
          },
        ),
        SizedBox(height: isMobile ? 16 : 20),

        Text(
          'Banners (Optional)',
          style: GoogleFonts.lato(
            fontSize: Responsive.getFontSize(context, isMobile ? 14 : 16),
            fontWeight: FontWeight.w600,
            color: colors.text,
          ),
        ),

        SizedBox(height: isMobile ? 16 : 20),

        ImageUploadWidget(
          label: "First Banner Image",
          hintText: null,
          height: 120,
          initialImage: _selectedBannerImageOne,
          onImageSelected: (File? image) {
            setState(() {
              _selectedBannerImageOne = image;
              if (image != null) {
                _bannerOneError = null;
              }
            });
          },
          successMessage: "Banner Image uploaded successfully",
        ),
        if (_bannerOneError != null) ...[
          SizedBox(height: 4),
          Text(
            _bannerOneError!,
            style: TextStyle(fontSize: 10, color: colors.error, fontWeight: FontWeight.w500),
          ),
        ],
        SizedBox(height: isMobile ? 16 : 20),

        ImageUploadWidget(
          label: "Second Banner Image",
          hintText: null,
          height: 120,
          initialImage: _selectedBannerImageTwo,
          onImageSelected: (File? image) {
            setState(() {
              _selectedBannerImageTwo = image;
              if (image != null) {
                _bannerTwoError = null;
              }
            });
          },
          successMessage: "Banner Image uploaded successfully",
        ),
        if (_bannerTwoError != null) ...[
          SizedBox(height: 4),
          Text(
            _bannerTwoError!,
            style: TextStyle(fontSize: 10, color: colors.error, fontWeight: FontWeight.w500),
          ),
        ],
      ],
    );
  }

  Widget _buildSocialMediaPage(AppColorsExtension colors, bool isMobile, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Social Media & Hours',
          style: GoogleFonts.lato(
            fontSize: Responsive.getFontSize(context, isMobile ? 20 : 24),
            fontWeight: FontWeight.bold,
            color: colors.text,
          ),
        ),
        Text(
          'Connect your social media and set your operating hours',
          style: GoogleFonts.lato(fontSize: Responsive.getFontSize(context, isMobile ? 10 : 12), color: AppColors.grey),
        ),
        SizedBox(height: Responsive.getCardSpacing(context)),

        Text(
          'Social Media (Optional)',
          style: GoogleFonts.lato(
            fontSize: Responsive.getFontSize(context, isMobile ? 14 : 16),
            fontWeight: FontWeight.w600,
            color: colors.text,
          ),
        ),
        SizedBox(height: isMobile ? 12 : 16),

        AppTextInputPanels(
          controller: _instagramController,
          label: 'Instagram',
          hintText: '@instagramhandle',
          borderColor: colors.border,
          fillColor: isDark ? AppColors.darkBackground : AppColors.secondaryBackground,
          borderRadius: KBorderSize.borderRadius15,
          contentPadding: EdgeInsets.all(isMobile ? 12 : 16),
          prefixIcon: Padding(
            padding: EdgeInsets.all(isMobile ? 12 : 16),
            child: SvgIcon(svgImage: Assets.icons.instagram, width: 20, height: 20, color: colors.textSecondary),
          ),
        ),
        SizedBox(height: isMobile ? 16 : 20),

        AppTextInputPanels(
          controller: _facebookController,
          label: 'Facebook',
          hintText: '@facebookhandle',
          borderColor: colors.border,
          fillColor: isDark ? AppColors.darkBackground : AppColors.secondaryBackground,
          borderRadius: KBorderSize.borderRadius15,
          contentPadding: EdgeInsets.all(isMobile ? 12 : 16),
          prefixIcon: Padding(
            padding: EdgeInsets.all(isMobile ? 12 : 16),
            child: SvgIcon(svgImage: Assets.icons.facebookTag, width: 20, height: 20, color: colors.textSecondary),
          ),
        ),
        SizedBox(height: isMobile ? 16 : 20),

        AppTextInputPanels(
          controller: _twitterController,
          label: 'Twitter',
          hintText: '@twitterhandle',
          borderColor: colors.border,
          fillColor: isDark ? AppColors.darkBackground : AppColors.secondaryBackground,
          borderRadius: KBorderSize.borderRadius15,
          contentPadding: EdgeInsets.all(isMobile ? 12 : 16),
          prefixIcon: Padding(
            padding: EdgeInsets.all(isMobile ? 12 : 16),
            child: SvgIcon(svgImage: Assets.icons.x, width: 20, height: 20, color: colors.textSecondary),
          ),
        ),
        SizedBox(height: isMobile ? 16 : 20),

        AppTextInputPanels(
          controller: _tiktokController,
          label: 'TikTok ',
          hintText: '@tiktokhandle',
          borderColor: colors.border,
          fillColor: isDark ? AppColors.darkBackground : AppColors.secondaryBackground,
          borderRadius: KBorderSize.borderRadius15,
          contentPadding: EdgeInsets.all(isMobile ? 12 : 16),
          prefixIcon: Padding(
            padding: EdgeInsets.all(isMobile ? 12 : 16),
            child: SvgIcon(svgImage: Assets.icons.tiktok, width: 20, height: 20, color: colors.textSecondary),
          ),
        ),
        SizedBox(height: Responsive.getCardSpacing(context)),

        OpeningHoursSelection(
          openingHours: _openingHours,
          days: _days,
          onHoursSelected: _selectHours,
          onClosedToggled: _toggleClosedDay,
          closedDays: _closedDays,
        ),
      ],
    );
  }

  Widget _buildNavigationButtons(bool isDark, bool isMobile, bool isLastPage) {
    return Row(
      children: [
        if (_currentPage > 0) ...[
          Expanded(
            child: AppButton(
              buttonText: 'PREVIOUS',
              onPressed: () {
                _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
              },
              backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightSurface,
              textColor: isDark ? AppColors.white : AppColors.primary,
              borderRadius: KBorderSize.borderRadius15,
              padding: EdgeInsets.symmetric(vertical: isMobile ? 16 : 18),
            ),
          ),
          SizedBox(width: isMobile ? 12 : 16),
        ],
        Expanded(
          child: AppButton(
            buttonText: isLastPage ? 'COMPLETE SETUP' : 'NEXT',
            onPressed: isLastPage ? _completeSetup : _nextPage,
            borderRadius: KBorderSize.borderRadius15,
            padding: EdgeInsets.symmetric(vertical: isMobile ? 16 : 18),
          ),
        ),
      ],
    );
  }

  void _nextPage() {
    if (_validateCurrentPage()) {
      _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    }
  }

  bool _validateCurrentPage() {
    _foodTypeError = null;
    _descriptionError = null;
    _deliveryTimeError = null;
    _deliveryFeeError = null;
    _minOrderError = null;
    _paymentMethodsError = null;

    bool hasErrors = false;

    switch (_currentPage) {
      case 0:
        if (_selectedFoodTypes.isEmpty) {
          _foodTypeError = 'Please select at least one food type';
          hasErrors = true;
        }
        if (_descriptionController.text.isEmpty) {
          _descriptionError = 'Restaurant description is required';
          hasErrors = true;
        }
        break;
      case 1:
        if (_deliveryTimeController.text.isEmpty) {
          _deliveryTimeError = 'Delivery time is required';
          hasErrors = true;
        } else if (int.tryParse(_deliveryTimeController.text) == null) {
          _deliveryTimeError = 'Please enter a valid number';
          hasErrors = true;
        }

        if (_deliveryFeeController.text.isEmpty) {
          _deliveryFeeError = 'Delivery fee is required';
          hasErrors = true;
        } else if (double.tryParse(_deliveryFeeController.text) == null) {
          _deliveryFeeError = 'Please enter a valid amount';
          hasErrors = true;
        }

        if (_minOrderController.text.isEmpty) {
          _minOrderError = 'Minimum order amount is required';
          hasErrors = true;
        } else if (double.tryParse(_minOrderController.text) == null) {
          _minOrderError = 'Please enter a valid amount';
          hasErrors = true;
        }

        if (_selectedPaymentMethods.isEmpty) {
          _paymentMethodsError = 'Please select at least one payment method';
          hasErrors = true;
        }
        break;
      case 2:
        break;
    }

    if (hasErrors) {
      setState(() {});
    }

    return !hasErrors;
  }

  void _completeSetup() {
    if (!_validateCurrentPage()) return;

    final setup = RestaurantSetup(
      foodType: _selectedFoodTypes.join(', '),
      description: _descriptionController.text,
      latitude: _latitudeController.text.isNotEmpty ? double.tryParse(_latitudeController.text) : null,
      longitude: _longitudeController.text.isNotEmpty ? double.tryParse(_longitudeController.text) : null,
      averageDeliveryTime: int.tryParse(_deliveryTimeController.text),
      deliveryFee: double.tryParse(_deliveryFeeController.text),
      minOrder: double.tryParse(_minOrderController.text),
      openingHours: _openingHours,
      paymentMethods: _selectedPaymentMethods,
      socials: RestaurantSocials(
        instagram: _instagramController.text.isNotEmpty ? _instagramController.text : null,
        facebook: _facebookController.text.isNotEmpty ? _facebookController.text : null,
      ),
    );

    if (setup.isComplete) {}

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const RestaurantDashboardComprehensive()),
    );
  }

  void _selectHours(String day) {
    showDialog(
      context: context,
      builder: (context) => HoursSelectionDialog(
        day: day,
        currentHours: _openingHours[day] ?? '09:00 - 22:00',
        onHoursSelected: (hours) {
          setState(() {
            _openingHours[day] = hours;
          });
        },
      ),
    );
  }

  void _toggleClosedDay(String day, bool isClosed) {
    setState(() {
      _closedDays[day] = isClosed;
      if (isClosed) {
        _openingHours[day] = '';
      } else {
        _openingHours[day] = '09:00 - 22:00';
      }
    });
  }
}

class _OptimizedPage extends StatefulWidget {
  final Widget child;

  const _OptimizedPage({required this.child});

  @override
  State<_OptimizedPage> createState() => _OptimizedPageState();
}

class _OptimizedPageState extends State<_OptimizedPage> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return SingleChildScrollView(physics: const BouncingScrollPhysics(), child: widget.child);
  }
}
