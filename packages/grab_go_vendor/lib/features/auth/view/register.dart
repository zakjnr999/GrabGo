import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:grab_go_vendor/features/auth/model/vendor_service_option.dart';
import 'package:grab_go_vendor/features/auth/viewmodel/register_viewmodel.dart';
import 'package:provider/provider.dart';

class Register extends StatelessWidget {
  const Register({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(create: (_) => RegisterViewModel(), child: const _RegisterView());
  }
}

class _RegisterView extends StatelessWidget {
  const _RegisterView();

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarDividerColor: Colors.transparent,
        systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: colors.backgroundPrimary,
        body: SafeArea(
          child: Consumer<RegisterViewModel>(
            builder: (context, viewModel, child) {
              return SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextButton.icon(
                      onPressed: () {
                        if (Navigator.of(context).canPop()) {
                          context.pop();
                        } else {
                          context.go('/login');
                        }
                      },
                      style: TextButton.styleFrom(padding: EdgeInsets.zero, foregroundColor: colors.textSecondary),
                      icon: Icon(Icons.arrow_back_rounded, size: 18.sp),
                      label: Text(
                        'Back',
                        style: TextStyle(color: colors.textSecondary, fontSize: 14.sp, fontWeight: FontWeight.w600),
                      ),
                    ),
                    SizedBox(height: 8.h),
                    _TopCard(colors: colors),
                    SizedBox(height: 20.h),
                    Text(
                      'Create your vendor account',
                      style: TextStyle(
                        fontSize: 30.sp,
                        fontWeight: FontWeight.w900,
                        color: colors.textPrimary,
                        height: 1.15,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      'Adapted from partner registration flow with full vendor verification details.',
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w500,
                        color: colors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                    SizedBox(height: 18.h),
                    _SectionCard(
                      title: 'Business Information',
                      child: Column(
                        children: [
                          AppTextInput(
                            controller: viewModel.businessNameController,
                            label: 'Business Name',
                            hintText: 'Enter your business name',
                            errorText: viewModel.businessNameError,
                            fillColor: colors.backgroundPrimary,
                            borderColor: colors.inputBorder,
                            borderActiveColor: colors.vendorPrimaryBlue,
                            borderRadius: KBorderSize.borderRadius12,
                            cursorColor: colors.vendorPrimaryBlue,
                            prefixIcon: const Icon(Icons.storefront_rounded),
                          ),
                          SizedBox(height: 12.h),
                          AppTextInput(
                            controller: viewModel.businessEmailController,
                            label: 'Business Email',
                            hintText: 'vendor@example.com',
                            keyboardType: TextInputType.emailAddress,
                            errorText: viewModel.businessEmailError,
                            fillColor: colors.backgroundPrimary,
                            borderColor: colors.inputBorder,
                            borderActiveColor: colors.vendorPrimaryBlue,
                            borderRadius: KBorderSize.borderRadius12,
                            cursorColor: colors.vendorPrimaryBlue,
                            prefixIcon: const Icon(Icons.mail_outline_rounded),
                          ),
                          SizedBox(height: 12.h),
                          AppTextInput(
                            controller: viewModel.businessPhoneController,
                            label: 'Business Phone',
                            hintText: 'Enter business phone number',
                            keyboardType: TextInputType.phone,
                            errorText: viewModel.businessPhoneError,
                            fillColor: colors.backgroundPrimary,
                            borderColor: colors.inputBorder,
                            borderActiveColor: colors.vendorPrimaryBlue,
                            borderRadius: KBorderSize.borderRadius12,
                            cursorColor: colors.vendorPrimaryBlue,
                            prefixIcon: const Icon(Icons.call_outlined),
                          ),
                          SizedBox(height: 12.h),
                          AppTextInput(
                            controller: viewModel.businessAddressController,
                            label: 'Business Address',
                            hintText: 'Enter your business location',
                            keyboardType: TextInputType.streetAddress,
                            errorText: viewModel.businessAddressError,
                            fillColor: colors.backgroundPrimary,
                            borderColor: colors.inputBorder,
                            borderActiveColor: colors.vendorPrimaryBlue,
                            borderRadius: KBorderSize.borderRadius12,
                            cursorColor: colors.vendorPrimaryBlue,
                            prefixIcon: const Icon(Icons.location_on_outlined),
                          ),
                          SizedBox(height: 12.h),
                          AppTextInput(
                            controller: viewModel.businessIdController,
                            label: 'Business ID',
                            hintText: 'Enter registration/license number',
                            keyboardType: TextInputType.text,
                            errorText: viewModel.businessIdError,
                            fillColor: colors.backgroundPrimary,
                            borderColor: colors.inputBorder,
                            borderActiveColor: colors.vendorPrimaryBlue,
                            borderRadius: KBorderSize.borderRadius12,
                            cursorColor: colors.vendorPrimaryBlue,
                            prefixIcon: const Icon(Icons.badge_outlined),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 16.h),
                    _SectionCard(
                      title: 'Owner Information',
                      child: Column(
                        children: [
                          AppTextInput(
                            controller: viewModel.ownerNameController,
                            label: 'Owner Full Name',
                            hintText: 'Enter legal full name',
                            errorText: viewModel.ownerNameError,
                            fillColor: colors.backgroundPrimary,
                            borderColor: colors.inputBorder,
                            borderActiveColor: colors.vendorPrimaryBlue,
                            borderRadius: KBorderSize.borderRadius12,
                            cursorColor: colors.vendorPrimaryBlue,
                            prefixIcon: const Icon(Icons.person_outline_rounded),
                          ),
                          SizedBox(height: 12.h),
                          AppTextInput(
                            controller: viewModel.ownerPhoneController,
                            label: 'Owner Phone',
                            hintText: 'Enter owner phone number',
                            keyboardType: TextInputType.phone,
                            errorText: viewModel.ownerPhoneError,
                            fillColor: colors.backgroundPrimary,
                            borderColor: colors.inputBorder,
                            borderActiveColor: colors.vendorPrimaryBlue,
                            borderRadius: KBorderSize.borderRadius12,
                            cursorColor: colors.vendorPrimaryBlue,
                            prefixIcon: const Icon(Icons.call_outlined),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 16.h),
                    _SectionCard(
                      title: 'Services You Offer',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8.w,
                            runSpacing: 8.h,
                            children: vendorServiceOptions.map((option) {
                              final isSelected = viewModel.selectedServices.contains(option.type);
                              final serviceColor = _serviceColorForType(colors, option.type);
                              return _ServiceOptionChip(
                                label: option.label,
                                icon: option.icon,
                                color: serviceColor,
                                selected: isSelected,
                                onTap: () => viewModel.toggleService(option.type),
                              );
                            }).toList(),
                          ),
                          if (viewModel.serviceError != null) ...[
                            SizedBox(height: 8.h),
                            Text(
                              viewModel.serviceError!,
                              style: TextStyle(fontSize: 11.sp, color: colors.error, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ],
                      ),
                    ),
                    SizedBox(height: 16.h),
                    _SectionCard(
                      title: 'Verification Documents',
                      child: Column(
                        children: [
                          ImageUploadWidget(
                            label: 'Business Logo',
                            hintText: 'Tap to upload logo',
                            initialImage: viewModel.businessLogoImage,
                            onImageSelected: viewModel.setBusinessLogoImage,
                            successMessage: 'Business logo uploaded successfully',
                          ),
                          if (viewModel.businessLogoImageError != null)
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Padding(
                                padding: EdgeInsets.only(top: 6.h, left: 4.w),
                                child: Text(
                                  viewModel.businessLogoImageError!,
                                  style: TextStyle(fontSize: 11.sp, color: colors.error, fontWeight: FontWeight.w500),
                                ),
                              ),
                            ),
                          SizedBox(height: 12.h),
                          ImageUploadWidget(
                            label: 'Business ID Document',
                            hintText: 'Tap to upload ID document',
                            initialImage: viewModel.businessIdImage,
                            onImageSelected: viewModel.setBusinessIdImage,
                            successMessage: 'Business ID uploaded successfully',
                          ),
                          if (viewModel.businessIdImageError != null)
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Padding(
                                padding: EdgeInsets.only(top: 6.h, left: 4.w),
                                child: Text(
                                  viewModel.businessIdImageError!,
                                  style: TextStyle(fontSize: 11.sp, color: colors.error, fontWeight: FontWeight.w500),
                                ),
                              ),
                            ),
                          SizedBox(height: 12.h),
                          ImageUploadWidget(
                            label: 'Owner Verification Photo',
                            hintText: 'Tap to upload owner photo',
                            initialImage: viewModel.ownerPhotoImage,
                            onImageSelected: viewModel.setOwnerPhotoImage,
                            successMessage: 'Owner photo uploaded successfully',
                          ),
                          if (viewModel.ownerPhotoImageError != null)
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Padding(
                                padding: EdgeInsets.only(top: 6.h, left: 4.w),
                                child: Text(
                                  viewModel.ownerPhotoImageError!,
                                  style: TextStyle(fontSize: 11.sp, color: colors.error, fontWeight: FontWeight.w500),
                                ),
                              ),
                            ),
                          SizedBox(height: 12.h),
                          ImageUploadWidget(
                            label: 'Additional Supporting Document',
                            hintText: 'Optional document upload',
                            initialImage: viewModel.additionalDocumentImage,
                            onImageSelected: viewModel.setAdditionalDocumentImage,
                            successMessage: 'Additional document uploaded',
                          ),
                          SizedBox(height: 10.h),
                          Container(
                            width: double.infinity,
                            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                            decoration: BoxDecoration(
                              color: colors.vendorPrimaryBlue.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(10.r),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.shield_outlined, size: 16.sp, color: colors.vendorPrimaryBlue),
                                SizedBox(width: 8.w),
                                Expanded(
                                  child: Text(
                                    'These documents are used only for secure business verification before approval.',
                                    style: TextStyle(
                                      fontSize: 12.sp,
                                      fontWeight: FontWeight.w500,
                                      color: colors.textSecondary,
                                      height: 1.35,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 16.h),
                    _SectionCard(
                      title: 'Security',
                      child: Column(
                        children: [
                          AppTextInput(
                            controller: viewModel.passwordController,
                            label: 'Password',
                            hintText: 'Minimum 8 characters',
                            obscureText: !viewModel.isPasswordVisible,
                            errorText: viewModel.passwordError,
                            fillColor: colors.backgroundPrimary,
                            borderColor: colors.inputBorder,
                            borderActiveColor: colors.vendorPrimaryBlue,
                            borderRadius: KBorderSize.borderRadius12,
                            cursorColor: colors.vendorPrimaryBlue,
                            prefixIcon: const Icon(Icons.lock_outline_rounded),
                            suffixIcon: IconButton(
                              onPressed: viewModel.togglePasswordVisibility,
                              icon: Icon(
                                viewModel.isPasswordVisible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                size: 18.sp,
                                color: colors.iconSecondary,
                              ),
                            ),
                          ),
                          SizedBox(height: 12.h),
                          AppTextInput(
                            controller: viewModel.confirmPasswordController,
                            label: 'Confirm Password',
                            hintText: 'Re-enter password',
                            obscureText: !viewModel.isConfirmPasswordVisible,
                            errorText: viewModel.confirmPasswordError,
                            fillColor: colors.backgroundPrimary,
                            borderColor: colors.inputBorder,
                            borderActiveColor: colors.vendorPrimaryBlue,
                            borderRadius: KBorderSize.borderRadius12,
                            cursorColor: colors.vendorPrimaryBlue,
                            prefixIcon: const Icon(Icons.lock_outline_rounded),
                            suffixIcon: IconButton(
                              onPressed: viewModel.toggleConfirmPasswordVisibility,
                              icon: Icon(
                                viewModel.isConfirmPasswordVisible
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                size: 18.sp,
                                color: colors.iconSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 12.h),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Checkbox(
                          value: viewModel.termsAccepted,
                          onChanged: viewModel.toggleTermsAccepted,
                          activeColor: colors.vendorPrimaryBlue,
                          side: BorderSide(color: colors.inputBorder),
                        ),
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(top: 13.h),
                            child: Text(
                              'I agree to GrabGo vendor terms and onboarding verification requirements.',
                              style: TextStyle(
                                fontSize: 12.sp,
                                color: colors.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (viewModel.termsError != null)
                      Padding(
                        padding: EdgeInsets.only(left: 12.w),
                        child: Text(
                          viewModel.termsError!,
                          style: TextStyle(fontSize: 11.sp, color: colors.error, fontWeight: FontWeight.w500),
                        ),
                      ),
                    SizedBox(height: 16.h),
                    SizedBox(
                      width: double.infinity,
                      child: AppButton(
                        buttonText: 'Create Account',
                        onPressed: () => _handleSubmit(context, viewModel),
                        backgroundColor: colors.vendorPrimaryBlue,
                        borderRadius: KBorderSize.borderRadius12,
                        textStyle: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15.sp),
                      ),
                    ),
                    SizedBox(height: 10.h),
                    Center(
                      child: Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            'Already have an account? ',
                            style: TextStyle(fontSize: 13.sp, color: colors.textSecondary, fontWeight: FontWeight.w500),
                          ),
                          TextButton(
                            onPressed: () => context.go('/login'),
                            style: TextButton.styleFrom(
                              foregroundColor: colors.vendorPrimaryBlue,
                              padding: EdgeInsets.symmetric(horizontal: 4.w),
                              minimumSize: Size(0, 24.h),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(
                              'Login',
                              style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Color _serviceColorForType(AppColorsExtension colors, VendorServiceType type) {
    switch (type) {
      case VendorServiceType.food:
        return colors.serviceFood;
      case VendorServiceType.grocery:
        return colors.serviceGrocery;
      case VendorServiceType.pharmacy:
        return colors.servicePharmacy;
      case VendorServiceType.grabMart:
        return colors.serviceGrabMart;
    }
  }

  void _handleSubmit(BuildContext context, RegisterViewModel viewModel) {
    HapticFeedback.selectionClick();
    if (!viewModel.validate()) return;
    context.go(
      '/otpVerification',
      extra: {'channel': 'Email', 'destination': viewModel.businessEmailController.text.trim()},
    );
  }
}

class _TopCard extends StatelessWidget {
  final AppColorsExtension colors;

  const _TopCard({required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
      decoration: BoxDecoration(
        color: colors.backgroundSecondary,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: colors.inputBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 48.w,
            height: 48.w,
            decoration: BoxDecoration(
              color: colors.vendorPrimaryBlue.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Center(
              child: SvgPicture.asset(
                Assets.icons.store,
                package: 'grab_go_shared',
                width: 24.w,
                height: 24.w,
                colorFilter: ColorFilter.mode(colors.vendorPrimaryBlue, BlendMode.srcIn),
              ),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Vendor Registration',
                  style: TextStyle(fontSize: 17.sp, fontWeight: FontWeight.w800, color: colors.textPrimary),
                ),
                SizedBox(height: 3.h),
                Text(
                  'Set up your business profile to start onboarding',
                  style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w500, color: colors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w700, color: colors.textPrimary),
        ),
        SizedBox(height: 10.h),
        child,
      ],
    );
  }
}

class _ServiceOptionChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _ServiceOptionChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(100.r),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.16) : Colors.transparent,
          borderRadius: BorderRadius.circular(100.r),
          border: Border.all(color: selected ? color : context.appColors.inputBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16.sp, color: selected ? color : context.appColors.iconSecondary),
            SizedBox(width: 6.w),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.w700,
                color: selected ? color : context.appColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
