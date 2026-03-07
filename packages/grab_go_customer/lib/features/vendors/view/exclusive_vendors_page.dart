import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_customer/features/vendors/model/vendor_model.dart';
import 'package:grab_go_customer/features/vendors/model/vendor_type.dart';
import 'package:grab_go_customer/features/vendors/service/exclusive_vendor_service.dart';
import 'package:grab_go_customer/features/vendors/widgets/vendor_card.dart';
import 'package:grab_go_customer/shared/viewmodels/native_location_provider.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:provider/provider.dart';

enum _ExclusiveVendorTab { all, food, grocery, pharmacy, grabmart }

class ExclusiveVendorsPage extends StatefulWidget {
  final String? initialTabId;

  const ExclusiveVendorsPage({super.key, this.initialTabId});

  @override
  State<ExclusiveVendorsPage> createState() => _ExclusiveVendorsPageState();
}

class _ExclusiveVendorsPageState extends State<ExclusiveVendorsPage> {
  final ExclusiveVendorService _service = ExclusiveVendorService();
  final TextEditingController _searchController = TextEditingController();

  List<VendorModel> _vendors = const [];
  bool _isLoading = true;
  String? _error;
  String _searchQuery = '';
  double? _lastLat;
  double? _lastLng;
  bool _hasRequestedInitialLoad = false;
  int _latestLoadToken = 0;

  late _ExclusiveVendorTab _selectedTab;

