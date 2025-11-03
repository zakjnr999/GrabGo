import 'package:flutter/material.dart';
import 'package:grab_go_admin/shared/providers/theme_provider.dart';
import 'package:provider/provider.dart';
import 'features/auth/view/login_screen.dart';
import 'features/dashboard/view/admin_dashboard.dart';
import 'features/restaurants/viewmodel/restaurant_provider.dart';
import 'shared/utils/app_theme.dart';

void main() {
  runApp(const GrabGoAdmin());
}

class GrabGoAdmin extends StatelessWidget {
  const GrabGoAdmin({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => ThemeProvider()),
        ChangeNotifierProvider(create: (context) => RestaurantProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            title: 'GrabGo Admin Panel',
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.themeMode,
            initialRoute: '/',
            routes: {'/': (context) => const LandingScreen(), '/admin': (context) => const AdminDashboard()},
            debugShowCheckedModeBanner: false,
          );
        },
      ),
    );
  }
}
