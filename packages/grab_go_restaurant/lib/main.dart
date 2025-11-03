import 'package:flutter/material.dart';
import 'package:grab_go_restaurant/features/dashboard/view/restaurant_dashboard.dart';
import 'package:grab_go_restaurant/shared/providers/theme_provider.dart';
import 'package:grab_go_restaurant/shared/app_theme.dart';
import 'package:provider/provider.dart';
import 'features/auth/view/login_screen.dart';

void main() {
  runApp(const GrabGoRestaurant());
}

class GrabGoRestaurant extends StatelessWidget {
  const GrabGoRestaurant({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [ChangeNotifierProvider(create: (context) => ThemeProvider())],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            title: 'GrabGo Restaurant Panel',
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.themeMode,
            initialRoute: '/',
            routes: {'/': (context) => const LandingScreen(), '/restaurant': (context) => const RestaurantDashboard()},
            debugShowCheckedModeBanner: false,
          );
        },
      ),
    );
  }
}