  @override
  void initState() {
    super.initState();
    _selectedTab = _tabFromId(widget.initialTabId);
    _searchController.addListener(() {
      if (!mounted) return;
      setState(() {
        _searchQuery = _searchController.text.trim();
      });
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final locationProvider = Provider.of<NativeLocationProvider>(context);
    final latitude = locationProvider.latitude;
    final longitude = locationProvider.longitude;
    final locationChanged =
        _hasRequestedInitialLoad &&
        (latitude != _lastLat || longitude != _lastLng);

    if (!_hasRequestedInitialLoad || locationChanged) {
      _hasRequestedInitialLoad = true;
      _lastLat = latitude;
      _lastLng = longitude;
      _loadExclusiveVendors(latitude: latitude, longitude: longitude);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadExclusiveVendors({
    double? latitude,
    double? longitude,
  }) async {
    final loadToken = ++_latestLoadToken;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final vendors = await _service.fetchExclusiveVendors(
        latitude: latitude,
        longitude: longitude,
      );
      if (!mounted || loadToken != _latestLoadToken) return;
      setState(() {
        _vendors = vendors;
        _error = null;
      });
    } catch (error) {
      if (!mounted || loadToken != _latestLoadToken) return;
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted && loadToken == _latestLoadToken) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  _ExclusiveVendorTab _tabFromId(String? id) {
    switch (id) {
      case 'food':
        return _ExclusiveVendorTab.food;
      case 'grocery':
        return _ExclusiveVendorTab.grocery;
      case 'pharmacy':
        return _ExclusiveVendorTab.pharmacy;
      case 'grabmart':
        return _ExclusiveVendorTab.grabmart;
      default:
        return _ExclusiveVendorTab.all;
    }
  }

  VendorType? _vendorTypeForTab(_ExclusiveVendorTab tab) {
    switch (tab) {
      case _ExclusiveVendorTab.food:
        return VendorType.food;
      case _ExclusiveVendorTab.grocery:
        return VendorType.grocery;
      case _ExclusiveVendorTab.pharmacy:
        return VendorType.pharmacy;
      case _ExclusiveVendorTab.grabmart:
        return VendorType.grabmart;
      case _ExclusiveVendorTab.all:
        return null;
    }
  }

  String _tabLabel(_ExclusiveVendorTab tab) {
    switch (tab) {
      case _ExclusiveVendorTab.all:
        return 'All';
      case _ExclusiveVendorTab.food:
        return 'Food';
      case _ExclusiveVendorTab.grocery:
        return 'Grocery';
      case _ExclusiveVendorTab.pharmacy:
        return 'Pharmacy';
      case _ExclusiveVendorTab.grabmart:
        return 'GrabMart';
    }
  }

  List<VendorModel> get _filteredVendors {
    final activeType = _vendorTypeForTab(_selectedTab);
    final byTab = activeType == null
        ? _vendors
        : _vendors
              .where((vendor) => vendor.vendorTypeEnum == activeType)
              .toList(growable: false);

    if (_searchQuery.isEmpty) {
      return byTab;
    }

    final query = _searchQuery.toLowerCase();
    return byTab
        .where((vendor) {
          final haystack = [
            vendor.displayName,
            vendor.description ?? '',
            vendor.city,
            vendor.area ?? '',
            vendor.vendorTypeEnum.displayName,
            ...vendor.vendorCategories,
          ].join(' ').toLowerCase();
          return haystack.contains(query);
        })
        .toList(growable: false);
  }

  int _countForTab(_ExclusiveVendorTab tab) {
    final vendorType = _vendorTypeForTab(tab);
    if (vendorType == null) {
      return _vendors.length;
    }
    return _vendors
        .where((vendor) => vendor.vendorTypeEnum == vendorType)
        .length;
  }

  String _emptyTitle() {
    if (_searchQuery.isNotEmpty) {
      return 'No exclusive vendors match "$_searchQuery".';
    }

    switch (_selectedTab) {
      case _ExclusiveVendorTab.all:
        return 'No GrabGo exclusive vendors are available right now.';
      case _ExclusiveVendorTab.food:
        return 'No exclusive food vendors are available right now.';
      case _ExclusiveVendorTab.grocery:
        return 'No exclusive grocery stores are available right now.';
      case _ExclusiveVendorTab.pharmacy:
        return 'No exclusive pharmacies are available right now.';
      case _ExclusiveVendorTab.grabmart:
        return 'No exclusive GrabMart stores are available right now.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final systemUiOverlayStyle = SystemUiOverlayStyle(
      statusBarColor: colors.accentOrange,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: colors.backgroundPrimary,
      systemNavigationBarIconBrightness: isDark
          ? Brightness.light
          : Brightness.dark,
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: systemUiOverlayStyle,
      child: Scaffold(
        backgroundColor: colors.backgroundPrimary,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Material(
                          color: colors.accentOrange.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999.r),
                          child: InkWell(
                            onTap: () => context.pop(),
                            borderRadius: BorderRadius.circular(999.r),
                            child: SizedBox(
                              width: 42.w,
                              height: 42.w,
                              child: Icon(
                                Icons.arrow_back_ios_new_rounded,
                                size: 16.sp,
                                color: colors.accentOrange,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 14.w),
                        Expanded(
                          child: Text(
                            'GrabGo Exclusives',
                            style: TextStyle(
                              color: colors.textPrimary,
                              fontSize: 22.sp,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 18.h),
                    Text(
                      'Explore partner vendors getting premium placement on GrabGo across food, grocery, pharmacy, and GrabMart.',
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w500,
                        height: 1.45,
                      ),
                    ),
                    SizedBox(height: 18.h),
                    _buildSearchField(colors),
                    SizedBox(height: 14.h),
                    _buildTabSelector(colors),
                    SizedBox(height: 18.h),
                  ],
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () => _loadExclusiveVendors(
                    latitude: _lastLat,
                    longitude: _lastLng,
                  ),
                  color: colors.accentOrange,
                  child: _buildBody(colors),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchField(AppColorsExtension colors) {
    return TextField(
      controller: _searchController,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Search exclusive vendors',
        hintStyle: TextStyle(
          color: colors.textTertiary,
          fontSize: 13.sp,
          fontWeight: FontWeight.w500,
        ),
        prefixIcon: Icon(
          Icons.search_rounded,
          color: colors.textSecondary,
          size: 20.sp,
        ),
        filled: true,
        fillColor: colors.backgroundSecondary,
        contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18.r),
          borderSide: BorderSide(color: colors.inputBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18.r),
          borderSide: BorderSide(color: colors.inputBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18.r),
          borderSide: BorderSide(color: colors.accentOrange, width: 1.2),
        ),
      ),
    );
  }

  Widget _buildTabSelector(AppColorsExtension colors) {
    final tabs = _ExclusiveVendorTab.values;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Container(
        padding: EdgeInsets.all(6.r),
        decoration: BoxDecoration(
          color: colors.backgroundSecondary,
          borderRadius: BorderRadius.circular(999.r),
        ),
        child: Row(
          children: tabs
              .map((tab) {
                final isSelected = _selectedTab == tab;
                return GestureDetector(
                  onTap: () {
                    if (isSelected) return;
                    setState(() {
                      _selectedTab = tab;
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    margin: EdgeInsets.only(right: tab == tabs.last ? 0 : 6.w),
                    padding: EdgeInsets.symmetric(
                      horizontal: 16.w,
                      vertical: 11.h,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? colors.accentOrange
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(999.r),
                    ),
                    child: Text(
                      '${_tabLabel(tab)} (${_countForTab(tab)})',
                      style: TextStyle(
                        color: isSelected ? Colors.white : colors.textSecondary,
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                );
              })
              .toList(growable: false),
        ),
      ),
    );
  }

  Widget _buildBody(AppColorsExtension colors) {
    if (_isLoading) {
      return _buildLoadingState(colors);
    }

    if (_error != null && _vendors.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 24.h),
        children: [
          Text(
            _error!,
            style: TextStyle(
              color: colors.error,
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
    }

    final vendors = _filteredVendors;
    if (vendors.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 24.h),
        children: [
          Text(
            _emptyTitle(),
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
              height: 1.5,
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(20.w, 4.h, 20.w, 24.h),
      itemCount: vendors.length,
      separatorBuilder: (_, _) => SizedBox(height: 14.h),
      itemBuilder: (context, index) {
        final vendor = vendors[index];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_selectedTab == _ExclusiveVendorTab.all)
              Padding(
                padding: EdgeInsets.only(left: 4.w, bottom: 8.h),
                child: _buildTypePill(colors, vendor.vendorTypeEnum),
              ),
            VendorCard(
              vendor: vendor,
              onTap: () => context.push('/vendorDetails', extra: vendor),
              margin: EdgeInsets.zero,
              showClosedOnImage: true,
              highlightExclusiveBadge: true,
            ),
          ],
        );
      },
    );
  }

  Widget _buildTypePill(AppColorsExtension colors, VendorType vendorType) {
    final accentColor = Color(vendorType.color);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999.r),
      ),
      child: Text(
        vendorType.displayName,
        style: TextStyle(
          color: accentColor,
          fontSize: 11.sp,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildLoadingState(AppColorsExtension colors) {
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(20.w, 4.h, 20.w, 24.h),
      itemCount: 3,
      separatorBuilder: (_, _) => SizedBox(height: 14.h),
      itemBuilder: (context, index) {
        return Container(
          height: 210.h,
          decoration: BoxDecoration(
            color: colors.backgroundSecondary,
            borderRadius: BorderRadius.circular(20.r),
          ),
        );
      },
    );
  }
}
