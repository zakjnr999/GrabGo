import 'package:flutter/material.dart';
import 'package:grab_go_customer/features/home/model/promotional_banner.dart';

class ServiceHubConfig {
  final String serviceId;
  final String title;
  final String subtitle;
  final List<PromotionalBanner> banners;
  final Color accentColor;
  final String categoryServiceType;
  final String categoryTitle;

  const ServiceHubConfig({
    required this.serviceId,
    required this.title,
    required this.subtitle,
    required this.banners,
    required this.accentColor,
    required this.categoryServiceType,
    required this.categoryTitle,
  });

  static ServiceHubConfig? fromServiceId(String serviceId) {
    switch (serviceId) {
      case 'groceries':
        return const ServiceHubConfig(
          serviceId: 'groceries',
          title: 'Groceries',
          subtitle: 'Daily essentials at great prices',
          banners: [
            PromotionalBanner(
              id: 'grocery_weekly_deals',
              title: 'Weekly Basket Deals',
              subtitle: 'Save more on staples and fresh produce',
              actionText: 'Shop Deals',
              gradientColors: [Color(0xFF1B5E20), Color(0xFF66BB6A)],
              emoji: '🛒',
              isDismissible: false,
            ),
            PromotionalBanner(
              id: 'grocery_fresh_fast',
              title: 'Fresh Picks in Minutes',
              subtitle: 'Fruits, veggies, and essentials from nearby stores',
              actionText: 'Shop Fresh',
              gradientColors: [Color(0xFF2E7D32), Color(0xFF81C784)],
              emoji: '🥬',
              isDismissible: false,
            ),
            PromotionalBanner(
              id: 'grocery_restock',
              title: 'Restock Home Essentials',
              subtitle: 'Beverages, snacks, and household must-haves',
              actionText: 'Restock',
              gradientColors: [Color(0xFF33691E), Color(0xFF9CCC65)],
              emoji: '🧺',
              isDismissible: false,
            ),
          ],
          accentColor: Color(0xFF4CAF50),
          categoryServiceType: 'grocery',
          categoryTitle: 'Grocery Categories',
        );

      case 'pharmacy':
        return const ServiceHubConfig(
          serviceId: 'pharmacy',
          title: 'Pharmacy',
          subtitle: 'Health and wellness essentials',
          banners: [
            PromotionalBanner(
              id: 'pharmacy_wellness_deals',
              title: 'Wellness Week Offers',
              subtitle: 'Daily savings on vitamins and health essentials',
              actionText: 'View Offers',
              gradientColors: [Color(0xFF00695C), Color(0xFF26A69A)],
              emoji: '💊',
              isDismissible: false,
            ),
            PromotionalBanner(
              id: 'pharmacy_fast_otc',
              title: 'OTC Delivered Fast',
              subtitle: 'Cold, pain, and daily care items near you',
              actionText: 'Shop OTC',
              gradientColors: [Color(0xFF00796B), Color(0xFF4DB6AC)],
              emoji: '🩺',
              isDismissible: false,
            ),
            PromotionalBanner(
              id: 'pharmacy_family_care',
              title: 'Family Care Essentials',
              subtitle: 'Personal care and trusted everyday products',
              actionText: 'Explore',
              gradientColors: [Color(0xFF00897B), Color(0xFF80CBC4)],
              emoji: '🧴',
              isDismissible: false,
            ),
          ],
          accentColor: Color(0xFF009688),
          categoryServiceType: 'pharmacy',
          categoryTitle: 'Pharmacy Categories',
        );

      case 'convenience':
        return const ServiceHubConfig(
          serviceId: 'convenience',
          title: 'GrabMart',
          subtitle: 'Convenience shopping in minutes',
          banners: [
            PromotionalBanner(
              id: 'grabmart_late_night',
              title: 'Late-Night Essentials',
              subtitle: 'Quick picks when you need items after hours',
              actionText: 'Shop Now',
              gradientColors: [Color(0xFF4A148C), Color(0xFFBA68C8)],
              emoji: '🌙',
              isDismissible: false,
            ),
            PromotionalBanner(
              id: 'grabmart_snacks',
              title: 'Snacks & Drinks Picks',
              subtitle: 'Instant cravings, chilled drinks, and more',
              actionText: 'Grab Picks',
              gradientColors: [Color(0xFF6D28D9), Color(0xFFA78BFA)],
              emoji: '🥤',
              isDismissible: false,
            ),
            PromotionalBanner(
              id: 'grabmart_home_cleaning',
              title: 'Home & Cleaning Deals',
              subtitle: 'Household basics and cleaning must-haves',
              actionText: 'Browse Deals',
              gradientColors: [Color(0xFF9A3412), Color(0xFFF97316)],
              emoji: '🧼',
              isDismissible: false,
            ),
          ],
          accentColor: Color(0xFF9C27B0),
          categoryServiceType: 'convenience',
          categoryTitle: 'GrabMart Categories',
        );

      default:
        return null;
    }
  }
}
