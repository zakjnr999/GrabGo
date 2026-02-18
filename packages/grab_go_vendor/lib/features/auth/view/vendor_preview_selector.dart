import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:grab_go_vendor/features/auth/model/vendor_service_option.dart';
import 'package:grab_go_vendor/shared/viewmodel/vendor_preview_session_viewmodel.dart';
import 'package:provider/provider.dart';

class VendorPreviewSelectorPage extends StatelessWidget {
  final bool returnToPrevious;

  const VendorPreviewSelectorPage({super.key, this.returnToPrevious = false});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Scaffold(
      backgroundColor: colors.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: colors.backgroundPrimary,
        elevation: 0,
        automaticallyImplyLeading: returnToPrevious,
        title: Text(
          'Preview Vendor Type',
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.w800,
            color: colors.textPrimary,
          ),
        ),
      ),
      body: SafeArea(
        child: Consumer<VendorPreviewSessionViewModel>(
          builder: (context, previewSession, _) {
            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20.w, 10.h, 20.w, 24.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pick a vendor profile to preview service-specific UI before backend integration.',
                    style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w500,
                      color: colors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                  SizedBox(height: 10.h),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(12.r),
                    decoration: BoxDecoration(
                      color: colors.vendorPrimaryBlue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          color: colors.vendorPrimaryBlue,
                          size: 18.sp,
                        ),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: Text(
                            'This is UI preview mode. In production, the backend will enforce the registered vendor service type.',
                            style: TextStyle(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w600,
                              color: colors.vendorPrimaryBlue,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 14.h),
                  ...previewSession.profiles.map((profile) {
                    final selected =
                        previewSession.activeProfile.type == profile.type;
                    return _PreviewProfileCard(
                      profile: profile,
                      selected: selected,
                      onTap: () =>
                          previewSession.setActiveProfile(profile.type),
                    );
                  }),
                  SizedBox(height: 8.h),
                  SizedBox(
                    width: double.infinity,
                    child: AppButton(
                      buttonText: returnToPrevious
                          ? 'Apply Selection'
                          : 'Continue to Dashboard',
                      onPressed: () => _handleContinue(context),
                      backgroundColor: colors.vendorPrimaryBlue,
                      borderRadius: KBorderSize.borderRadius12,
                      textStyle: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14.sp,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  void _handleContinue(BuildContext context) {
    if (returnToPrevious && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
      return;
    }
    context.go('/home');
  }
}

class _PreviewProfileCard extends StatelessWidget {
  final VendorPreviewProfile profile;
  final bool selected;
  final VoidCallback onTap;

  const _PreviewProfileCard({
    required this.profile,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final accentColor = _accentColorForProfile(colors, profile.type);
    final orderedServices = profile.allowedServices.toList()
      ..sort((a, b) => a.index.compareTo(b.index));

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14.r),
      child: Container(
        width: double.infinity,
        margin: EdgeInsets.only(bottom: 10.h),
        padding: EdgeInsets.all(12.r),
        decoration: BoxDecoration(
          color: colors.backgroundPrimary,
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(
            color: selected ? accentColor : colors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42.w,
                  height: 42.w,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Icon(
                    _iconForProfile(profile.type),
                    color: accentColor,
                    size: 20.sp,
                  ),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile.title,
                        style: TextStyle(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w800,
                          color: colors.textPrimary,
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        profile.subtitle,
                        style: TextStyle(
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w600,
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (selected)
                  Icon(
                    Icons.check_circle_rounded,
                    color: accentColor,
                    size: 19.sp,
                  ),
              ],
            ),
            SizedBox(height: 10.h),
            Wrap(
              spacing: 8.w,
              runSpacing: 8.h,
              children: orderedServices.map((service) {
                final color = _serviceColor(colors, service);
                return Container(
                  padding: EdgeInsets.symmetric(horizontal: 9.w, vertical: 5.h),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999.r),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_serviceIcon(service), size: 13.sp, color: color),
                      SizedBox(width: 4.w),
                      Text(
                        _serviceLabel(service),
                        style: TextStyle(
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

Color _accentColorForProfile(
  AppColorsExtension colors,
  VendorPreviewType profileType,
) {
  return switch (profileType) {
    VendorPreviewType.restaurant => colors.serviceFood,
    VendorPreviewType.grocery => colors.serviceGrocery,
    VendorPreviewType.pharmacy => colors.servicePharmacy,
    VendorPreviewType.grabMart => colors.serviceGrabMart,
    VendorPreviewType.multiService => colors.vendorPrimaryBlue,
  };
}

IconData _iconForProfile(VendorPreviewType profileType) {
  return switch (profileType) {
    VendorPreviewType.restaurant => Icons.restaurant_rounded,
    VendorPreviewType.grocery => Icons.local_grocery_store_rounded,
    VendorPreviewType.pharmacy => Icons.local_pharmacy_outlined,
    VendorPreviewType.grabMart => Icons.shopping_bag_outlined,
    VendorPreviewType.multiService => Icons.storefront_rounded,
  };
}

IconData _serviceIcon(VendorServiceType serviceType) {
  return switch (serviceType) {
    VendorServiceType.food => Icons.restaurant_rounded,
    VendorServiceType.grocery => Icons.local_grocery_store_rounded,
    VendorServiceType.pharmacy => Icons.local_pharmacy_outlined,
    VendorServiceType.grabMart => Icons.shopping_bag_outlined,
  };
}

String _serviceLabel(VendorServiceType serviceType) {
  return switch (serviceType) {
    VendorServiceType.food => 'Food',
    VendorServiceType.grocery => 'Grocery',
    VendorServiceType.pharmacy => 'Pharmacy',
    VendorServiceType.grabMart => 'GrabMart',
  };
}

Color _serviceColor(AppColorsExtension colors, VendorServiceType serviceType) {
  return switch (serviceType) {
    VendorServiceType.food => colors.serviceFood,
    VendorServiceType.grocery => colors.serviceGrocery,
    VendorServiceType.pharmacy => colors.servicePharmacy,
    VendorServiceType.grabMart => colors.serviceGrabMart,
  };
}
