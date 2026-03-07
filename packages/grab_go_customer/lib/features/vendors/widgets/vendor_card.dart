import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:grab_go_customer/shared/viewmodels/favorites_provider.dart';
import 'package:provider/provider.dart';
import 'exclusive_stamp_badge.dart';
import '../model/vendor_model.dart';
import '../model/vendor_type.dart';

class VendorCard extends StatelessWidget {
  final VendorModel vendor;
  final VoidCallback onTap;
  final bool showDistance;
  final double? width;
  final EdgeInsetsGeometry? margin;
  final bool showClosedOnImage;
  final bool highlightExclusiveBadge;

  const VendorCard({
    super.key,
    required this.vendor,
    required this.onTap,
    this.showDistance = true,
    this.width,
    this.margin,
    this.showClosedOnImage = false,
    this.highlightExclusiveBadge = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final size = MediaQuery.sizeOf(context);
    final cardWidth = width ?? (size.width - 40.w);
    final imageHeight = (cardWidth * 0.45).clamp(90.0, 125.0);
    final reviewCountText = vendor.totalReviews > 0
        ? " (${vendor.totalReviews})"
        : "";
    final opsState = _buildOpsState(colors);

    return Container(
      width: width ?? double.infinity,
      margin: margin ?? EdgeInsets.symmetric(horizontal: 20.w, vertical: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(KBorderSize.borderMedium),
          child: Container(
            decoration: BoxDecoration(
              color: colors.backgroundPrimary,
              borderRadius: BorderRadius.circular(KBorderSize.borderMedium),
            ),
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: EdgeInsets.all(1.0.r),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildVendorImage(context, colors, imageHeight),
                  Padding(
                    padding: EdgeInsets.only(top: 10.r),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                vendor.displayName,
                                style: TextStyle(
                                  color: colors.textPrimary,
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w800,
                                  fontFamily: "Lato",
                                  package: 'grab_go_shared',
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SvgPicture.asset(
                                  Assets.icons.starSolid,
                                  package: 'grab_go_shared',
                                  height: 13,
                                  width: 13.w,
                                  colorFilter: ColorFilter.mode(
                                    colors.accentOrange,
                                    BlendMode.srcIn,
                                  ),
                                ),
                                SizedBox(width: 4.w),
                                Text(
                                  '${vendor.rating.toStringAsFixed(1)}$reviewCountText',
                                  style: TextStyle(
                                    fontSize: 12.sp,
                                    color: colors.textPrimary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Wrap(
                              spacing: 6.w,
                              runSpacing: 2.h,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                if (vendor.vendorCategories.isNotEmpty)
                                  Text(
                                    vendor.vendorCategories.first,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 13.sp,
                                      color: colors.textSecondary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                if (vendor.vendorCategories.isNotEmpty &&
                                    showDistance &&
                                    vendor.distanceText.isNotEmpty)
                                  Text(
                                    "·",
                                    style: TextStyle(
                                      color: colors.textSecondary,
                                      fontSize: 13.sp,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                if (showDistance &&
                                    vendor.distanceText.isNotEmpty)
                                  Text(
                                    vendor.distanceText,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: colors.textSecondary,
                                      fontSize: 13.sp,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                              ],
                            ),
                            SizedBox(width: 8.w),
                            Container(
                              width: 3.w,
                              height: 3,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: colors.textSecondary,
                              ),
                            ),
                            SizedBox(width: 8.w),
                            SvgPicture.asset(
                              Assets.icons.timer,
                              package: 'grab_go_shared',
                              height: 12,
                              width: 12.w,
                              colorFilter: ColorFilter.mode(
                                colors.textSecondary,
                                BlendMode.srcIn,
                              ),
                            ),
                            SizedBox(width: 4.w),
                            Flexible(
                              child: Text(
                                "${vendor.averageDeliveryTime} mins",
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11.sp,
                                  fontWeight: FontWeight.w500,
                                  color: colors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        opsState == null
                            ? _buildPricingRow(colors)
                            : Row(
                                children: [
                                  Expanded(
                                    child: Wrap(
                                      spacing: 10.w,
                                      runSpacing: 2.h,
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      children: [
                                        _buildDeliveryFeeMeta(colors),
                                        if (vendor.minOrder > 0) ...[
                                          _buildMinOrderMeta(colors),
                                        ],
                                      ],
                                    ),
                                  ),
                                  SizedBox(width: 8.w),
                                  _buildOpsStatePill(
                                    colors: colors,
                                    label: opsState.label,
                                    textColor: opsState.textColor,
                                    backgroundColor: opsState.backgroundColor,
                                  ),
                                ],
                              ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVendorImage(
    BuildContext context,
    AppColorsExtension colors,
    double imageHeight,
  ) {
    final imageUrl = _vendorCardImageUrl();
    final showExclusiveStamp = highlightExclusiveBadge && vendor.isExclusive;
    final trustBadges = <Widget>[
      if (!showExclusiveStamp && (vendor.featured ?? false))
        _buildTrustBadge(
          colors: colors,
          iconAsset: Assets.icons.sparkles,
          label: 'Featured',
          textColor: Colors.white,
          backgroundColor: colors.accentOrange.withValues(alpha: 0.92),
        ),
      if (!showExclusiveStamp && (vendor.isVerified ?? false))
        _buildTrustBadge(
          colors: colors,
          iconAsset: Assets.icons.badgeCheck,
          label: 'Verified',
          textColor: Colors.white,
          backgroundColor: Colors.black.withValues(alpha: 0.55),
        ),
    ];

    return Stack(
      children: [
        ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(KBorderSize.borderMedium),
            topRight: Radius.circular(KBorderSize.borderMedium),
            bottomLeft: Radius.circular(KBorderSize.borderRadius4),
            bottomRight: Radius.circular(KBorderSize.borderRadius4),
          ),
          child: CachedNetworkImage(
            imageUrl: ImageOptimizer.getPreviewUrl(imageUrl ?? '', width: 800),
            height: imageHeight,
            width: double.infinity,
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(
              height: imageHeight,
              width: double.infinity,
              color: colors.inputBorder,
              child: Center(
                child: SvgPicture.asset(
                  Assets.icons.store,
                  package: 'grab_go_shared',
                  colorFilter: ColorFilter.mode(
                    colors.textSecondary,
                    BlendMode.srcIn,
                  ),
                  width: 30.w,
                  height: 30,
                ),
              ),
            ),
            errorWidget: (context, url, error) => Container(
              height: imageHeight,
              width: double.infinity,
              color: colors.inputBorder,
              child: Center(
                child: SvgPicture.asset(
                  Assets.icons.store,
                  package: 'grab_go_shared',
                  colorFilter: ColorFilter.mode(
                    colors.textSecondary,
                    BlendMode.srcIn,
                  ),
                  width: 30.w,
                  height: 30,
                ),
              ),
            ),
          ),
        ),
        if (showExclusiveStamp)
          Positioned(
            left: 0,
            top: 10.h,
            child: ExclusiveStampBadge(width: 74.w, height: 24.h),
          ),
        if (trustBadges.isNotEmpty)
          Positioned(
            left: 8.w,
            top: 8.h,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < trustBadges.length; i++) ...[
                  if (i > 0) SizedBox(height: 6.h),
                  trustBadges[i],
                ],
              ],
            ),
          ),
        Positioned(
          top: 2.h,
          right: 2.w,
          child: IgnorePointer(
            child: Container(
              width: 36.w,
              height: 36.w,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(KBorderSize.borderMedium),
                ),
                gradient: RadialGradient(
                  center: const Alignment(1.0, -1.0),
                  radius: 1.15,
                  colors: [
                    Colors.black.withValues(alpha: 0.28),
                    Colors.black.withValues(alpha: 0.10),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.45, 1.0],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          right: 6.r,
          top: 6.r,
          child: Consumer<FavoritesProvider>(
            builder: (context, favoritesProvider, child) {
              final favoriteVendor = _toFavoriteVendor(vendor);
              final isFavorite = favoritesProvider.isVendorFavorite(
                favoriteVendor,
              );

              return GestureDetector(
                onTap: () async {
                  try {
                    await favoritesProvider.toggleVendorFavorite(
                      favoriteVendor,
                    );
                  } catch (_) {
                    if (context.mounted) {
                      AppToastMessage.show(
                        context: context,
                        backgroundColor: context.appColors.error,
                        message: 'Could not update favorite. Please try again.',
                      );
                    }
                  }
                },
                child: SvgPicture.asset(
                  isFavorite ? Assets.icons.heartSolid : Assets.icons.heart,
                  package: 'grab_go_shared',
                  height: 24,
                  width: 24.w,
                  colorFilter: ColorFilter.mode(
                    isFavorite ? context.appColors.error : Colors.white,
                    BlendMode.srcIn,
                  ),
                ),
              );
            },
          ),
        ),
        if (!vendor.isAvailableForOrders && showClosedOnImage)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.45),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(KBorderSize.borderMedium),
                  topRight: Radius.circular(KBorderSize.borderMedium),
                  bottomLeft: Radius.circular(KBorderSize.borderRadius4),
                  bottomRight: Radius.circular(KBorderSize.borderRadius4),
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                vendor.overlayAvailabilityLabel,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
      ],
    );
  }

  String? _vendorCardImageUrl() {
    final bannerImage = vendor.bannerImages
        ?.cast<String?>()
        .map((entry) => entry?.trim() ?? '')
        .firstWhere((entry) => entry.isNotEmpty, orElse: () => '');
    if (bannerImage != null && bannerImage.isNotEmpty) {
      return bannerImage;
    }

    final logo = vendor.logo?.trim();
    if (logo != null && logo.isNotEmpty) {
      return logo;
    }

    return null;
  }

  _VendorOpsState? _buildOpsState(AppColorsExtension colors) {
    if (vendor.isAvailableForOrders) {
      return null;
    }

    if (vendor.isTemporarilyUnavailableButOpen) {
      return _VendorOpsState(
        label: 'Not accepting',
        textColor: colors.error,
        backgroundColor: colors.error.withValues(alpha: 0.10),
      );
    }

    if (showClosedOnImage) {
      return null;
    }

    return _VendorOpsState(
      label: 'Closed for now',
      textColor: colors.error,
      backgroundColor: colors.error.withValues(alpha: 0.10),
    );
  }

  Widget _buildTrustBadge({
    required AppColorsExtension colors,
    required String iconAsset,
    required String label,
    required Color textColor,
    required Color backgroundColor,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 5.h),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset(
            iconAsset,
            package: 'grab_go_shared',
            width: 12.w,
            height: 12.h,
            colorFilter: ColorFilter.mode(textColor, BlendMode.srcIn),
          ),
          SizedBox(width: 4.w),
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: 10.sp,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOpsStatePill({
    required AppColorsExtension colors,
    required String label,
    required Color textColor,
    required Color backgroundColor,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 5.h),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6.w,
            height: 6.w,
            decoration: BoxDecoration(color: textColor, shape: BoxShape.circle),
          ),
          SizedBox(width: 5.w),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: textColor,
              fontSize: 10.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPricingRow(AppColorsExtension colors) {
    if (vendor.minOrder <= 0) {
      return _buildDeliveryFeeMeta(colors);
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(child: _buildDeliveryFeeMeta(colors)),
        SizedBox(width: 12.w),
        Flexible(
          child: Align(
            alignment: Alignment.centerRight,
            child: _buildMinOrderMeta(colors),
          ),
        ),
      ],
    );
  }

  Widget _buildDeliveryFeeMeta(AppColorsExtension colors) {
    final deliveryValue = vendor.deliveryFee == 0
        ? 'Free'
        : 'GHS ${vendor.deliveryFee.toStringAsFixed(0)}';

    return Wrap(
      spacing: 4.w,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          'Delivery:',
          style: TextStyle(
            color: colors.textSecondary,
            fontSize: 12.sp,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          deliveryValue,
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: 12.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildMinOrderMeta(AppColorsExtension colors) {
    return Wrap(
      spacing: 4.w,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          'Min order:',
          style: TextStyle(
            color: colors.textSecondary,
            fontSize: 12.sp,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          'GHS ${vendor.minOrder.toStringAsFixed(0)}',
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: 12.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  FavoriteVendor _toFavoriteVendor(VendorModel vendor) {
    return FavoriteVendor(
      id: vendor.id,
      name: vendor.displayName,
      image: vendor.logo ?? '',
      address: vendor.address.isNotEmpty ? vendor.address : null,
      city: vendor.city.isNotEmpty ? vendor.city : null,
      area: vendor.area,
      status: 'approved',
      isOpen: vendor.isOpen,
      isAcceptingOrders: vendor.isAcceptingOrders,
      isVerified: vendor.isVerified ?? false,
      featured: vendor.featured ?? false,
      lastOnlineAt: vendor.lastOnlineAt,
      type: _toFavoriteVendorType(vendor),
    );
  }

  FavoriteVendorType _toFavoriteVendorType(VendorModel vendor) {
    final rawType = vendor.vendorType?.trim().toLowerCase();
    if (rawType != null && rawType.isNotEmpty) {
      final normalizedType = rawType.replaceAll('-', '_').replaceAll(' ', '_');
      if (normalizedType == 'restaurant' || normalizedType == 'food') {
        return FavoriteVendorType.restaurant;
      }
      if (normalizedType == 'grocery' || normalizedType == 'grocery_store') {
        return FavoriteVendorType.groceryStore;
      }
      if (normalizedType == 'pharmacy' || normalizedType == 'pharmacy_store') {
        return FavoriteVendorType.pharmacyStore;
      }
      if (normalizedType == 'grabmart' || normalizedType == 'grabmart_store') {
        return FavoriteVendorType.grabMartStore;
      }
    }

    switch (vendor.vendorTypeEnum) {
      case VendorType.food:
        return FavoriteVendorType.restaurant;
      case VendorType.grocery:
        return FavoriteVendorType.groceryStore;
      case VendorType.pharmacy:
        return FavoriteVendorType.pharmacyStore;
      case VendorType.grabmart:
        return FavoriteVendorType.grabMartStore;
    }
  }
}

class _VendorOpsState {
  final String label;
  final Color textColor;
  final Color backgroundColor;

  const _VendorOpsState({
    required this.label,
    required this.textColor,
    required this.backgroundColor,
  });
}
