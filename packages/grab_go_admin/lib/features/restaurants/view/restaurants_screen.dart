import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../shared/app_colors.dart';
import '../../../shared/utils/responsive.dart';
import '../../../shared/widgets/text_input.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/svg_icon.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';

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

  final List<Map<String, dynamic>> restaurants = [
    {
      'id': 'R001',
      'name': 'Golden Spoon Restaurant',
      'owner': 'John Doe',
      'email': 'john@goldenspoon.com',
      'phone': '+233 24 123 4567',
      'address': '123 Oxford Street, Accra',
      'status': 'Active',
      'registrationDate': '2024-01-15',
      'totalSales': 'GHC 45,230',
      'rating': 4.8,
      'deliveryFee': 'GHC 5.00',
      'minOrder': 'GHC 25.00',
      'orders': 1247,
    },
    {
      'id': 'R002',
      'name': 'Spice Garden',
      'owner': 'Sarah Wilson',
      'email': 'sarah@spicegarden.com',
      'phone': '+233 24 234 5678',
      'address': '456 Ring Road, Kumasi',
      'status': 'Pending',
      'registrationDate': '2024-02-20',
      'totalSales': 'GHC 0',
      'rating': 0.0,
      'deliveryFee': 'GHC 8.00',
      'minOrder': 'GHC 30.00',
      'orders': 0,
    },
    {
      'id': 'R003',
      'name': 'Coastal Bites',
      'owner': 'Michael Brown',
      'email': 'michael@coastalbites.com',
      'phone': '+233 24 345 6789',
      'address': '789 Beach Road, Takoradi',
      'status': 'Active',
      'registrationDate': '2024-01-08',
      'totalSales': 'GHC 32,150',
      'rating': 4.6,
      'deliveryFee': 'GHC 6.00',
      'minOrder': 'GHC 20.00',
      'orders': 856,
    },
    {
      'id': 'R004',
      'name': 'Mountain View Cafe',
      'owner': 'Emily Davis',
      'email': 'emily@mountainview.com',
      'phone': '+233 24 456 7890',
      'address': '321 Hill Street, Tamale',
      'status': 'Suspended',
      'registrationDate': '2024-01-25',
      'totalSales': 'GHC 12,890',
      'rating': 3.2,
      'deliveryFee': 'GHC 10.00',
      'minOrder': 'GHC 35.00',
      'orders': 234,
    },
    {
      'id': 'R005',
      'name': 'Urban Kitchen',
      'owner': 'David Johnson',
      'email': 'david@urbankitchen.com',
      'phone': '+233 24 567 8901',
      'address': '654 City Center, Accra',
      'status': 'Active',
      'registrationDate': '2024-02-10',
      'totalSales': 'GHC 28,750',
      'rating': 4.7,
      'deliveryFee': 'GHC 4.00',
      'minOrder': 'GHC 15.00',
      'orders': 692,
    },
  ];

  List<Map<String, dynamic>> get filteredRestaurants {
    var filtered = restaurants.where((restaurant) {
      final matchesSearch =
          restaurant['name'].toLowerCase().contains(searchQuery.toLowerCase()) ||
          restaurant['owner'].toLowerCase().contains(searchQuery.toLowerCase()) ||
          restaurant['email'].toLowerCase().contains(searchQuery.toLowerCase());

      final matchesStatus = selectedStatus == 'All' || restaurant['status'] == selectedStatus;

      return matchesSearch && matchesStatus;
    }).toList();

    // Sort the results
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
          // Header Section
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
                AppButton(
                  buttonText: 'Refresh',
                  onPressed: () {
                    // Refresh restaurants list
                    setState(() {
                      // Trigger a refresh of the restaurants list
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Restaurants list refreshed'), backgroundColor: AppColors.successGreen),
                    );
                  },
                  backgroundColor: AppColors.accentOrange,
                  textColor: AppColors.white,
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  icon: SvgIcon(svgImage: Assets.icons.alarm, width: 18, height: 18, color: AppColors.white),
                ),
            ],
          ),
          SizedBox(height: isMobile ? 20 : 24),

          // Search and Filters Section
          _buildSearchAndFilters(isDark, isMobile, isTablet),
          SizedBox(height: isMobile ? 16 : 20),

          // Restaurants List
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
        borderRadius: BorderRadius.circular(12),
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
          // Search Bar
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

          // Filters Row
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
    final restaurants = filteredRestaurants;

    if (restaurants.isEmpty) {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.all(isMobile ? 40 : 60),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.white,
          borderRadius: BorderRadius.circular(12),
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
        borderRadius: BorderRadius.circular(12),
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
          // Table Header (only for desktop)
          if (!isMobile)
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkBackground : AppColors.secondaryBackground,
                borderRadius: BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
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
          // Table Rows
          ...restaurants.asMap().entries.map((entry) {
            final index = entry.key;
            final restaurant = entry.value;
            return _buildRestaurantRow(restaurant, isDark, isMobile, isTablet, index == restaurants.length - 1);
          }),
        ],
      ),
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
            if (restaurant['status'] == 'Pending')
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
                          padding: EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: AppButton(
                          buttonText: 'Suspend',
                          onPressed: () => _suspendRestaurant(restaurant),
                          backgroundColor: AppColors.errorRed,
                          textColor: AppColors.white,
                          padding: EdgeInsets.symmetric(vertical: 8),
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
                    padding: EdgeInsets.symmetric(vertical: 8),
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
                      padding: EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: AppButton(
                      buttonText: _getActionText(restaurant['status']),
                      onPressed: () => _handleRestaurantAction(restaurant),
                      backgroundColor: _getActionColor(restaurant['status']),
                      textColor: AppColors.white,
                      padding: EdgeInsets.symmetric(vertical: 8),
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
                  if (restaurant['status'] == 'Pending') ...[
                    IconButton(
                      onPressed: () => _approveRestaurant(restaurant),
                      icon: SvgIcon(svgImage: Assets.icons.check, width: 18, height: 18, color: AppColors.successGreen),
                    ),
                    IconButton(
                      onPressed: () => _suspendRestaurant(restaurant),
                      icon: SvgIcon(svgImage: Assets.icons.alarm, width: 18, height: 18, color: AppColors.errorRed),
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
      case 'Active':
        backgroundColor = AppColors.successGreen.withValues(alpha: 0.1);
        textColor = AppColors.successGreen;
        break;
      case 'Pending':
        backgroundColor = AppColors.warningOrange.withValues(alpha: 0.1);
        textColor = AppColors.warningOrange;
        break;
      case 'Suspended':
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
      case 'Active':
        return 'Suspend';
      case 'Pending':
        return 'Approve';
      case 'Suspended':
        return 'Activate';
      default:
        return 'Action';
    }
  }

  Color _getActionColor(String status) {
    switch (status) {
      case 'Active':
        return AppColors.errorRed;
      case 'Pending':
        return AppColors.successGreen;
      case 'Suspended':
        return AppColors.successGreen;
      default:
        return AppColors.accentOrange;
    }
  }

  SvgIcon _getActionIcon(String status) {
    switch (status) {
      case 'Active':
        return SvgIcon(svgImage: Assets.icons.alarm, width: 18, height: 18, color: AppColors.errorRed);
      case 'Pending':
        return SvgIcon(svgImage: Assets.icons.check, width: 18, height: 18, color: AppColors.successGreen);
      case 'Suspended':
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

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        title: Text('Confirm Action'),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Handle the action here
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text('$action action completed for ${restaurant['name']}')));
            },
            child: Text(action),
          ),
        ],
      ),
    );
  }

  Widget _buildRestaurantDetailsDialog(Map<String, dynamic> restaurant) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.white,
      title: Text(
        restaurant['name'],
        style: GoogleFonts.lato(color: isDark ? AppColors.white : AppColors.primary, fontWeight: FontWeight.w600),
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDetailRow('Owner', restaurant['owner'], isDark),
            _buildDetailRow('Email', restaurant['email'], isDark),
            _buildDetailRow('Phone', restaurant['phone'], isDark),
            _buildDetailRow('Address', restaurant['address'], isDark),
            _buildDetailRow('Status', restaurant['status'], isDark),
            _buildDetailRow('Registration Date', restaurant['registrationDate'], isDark),
            _buildDetailRow('Total Sales', restaurant['totalSales'], isDark),
            _buildDetailRow('Total Orders', restaurant['orders'].toString(), isDark),
            _buildDetailRow('Rating', restaurant['rating'] == 0.0 ? 'N/A' : '${restaurant['rating']}', isDark),
            _buildDetailRow('Delivery Fee', restaurant['deliveryFee'], isDark),
            _buildDetailRow('Minimum Order', restaurant['minOrder'], isDark),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text('Close')),
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop();
            // Navigate to edit restaurant screen
          },
          child: Text('Edit Details'),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value, bool isDark) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: GoogleFonts.lato(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.grey),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.lato(fontSize: 14, color: isDark ? AppColors.white : AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }

  void _approveRestaurant(Map<String, dynamic> restaurant) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          backgroundColor: isDark ? AppColors.darkSurface : AppColors.white,
          title: Text(
            'Approve Restaurant',
            style: GoogleFonts.lato(color: isDark ? AppColors.white : AppColors.primary, fontWeight: FontWeight.bold),
          ),
          content: Text(
            'Are you sure you want to approve "${restaurant['name']}"?',
            style: GoogleFonts.lato(color: isDark ? AppColors.white : AppColors.primary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel', style: GoogleFonts.lato(color: AppColors.grey)),
            ),
            TextButton(
              onPressed: () {
                // Update restaurant status to Active
                setState(() {
                  restaurant['status'] = 'Active';
                });
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${restaurant['name']} has been approved successfully!'),
                    backgroundColor: AppColors.successGreen,
                  ),
                );
              },
              child: Text(
                'Approve',
                style: GoogleFonts.lato(color: AppColors.successGreen, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  void _suspendRestaurant(Map<String, dynamic> restaurant) {
    final isPending = restaurant['status'] == 'Pending';
    final title = isPending ? 'Reject Restaurant Application' : 'Suspend Restaurant';
    final content = isPending
        ? 'Are you sure you want to reject the application for "${restaurant['name']}"?'
        : 'Are you sure you want to suspend "${restaurant['name']}"?';

    showDialog(
      context: context,
      builder: (BuildContext context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          backgroundColor: isDark ? AppColors.darkSurface : AppColors.white,
          title: Text(
            title,
            style: GoogleFonts.lato(color: isDark ? AppColors.white : AppColors.primary, fontWeight: FontWeight.bold),
          ),
          content: Text(content, style: GoogleFonts.lato(color: isDark ? AppColors.white : AppColors.primary)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel', style: GoogleFonts.lato(color: AppColors.grey)),
            ),
            TextButton(
              onPressed: () {
                // Update restaurant status based on current status
                setState(() {
                  restaurant['status'] = isPending ? 'Rejected' : 'Suspended';
                });
                Navigator.of(context).pop();
                final message = isPending
                    ? '${restaurant['name']} application has been rejected.'
                    : '${restaurant['name']} has been suspended.';
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(message), backgroundColor: AppColors.errorRed));
              },
              child: Text(
                isPending ? 'Reject' : 'Suspend',
                style: GoogleFonts.lato(color: AppColors.errorRed, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }
}
