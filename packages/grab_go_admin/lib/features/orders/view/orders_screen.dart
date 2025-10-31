import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:grab_go_admin/shared/app_colors.dart';

class OrdersScreen extends StatelessWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.secondaryBackground,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shopping_cart_outlined, size: 80, color: isDark ? AppColors.white : AppColors.primary),
            const SizedBox(height: 24),
            Text(
              'Orders',
              style: GoogleFonts.lato(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.white : AppColors.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text('Order management coming soon...', style: GoogleFonts.lato(fontSize: 16, color: AppColors.grey)),
          ],
        ),
      ),
    );
  }
}
