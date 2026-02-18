import 'package:flutter/material.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_vendor/features/onboarding/model/onboarding_item.dart';

class OnboardingViewModel extends ChangeNotifier {
  final PageController pageController = PageController();

  final List<VendorOnboardingItem> _items = [
    VendorOnboardingItem(
      badge: 'Operations Hub',
      title: 'Manage all GrabGo services in one workspace.',
      subtitle: 'Food, grocery, pharmacy, and GrabMart orders in one clean daily workflow.',
      heroIcon: Assets.icons.store,
    ),
    VendorOnboardingItem(
      badge: 'Fast Fulfillment',
      title: 'Handle incoming orders quickly and clearly.',
      subtitle: 'Accept requests, update prep status, and keep dispatch running on time.',
      heroIcon: Assets.icons.store,
    ),
    VendorOnboardingItem(
      badge: 'Business Insights',
      title: 'Track performance and grow with confidence.',
      subtitle: 'Monitor sales, peak times, and service quality to make smarter decisions.',
      heroIcon: Assets.icons.store,
    ),
  ];

  int _currentIndex = 0;

  List<VendorOnboardingItem> get items => _items;
  int get currentIndex => _currentIndex;
  bool get isLastPage => _currentIndex == _items.length - 1;

  void onPageChanged(int index) {
    if (_currentIndex == index) return;
    _currentIndex = index;
    notifyListeners();
  }

  Future<void> nextPage() async {
    if (isLastPage) return;
    await pageController.nextPage(duration: const Duration(milliseconds: 320), curve: Curves.easeInOut);
  }

  Future<void> skipToLastPage() async {
    if (isLastPage) return;
    await pageController.animateToPage(
      _items.length - 1,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    pageController.dispose();
    super.dispose();
  }
}
