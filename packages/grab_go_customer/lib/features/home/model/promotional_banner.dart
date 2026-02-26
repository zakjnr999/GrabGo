import 'package:flutter/material.dart';
import 'package:grab_go_shared/grub_go_shared.dart';

/// Model for promotional banners
class PromotionalBanner {
  final String id;
  final String title;
  final String subtitle;
  final String actionText;
  final List<Color> gradientColors;
  final String emoji;
  final VoidCallback? onTap;
  final bool isDismissible;

  const PromotionalBanner({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.actionText,
    required this.gradientColors,
    required this.emoji,
    this.onTap,
    this.isDismissible = true,
  });
}

/// Predefined promotional banners
class AppPromotionalBanners {
  static PromotionalBanner welcomeOffer({VoidCallback? onTap}) =>
      PromotionalBanner(
        id: 'welcome_offer',
        title: '50% Off First Order',
        subtitle: 'New here? Get half off your first meal!',
        actionText: 'Claim Offer',
        gradientColors: [AppColors.serviceFood, AppColors.serviceFood],
        emoji: '🎉',
        onTap: onTap,
      );

  static PromotionalBanner referralBoost({VoidCallback? onTap}) =>
      PromotionalBanner(
        id: 'referral_boost',
        title: 'Refer & Earn GH₵20',
        subtitle: 'Share with friends and get rewarded',
        actionText: 'Invite Now',
        gradientColors: [const Color(0xFF0B6E4F), const Color(0xFF0B6E4F)],
        emoji: '🎁',
        onTap: onTap,
      );

  static PromotionalBanner flashDeal({VoidCallback? onTap}) =>
      PromotionalBanner(
        id: 'flash_deal',
        title: '20% Off Burgers',
        subtitle: 'Limited time! Ends in 2 hours',
        actionText: 'Order Now',
        gradientColors: [const Color(0xFFF44336), const Color(0xFFF44336)],
        emoji: '⚡',
        onTap: onTap,
      );

  static PromotionalBanner grabMartHighlight({VoidCallback? onTap}) =>
      PromotionalBanner(
        id: 'grabmart_highlight',
        title: 'Try GrabMart',
        subtitle: 'Groceries delivered in 20 minutes',
        actionText: 'Shop Now',
        gradientColors: [AppColors.serviceGrabMart, AppColors.serviceGrabMart],
        emoji: '🏪',
        onTap: onTap,
      );

  static List<PromotionalBanner> getDefaultBanners({
    VoidCallback? onWelcomeTap,
    VoidCallback? onReferralTap,
    VoidCallback? onFlashDealTap,
    VoidCallback? onGrabMartTap,
  }) {
    return [
      welcomeOffer(onTap: onWelcomeTap),
      referralBoost(onTap: onReferralTap),
      flashDeal(onTap: onFlashDealTap),
      grabMartHighlight(onTap: onGrabMartTap),
    ];
  }
}
