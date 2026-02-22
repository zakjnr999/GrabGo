import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:grab_go_vendor/features/profile/model/vendor_profile_models.dart';
import 'package:grab_go_vendor/features/profile/viewmodel/profile_security_viewmodel.dart';
import 'package:provider/provider.dart';

class ProfileSecurityPage extends StatelessWidget {
  const ProfileSecurityPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ProfileSecurityViewModel(),
      child: const _ProfileSecurityView(),
    );
  }
}

class _ProfileSecurityView extends StatelessWidget {
  const _ProfileSecurityView();

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Consumer<ProfileSecurityViewModel>(
      builder: (context, viewModel, _) {
        return Scaffold(
          backgroundColor: colors.backgroundPrimary,
          appBar: AppBar(
            backgroundColor: colors.backgroundPrimary,
            elevation: 0,
            title: Text(
              'Profile & Security',
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.w800,
                color: colors.textPrimary,
              ),
            ),
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 24.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Manage account profile, password, and active sessions.',
                    style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w500,
                      color: colors.textSecondary,
                    ),
                  ),
                  SizedBox(height: 12.h),
                  _SectionCard(
                    title: 'Business Profile',
                    child: Column(
                      children: [
                        AppTextInput(
                          controller: viewModel.businessNameController,
                          label: 'Business Name',
                          hintText: 'Enter business name',
                          errorText: viewModel.businessNameError,
                          fillColor: colors.backgroundPrimary,
                          borderColor: colors.inputBorder,
                          borderActiveColor: colors.vendorPrimaryBlue,
                          borderRadius: KBorderSize.borderRadius12,
                          cursorColor: colors.vendorPrimaryBlue,
                        ),
                        SizedBox(height: 10.h),
                        AppTextInput(
                          controller: viewModel.ownerNameController,
                          label: 'Owner Name',
                          hintText: 'Enter owner name',
                          errorText: viewModel.ownerNameError,
                          fillColor: colors.backgroundPrimary,
                          borderColor: colors.inputBorder,
                          borderActiveColor: colors.vendorPrimaryBlue,
                          borderRadius: KBorderSize.borderRadius12,
                          cursorColor: colors.vendorPrimaryBlue,
                        ),
                        SizedBox(height: 10.h),
                        AppTextInput(
                          controller: viewModel.businessEmailController,
                          label: 'Business Email',
                          hintText: 'Enter business email',
                          keyboardType: TextInputType.emailAddress,
                          errorText: viewModel.businessEmailError,
                          fillColor: colors.backgroundPrimary,
                          borderColor: colors.inputBorder,
                          borderActiveColor: colors.vendorPrimaryBlue,
                          borderRadius: KBorderSize.borderRadius12,
                          cursorColor: colors.vendorPrimaryBlue,
                        ),
                        SizedBox(height: 10.h),
                        AppTextInput(
                          controller: viewModel.phoneController,
                          label: 'Phone Number',
                          hintText: 'Enter contact number',
                          keyboardType: TextInputType.phone,
                          errorText: viewModel.phoneError,
                          fillColor: colors.backgroundPrimary,
                          borderColor: colors.inputBorder,
                          borderActiveColor: colors.vendorPrimaryBlue,
                          borderRadius: KBorderSize.borderRadius12,
                          cursorColor: colors.vendorPrimaryBlue,
                        ),
                        SizedBox(height: 10.h),
                        AppTextInput(
                          controller: viewModel.addressController,
                          label: 'Business Address',
                          hintText: 'Enter branch address',
                          errorText: viewModel.addressError,
                          fillColor: colors.backgroundPrimary,
                          borderColor: colors.inputBorder,
                          borderActiveColor: colors.vendorPrimaryBlue,
                          borderRadius: KBorderSize.borderRadius12,
                          cursorColor: colors.vendorPrimaryBlue,
                        ),
                        SizedBox(height: 12.h),
                        SizedBox(
                          width: double.infinity,
                          child: AppButton(
                            buttonText: 'Save Profile',
                            onPressed: () => _saveProfile(context, viewModel),
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
                  SizedBox(height: 12.h),
                  _SectionCard(
                    title: 'Security Controls',
                    child: Column(
                      children: [
                        _SwitchRow(
                          title: 'Two-Factor Verification',
                          subtitle:
                              'Require OTP verification during login attempts.',
                          value: viewModel.twoFactorEnabled,
                          onChanged: viewModel.setTwoFactorEnabled,
                        ),
                        _SwitchRow(
                          title: 'Biometric Unlock',
                          subtitle:
                              'Allow fingerprint/face unlock where available.',
                          value: viewModel.biometricEnabled,
                          onChanged: viewModel.setBiometricEnabled,
                        ),
                        _SwitchRow(
                          title: 'OTP for Sensitive Actions',
                          subtitle:
                              'Require OTP for staff edits, payouts, and policy changes.',
                          value: viewModel.otpForSensitiveActions,
                          onChanged: viewModel.setOtpForSensitiveActions,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 12.h),
                  _SectionCard(
                    title: 'Change Password',
                    child: Column(
                      children: [
                        AppTextInput(
                          controller: viewModel.currentPasswordController,
                          label: 'Current Password',
                          hintText: 'Enter current password',
                          obscureText: viewModel.hideCurrentPassword,
                          errorText: viewModel.currentPasswordError,
                          fillColor: colors.backgroundPrimary,
                          borderColor: colors.inputBorder,
                          borderActiveColor: colors.vendorPrimaryBlue,
                          borderRadius: KBorderSize.borderRadius12,
                          cursorColor: colors.vendorPrimaryBlue,
                          suffixIcon: IconButton(
                            onPressed:
                                viewModel.toggleCurrentPasswordVisibility,
                            icon: Icon(
                              viewModel.hideCurrentPassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
                        ),
                        SizedBox(height: 10.h),
                        AppTextInput(
                          controller: viewModel.newPasswordController,
                          label: 'New Password',
                          hintText: 'Minimum 8 characters',
                          obscureText: viewModel.hideNewPassword,
                          errorText: viewModel.newPasswordError,
                          fillColor: colors.backgroundPrimary,
                          borderColor: colors.inputBorder,
                          borderActiveColor: colors.vendorPrimaryBlue,
                          borderRadius: KBorderSize.borderRadius12,
                          cursorColor: colors.vendorPrimaryBlue,
                          suffixIcon: IconButton(
                            onPressed: viewModel.toggleNewPasswordVisibility,
                            icon: Icon(
                              viewModel.hideNewPassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
                        ),
                        SizedBox(height: 10.h),
                        AppTextInput(
                          controller: viewModel.confirmPasswordController,
                          label: 'Confirm New Password',
                          hintText: 'Re-enter new password',
                          obscureText: viewModel.hideConfirmPassword,
                          errorText: viewModel.confirmPasswordError,
                          fillColor: colors.backgroundPrimary,
                          borderColor: colors.inputBorder,
                          borderActiveColor: colors.vendorPrimaryBlue,
                          borderRadius: KBorderSize.borderRadius12,
                          cursorColor: colors.vendorPrimaryBlue,
                          suffixIcon: IconButton(
                            onPressed:
                                viewModel.toggleConfirmPasswordVisibility,
                            icon: Icon(
                              viewModel.hideConfirmPassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
                        ),
                        SizedBox(height: 12.h),
                        SizedBox(
                          width: double.infinity,
                          child: AppButton(
                            buttonText: 'Update Password',
                            onPressed: () =>
                                _updatePassword(context, viewModel),
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
                  SizedBox(height: 12.h),
                  _SectionCard(
                    title: 'Active Sessions',
                    child: Column(
                      children: [
                        ...viewModel.sessions.map((session) {
                          return _SessionCard(
                            session: session,
                            onTerminate: session.isCurrent
                                ? null
                                : () => _terminateSession(context, session.id),
                          );
                        }),
                        SizedBox(height: 8.h),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: viewModel.hasOtherSessions
                                ? () => _terminateOtherSessions(context)
                                : null,
                            icon: Icon(Icons.logout_rounded, size: 16.sp),
                            label: Text(
                              'Sign out other devices',
                              style: TextStyle(
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: colors.error,
                              disabledForegroundColor: colors.textSecondary,
                              side: BorderSide(
                                color: viewModel.hasOtherSessions
                                    ? colors.error.withValues(alpha: 0.4)
                                    : colors.inputBorder,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10.r),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 12.h),
                  _SectionCard(
                    title: 'Danger Zone',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'This signs out the current session on this device.',
                          style: TextStyle(
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w600,
                            color: colors.textSecondary,
                          ),
                        ),
                        SizedBox(height: 10.h),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () => _showSignOutHint(context),
                            icon: Icon(
                              Icons.logout_rounded,
                              color: colors.error,
                              size: 16.sp,
                            ),
                            label: Text(
                              'Sign Out',
                              style: TextStyle(
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w700,
                                color: colors.error,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(
                                color: colors.error.withValues(alpha: 0.4),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10.r),
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
          ),
        );
      },
    );
  }

  void _saveProfile(BuildContext context, ProfileSecurityViewModel viewModel) {
    if (!viewModel.validateProfileForm()) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile saved (UI preview only).')),
    );
  }

  void _updatePassword(
    BuildContext context,
    ProfileSecurityViewModel viewModel,
  ) {
    if (!viewModel.validatePasswordForm()) return;
    viewModel.clearPasswordForm();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Password updated (UI preview only).')),
    );
  }

  void _terminateSession(BuildContext context, String sessionId) {
    context.read<ProfileSecurityViewModel>().revokeSession(sessionId);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Session ended.')));
  }

  void _terminateOtherSessions(BuildContext context) {
    context.read<ProfileSecurityViewModel>().revokeOtherSessions();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Other sessions have been signed out.')),
    );
  }

  void _showSignOutHint(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sign-out flow will be connected to auth.')),
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
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(14.r),
      decoration: BoxDecoration(
        color: colors.backgroundPrimary,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w800,
              color: colors.textPrimary,
            ),
          ),
          SizedBox(height: 10.h),
          child,
        ],
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Padding(
      padding: EdgeInsets.only(bottom: 10.h),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w500,
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          CustomSwitch(
            value: value,
            onChanged: onChanged,
            activeColor: colors.vendorPrimaryBlue,
            inactiveColor: colors.inputBorder,
            thumbColor: colors.backgroundPrimary,
          ),
        ],
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  final VendorSessionDevice session;
  final VoidCallback? onTerminate;

  const _SessionCard({required this.session, required this.onTerminate});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: 10.h),
      padding: EdgeInsets.all(12.r),
      decoration: BoxDecoration(
        color: colors.backgroundPrimary,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                session.isCurrent
                    ? Icons.smartphone_rounded
                    : Icons.devices_other_rounded,
                size: 20.sp,
                color: session.isCurrent
                    ? colors.vendorPrimaryBlue
                    : colors.textSecondary,
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(
                  session.deviceName,
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 3.h),
                decoration: BoxDecoration(
                  color: (session.isCurrent ? colors.success : colors.warning)
                      .withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999.r),
                ),
                child: Text(
                  session.isCurrent ? 'Current' : 'Active',
                  style: TextStyle(
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w700,
                    color: session.isCurrent ? colors.success : colors.warning,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${session.location} • ${session.lastActiveLabel}',
                  style: TextStyle(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w600,
                    color: colors.textSecondary,
                  ),
                ),
              ),
              TextButton(
                onPressed: onTerminate,
                child: Text(
                  session.isCurrent ? 'This device' : 'Terminate',
                  style: TextStyle(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w700,
                    color: session.isCurrent
                        ? colors.textSecondary
                        : colors.error,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
