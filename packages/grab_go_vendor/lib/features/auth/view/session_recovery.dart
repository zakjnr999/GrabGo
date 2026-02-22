import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:grab_go_vendor/features/auth/view/widgets/auth_entrance.dart';
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
      body: SafeArea(
        child: Consumer<SessionRecoveryViewModel>(
          builder: (context, viewModel, _) {
            return Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 430.w),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20.w),
                  child: Column(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          padding: EdgeInsets.only(top: 12.h, bottom: 12.h),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AuthEntrance(
                                delay: const Duration(milliseconds: 20),
                                child: TextButton.icon(
                                  onPressed: () =>
                                      context.pushReplacement('/login'),
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    foregroundColor: colors.textSecondary,
                                  ),
                                  icon: SvgPicture.asset(
                                    Assets.icons.navArrowLeft,
                                    package: 'grab_go_shared',
                                    width: 18.w,
                                    height: 18.w,
                                    colorFilter: ColorFilter.mode(
                                      colors.textSecondary,
                                      BlendMode.srcIn,
                                    ),
                                  ),
                                  label: Text(
                                    'Back',
                                    style: TextStyle(
                                      color: colors.textSecondary,
                                      fontSize: 14.sp,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(height: 6.h),
                              AuthEntrance(
                                delay: const Duration(milliseconds: 50),
                                child: Text(
                                  'Session Recovery',
                                  style: TextStyle(
                                    fontSize: 30.sp,
                                    fontWeight: FontWeight.w900,
                                    color: colors.textPrimary,
                                    height: 1.15,
                                  ),
                                ),
                              ),
                              SizedBox(height: 8.h),
                              AuthEntrance(
                                delay: const Duration(milliseconds: 90),
                                child: Text(
                                  'Recover vendor account access if you cannot log in from your usual device.',
                                  style: TextStyle(
                                    fontSize: 13.sp,
                                    fontWeight: FontWeight.w500,
                                    color: colors.textSecondary,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                              SizedBox(height: 12.h),
                              AuthEntrance(
                                delay: const Duration(milliseconds: 130),
                                child: Container(
                                  width: double.infinity,
                                  padding: EdgeInsets.all(12.r),
                                  decoration: BoxDecoration(
                                    color: colors.vendorPrimaryBlue.withValues(
                                      alpha: 0.1,
                                    ),
                                    borderRadius: BorderRadius.circular(12.r),
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      SvgPicture.asset(
                                        Assets.icons.shieldCheck,
                                        package: 'grab_go_shared',
                                        width: KIconSize.md,
                                        height: KIconSize.md,
                                        colorFilter: ColorFilter.mode(
                                          colors.vendorPrimaryBlue,
                                          BlendMode.srcIn,
                                        ),
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
                              ),
                              SizedBox(height: 14.h),
                              AuthEntrance(
                                delay: const Duration(milliseconds: 170),
                                child: AppTextInput(
                                  controller: viewModel.accountController,
                                  label: 'Business Email or Phone',
                                  hintText: 'vendor@example.com or +233...',
                                  keyboardType: TextInputType.emailAddress,
                                  errorText: viewModel.accountError,
                                  fillColor: colors.backgroundSecondary,
                                  borderColor: colors.inputBorder,
                                  borderActiveColor: colors.vendorPrimaryBlue,
                                  borderRadius: KBorderSize.border,
                                  cursorColor: colors.vendorPrimaryBlue,
                                ),
                              ),
                              SizedBox(height: 12.h),
                              AuthEntrance(
                                delay: const Duration(milliseconds: 210),
                                child: Text(
                                  'Recovery Method',
                                  style: TextStyle(
                                    fontSize: 12.sp,
                                    fontWeight: FontWeight.w700,
                                    color: colors.textPrimary,
                                  ),
                                ),
                              ),
                              SizedBox(height: 8.h),
                              AuthEntrance(
                                delay: const Duration(milliseconds: 250),
                                child: _MethodTile(
                                  icon: Assets.icons.mail,
                                  title: 'Email Recovery Link',
                                  subtitle:
                                      'Receive a secure reset link in inbox.',
                                  selected:
                                      viewModel.method ==
                                      SessionRecoveryMethod.emailLink,
                                  onTap: () => viewModel.setMethod(
                                    SessionRecoveryMethod.emailLink,
                                  ),
                                ),
                              ),
                              AuthEntrance(
                                delay: const Duration(milliseconds: 290),
                                child: _MethodTile(
                                  icon: Assets.icons.lock,
                                  title: 'OTP Verification',
                                  subtitle:
                                      'Receive one-time code for account recovery.',
                                  selected:
                                      viewModel.method ==
                                      SessionRecoveryMethod.otpCode,
                                  onTap: () => viewModel.setMethod(
                                    SessionRecoveryMethod.otpCode,
                                  ),
                                ),
                              ),
                              AuthEntrance(
                                delay: const Duration(milliseconds: 330),
                                child: Padding(
                                  padding: EdgeInsets.symmetric(vertical: 6.h),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Secure all active sessions',
                                              style: TextStyle(
                                                fontSize: 13.sp,
                                                fontWeight: FontWeight.w700,
                                                color: colors.textPrimary,
                                              ),
                                            ),
                                            SizedBox(height: 2.h),
                                            Text(
                                              'Sign out previously active devices after recovery.',
                                              style: TextStyle(
                                                fontSize: 11.sp,
                                                fontWeight: FontWeight.w500,
                                                color: colors.textSecondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      SizedBox(width: 12.w),
                                      CustomSwitch(
                                        value: viewModel.secureAllSessions,
                                        onChanged:
                                            viewModel.setSecureAllSessions,
                                        activeColor: colors.vendorPrimaryBlue,
                                        inactiveColor: colors.inputBorder,
                                        thumbColor: colors.backgroundPrimary,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.only(bottom: 12.h),
                        child: AuthEntrance(
                          delay: const Duration(milliseconds: 370),
                          child: SizedBox(
                            width: double.infinity,
                            child: AppButton(
                              buttonText:
                                  viewModel.method ==
                                      SessionRecoveryMethod.emailLink
                                  ? 'Send Recovery Link'
                                  : 'Send OTP Code',
                              onPressed: () => _submit(context, viewModel),
                              backgroundColor: colors.vendorPrimaryBlue,
                              borderRadius: KBorderSize.border,
                              textStyle: TextStyle(
                                color: Colors.white,
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
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
  final String icon;
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
              padding: EdgeInsets.all(10.r),
              decoration: BoxDecoration(
                color: colors.vendorPrimaryBlue.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: SvgPicture.asset(
                icon,
                package: 'grab_go_shared',
                width: 18,
                height: 18,
                colorFilter: ColorFilter.mode(
                  colors.vendorPrimaryBlue,
                  BlendMode.srcIn,
                ),
              ),
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
            selected
                ? SvgPicture.asset(
                    Assets.icons.check,
                    package: 'grab_go_shared',
                    width: 18.w,
                    height: 18.w,
                    colorFilter: ColorFilter.mode(
                      selected
                          ? colors.vendorPrimaryBlue
                          : colors.textSecondary,
                      BlendMode.srcIn,
                    ),
                  )
                : SizedBox.shrink(),
            // Icon(
            //   selected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
            //   color: selected ? colors.vendorPrimaryBlue : colors.textSecondary,
            //   size: 18.sp,
            // ),
          ],
        ),
      ),
    );
  }
}
