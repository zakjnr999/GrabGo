import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:grab_go_shared/shared/utils/colors.dart';

class AppHelpers {
  // Get icon data from string
  static IconData getIconData(String iconName) {
    switch (iconName) {
      case 'dashboard':
        return Icons.dashboard;
      case 'bar_chart':
        return Icons.bar_chart;
      case 'account_balance_wallet':
        return Icons.account_balance_wallet;
      case 'list_alt':
        return Icons.list_alt;
      case 'settings':
        return Icons.settings;
      case 'restaurant_menu':
        return Icons.restaurant_menu;
      case 'shopping_bag':
        return Icons.shopping_bag;
      case 'people':
        return Icons.people;
      case 'trending_up':
        return Icons.trending_up;
      default:
        return Icons.info;
    }
  }

  // Get color from string
  static Color getColor(String colorName) {
    switch (colorName) {
      case 'primary':
        return AppColors.primary;
      case 'blueAccent':
        return AppColors.blueAccent;
      case 'grey':
        return AppColors.grey;
      case 'accentOrange':
        return AppColors.accentOrange;
      case 'violetAccent':
        return AppColors.violetAccent;
      default:
        return AppColors.primary;
    }
  }

  // Get text style for table
  static TextStyle getTableTextStyle() {
    return GoogleFonts.lato(fontSize: 12, color: AppColors.primary);
  }

  // Get text style for headers
  static TextStyle getHeaderTextStyle() {
    return GoogleFonts.lato(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary);
  }

  // Format currency
  static String formatCurrency(double amount) {
    return '\$${amount.toStringAsFixed(2)}';
  }

  // Format date
  static String formatDate(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}th, ${date.year}';
  }
}
