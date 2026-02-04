import 'package:animations/animations.dart';
import 'package:flutter/material.dart' hide Notification;
import 'package:go_router/go_router.dart';
import 'package:grab_go_customer/features/auth/view/location_permission.dart';
import 'package:grab_go_customer/features/auth/view/notification_permission.dart';
import 'package:grab_go_customer/features/grabmart/model/grabmart_item.dart';
import 'package:grab_go_customer/features/home/navigation/bottom_navigator.dart';
import 'package:grab_go_customer/features/pharmacy/model/pharmacy_item.dart';
import 'package:grab_go_customer/features/profile/view/settings_page.dart';
import 'package:grab_go_customer/features/status/view/status_page.dart';
import 'package:grab_go_customer/features/status/view/all_statuses_page.dart';
import 'package:grab_go_customer/features/status/model/status_model.dart';
import 'package:grab_go_customer/shared/widgets/deep_link_error_screen.dart';
import 'package:grab_go_customer/shared/widgets/food_from_link_handler.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:grab_go_customer/features/auth/view/email_verification.dart';
import 'package:grab_go_customer/features/auth/view/login.dart';
import 'package:grab_go_customer/features/auth/view/onboarding_main.dart';
import 'package:grab_go_customer/features/profile/view/edit_profile.dart';
import 'package:grab_go_customer/features/profile/view/favorites.dart';
import 'package:grab_go_customer/features/cart/view/cart.dart';
import 'package:grab_go_customer/features/auth/view/account_created.dart';
import 'package:grab_go_customer/features/order/view/map_tracking.dart';
import 'package:grab_go_customer/features/auth/view/forgot_password.dart';
import 'package:grab_go_customer/features/auth/view/otp_verification.dart';
import 'package:grab_go_customer/features/auth/view/profile_upload.dart';
import 'package:grab_go_customer/features/auth/view/register.dart';
import 'package:grab_go_customer/features/auth/view/restaurant_registration.dart';
import 'package:grab_go_customer/features/auth/view/verify_phone.dart';
import 'package:grab_go_customer/features/cart/view/checkout.dart';
import 'package:grab_go_customer/features/home/view/food_details.dart';
import 'package:grab_go_customer/features/home/view/search_page.dart';
import 'package:grab_go_customer/features/home/view/notification.dart' as notification_page;
import 'package:grab_go_customer/features/order/view/order_summary.dart';
import 'package:grab_go_customer/features/order/view/order_tracking.dart';
import 'package:grab_go_customer/features/profile/view/view_profile.dart';
import 'package:grab_go_customer/features/restaurant/view/restaurant_account_creation_tracking.dart';
import 'package:grab_go_customer/features/restaurant/view/restaurant_details.dart';
import 'package:grab_go_customer/features/restaurant/view/restaurant_registration_success.dart';
import 'package:grab_go_customer/features/restaurant/view/restaurant_review_page.dart';
import 'package:grab_go_customer/features/restaurant/model/restaurant_registration_data.dart';
import 'package:grab_go_customer/features/restaurant/model/restaurants_model.dart';
import 'package:grab_go_customer/features/profile/view/orders.dart';
import 'package:grab_go_customer/features/profile/view/payment.dart';
import 'package:grab_go_customer/features/profile/view/referral_page.dart';
import 'package:grab_go_customer/features/profile/view/credits_screen.dart';
import 'package:grab_go_customer/features/order/view/payment_complete.dart';
import 'package:grab_go_customer/features/restaurant/view/restaurants.dart';
import 'package:grab_go_customer/features/home/model/food_category.dart';
import 'package:grab_go_customer/splash_screen.dart';
import 'package:grab_go_customer/features/groceries/model/grocery_item.dart';
import 'package:grab_go_customer/features/location/view/location_picker_page.dart';
import 'package:grab_go_customer/features/browse/view/category_items_page.dart';
import 'package:flutter/material.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: "/",
  redirect: (BuildContext context, GoRouterState state) {
    final uri = state.uri;
    final location = state.uri.toString();
    if (uri.scheme == 'grabgo') {
      String? foodId;
      if (uri.host == 'food' && uri.path.isNotEmpty) {
        foodId = uri.path.replaceFirst('/', '').split('?').first.trim();
      } else if (uri.path.startsWith('/food/')) {
        foodId = uri.path.replaceFirst('/food/', '').split('?').first.trim();
      } else if (location.contains('/food/')) {
        final match = RegExp(r'/food/([^/?]+)').firstMatch(location);
        if (match != null) {
          foodId = match.group(1)?.trim();
        }
      } else if (uri.path.startsWith('/') && uri.path.length > 1) {
        foodId = uri.path.replaceFirst('/', '').split('?').first.trim();
      }

      if (foodId != null && foodId.isNotEmpty) {
        return '/food/$foodId';
      }
    }

    if ((uri.scheme == 'https' || uri.scheme == 'http') && uri.host.contains('grabgo')) {
      if (uri.path.startsWith('/food/')) {
        final foodId = uri.path.replaceFirst('/food/', '').split('?').first.trim();
        if (foodId.isNotEmpty) {
          return '/food/$foodId';
        }
      }
    }
    return null;
  },
  errorBuilder: (context, state) {
    final uri = state.uri;

    final uriString = uri.toString();
    if (uriString.contains('/food/')) {
      final foodIdMatch = RegExp(r'/food/([^/?]+)').firstMatch(uriString);
      if (foodIdMatch != null) {
        final foodId = foodIdMatch.group(1) ?? '';
        if (foodId.isNotEmpty) {
          Future.microtask(() {
            if (context.mounted) {
              context.go('/food/$foodId');
            }
          });
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) {
              LoadingDialog.instance().show(context: context, text: "Loading food item...");
            }
          });
          return const Scaffold(backgroundColor: Colors.transparent, body: SizedBox.shrink());
        }
      }
    }
    return const DeepLinkErrorScreen();
  },
  routes: [
    GoRoute(path: "/", builder: (context, state) => const SplashScreen()),
    GoRoute(
      path: "/onboarding",
      pageBuilder: (context, state) {
        return CustomTransitionPage(
          key: state.pageKey,
          child: const OnboardingMain(),
          transitionDuration: const Duration(milliseconds: 800),
          reverseTransitionDuration: const Duration(milliseconds: 800),
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
          reverseTransitionDuration: const Duration(milliseconds: 800),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SharedAxisTransition(
              animation: animation,
              secondaryAnimation: secondaryAnimation,
              transitionType: SharedAxisTransitionType.vertical,
              child: child,
            );
          },
        );
      },
    ),
    GoRoute(
      path: "/editProfile",
      pageBuilder: (context, state) {
        return CustomTransitionPage(
          key: state.pageKey,
          child: const EditProfile(),
          transitionDuration: const Duration(milliseconds: 800),
          reverseTransitionDuration: const Duration(milliseconds: 800),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SharedAxisTransition(
              animation: animation,
              secondaryAnimation: secondaryAnimation,
              transitionType: SharedAxisTransitionType.vertical,
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
          reverseTransitionDuration: const Duration(milliseconds: 800),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SharedAxisTransition(
              animation: animation,
              secondaryAnimation: secondaryAnimation,
              transitionType: SharedAxisTransitionType.vertical,
              child: child,
            );
          },
        );
      },
    ),
    GoRoute(
      path: "/emailVerification",
      pageBuilder: (context, state) {
        return CustomTransitionPage(
          key: state.pageKey,
          child: const EmailVerification(),
          transitionDuration: const Duration(milliseconds: 800),
          reverseTransitionDuration: const Duration(milliseconds: 800),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SharedAxisTransition(
              animation: animation,
              secondaryAnimation: secondaryAnimation,
              transitionType: SharedAxisTransitionType.vertical,
              child: child,
            );
          },
        );
      },
    ),
    GoRoute(
      path: "/viewProfile",
      pageBuilder: (context, state) {
        final user = state.extra as User;
        return CustomTransitionPage(
          key: state.pageKey,
          child: ViewProfile(user: user),
          transitionDuration: const Duration(milliseconds: 800),
          reverseTransitionDuration: const Duration(milliseconds: 800),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SharedAxisTransition(
              animation: animation,
              secondaryAnimation: secondaryAnimation,
              transitionType: SharedAxisTransitionType.vertical,
              child: child,
            );
          },
        );
      },
    ),
    GoRoute(
      path: "/OTPVerification",
      pageBuilder: (context, state) {
        return CustomTransitionPage(
          key: state.pageKey,
          child: const OtpVerification(),
          transitionDuration: const Duration(milliseconds: 800),
          reverseTransitionDuration: const Duration(milliseconds: 800),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SharedAxisTransition(
              animation: animation,
              secondaryAnimation: secondaryAnimation,
              transitionType: SharedAxisTransitionType.vertical,
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
          reverseTransitionDuration: const Duration(milliseconds: 800),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SharedAxisTransition(
              animation: animation,
              secondaryAnimation: secondaryAnimation,
              transitionType: SharedAxisTransitionType.vertical,
              child: child,
            );
          },
        );
      },
    ),
    GoRoute(
      path: "/restaurantRegistration",
      pageBuilder: (context, state) {
        return CustomTransitionPage(
          key: state.pageKey,
          child: const RestaurantRegistration(),
          transitionDuration: const Duration(milliseconds: 800),
          reverseTransitionDuration: const Duration(milliseconds: 800),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SharedAxisTransition(
              animation: animation,
              secondaryAnimation: secondaryAnimation,
              transitionType: SharedAxisTransitionType.vertical,
              child: child,
            );
          },
        );
      },
    ),
    GoRoute(
      path: "/status",
      pageBuilder: (context, state) {
        return CustomTransitionPage(
          key: state.pageKey,
          child: const StatusPage(),
          transitionDuration: const Duration(milliseconds: 400),
          reverseTransitionDuration: const Duration(milliseconds: 400),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SharedAxisTransition(
              animation: animation,
              secondaryAnimation: secondaryAnimation,
              transitionType: SharedAxisTransitionType.vertical,
              child: child,
            );
          },
        );
      },
    ),
    GoRoute(
      path: "/settings",
      pageBuilder: (context, state) {
        return CustomTransitionPage(
          key: state.pageKey,
          child: const SettingsPage(),
          transitionDuration: const Duration(milliseconds: 400),
          reverseTransitionDuration: const Duration(milliseconds: 400),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SharedAxisTransition(
              animation: animation,
              secondaryAnimation: secondaryAnimation,
              transitionType: SharedAxisTransitionType.vertical,
              child: child,
            );
          },
        );
      },
    ),
    GoRoute(
      path: "/referral",
      pageBuilder: (context, state) {
        return CustomTransitionPage(
          key: state.pageKey,
          child: const ReferralPage(),
          transitionDuration: const Duration(milliseconds: 400),
          reverseTransitionDuration: const Duration(milliseconds: 400),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SharedAxisTransition(
              animation: animation,
              secondaryAnimation: secondaryAnimation,
              transitionType: SharedAxisTransitionType.horizontal,
              child: child,
            );
          },
        );
      },
    ),
    GoRoute(
      path: "/credits",
      pageBuilder: (context, state) {
        return CustomTransitionPage(
          key: state.pageKey,
          child: const CreditsScreen(),
          transitionDuration: const Duration(milliseconds: 400),
          reverseTransitionDuration: const Duration(milliseconds: 400),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SharedAxisTransition(
              animation: animation,
              secondaryAnimation: secondaryAnimation,
              transitionType: SharedAxisTransitionType.horizontal,
              child: child,
            );
          },
        );
      },
    ),
    GoRoute(
      path: "/review",
      pageBuilder: (context, state) {
        final registrationData = state.extra as RestaurantRegistrationData?;
        return CustomTransitionPage(
          key: state.pageKey,
          child: ReviewPage(registrationData: registrationData!),
          transitionDuration: const Duration(milliseconds: 800),
          reverseTransitionDuration: const Duration(milliseconds: 800),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SharedAxisTransition(
              animation: animation,
              secondaryAnimation: secondaryAnimation,
              transitionType: SharedAxisTransitionType.vertical,
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
          reverseTransitionDuration: const Duration(milliseconds: 800),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SharedAxisTransition(
              animation: animation,
              secondaryAnimation: secondaryAnimation,
              transitionType: SharedAxisTransitionType.vertical,
              child: child,
            );
          },
        );
      },
    ),
    GoRoute(
      path: "/locationPermission",
      pageBuilder: (context, state) {
        return CustomTransitionPage(
          key: state.pageKey,
          child: const LocationPermission(),
          transitionDuration: const Duration(milliseconds: 800),
          reverseTransitionDuration: const Duration(milliseconds: 800),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SharedAxisTransition(
              animation: animation,
              secondaryAnimation: secondaryAnimation,
              transitionType: SharedAxisTransitionType.vertical,
              child: child,
            );
          },
        );
      },
    ),
    GoRoute(
      path: "/notificationPermission",
      pageBuilder: (context, state) {
        return CustomTransitionPage(
          key: state.pageKey,
          child: const NotificationPermission(),
          transitionDuration: const Duration(milliseconds: 800),
          reverseTransitionDuration: const Duration(milliseconds: 800),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SharedAxisTransition(
              animation: animation,
              secondaryAnimation: secondaryAnimation,
              transitionType: SharedAxisTransitionType.vertical,
              child: child,
            );
          },
        );
      },
    ),
    GoRoute(
      path: "/profileUpload",
      pageBuilder: (context, state) {
        return CustomTransitionPage(
          key: state.pageKey,
          child: const ProfileUpload(),
          transitionDuration: const Duration(milliseconds: 800),
          reverseTransitionDuration: const Duration(milliseconds: 800),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SharedAxisTransition(
              animation: animation,
              secondaryAnimation: secondaryAnimation,
              transitionType: SharedAxisTransitionType.vertical,
              child: child,
            );
          },
        );
      },
    ),
    GoRoute(
      path: "/restaurantRegistrationSuccess",
      pageBuilder: (context, state) {
        return CustomTransitionPage(
          key: state.pageKey,
          child: const RestaurantRegistrationSuccess(),
          transitionDuration: const Duration(milliseconds: 800),
          reverseTransitionDuration: const Duration(milliseconds: 800),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SharedAxisTransition(
              animation: animation,
              secondaryAnimation: secondaryAnimation,
              transitionType: SharedAxisTransitionType.vertical,
              child: child,
            );
          },
        );
      },
    ),
    GoRoute(
      path: "/orders",
      pageBuilder: (context, state) {
        return CustomTransitionPage(
          key: state.pageKey,
          child: const Orders(),
          transitionDuration: const Duration(milliseconds: 400),
          reverseTransitionDuration: const Duration(milliseconds: 400),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SharedAxisTransition(
              animation: animation,
              secondaryAnimation: secondaryAnimation,
              transitionType: SharedAxisTransitionType.vertical,
              child: child,
            );
          },
        );
      },
    ),
    GoRoute(
      path: "/mapTracking",
      pageBuilder: (context, state) {
        final orderId = state.uri.queryParameters['orderId'] ?? '';
        return CustomTransitionPage(
          key: state.pageKey,
          child: MapTracking(orderId: orderId),
          transitionDuration: const Duration(milliseconds: 800),
          reverseTransitionDuration: const Duration(milliseconds: 800),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SharedAxisTransition(
              animation: animation,
              secondaryAnimation: secondaryAnimation,
              transitionType: SharedAxisTransitionType.vertical,
              child: child,
            );
          },
        );
      },
    ),
    GoRoute(
      path: "/restaurantAccountCreationTracking",
      pageBuilder: (context, state) {
        return CustomTransitionPage(
          key: state.pageKey,
          child: const RestaurantAccountCreationTracking(),
          transitionDuration: const Duration(milliseconds: 800),
          reverseTransitionDuration: const Duration(milliseconds: 800),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SharedAxisTransition(
              animation: animation,
              secondaryAnimation: secondaryAnimation,
              transitionType: SharedAxisTransitionType.vertical,
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
          reverseTransitionDuration: const Duration(milliseconds: 800),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SharedAxisTransition(
              animation: animation,
              secondaryAnimation: secondaryAnimation,
              transitionType: SharedAxisTransitionType.vertical,
              child: child,
            );
          },
        );
      },
    ),
    GoRoute(
      path: "/homepage",
      pageBuilder: (context, state) {
        return CustomTransitionPage(
          key: state.pageKey,
          child: const BottomNavigator(),
          transitionDuration: const Duration(milliseconds: 400),
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
      path: "/restaurants",
      pageBuilder: (context, state) {
        return CustomTransitionPage(
          key: state.pageKey,
          child: const Restaurants(),
          transitionDuration: const Duration(milliseconds: 400),
          reverseTransitionDuration: const Duration(milliseconds: 400),
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
      path: "/orderTracking",
      pageBuilder: (context, state) {
        return CustomTransitionPage(
          key: state.pageKey,
          child: const OrderTracking(),
          transitionDuration: const Duration(milliseconds: 400),
          reverseTransitionDuration: const Duration(milliseconds: 400),
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
      path: "/paymentMethod",
      pageBuilder: (context, state) {
        return CustomTransitionPage(
          key: state.pageKey,
          child: const Payment(),
          transitionDuration: const Duration(milliseconds: 400),
          reverseTransitionDuration: const Duration(milliseconds: 400),
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
      path: "/restaurantDetails",
      pageBuilder: (context, state) {
        final restaurant = state.extra as RestaurantModel;

        return CustomTransitionPage(
          key: state.pageKey,
          child: RestaurantDetails(restaurant: restaurant),
          transitionDuration: const Duration(milliseconds: 400),
          reverseTransitionDuration: const Duration(milliseconds: 400),
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
      path: "/paymentComplete",
      pageBuilder: (context, state) {
        final extra = state.extra as Map<String, dynamic>? ?? {};

        return CustomTransitionPage(
          key: state.pageKey,
          child: PaymentComplete(
            method: extra["method"] as String? ?? "",
            total: extra["total"] as double? ?? 0.0,
            subTotal: extra["subTotal"] as double? ?? 0.0,
            deliveryFee: extra["deliveryFee"] as double? ?? 0.0,
            orderNumber: extra["orderNumber"] as String?,
            timestamp: extra["timestamp"] as String?,
          ),
          transitionDuration: const Duration(milliseconds: 400),
          reverseTransitionDuration: const Duration(milliseconds: 400),
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
      path: "/cart",
      pageBuilder: (context, state) {
        return CustomTransitionPage(
          key: state.pageKey,
          child: const Cart(),
          transitionDuration: const Duration(milliseconds: 400),
          reverseTransitionDuration: const Duration(milliseconds: 400),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SharedAxisTransition(
              animation: animation,
              secondaryAnimation: secondaryAnimation,
              transitionType: SharedAxisTransitionType.horizontal,
              child: child,
            );
          },
        );
      },
    ),
    GoRoute(
      path: "/favorites",
      pageBuilder: (context, state) {
        return CustomTransitionPage(
          key: state.pageKey,
          child: const FavoritesPage(),
          transitionDuration: const Duration(milliseconds: 400),
          reverseTransitionDuration: const Duration(milliseconds: 400),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SharedAxisTransition(
              animation: animation,
              secondaryAnimation: secondaryAnimation,
              transitionType: SharedAxisTransitionType.horizontal,
              child: child,
            );
          },
        );
      },
    ),
    GoRoute(
      path: "/checkout",
      pageBuilder: (context, state) {
        return CustomTransitionPage(
          key: state.pageKey,
          child: const Checkout(),
          transitionDuration: const Duration(milliseconds: 400),
          reverseTransitionDuration: const Duration(milliseconds: 400),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SharedAxisTransition(
              animation: animation,
              secondaryAnimation: secondaryAnimation,
              transitionType: SharedAxisTransitionType.horizontal,
              child: child,
            );
          },
        );
      },
    ),
    GoRoute(
      path: "/orderSummary",
      pageBuilder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;

        final selectedAddress = extra?['address'] as String? ?? 'N/A';
        final selectedAddressDetails = extra?['addressDetails'] as String? ?? '';
        final selectedPayment = extra?['payment'] as String? ?? 'N/A';
        final selectedInstructions = extra?['selectedInstructions'] as List<String>? ?? [];
        final customRestaurantInstruction = extra?['customRestaurantInstruction'] as String? ?? '';
        final selectedDeliveryInstructions = extra?['selectedDeliveryInstructions'] as List<String>? ?? [];
        final customDeliveryInstruction = extra?['customDeliveryInstruction'] as String? ?? '';
        final tipAmount = extra?['tipAmount'] as double? ?? 0.0;

        return CustomTransitionPage(
          key: state.pageKey,
          child: OrderSummaryPage(
            selectedAddress: selectedAddress,
            selectedAddressDetails: selectedAddressDetails,
            selectedPaymentMethod: selectedPayment,
            selectedInstructions: selectedInstructions,
            customRestaurantInstruction: customRestaurantInstruction,
            selectedDeliveryInstructions: selectedDeliveryInstructions,
            customDeliveryInstruction: customDeliveryInstruction,
            tipAmount: tipAmount,
          ),
          transitionDuration: const Duration(milliseconds: 400),
          reverseTransitionDuration: const Duration(milliseconds: 400),
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
      path: "/foodDetails",
      pageBuilder: (context, state) {
        final extra = state.extra;

        // Handle null case
        if (extra == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) {
              context.pop();
            }
          });
          return CustomTransitionPage(
            key: state.pageKey,
            child: const SizedBox.shrink(),
            transitionDuration: const Duration(milliseconds: 400),
            reverseTransitionDuration: const Duration(milliseconds: 400),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return child;
            },
          );
        }

        // Detect type and create appropriate widget
        final Widget child;
        if (extra is GroceryItem) {
          child = FoodDetails(groceryItem: extra);
        } else if (extra is FoodItem) {
          child = FoodDetails(foodItem: extra);
        } else if (extra is PharmacyItem) {
          child = FoodDetails(pharmacyItem: extra);
        } else if (extra is GrabMartItem) {
          child = FoodDetails(grabMartItem: extra);
        } else {
          child = const Scaffold(body: Center(child: Text('Invalid item type')));
        }

        return CustomTransitionPage(
          key: state.pageKey,
          child: child,
          transitionDuration: const Duration(milliseconds: 400),
          reverseTransitionDuration: const Duration(milliseconds: 400),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SharedAxisTransition(
              animation: animation,
              secondaryAnimation: secondaryAnimation,
              transitionType: SharedAxisTransitionType.vertical,
              child: child,
            );
          },
        );
      },
    ),
    GoRoute(
      path: "/food/:foodId",
      pageBuilder: (context, state) {
        final foodId = state.pathParameters['foodId'] ?? '';

        return CustomTransitionPage(
          key: state.pageKey,
          child: FoodFromLinkHandler(foodId: foodId),
          transitionDuration: const Duration(milliseconds: 400),
          reverseTransitionDuration: const Duration(milliseconds: 400),
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
      path: "/notification",
      pageBuilder: (context, state) {
        return CustomTransitionPage(
          key: state.pageKey,
          child: const notification_page.Notification(),
          transitionDuration: const Duration(milliseconds: 400),
          reverseTransitionDuration: const Duration(milliseconds: 400),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SharedAxisTransition(
              animation: animation,
              secondaryAnimation: secondaryAnimation,
              transitionType: SharedAxisTransitionType.horizontal,
              child: child,
            );
          },
        );
      },
    ),
    GoRoute(
      path: "/search",
      pageBuilder: (context, state) {
        return CustomTransitionPage(
          key: state.pageKey,
          child: const SearchPage(),
          transitionDuration: const Duration(milliseconds: 400),
          reverseTransitionDuration: const Duration(milliseconds: 400),
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
      path: "/allStatuses",
      pageBuilder: (context, state) {
        final category = state.extra as StatusCategory?;
        return CustomTransitionPage(
          key: state.pageKey,
          child: AllStatusesPage(initialCategory: category),
          transitionDuration: const Duration(milliseconds: 400),
          reverseTransitionDuration: const Duration(milliseconds: 400),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SharedAxisTransition(
              animation: animation,
              secondaryAnimation: secondaryAnimation,
              transitionType: SharedAxisTransitionType.horizontal,
              child: child,
            );
          },
        );
      },
    ),
    GoRoute(
      path: "/categoryItems",
      pageBuilder: (context, state) {
        final extra = state.extra as Map<String, dynamic>;
        return CustomTransitionPage(
          key: state.pageKey,
          child: CategoryItemsPage(
            categoryId: (extra['categoryId'] as String?) ?? '',
            categoryName: (extra['categoryName'] as String?) ?? 'Items',
            categoryEmoji: (extra['categoryEmoji'] as String?) ?? '📦',
            serviceType: extra['serviceType'] as String? ?? (extra['isFood'] == true ? 'food' : 'grocery'),
          ),
          transitionDuration: const Duration(milliseconds: 400),
          reverseTransitionDuration: const Duration(milliseconds: 400),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SharedAxisTransition(
              animation: animation,
              secondaryAnimation: secondaryAnimation,
              transitionType: SharedAxisTransitionType.horizontal,
              child: child,
            );
          },
        );
      },
    ),
    GoRoute(
      path: "/location-picker",
      pageBuilder: (context, state) {
        final isFromRegistration = state.extra as bool? ?? false;
        return CustomTransitionPage(
          key: state.pageKey,
          child: LocationPickerPage(isFromRegistration: isFromRegistration),
          transitionDuration: const Duration(milliseconds: 400),
          reverseTransitionDuration: const Duration(milliseconds: 400),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SharedAxisTransition(
              animation: animation,
              secondaryAnimation: secondaryAnimation,
              transitionType: SharedAxisTransitionType.vertical,
              child: child,
            );
          },
        );
      },
    ),
  ],
);
