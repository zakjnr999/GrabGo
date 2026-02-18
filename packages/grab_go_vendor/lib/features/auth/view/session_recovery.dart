import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:grab_go_vendor/features/auth/viewmodel/session_recovery_viewmodel.dart';
import 'package:provider/provider.dart';

class SessionRecoveryPage extends StatelessWidget {
  const SessionRecoveryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => SessionRecoveryViewModel(),
      child: const _SessionRecoveryView(),
    );
  }
}

class _SessionRecoveryView extends StatelessWidget {
  const _SessionRecoveryView();

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Scaffold(
      backgroundColor: colors.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: colors.backgroundPrimary,
        elevation: 0,
        title: Text(
          'Session Recovery',
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.w800,
            color: colors.textPrimary,
          ),
        ),
      ),
      body: SafeArea(
        child: Consumer<SessionRecoveryViewModel>(
          builder: (context, viewModel, _) {
            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 24.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Recover vendor account access if you cannot log in from your usual device.',
                    style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w500,
                      color: colors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                  SizedBox(height: 12.h),
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
                          Icons.security_rounded,
                          color: colors.vendorPrimaryBlue,
                          size: 18.sp,
                        ),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: Text(
                            'Use your business email or verified phone to send a secure recovery request.',
                            style: TextStyle(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w600,
                              color: colors.vendorPrimaryBlue,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 14.h),
                  AppTextInput(
                    controller: viewModel.accountController,
                    label: 'Business Email or Phone',
                    hintText: 'vendor@example.com or +233...',
                    keyboardType: TextInputType.emailAddress,
                    errorText: viewModel.accountError,
                    fillColor: colors.backgroundPrimary,
                    borderColor: colors.inputBorder,
                    borderActiveColor: colors.vendorPrimaryBlue,
                    borderRadius: KBorderSize.borderRadius12,
                    cursorColor: colors.vendorPrimaryBlue,
                    prefixIcon: const Icon(Icons.alternate_email_rounded),
                  ),
                  SizedBox(height: 12.h),
                  Text(
                    'Recovery Method',
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  _MethodTile(
                    icon: Icons.mark_email_unread_outlined,
                    title: 'Email Recovery Link',
                    subtitle: 'Receive a secure reset link in inbox.',
                    selected:
                        viewModel.method == SessionRecoveryMethod.emailLink,
                    onTap: () =>
                        viewModel.setMethod(SessionRecoveryMethod.emailLink),
                  ),
                  _MethodTile(
                    icon: Icons.pin_outlined,
                    title: 'OTP Verification',
                    subtitle: 'Receive one-time code for account recovery.',
                    selected: viewModel.method == SessionRecoveryMethod.otpCode,
                    onTap: () =>
                        viewModel.setMethod(SessionRecoveryMethod.otpCode),
                  ),
                  SizedBox(height: 8.h),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: viewModel.secureAllSessions,
                    onChanged: viewModel.setSecureAllSessions,
                    activeTrackColor: colors.vendorPrimaryBlue,
                    title: Text(
                      'Secure all active sessions',
                      style: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary,
                      ),
                    ),
                    subtitle: Text(
                      'Sign out previously active devices after recovery.',
                      style: TextStyle(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w500,
                        color: colors.textSecondary,
                      ),
                    ),
                  ),
                  SizedBox(height: 10.h),
                  SizedBox(
                    width: double.infinity,
                    child: AppButton(
                      buttonText:
                          viewModel.method == SessionRecoveryMethod.emailLink
                          ? 'Send Recovery Link'
                          : 'Send OTP Code',
                      onPressed: () => _submit(context, viewModel),
                      backgroundColor: colors.vendorPrimaryBlue,
                      borderRadius: KBorderSize.borderRadius12,
                      textStyle: TextStyle(
                        color: Colors.white,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => context.go('/login'),
                      child: Text(
                        'Back to Login',
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w700,
                          color: colors.vendorPrimaryBlue,
                        ),
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

  void _submit(BuildContext context, SessionRecoveryViewModel viewModel) {
    final valid = viewModel.validate();
    if (!valid) {
      return;
    }

    final method = viewModel.method == SessionRecoveryMethod.emailLink
        ? 'Recovery link'
        : 'OTP code';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$method sent to ${viewModel.accountController.text.trim()} (UI preview).',
        ),
      ),
    );
  }
}

class _MethodTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _MethodTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12.r),
      child: Container(
        width: double.infinity,
        margin: EdgeInsets.only(bottom: 8.h),
        padding: EdgeInsets.all(10.r),
        decoration: BoxDecoration(
          color: colors.backgroundPrimary,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color: selected ? colors.vendorPrimaryBlue : colors.border,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40.w,
              height: 40.w,
              decoration: BoxDecoration(
                color: colors.vendorPrimaryBlue.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: Icon(icon, color: colors.vendorPrimaryBlue, size: 19.sp),
            ),
            SizedBox(width: 9.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12.sp,
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
            Icon(
              selected
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: selected ? colors.vendorPrimaryBlue : colors.textSecondary,
              size: 18.sp,
            ),
          ],
        ),
      ),
    );
  }
}
