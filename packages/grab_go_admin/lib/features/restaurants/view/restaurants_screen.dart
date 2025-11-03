import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:grab_go_shared/shared/widgets/app_dialog_panels.dart';
import '../../../shared/app_colors.dart';
import '../../../shared/utils/responsive.dart';
import '../../../shared/widgets/text_input.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/svg_icon.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import '../viewmodel/restaurant_provider.dart';
import '../model/restaurant_response.dart';
import 'package:intl/intl.dart';
import '../../../shared/providers/theme_provider.dart';

class RestaurantsScreen extends StatefulWidget {
  const RestaurantsScreen({super.key});

  @override
  State<RestaurantsScreen> createState() => _RestaurantsScreenState();
}

class _RestaurantsScreenState extends State<RestaurantsScreen> {
  String searchQuery = '';
  String selectedStatus = 'All';
  String selectedSortBy = 'Name';
  final TextEditingController _searchController = TextEditingController();
  final List<String> statusOptions = ['All', 'Active', 'Pending', 'Suspended'];
  final List<String> sortOptions = ['Name', 'Registration Date', 'Total Sales', 'Rating'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RestaurantProvider>().fetchRestaurants();
    });
  }

  List<Map<String, dynamic>> _convertRestaurantsToMaps(List<RestaurantData> restaurants) {
    return restaurants.map((restaurant) {
      final dateFormat = DateFormat('yyyy-MM-dd');
      final registrationDate = dateFormat.format(restaurant.createdAt);

      final deliveryFee = restaurant.deliveryFee != null ? 'GHC ${restaurant.deliveryFee!.toStringAsFixed(2)}' : 'N/A';
      final minOrder = restaurant.minOrder != null ? 'GHC ${restaurant.minOrder!.toStringAsFixed(2)}' : 'N/A';

      final totalSales = 'N/A';

      return {
        'id': restaurant.id,
        'name': restaurant.restaurantName,
        'owner': restaurant.ownerFullName,
        'ownerContact': restaurant.ownerContactNumber,
        'email': restaurant.email,
        'phone': restaurant.phone,
        'address': restaurant.address,
        'city': restaurant.city,
        'businessIdNumber': restaurant.businessIdNumber,
        'status': restaurant.status,
        'registrationDate': registrationDate,
        'totalSales': totalSales,
        'rating': restaurant.rating,
        'deliveryFee': deliveryFee,
        'minOrder': minOrder,
        'orders': restaurant.totalReviews,
        'foodType': restaurant.foodType,
        'description': restaurant.description,
        'openingHours': restaurant.openingHours,
        'averageDeliveryTime': restaurant.averageDeliveryTime,
        'paymentMethods': restaurant.paymentMethods,
        'bannerImages': restaurant.bannerImages,
        'logo': restaurant.logo,
        'isOpen': restaurant.isOpen,
        'latitude': restaurant.latitude,
        'longitude': restaurant.longitude,
        'socials': restaurant.socials,
      };
    }).toList();
  }

  List<Map<String, dynamic>> _getFilteredRestaurants(List<RestaurantData> restaurantDataList) {
    final restaurants = _convertRestaurantsToMaps(restaurantDataList);

    var filtered = restaurants.where((restaurant) {
      final matchesSearch =
          restaurant['name'].toLowerCase().contains(searchQuery.toLowerCase()) ||
          restaurant['owner'].toLowerCase().contains(searchQuery.toLowerCase()) ||
          restaurant['email'].toLowerCase().contains(searchQuery.toLowerCase());

      final matchesStatus = selectedStatus == 'All' || restaurant['status'] == selectedStatus;

      return matchesSearch && matchesStatus;
    }).toList();

    filtered.sort((a, b) {
      switch (selectedSortBy) {
        case 'Name':
          return a['name'].compareTo(b['name']);
        case 'Registration Date':
          return b['registrationDate'].compareTo(a['registrationDate']);
        case 'Total Sales':
          final aSales = double.parse(a['totalSales'].replaceAll('GHC ', '').replaceAll(',', ''));
          final bSales = double.parse(b['totalSales'].replaceAll('GHC ', '').replaceAll(',', ''));
          return bSales.compareTo(aSales);
        case 'Rating':
          return b['rating'].compareTo(a['rating']);
        default:
          return 0;
      }
    });

    return filtered;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isMobile = Responsive.isMobile(context);
    final isTablet = Responsive.isTablet(context);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: Responsive.getScreenPadding(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Manage all registered restaurants and their details',
                      style: GoogleFonts.lato(
                        fontSize: Responsive.getFontSize(context, isMobile ? 12 : 14),
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.white : AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
              if (!isMobile)
                Consumer<RestaurantProvider>(
                  builder: (context, provider, child) {
                    return AppButton(
                      buttonText: 'Refresh',
                      onPressed: provider.isLoading
                          ? () {}
                          : () {
                              provider.refreshRestaurants();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Refreshing restaurants...'),
                                  backgroundColor: AppColors.successGreen,
                                ),
                              );
                            },
                      borderRadius: 4,
                      backgroundColor: AppColors.accentOrange,
                      textColor: AppColors.white,
                      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      icon: provider.isLoading
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.white),
                            )
                          : SvgIcon(svgImage: Assets.icons.refresh, width: 18, height: 18, color: AppColors.white),
                    );
                  },
                ),
            ],
          ),
          SizedBox(height: isMobile ? 20 : 24),

          _buildSearchAndFilters(isDark, isMobile, isTablet),
          SizedBox(height: isMobile ? 16 : 20),

          _buildRestaurantsList(isDark, isMobile, isTablet),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilters(bool isDark, bool isMobile, bool isTablet) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          TextInput(
            controller: _searchController,
            label: 'Search Restaurants',
            hintText: 'Search by name, owner, or email...',
            onChanged: (value) {
              setState(() {
                searchQuery = value;
              });
            },
            prefixIcon: Padding(
              padding: EdgeInsets.all(isMobile ? 10 : 12),
              child: SvgIcon(
                svgImage: Assets.icons.search,
                width: Responsive.getIconSize(context),
                height: Responsive.getIconSize(context),
                color: AppColors.grey,
              ),
            ),
          ),
          SizedBox(height: isMobile ? 16 : 20),

          if (isMobile)
            Column(
              children: [
                _buildFilterDropdown(
                  'Status',
                  selectedStatus,
                  statusOptions,
                  (value) {
                    setState(() {
                      selectedStatus = value!;
                    });
                  },
                  isDark,
                  isMobile,
                ),
                SizedBox(height: 12),
                _buildFilterDropdown(
                  'Sort By',
                  selectedSortBy,
                  sortOptions,
                  (value) {
                    setState(() {
                      selectedSortBy = value!;
                    });
                  },
                  isDark,
                  isMobile,
                ),
              ],
            )
          else
            Row(
              children: [
                Expanded(
                  child: _buildFilterDropdown(
                    'Status',
                    selectedStatus,
                    statusOptions,
                    (value) {
                      setState(() {
                        selectedStatus = value!;
                      });
                    },
                    isDark,
                    isMobile,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: _buildFilterDropdown(
                    'Sort By',
                    selectedSortBy,
                    sortOptions,
                    (value) {
                      setState(() {
                        selectedSortBy = value!;
                      });
                    },
                    isDark,
                    isMobile,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildFilterDropdown(
    String label,
    String value,
    List<String> options,
    ValueChanged<String?> onChanged,
    bool isDark,
    bool isMobile,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.lato(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isDark ? AppColors.white : AppColors.primary,
          ),
        ),
        SizedBox(height: 8),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : AppColors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightSurface, width: 0.5),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              dropdownColor: isDark ? AppColors.darkSurface : AppColors.white,
              style: GoogleFonts.lato(fontSize: 14, color: isDark ? AppColors.white : AppColors.primary),
              items: options.map((String option) {
                return DropdownMenuItem<String>(value: option, child: Text(option));
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRestaurantsList(bool isDark, bool isMobile, bool isTablet) {
    return Consumer<RestaurantProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading && provider.restaurants.isEmpty) {
          return Container(
            width: double.infinity,
            padding: EdgeInsets.all(isMobile ? 40 : 60),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : AppColors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: AppColors.accentOrange),
                  SizedBox(height: 16),
                  Text('Loading restaurants...', style: GoogleFonts.lato(fontSize: 14, color: AppColors.grey)),
                ],
              ),
            ),
          );
        }

        if (provider.error != null && provider.restaurants.isEmpty) {
          return Container(
            width: double.infinity,
            padding: EdgeInsets.all(isMobile ? 40 : 60),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : AppColors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SvgIcon(svgImage: Assets.icons.warningCircle, width: 48, height: 48, color: AppColors.errorRed),
                SizedBox(height: 16),
                Text(
                  'Error loading restaurants',
                  style: GoogleFonts.lato(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.white : AppColors.primary,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  provider.error!,
                  style: GoogleFonts.lato(fontSize: 14, color: AppColors.grey),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 16),
                AppButton(
                  buttonText: 'Retry',
                  onPressed: () => provider.fetchRestaurants(),
                  backgroundColor: AppColors.accentOrange,
                  textColor: AppColors.white,
                ),
              ],
            ),
          );
        }

        final restaurants = _getFilteredRestaurants(provider.restaurants);

        if (restaurants.isEmpty) {
          return Container(
            width: double.infinity,
            padding: EdgeInsets.all(isMobile ? 40 : 60),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : AppColors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                SvgIcon(svgImage: Assets.icons.search, width: 48, height: 48, color: AppColors.grey),
                SizedBox(height: 16),
                Text(
                  'No restaurants found',
                  style: GoogleFonts.lato(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.white : AppColors.primary,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Try adjusting your search or filter criteria',
                  style: GoogleFonts.lato(fontSize: 14, color: AppColors.grey),
                ),
              ],
            ),
          );
        }

        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : AppColors.white,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              if (!isMobile)
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkBackground : AppColors.secondaryBackground,
                    borderRadius: BorderRadius.only(topLeft: Radius.circular(8), topRight: Radius.circular(8)),
                  ),
                  child: Row(
                    children: [
                      Expanded(flex: 2, child: _buildTableHeader('Restaurant', isDark)),
                      Expanded(flex: 2, child: _buildTableHeader('Owner', isDark)),
                      Expanded(flex: 1, child: _buildTableHeader('Status', isDark)),
                      Expanded(flex: 1, child: _buildTableHeader('Sales', isDark)),
                      Expanded(flex: 1, child: _buildTableHeader('Rating', isDark)),
                      Expanded(flex: 1, child: _buildTableHeader('Actions', isDark)),
                    ],
                  ),
                ),
              ...restaurants.asMap().entries.map((entry) {
                final index = entry.key;
                final restaurant = entry.value;
                return _buildRestaurantRow(restaurant, isDark, isMobile, isTablet, index == restaurants.length - 1);
              }),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTableHeader(String text, bool isDark) {
    return Text(
      text,
      style: GoogleFonts.lato(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: isDark ? AppColors.white : AppColors.primary,
      ),
    );
  }

  Widget _buildRestaurantRow(Map<String, dynamic> restaurant, bool isDark, bool isMobile, bool isTablet, bool isLast) {
    if (isMobile) {
      return Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isDark ? AppColors.white.withValues(alpha: 0.1) : AppColors.lightSurface,
              width: isLast ? 0 : 1,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        restaurant['name'],
                        style: GoogleFonts.lato(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.white : AppColors.primary,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(restaurant['owner'], style: GoogleFonts.lato(fontSize: 14, color: AppColors.grey)),
                    ],
                  ),
                ),
                _buildStatusChip(restaurant['status']),
              ],
            ),
            SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildInfoItem('Sales', restaurant['totalSales'], isDark)),
                Expanded(
                  child: _buildInfoItem(
                    'Rating',
                    restaurant['rating'] == 0.0 ? 'N/A' : '${restaurant['rating']}',
                    isDark,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            if (restaurant['status'] == 'pending')
              Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: AppButton(
                          buttonText: 'Approve',
                          onPressed: () => _approveRestaurant(restaurant),
                          backgroundColor: AppColors.successGreen,
                          textColor: AppColors.white,
                        ),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: AppButton(
                          buttonText: 'Suspend',
                          onPressed: () => _suspendRestaurant(restaurant),
                          backgroundColor: AppColors.errorRed,
                          textColor: AppColors.white,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  AppButton(
                    buttonText: 'View Details',
                    onPressed: () => _viewRestaurantDetails(restaurant),
                    backgroundColor: Colors.transparent,
                    textColor: AppColors.accentOrange,
                    borderColor: AppColors.accentOrange,
                  ),
                ],
              )
            else
              Row(
                children: [
                  Expanded(
                    child: AppButton(
                      buttonText: 'View Details',
                      onPressed: () => _viewRestaurantDetails(restaurant),
                      backgroundColor: Colors.transparent,
                      textColor: AppColors.accentOrange,
                      borderColor: AppColors.accentOrange,
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: AppButton(
                      buttonText: _getActionText(restaurant['status']),
                      onPressed: () => _handleRestaurantAction(restaurant),
                      backgroundColor: _getActionColor(restaurant['status']),
                      textColor: AppColors.white,
                    ),
                  ),
                ],
              ),
          ],
        ),
      );
    } else {
      return Container(
        padding: EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isDark ? AppColors.white.withValues(alpha: 0.1) : AppColors.lightSurface,
              width: isLast ? 0 : 1,
            ),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    restaurant['name'],
                    style: GoogleFonts.lato(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.white : AppColors.primary,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    restaurant['address'],
                    style: GoogleFonts.lato(fontSize: 12, color: AppColors.grey),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    restaurant['owner'],
                    style: GoogleFonts.lato(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: isDark ? AppColors.white : AppColors.primary,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    restaurant['email'],
                    style: GoogleFonts.lato(fontSize: 12, color: AppColors.grey),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Expanded(flex: 1, child: _buildStatusChip(restaurant['status'])),
            Expanded(
              flex: 1,
              child: Text(
                restaurant['totalSales'],
                style: GoogleFonts.lato(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isDark ? AppColors.white : AppColors.primary,
                ),
              ),
            ),
            Expanded(
              flex: 1,
              child: Text(
                restaurant['rating'] == 0.0 ? 'N/A' : '${restaurant['rating']}',
                style: GoogleFonts.lato(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isDark ? AppColors.white : AppColors.primary,
                ),
              ),
            ),
            Expanded(
              flex: 1,
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => _viewRestaurantDetails(restaurant),
                    icon: SvgIcon(svgImage: Assets.icons.eye, width: 18, height: 18, color: AppColors.accentOrange),
                  ),
                  if (restaurant['status'] == 'pending') ...[
                    IconButton(
                      onPressed: () => _approveRestaurant(restaurant),
                      icon: SvgIcon(svgImage: Assets.icons.check, width: 18, height: 18, color: AppColors.successGreen),
                    ),
                    IconButton(
                      onPressed: () => _suspendRestaurant(restaurant),
                      icon: SvgIcon(svgImage: Assets.icons.ban, width: 18, height: 18, color: AppColors.errorRed),
                    ),
                  ] else
                    IconButton(
                      onPressed: () => _handleRestaurantAction(restaurant),
                      icon: _getActionIcon(restaurant['status']),
                      iconSize: 18,
                      constraints: BoxConstraints(minWidth: 24, minHeight: 24),
                    ),
                ],
              ),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildInfoItem(String label, String value, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.lato(fontSize: 12, color: AppColors.grey)),
        SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.lato(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: isDark ? AppColors.white : AppColors.primary,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusChip(String status) {
    Color backgroundColor;
    Color textColor;

    switch (status) {
      case 'active':
        backgroundColor = AppColors.successGreen.withValues(alpha: 0.1);
        textColor = AppColors.successGreen;
        break;
      case 'pending':
        backgroundColor = AppColors.warningOrange.withValues(alpha: 0.1);
        textColor = AppColors.warningOrange;
        break;
      case 'suspended':
        backgroundColor = AppColors.errorRed.withValues(alpha: 0.1);
        textColor = AppColors.errorRed;
        break;
      default:
        backgroundColor = AppColors.grey.withValues(alpha: 0.1);
        textColor = AppColors.grey;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      margin: EdgeInsets.only(right: 8, top: 2),
      decoration: BoxDecoration(color: backgroundColor, borderRadius: BorderRadius.circular(12)),
      child: Text(
        status,
        style: GoogleFonts.lato(fontSize: 12, fontWeight: FontWeight.w600, color: textColor),
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  String _getActionText(String status) {
    switch (status) {
      case 'active':
        return 'Suspend';
      case 'pending':
        return 'Approve';
      case 'suspended':
        return 'Activate';
      default:
        return 'Action';
    }
  }

  Color _getActionColor(String status) {
    switch (status) {
      case 'active':
        return AppColors.errorRed;
      case 'pending':
        return AppColors.successGreen;
      case 'suspended':
        return AppColors.successGreen;
      default:
        return AppColors.accentOrange;
    }
  }

  SvgIcon _getActionIcon(String status) {
    switch (status) {
      case 'active':
        return SvgIcon(svgImage: Assets.icons.ban, width: 18, height: 18, color: AppColors.errorRed);
      case 'pending':
        return SvgIcon(svgImage: Assets.icons.check, width: 18, height: 18, color: AppColors.successGreen);
      case 'suspended':
        return SvgIcon(svgImage: Assets.icons.check, width: 18, height: 18, color: AppColors.successGreen);
      default:
        return SvgIcon(svgImage: Assets.icons.moreVert, width: 18, height: 18, color: AppColors.accentOrange);
    }
  }

  void _viewRestaurantDetails(Map<String, dynamic> restaurant) {
    showDialog(context: context, builder: (context) => _buildRestaurantDetailsDialog(restaurant));
  }

  void _handleRestaurantAction(Map<String, dynamic> restaurant) {
    String action = _getActionText(restaurant['status']);
    String message = 'Are you sure you want to $action "${restaurant['name']}"?';
    String status = restaurant['status'] == 'active' ? 'suspended' : 'active';

    AppDialogPanels.show(
      context: context,
      title: 'Confirm Action',
      message: message,
      type: AppDialogType.question,
      primaryButtonText: 'Confirm',
      secondaryButtonText: 'Cancel',
      primaryButtonColor: AppColors.accentOrange,
      onPrimaryPressed: () async {
        Navigator.of(context).pop();
        final provider = context.read<RestaurantProvider>();
        final success = await provider.updateRestaurantStatus(restaurant['id'], status);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                success
                    ? 'Restaurant status updated successfully'
                    : provider.error ?? 'Failed to update restaurant status',
              ),
              backgroundColor: success ? AppColors.successGreen : AppColors.errorRed,
              duration: Duration(seconds: success ? 2 : 4),
            ),
          );
        }
      },
      onSecondaryPressed: () => Navigator.of(context).pop(),
    );
  }

  Widget _buildRestaurantDetailsDialog(Map<String, dynamic> restaurant) {
    final isMobile = Responsive.isMobile(context);
    final screenHeight = MediaQuery.of(context).size.height;

    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.all(isMobile ? 16 : 40),
          child: Container(
            width: double.infinity,
            constraints: BoxConstraints(maxHeight: screenHeight * 0.9),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : AppColors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 10)),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: EdgeInsets.all(isMobile ? 20 : 24),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkBackground : AppColors.secondaryBackground,
                    borderRadius: BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Restaurant Details',
                          style: GoogleFonts.lato(
                            fontSize: isMobile ? 20 : 24,
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppColors.white : AppColors.primary,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: Icon(Icons.close, color: isDark ? AppColors.white : AppColors.grey),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(isMobile ? 20 : 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Restaurant Logo',
                          style: GoogleFonts.lato(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppColors.white : AppColors.primary,
                          ),
                        ),
                        SizedBox(height: 12),
                        Container(
                          width: 200,
                          height: 120,
                          margin: EdgeInsets.only(right: 12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightSurface),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              restaurant['logo'],
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Container(
                                color: AppColors.grey.withValues(alpha: 0.1),
                                child: Padding(
                                  padding: const EdgeInsets.all(45),
                                  child: SvgPicture.asset(
                                    Assets.icons.mediaImage,
                                    package: 'grab_go_shared',
                                    width: 24,
                                    height: 24,
                                    colorFilter: ColorFilter.mode(AppColors.grey, BlendMode.srcIn),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 24),
                        _buildSectionTitle('Basic Information', isDark),
                        SizedBox(height: 12),
                        _buildDetailRow('Restaurant Name', restaurant['name'], isDark),
                        _buildDetailRow('Status', restaurant['status'] ?? 'N/A', isDark, showStatusChip: true),
                        _buildDetailRow('Business ID', restaurant['businessIdNumber'] ?? 'N/A', isDark),
                        if (restaurant['foodType'] != null)
                          _buildDetailRow('Food Type', restaurant['foodType'], isDark),
                        if (restaurant['description'] != null)
                          _buildDetailRow('Description', restaurant['description'], isDark, isMultiline: true),
                        SizedBox(height: 24),
                        _buildSectionTitle('Owner Information', isDark),
                        SizedBox(height: 12),
                        _buildDetailRow('Owner Name', restaurant['owner'] ?? 'N/A', isDark),
                        _buildDetailRow('Owner Contact', restaurant['ownerContact'] ?? 'N/A', isDark),
                        _buildDetailRow('Email', restaurant['email'] ?? 'N/A', isDark),
                        _buildDetailRow('Phone', restaurant['phone'] ?? 'N/A', isDark),
                        SizedBox(height: 24),
                        _buildSectionTitle('Location', isDark),
                        SizedBox(height: 12),
                        _buildDetailRow('Address', restaurant['address'] ?? 'N/A', isDark),
                        _buildDetailRow('City', restaurant['city'] ?? 'N/A', isDark),
                        if (restaurant['latitude'] != null && restaurant['longitude'] != null)
                          _buildDetailRow(
                            'Coordinates',
                            '${restaurant['latitude']}, ${restaurant['longitude']}',
                            isDark,
                          ),
                        SizedBox(height: 24),
                        _buildSectionTitle('Business Details', isDark),
                        SizedBox(height: 12),
                        _buildDetailRow('Registration Date', restaurant['registrationDate'] ?? 'N/A', isDark),
                        _buildDetailRow('Opening Hours', restaurant['openingHours'] ?? 'N/A', isDark),
                        _buildDetailRow('Average Delivery Time', restaurant['averageDeliveryTime'] ?? 'N/A', isDark),
                        _buildDetailRow('Is Open', restaurant['isOpen'] == true ? 'Yes' : 'No', isDark),
                        SizedBox(height: 24),
                        _buildSectionTitle('Pricing & Orders', isDark),
                        SizedBox(height: 12),
                        _buildDetailRow('Delivery Fee', restaurant['deliveryFee'] ?? 'N/A', isDark),
                        _buildDetailRow('Minimum Order', restaurant['minOrder'] ?? 'N/A', isDark),
                        _buildDetailRow('Total Orders', restaurant['orders']?.toString() ?? '0', isDark),
                        _buildDetailRow('Total Sales', restaurant['totalSales'] ?? 'N/A', isDark),
                        _buildDetailRow(
                          'Rating',
                          restaurant['rating'] == 0.0 ? 'N/A' : '${restaurant['rating']}',
                          isDark,
                        ),
                        if (restaurant['paymentMethods'] != null &&
                            (restaurant['paymentMethods'] as List).isNotEmpty) ...[
                          SizedBox(height: 24),
                          _buildSectionTitle('Payment Methods', isDark),
                          SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: (restaurant['paymentMethods'] as List)
                                .map((method) => _buildChip(method.toString(), isDark))
                                .toList(),
                          ),
                        ],
                        if (restaurant['socials'] != null) ...[
                          Builder(
                            builder: (context) {
                              final socials = restaurant['socials'];
                              final hasFacebook =
                                  (socials is Map && socials['facebook'] != null) ||
                                  (socials is Socials && socials.facebook != null);
                              final hasInstagram =
                                  (socials is Map && socials['instagram'] != null) ||
                                  (socials is Socials && socials.instagram != null);

                              if (!hasFacebook && !hasInstagram) {
                                return SizedBox.shrink();
                              }

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(height: 24),
                                  _buildSectionTitle('Social Media', isDark),
                                  SizedBox(height: 12),
                                  if (hasFacebook)
                                    _buildDetailRow(
                                      'Facebook',
                                      socials is Map ? socials['facebook'] : (socials as Socials).facebook!,
                                      isDark,
                                      isLink: true,
                                    ),
                                  if (hasInstagram)
                                    _buildDetailRow(
                                      'Instagram',
                                      socials is Map ? socials['instagram'] : (socials as Socials).instagram!,
                                      isDark,
                                      isLink: true,
                                    ),
                                ],
                              );
                            },
                          ),
                        ],
                        if (restaurant['bannerImages'] != null && (restaurant['bannerImages'] as List).isNotEmpty) ...[
                          SizedBox(height: 24),
                          _buildSectionTitle('Banner Images', isDark),
                          SizedBox(height: 12),
                          SizedBox(
                            height: 120,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: (restaurant['bannerImages'] as List).length,
                              itemBuilder: (context, index) {
                                return Container(
                                  width: 200,
                                  margin: EdgeInsets.only(right: 12),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightSurface),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(
                                      restaurant['bannerImages'][index],
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) => Container(
                                        color: AppColors.grey.withValues(alpha: 0.1),
                                        child: Padding(
                                          padding: const EdgeInsets.all(45),
                                          child: SvgPicture.asset(
                                            Assets.icons.mediaImage,
                                            package: 'grab_go_shared',
                                            width: 24,
                                            height: 24,
                                            colorFilter: ColorFilter.mode(AppColors.grey, BlendMode.srcIn),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                        SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
                Container(
                  padding: EdgeInsets.all(isMobile ? 16 : 20),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkBackground : AppColors.secondaryBackground,
                    borderRadius: BorderRadius.only(bottomLeft: Radius.circular(12), bottomRight: Radius.circular(12)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      GestureDetector(
                        onTap: () {
                          Navigator.of(context).pop();
                        },
                        child: Container(
                          height: 50.0,
                          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [AppColors.successGreen, AppColors.successGreen.withValues(alpha: 0.8)],
                            ),
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.successGreen.withValues(alpha: 0.3),
                                blurRadius: 15,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              'Approve Restaurant',
                              style: GoogleFonts.lato(
                                fontSize: Responsive.getFontSize(context, 15),
                                fontWeight: FontWeight.w700,
                                color: AppColors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSectionTitle(String title, bool isDark) {
    return Text(
      title,
      style: GoogleFonts.lato(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: isDark ? AppColors.white : AppColors.primary,
      ),
    );
  }

  Widget _buildChip(String label, bool isDark) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkBackground : AppColors.secondaryBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightSurface),
      ),
      child: Text(label, style: GoogleFonts.lato(fontSize: 12, color: isDark ? AppColors.white : AppColors.primary)),
    );
  }

  Widget _buildDetailRow(
    String label,
    String value,
    bool isDark, {
    bool isMultiline = false,
    bool isLink = false,
    bool showStatusChip = false,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 160,
            child: Text(
              label,
              style: GoogleFonts.lato(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.grey),
            ),
          ),
          Expanded(
            child: isLink
                ? GestureDetector(
                    onTap: () {},
                    child: Text(
                      value,
                      style: GoogleFonts.lato(
                        fontSize: 14,
                        color: AppColors.accentOrange,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  )
                : showStatusChip
                ? _buildStatusChip(value)
                : Text(
                    value,
                    style: GoogleFonts.lato(fontSize: 14, color: isDark ? AppColors.white : AppColors.primary),
                    maxLines: isMultiline ? null : 2,
                    overflow: isMultiline ? null : TextOverflow.ellipsis,
                  ),
          ),
        ],
      ),
    );
  }

  void _approveRestaurant(Map<String, dynamic> restaurant) {
    AppDialogPanels.show(
      context: context,
      title: 'Approve Restaurant',
      message: 'Are you sure you want to approve "${restaurant['name']}"?',
      type: AppDialogType.question,
      primaryButtonText: 'Approve',
      secondaryButtonText: 'Cancel',
      primaryButtonColor: AppColors.successGreen,
      onPrimaryPressed: () async {
        Navigator.of(context).pop();
        final provider = context.read<RestaurantProvider>();
        final success = await provider.approveRestaurant(restaurant['id']);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                success ? 'Restaurant approved successfully' : provider.error ?? 'Failed to approve restaurant',
              ),
              backgroundColor: success ? AppColors.successGreen : AppColors.errorRed,
              duration: Duration(seconds: success ? 2 : 4),
            ),
          );
        }
      },
      onSecondaryPressed: () => Navigator.of(context).pop(),
    );
  }

  void _suspendRestaurant(Map<String, dynamic> restaurant) {
    final isPending = restaurant['status'] == 'pending';
    final title = isPending ? 'Reject Restaurant Application' : 'Suspend Restaurant';
    final content = isPending
        ? 'Are you sure you want to reject the application for "${restaurant['name']}"?'
        : 'Are you sure you want to suspend "${restaurant['name']}"?';
    final status = isPending ? 'suspended' : 'suspended';

    AppDialogPanels.show(
      context: context,
      title: title,
      message: content,
      type: AppDialogType.question,
      primaryButtonText: 'Confirm',
      secondaryButtonText: 'Cancel',
      primaryButtonColor: isPending ? AppColors.errorRed : AppColors.accentOrange,
      onPrimaryPressed: () async {
        Navigator.of(context).pop();
        final provider = context.read<RestaurantProvider>();
        final success = await provider.updateRestaurantStatus(restaurant['id'], status);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                success
                    ? 'Restaurant status updated successfully'
                    : provider.error ?? 'Failed to update restaurant status',
              ),
              backgroundColor: success ? AppColors.successGreen : AppColors.errorRed,
              duration: Duration(seconds: success ? 2 : 4),
            ),
          );
        }
      },
      onSecondaryPressed: () => Navigator.of(context).pop(),
    );
  }
}
