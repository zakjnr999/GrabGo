import 'package:animations/animations.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_rider/features/auth/view/account_created.dart';
import 'package:grab_go_rider/features/auth/view/forgot_password.dart';
import 'package:grab_go_rider/features/auth/view/login.dart';
import 'package:grab_go_rider/features/auth/view/onboarding_main.dart';
import 'package:grab_go_rider/features/auth/view/otp_verification.dart';
import 'package:grab_go_rider/features/auth/view/register.dart';
import 'package:grab_go_rider/features/auth/view/rider_account_tracking.dart';
import 'package:grab_go_rider/features/auth/view/rider_verification.dart';
import 'package:grab_go_rider/features/auth/view/vehicle_details.dart';
import 'package:grab_go_rider/features/auth/view/verify_email.dart';
import 'package:grab_go_rider/features/auth/view/verify_phone.dart';
import 'package:grab_go_rider/features/home/view/home_page.dart';
import 'package:grab_go_rider/splash_screen.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: "/",
  routes: [
    GoRoute(path: "/", builder: (context, state) => const SplashScreen()),
    GoRoute(
      path: "/onboarding",
      pageBuilder: (context, state) {
        return CustomTransitionPage(
          key: state.pageKey,
          child: const OnboardingMain(),
          transitionDuration: const Duration(milliseconds: 800),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SharedAxisTransition(
              animation: animation,
              secondaryAnimation: secondaryAnimation,
              transitionType: SharedAxisTransitionType.scaled,
              child: child,
            );
          },
        );
      },
    ),
    GoRoute(
      path: "/login",
      pageBuilder: (context, state) {
        return CustomTransitionPage(
          key: state.pageKey,
          child: const Login(),
          transitionDuration: const Duration(milliseconds: 800),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SharedAxisTransition(
              animation: animation,
              secondaryAnimation: secondaryAnimation,
              transitionType: SharedAxisTransitionType.scaled,
              child: child,
            );
          },
        );
      },
    ),
    GoRoute(
      path: "/register",
      pageBuilder: (context, state) {
        return CustomTransitionPage(
          key: state.pageKey,
          child: const Register(),
          transitionDuration: const Duration(milliseconds: 800),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SharedAxisTransition(
              animation: animation,
              secondaryAnimation: secondaryAnimation,
              transitionType: SharedAxisTransitionType.scaled,
              child: child,
            );
          },
        );
      },
    ),
    GoRoute(
      path: "/otpVerification",
      pageBuilder: (context, state) {
        return CustomTransitionPage(
          key: state.pageKey,
          child: const OtpVerification(),
          transitionDuration: const Duration(milliseconds: 800),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SharedAxisTransition(
              animation: animation,
              secondaryAnimation: secondaryAnimation,
              transitionType: SharedAxisTransitionType.scaled,
              child: child,
            );
          },
        );
      },
    ),
    GoRoute(
      path: "/forgotPassword",
      pageBuilder: (context, state) {
        return CustomTransitionPage(
          key: state.pageKey,
          child: const ForgotPassword(),
          transitionDuration: const Duration(milliseconds: 800),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SharedAxisTransition(
              animation: animation,
              secondaryAnimation: secondaryAnimation,
              transitionType: SharedAxisTransitionType.scaled,
              child: child,
            );
          },
        );
      },
    ),
    GoRoute(
      path: "/verifyEmail",
      pageBuilder: (context, state) {
        return CustomTransitionPage(
          key: state.pageKey,
          child: const VerifyEmail(),
          transitionDuration: const Duration(milliseconds: 800),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SharedAxisTransition(
              animation: animation,
              secondaryAnimation: secondaryAnimation,
              transitionType: SharedAxisTransitionType.scaled,
              child: child,
            );
          },
        );
      },
    ),
    GoRoute(
      path: "/accountCreated",
      pageBuilder: (context, state) {
        return CustomTransitionPage(
          key: state.pageKey,
          child: const AccountCreated(),
          transitionDuration: const Duration(milliseconds: 800),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SharedAxisTransition(
              animation: animation,
              secondaryAnimation: secondaryAnimation,
              transitionType: SharedAxisTransitionType.scaled,
              child: child,
            );
          },
        );
      },
    ),
    GoRoute(
      path: "/verifyPhone",
      pageBuilder: (context, state) {
        return CustomTransitionPage(
          key: state.pageKey,
          child: const VerifyPhone(),
          transitionDuration: const Duration(milliseconds: 800),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SharedAxisTransition(
              animation: animation,
              secondaryAnimation: secondaryAnimation,
              transitionType: SharedAxisTransitionType.scaled,
              child: child,
            );
          },
        );
      },
    ),
    GoRoute(
      path: "/riderVerification",
      pageBuilder: (context, state) {
        return CustomTransitionPage(
          key: state.pageKey,
          child: const RiderVerification(),
          transitionDuration: const Duration(milliseconds: 800),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SharedAxisTransition(
              animation: animation,
              secondaryAnimation: secondaryAnimation,
              transitionType: SharedAxisTransitionType.scaled,
              child: child,
            );
          },
        );
      },
    ),
    GoRoute(
      path: "/vehicleDetails",
      pageBuilder: (context, state) {
        return CustomTransitionPage(
          key: state.pageKey,
          child: const VehicleDetails(),
          transitionDuration: const Duration(milliseconds: 800),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SharedAxisTransition(
              animation: animation,
              secondaryAnimation: secondaryAnimation,
              transitionType: SharedAxisTransitionType.scaled,
              child: child,
            );
          },
        );
      },
    ),
    GoRoute(
      path: "/riderAccountTracking",
      pageBuilder: (context, state) {
        return CustomTransitionPage(
          key: state.pageKey,
          child: const RiderAccountTracking(),
          transitionDuration: const Duration(milliseconds: 800),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SharedAxisTransition(
              animation: animation,
              secondaryAnimation: secondaryAnimation,
              transitionType: SharedAxisTransitionType.scaled,
              child: child,
            );
          },
        );
      },
    ),
    GoRoute(
      path: "/home",
      pageBuilder: (context, state) {
        return CustomTransitionPage(
          key: state.pageKey,
          child: const HomePage(),
          transitionDuration: const Duration(milliseconds: 800),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SharedAxisTransition(
              animation: animation,
              secondaryAnimation: secondaryAnimation,
              transitionType: SharedAxisTransitionType.scaled,
              child: child,
            );
          },
        );
      },
    ),
  ],
);
