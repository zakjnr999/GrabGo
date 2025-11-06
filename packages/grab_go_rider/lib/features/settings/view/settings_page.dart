import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_rider/shared/viewmodel/theme_provider.dart';
import 'package:grab_go_rider/shared/widgets/switch_tile.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:provider/provider.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _pushNotifications = true;
  bool _orderUpdates = true;
  bool _bonusAlerts = true;
  bool _promotionalNotifications = false;

  String _selectedLanguage = 'English';

  bool _autoAcceptOrders = false;
  bool _locationTracking = true;
  bool _soundEnabled = true;

  bool _shareLocation = true;
  bool _showPhoneNumber = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: colors.backgroundPrimary,
        systemNavigationBarDividerColor: Colors.transparent,
        systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: colors.backgroundSecondary,
        appBar: AppBar(
          backgroundColor: colors.backgroundPrimary,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            icon: SvgPicture.asset(
              Assets.icons.navArrowLeft,
              package: 'grab_go_shared',
              width: 24.w,
              height: 24.w,
              colorFilter: ColorFilter.mode(colors.textPrimary, BlendMode.srcIn),
            ),
            onPressed: () => context.pop(),
          ),
          title: Text(
            "Settings",
            style: TextStyle(
              fontFamily: "Lato",
              package: "grab_go_shared",
              color: colors.textPrimary,
              fontSize: 18.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
          centerTitle: true,
        ),
        body: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader("NOTIFICATIONS", colors),
              SizedBox(height: 12.h),
              _buildSettingsCard(
                colors: colors,
                children: [
                  switchTile(
                    context: context,
                    title: "Push Notifications",
                    subtitle: "Receive push notifications",
                    icon: Assets.icons.bell,
                    iconColor: colors.accentOrange,
                    value: _pushNotifications,
                    onChanged: (value) => setState(() => _pushNotifications = value),
                    colors: colors,
                  ),
                  _buildDivider(colors),
                  switchTile(
                    context: context,
                    title: "Order Updates",
                    subtitle: "Get notified about new orders",
                    icon: Assets.icons.deliveryTruck,
                    iconColor: colors.accentGreen,
                    value: _orderUpdates,
                    onChanged: (value) => setState(() => _orderUpdates = value),
                    colors: colors,
                  ),
                  _buildDivider(colors),
                  switchTile(
                    context: context,
                    title: "Bonus Alerts",
                    subtitle: "Notifications for bonuses and rewards",
                    icon: Assets.icons.gift,
                    iconColor: colors.accentViolet,
                    value: _bonusAlerts,
                    onChanged: (value) => setState(() => _bonusAlerts = value),
                    colors: colors,
                  ),
                  _buildDivider(colors),
                  switchTile(
                    context: context,
                    title: "Promotional Notifications",
                    subtitle: "Receive offers and promotions",
                    icon: Assets.icons.flame,
                    iconColor: colors.accentBlue,
                    value: _promotionalNotifications,
                    onChanged: (value) => setState(() => _promotionalNotifications = value),
                    colors: colors,
                  ),
                ],
              ),

              SizedBox(height: 24.h),

              _buildSectionHeader("APP PREFERENCES", colors),
              SizedBox(height: 12.h),
              Consumer<ThemeProvider>(
                builder: (context, themeProvider, child) => _buildSettingsCard(
                  colors: colors,
                  children: [
                    switchTile(
                      context: context,
                      title: "Dark Mode",
                      subtitle: isDark ? "Switch to light theme" : "Switch to dark theme",
                      icon: isDark ? Assets.icons.sunLight : Assets.icons.halfMoon,
                      iconColor: colors.accentBlue,
                      value: themeProvider.isDarkMode,
                      onChanged: (value) => themeProvider.setThemeMode(value ? ThemeMode.dark : ThemeMode.light),
                      colors: colors,
                    ),
                    _buildDivider(colors),
                    _buildNavigationTile(
                      "Language",
                      _selectedLanguage,
                      Assets.icons.infoCircle,
                      colors.accentGreen,
                      () {},
                      colors,
                    ),
                  ],
                ),
              ),

              SizedBox(height: 24.h),

              _buildSectionHeader("DELIVERY SETTINGS", colors),
              SizedBox(height: 12.h),
              _buildSettingsCard(
                colors: colors,
                children: [
                  switchTile(
                    context: context,
                    title: "Auto Accept Orders",
                    subtitle: "Automatically accept incoming orders",
                    icon: Assets.icons.deliveryTruck,
                    iconColor: colors.accentGreen,
                    value: _autoAcceptOrders,
                    onChanged: (value) => setState(() => _autoAcceptOrders = value),
                    colors: colors,
                  ),
                  _buildDivider(colors),
                  switchTile(
                    context: context,
                    title: "Location Tracking",
                    subtitle: "Share your location for better service",
                    icon: Assets.icons.shieldCheck,
                    iconColor: colors.accentBlue,
                    value: _locationTracking,
                    onChanged: (value) => setState(() => _locationTracking = value),
                    colors: colors,
                  ),
                  _buildDivider(colors),
                  switchTile(
                    context: context,
                    title: "Sound & Vibrate",
                    subtitle: "Enable sound notifications",
                    icon: Assets.icons.bell,
                    iconColor: colors.accentOrange,
                    value: _soundEnabled,
                    onChanged: (value) => setState(() => _soundEnabled = value),
                    colors: colors,
                  ),
                ],
              ),

              SizedBox(height: 24.h),

              _buildSectionHeader("PRIVACY & SECURITY", colors),
              SizedBox(height: 12.h),
              _buildSettingsCard(
                colors: colors,
                children: [
                  switchTile(
                    context: context,
                    title: "Share Location",
                    subtitle: "Allow location sharing with customers",
                    icon: Assets.icons.shieldCheck,
                    iconColor: colors.accentViolet,
                    value: _shareLocation,
                    onChanged: (value) => setState(() => _shareLocation = value),
                    colors: colors,
                  ),
                  _buildDivider(colors),
                  switchTile(
                    context: context,
                    title: "Show Phone Number",
                    subtitle: "Display your phone number to customers",
                    icon: Assets.icons.phone,
                    iconColor: colors.accentGreen,
                    value: _showPhoneNumber,
                    onChanged: (value) => setState(() => _showPhoneNumber = value),
                    colors: colors,
                  ),
                  _buildDivider(colors),
                  _buildNavigationTile(
                    "Change Password",
                    "Update your account password",
                    Assets.icons.lock,
                    colors.accentOrange,
                    () {},
                    colors,
                  ),
                ],
              ),

              SizedBox(height: 24.h),

              _buildSectionHeader("ACCOUNT", colors),
              SizedBox(height: 12.h),
              _buildSettingsCard(
                colors: colors,
                children: [
                  _buildNavigationTile(
                    "Payment Methods",
                    "Manage payment settings",
                    Assets.icons.creditCard,
                    colors.accentBlue,
                    () {},
                    colors,
                  ),
                  _buildDivider(colors),
                  _buildNavigationTile(
                    "Vehicle Information",
                    "Update vehicle details",
                    Assets.icons.deliveryTruck,
                    colors.accentGreen,
                    () {},
                    colors,
                  ),
                  _buildDivider(colors),
                  _buildNavigationTile(
                    "Bank Account",
                    "Manage bank account details",
                    Assets.icons.dollar,
                    colors.accentViolet,
                    () {},
                    colors,
                  ),
                ],
              ),

              SizedBox(height: 24.h),

              _buildSectionHeader("ABOUT", colors),
              SizedBox(height: 12.h),
              _buildSettingsCard(
                colors: colors,
                children: [
                  _buildNavigationTile(
                    "Terms & Conditions",
                    "Read our terms and conditions",
                    Assets.icons.infoCircle,
                    colors.textPrimary,
                    () {},
                    colors,
                  ),
                  _buildDivider(colors),
                  _buildNavigationTile(
                    "Privacy Policy",
                    "View privacy policy",
                    Assets.icons.shieldCheck,
                    colors.textPrimary,
                    () {},
                    colors,
                  ),
                  _buildDivider(colors),
                  _buildInfoTile("App Version", "1.0.0", Assets.icons.infoCircle, colors.textSecondary, colors),
                ],
              ),

              SizedBox(height: 32.h),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, AppColorsExtension colors) {
    return Text(
      title,
      style: TextStyle(color: colors.textSecondary, fontSize: 11.sp, fontWeight: FontWeight.w600, letterSpacing: 1.2),
    );
  }

  Widget _buildSettingsCard({required List<Widget> children, required AppColorsExtension colors}) {
    return Container(
      decoration: BoxDecoration(
        color: colors.backgroundPrimary,
        borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
        border: Border.all(color: colors.border, width: 1),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildNavigationTile(
    String title,
    String subtitle,
    String icon,
    Color iconColor,
    VoidCallback onTap,
    AppColorsExtension colors,
  ) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8.r),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
              ),
              child: SvgPicture.asset(
                icon,
                package: 'grab_go_shared',
                width: 20.w,
                height: 20.w,
                colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
              ),
            ),
            SizedBox(width: 16.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(color: colors.textPrimary, fontSize: 15.sp, fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    subtitle,
                    style: TextStyle(color: colors.textSecondary, fontSize: 12.sp, fontWeight: FontWeight.w400),
                  ),
                ],
              ),
            ),
            SvgPicture.asset(
              Assets.icons.navArrowRight,
              package: 'grab_go_shared',
              width: 18.w,
              height: 18.w,
              colorFilter: ColorFilter.mode(colors.textSecondary, BlendMode.srcIn),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTile(String title, String value, String icon, Color iconColor, AppColorsExtension colors) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8.r),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
            ),
            child: SvgPicture.asset(
              icon,
              package: 'grab_go_shared',
              width: 20.w,
              height: 20.w,
              colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
            ),
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: Text(
              title,
              style: TextStyle(color: colors.textPrimary, fontSize: 15.sp, fontWeight: FontWeight.w600),
            ),
          ),
          Text(
            value,
            style: TextStyle(color: colors.textSecondary, fontSize: 14.sp, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider(AppColorsExtension colors) {
    return Divider(color: colors.border.withValues(alpha: 0.3), thickness: 1, height: 1, indent: 60.w);
  }
}
