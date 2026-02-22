import 'package:go_router/go_router.dart';
import 'package:grab_go_vendor/core/view/splash_screen.dart';
import 'package:grab_go_vendor/features/auth/view/forgot_password.dart';
import 'package:grab_go_vendor/features/auth/view/login.dart';
import 'package:grab_go_vendor/features/auth/view/otp_verification.dart';
import 'package:grab_go_vendor/features/auth/view/reset_password.dart';
import 'package:grab_go_vendor/features/auth/view/session_recovery.dart';
import 'package:grab_go_vendor/features/auth/view/vendor_preview_selector.dart';
import 'package:grab_go_vendor/features/onboarding/view/onboarding_main.dart';
import 'package:grab_go_vendor/features/onboarding/view/onboarding_setup_shell.dart';
import 'package:grab_go_vendor/shared/widgets/bottom_navigation.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: "/",
  routes: [
    GoRoute(path: "/", builder: (context, state) => const SplashScreen()),
    GoRoute(
      path: "/onboarding",
      builder: (context, state) => const OnboardingMain(),
    ),
    GoRoute(
      path: "/onboardingGuide",
      builder: (context, state) {
        final data = state.extra;
        final replayMode = switch (data) {
          Map<String, dynamic>() => (data['replayMode'] as bool?) ?? false,
          bool() => data,
          _ => false,
        };
        return OnboardingSetupShell(isReplayMode: replayMode);
      },
    ),
    GoRoute(path: "/login", builder: (context, state) => const Login()),
    GoRoute(
      path: "/sessionRecovery",
      builder: (context, state) => const SessionRecoveryPage(),
    ),
    GoRoute(
      path: "/vendorPreview",
      builder: (context, state) {
        final data = state.extra;
        final returnToPrevious = switch (data) {
          Map<String, dynamic>() =>
            (data['returnToPrevious'] as bool?) ?? false,
          bool() => data,
          _ => false,
        };
        return VendorPreviewSelectorPage(returnToPrevious: returnToPrevious);
      },
    ),
    GoRoute(
      path: "/home",
      builder: (context, state) => const VendorBottomNavigator(),
    ),
    GoRoute(
      path: "/forgotPassword",
      builder: (context, state) => const ForgotPassword(),
    ),
    GoRoute(
      path: "/resetPassword",
      builder: (context, state) {
        final data = state.extra;
        final email = switch (data) {
          Map<String, dynamic>() =>
            (data['email'] as String?) ?? 'your business email',
          String() => data,
          _ => 'your business email',
        };
        return ResetPassword(email: email);
      },
    ),
    GoRoute(
      path: "/otpVerification",
      builder: (context, state) {
        final data = state.extra as Map<String, dynamic>?;
        final channel = (data?['channel'] as String?) ?? 'Email';
        final destination = (data?['destination'] as String?) ?? 'your contact';
        return OtpVerification(channel: channel, destination: destination);
      },
    ),
  ],
);
