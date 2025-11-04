import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  // Notification settings
  bool _pushNotifications = true;
  bool _orderUpdates = true;
  bool _bonusAlerts = true;
  bool _promotionalNotifications = false;

  // App preferences
  bool _darkMode = false;
  String _selectedLanguage = 'English';

  // Delivery settings
  bool _autoAcceptOrders = false;
  bool _locationTracking = true;
  bool _soundEnabled = true;

  // Privacy settings
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
          leading: Container(
            margin: EdgeInsets.all(8.w),
            decoration: BoxDecoration(
              color: colors.backgroundSecondary,
              shape: BoxShape.circle,
              border: Border.all(color: colors.border.withValues(alpha: 0.3), width: 1),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => context.pop(),
                customBorder: const CircleBorder(),
                child: Padding(
                  padding: EdgeInsets.all(10.r),
                  child: SvgPicture.asset(
                    Assets.icons.navArrowLeft,
                    package: 'grab_go_shared',
                    colorFilter: ColorFilter.mode(colors.textPrimary, BlendMode.srcIn),
                  ),
                ),
              ),
            ),
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
              // Notifications Section
              _buildSectionHeader("NOTIFICATIONS", colors),
              SizedBox(height: 12.h),
              _buildSettingsCard(
                colors: colors,
                children: [
                  _buildSwitchTile(
                    "Push Notifications",
                    "Receive push notifications",
                    Assets.icons.bell,
                    colors.accentOrange,
                    _pushNotifications,
                    (value) => setState(() => _pushNotifications = value),
                    colors,
                  ),
                  _buildDivider(colors),
                  _buildSwitchTile(
                    "Order Updates",
                    "Get notified about new orders",
                    Assets.icons.deliveryTruck,
                    colors.accentGreen,
                    _orderUpdates,
                    (value) => setState(() => _orderUpdates = value),
                    colors,
                  ),
                  _buildDivider(colors),
                  _buildSwitchTile(
                    "Bonus Alerts",
                    "Notifications for bonuses and rewards",
                    Assets.icons.gift,
                    colors.accentViolet,
                    _bonusAlerts,
                    (value) => setState(() => _bonusAlerts = value),
                    colors,
                  ),
                  _buildDivider(colors),
                  _buildSwitchTile(
                    "Promotional Notifications",
                    "Receive offers and promotions",
                    Assets.icons.flame,
                    colors.accentBlue,
                    _promotionalNotifications,
                    (value) => setState(() => _promotionalNotifications = value),
                    colors,
                  ),
                ],
              ),

              SizedBox(height: 24.h),

              // App Preferences Section
              _buildSectionHeader("APP PREFERENCES", colors),
              SizedBox(height: 12.h),
              _buildSettingsCard(
                colors: colors,
                children: [
                  _buildSwitchTile(
                    "Dark Mode",
                    "Switch to dark theme",
                    Assets.icons.halfMoon,
                    colors.accentBlue,
                    _darkMode,
                    (value) => setState(() => _darkMode = value),
                    colors,
                  ),
                  _buildDivider(colors),
                  _buildNavigationTile("Language", _selectedLanguage, Assets.icons.infoCircle, colors.accentGreen, () {
                    // Navigate to language selection
                  }, colors),
                ],
              ),

              SizedBox(height: 24.h),

              // Delivery Settings Section
              _buildSectionHeader("DELIVERY SETTINGS", colors),
              SizedBox(height: 12.h),
              _buildSettingsCard(
                colors: colors,
                children: [
                  _buildSwitchTile(
                    "Auto Accept Orders",
                    "Automatically accept incoming orders",
                    Assets.icons.deliveryTruck,
                    colors.accentGreen,
                    _autoAcceptOrders,
                    (value) => setState(() => _autoAcceptOrders = value),
                    colors,
                  ),
                  _buildDivider(colors),
                  _buildSwitchTile(
                    "Location Tracking",
                    "Share your location for better service",
                    Assets.icons.shieldCheck,
                    colors.accentBlue,
                    _locationTracking,
                    (value) => setState(() => _locationTracking = value),
                    colors,
                  ),
                  _buildDivider(colors),
                  _buildSwitchTile(
                    "Sound & Vibrate",
                    "Enable sound notifications",
                    Assets.icons.bell,
                    colors.accentOrange,
                    _soundEnabled,
                    (value) => setState(() => _soundEnabled = value),
                    colors,
                  ),
                ],
              ),

              SizedBox(height: 24.h),

              // Privacy & Security Section
              _buildSectionHeader("PRIVACY & SECURITY", colors),
              SizedBox(height: 12.h),
              _buildSettingsCard(
                colors: colors,
                children: [
                  _buildSwitchTile(
                    "Share Location",
                    "Allow location sharing with customers",
                    Assets.icons.shieldCheck,
                    colors.accentViolet,
                    _shareLocation,
                    (value) => setState(() => _shareLocation = value),
                    colors,
                  ),
                  _buildDivider(colors),
                  _buildSwitchTile(
                    "Show Phone Number",
                    "Display your phone number to customers",
                    Assets.icons.phone,
                    colors.accentGreen,
                    _showPhoneNumber,
                    (value) => setState(() => _showPhoneNumber = value),
                    colors,
                  ),
                  _buildDivider(colors),
                  _buildNavigationTile(
                    "Change Password",
                    "Update your account password",
                    Assets.icons.lock,
                    colors.accentOrange,
                    () {
                      // Navigate to change password
                    },
                    colors,
                  ),
                ],
              ),

              SizedBox(height: 24.h),

              // Account Section
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
                    () {
                      // Navigate to payment methods
                    },
                    colors,
                  ),
                  _buildDivider(colors),
                  _buildNavigationTile(
                    "Vehicle Information",
                    "Update vehicle details",
                    Assets.icons.deliveryTruck,
                    colors.accentGreen,
                    () {
                      // Navigate to vehicle info
                    },
                    colors,
                  ),
                  _buildDivider(colors),
                  _buildNavigationTile(
                    "Bank Account",
                    "Manage bank account details",
                    Assets.icons.dollar,
                    colors.accentViolet,
                    () {
                      // Navigate to bank account
                    },
                    colors,
                  ),
                ],
              ),

              SizedBox(height: 24.h),

              // About Section
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
                    () {
                      // Navigate to terms
                    },
                    colors,
                  ),
                  _buildDivider(colors),
                  _buildNavigationTile(
                    "Privacy Policy",
                    "View privacy policy",
                    Assets.icons.shieldCheck,
                    colors.textPrimary,
                    () {
                      // Navigate to privacy policy
                    },
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

  Widget _buildSwitchTile(
    String title,
    String subtitle,
    String icon,
    Color iconColor,
    bool value,
    ValueChanged<bool> onChanged,
    AppColorsExtension colors,
  ) {
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
          Switch.adaptive(value: value, onChanged: onChanged),
        ],
      ),
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
