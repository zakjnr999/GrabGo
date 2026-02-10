import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_customer/shared/services/image_cache_service.dart';
import 'package:grab_go_customer/shared/services/location_service.dart';
import 'package:grab_go_customer/shared/viewmodels/settings_provider.dart';
import 'package:grab_go_customer/shared/viewmodels/theme_provider.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/shared/widgets/custom_slider.dart';
import 'package:provider/provider.dart';
import 'package:grab_go_shared/grub_go_shared.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String _cacheSize = 'Calculating...';
  bool _socialExpanded = false;
  bool _promosExpanded = false;
  bool _otherExpanded = false;

  @override
  void initState() {
    super.initState();
    _calculateCacheSize();
  }

  Future<void> _calculateCacheSize() async {
    final size = await ImageCacheService.getCacheSize();
    if (mounted) {
      setState(() {
        _cacheSize = _formatBytes(size);
      });
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> _clearCache() async {
    final shouldClear = await AppDialog.show(
      context: context,
      title: 'Clear Cache',
      message: 'This will clear all cached images and data ($_cacheSize). This action cannot be undone.',
      type: AppDialogType.warning,
      primaryButtonText: 'Clear',
      secondaryButtonText: 'Cancel',
      primaryButtonColor: Colors.red,
      onPrimaryPressed: () => Navigator.of(context).pop(true),
      onSecondaryPressed: () => Navigator.of(context).pop(false),
    );

    if (shouldClear == true) {
      try {
        await ImageCacheService.clearAllCache();
        await _calculateCacheSize();
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Cache cleared successfully'), backgroundColor: Colors.green));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Failed to clear cache: $e'), backgroundColor: Colors.red));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<ThemeProvider, SettingsProvider>(
      builder: (context, themeProvider, settingsProvider, child) {
        final colors = context.appColors;
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final padding = MediaQuery.paddingOf(context);

        final systemUiOverlayStyle = SystemUiOverlayStyle(
          statusBarColor: colors.backgroundPrimary,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          systemNavigationBarColor: colors.backgroundPrimary,
          systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        );

        SystemChrome.setSystemUIOverlayStyle(systemUiOverlayStyle);

        return Scaffold(
          backgroundColor: colors.backgroundPrimary,
          body: Column(
            children: [
              Padding(
                padding: EdgeInsets.only(top: padding.top + 10, left: 20.w, right: 20.w, bottom: 16.h),
                child: Row(
                  children: [
                    Container(
                      height: 44,
                      width: 44,
                      decoration: BoxDecoration(
                        color: colors.backgroundSecondary,
                        shape: BoxShape.circle,
                        border: Border.all(color: colors.inputBorder.withValues(alpha: 0.3), width: 0.5),
                        boxShadow: [
                          BoxShadow(
                            color: isDark ? Colors.black.withAlpha(20) : Colors.black.withAlpha(5),
                            spreadRadius: 0,
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
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
                    SizedBox(width: 16.w),
                    Text(
                      "Settings",
                      style: TextStyle(
                        fontFamily: "Lato",
                        package: 'grab_go_shared',
                        color: colors.textPrimary,
                        fontSize: 20.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Divider(color: colors.backgroundSecondary, height: 1.h, thickness: 1),
              Expanded(
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: 12.h),
                      _buildSectionHeader("Appearance", colors),
                      _buildSection(isDark, colors, [
                        _buildThemeSelector(themeProvider, colors, isDark),
                        _buildFontSizeSelector(settingsProvider, colors),
                      ]),
                      SizedBox(height: 16.h),

                      _buildSectionHeader("Notifications", colors),
                      _buildSection(isDark, colors, [
                        _buildSubsectionHeader("Essential", colors),
                        _buildToggleTile("Order Updates", Assets.icons.package, settingsProvider.orderUpdatesEnabled, (
                          value,
                        ) {
                          settingsProvider.setOrderUpdates(value);
                        }, colors),
                        _buildToggleTile(
                          "Delivery Alerts",
                          Assets.icons.deliveryTruck,
                          settingsProvider.deliveryUpdatesEnabled,
                          (value) {
                            settingsProvider.setDeliveryUpdates(value);
                          },
                          colors,
                        ),
                        _buildToggleTile(
                          "Payment Confirmations",
                          Assets.icons.alarm,
                          settingsProvider.paymentUpdatesEnabled,
                          (value) {
                            settingsProvider.setPaymentUpdates(value);
                          },
                          colors,
                        ),

                        _buildCollapsibleSection(
                          "Social",
                          Assets.icons.chatBubble,
                          [
                            _buildToggleTile(
                              "Chat Messages",
                              Assets.icons.chatBubble,
                              settingsProvider.chatMessagesEnabled,
                              (value) {
                                settingsProvider.setChatMessages(value);
                              },
                              colors,
                            ),
                            _buildToggleTile(
                              "Comment Replies",
                              Assets.icons.chatBubble,
                              settingsProvider.commentRepliesEnabled,
                              (value) {
                                settingsProvider.setCommentReplies(value);
                              },
                              colors,
                            ),
                            _buildToggleTile(
                              "Comment Reactions",
                              Assets.icons.heart,
                              settingsProvider.commentReactionsEnabled,
                              (value) {
                                settingsProvider.setCommentReactions(value);
                              },
                              colors,
                            ),
                          ],
                          colors,
                          isDark,
                          _socialExpanded,
                          (expanded) => setState(() => _socialExpanded = expanded),
                        ),

                        // Promotions & Offers (Collapsible)
                        _buildCollapsibleSection(
                          "Promotions & Offers",
                          Assets.icons.gift,
                          [
                            _buildToggleTile(
                              "All Promotions",
                              Assets.icons.gift,
                              settingsProvider.promoNotificationsEnabled,
                              (value) {
                                settingsProvider.setPromoNotifications(value);
                              },
                              colors,
                            ),
                            _buildToggleTile(
                              "Cart Reminders",
                              Assets.icons.cart,
                              settingsProvider.cartRemindersEnabled,
                              (value) {
                                settingsProvider.setCartReminders(value);
                              },
                              colors,
                            ),
                            _buildToggleTile(
                              "Favorites Reminders",
                              Assets.icons.heart,
                              settingsProvider.favoritesRemindersEnabled,
                              (value) {
                                settingsProvider.setFavoritesReminders(value);
                              },
                              colors,
                            ),
                            _buildToggleTile(
                              "Reorder Suggestions",
                              Assets.icons.refresh,
                              settingsProvider.reorderSuggestionsEnabled,
                              (value) {
                                settingsProvider.setReorderSuggestions(value);
                              },
                              colors,
                            ),
                            _buildToggleTile(
                              "Re-engagement Reminders",
                              Assets.icons.bell,
                              settingsProvider.reengagementRemindersEnabled,
                              (value) {
                                settingsProvider.setReengagementReminders(value);
                              },
                              colors,
                            ),
                          ],
                          colors,
                          isDark,
                          _promosExpanded,
                          (expanded) => setState(() => _promosExpanded = expanded),
                        ),

                        _buildCollapsibleSection(
                          "Other",
                          Assets.icons.settings,
                          [
                            _buildToggleTile(
                              "Referral Updates",
                              Assets.icons.group,
                              settingsProvider.referralUpdatesEnabled,
                              (value) {
                                settingsProvider.setReferralUpdates(value);
                              },
                              colors,
                            ),
                            _buildToggleTile(
                              "System Updates",
                              Assets.icons.bell,
                              settingsProvider.systemUpdatesEnabled,
                              (value) {
                                settingsProvider.setSystemUpdates(value);
                              },
                              colors,
                            ),
                            _buildToggleTile(
                              "Notification Sound",
                              Assets.icons.soundHigh,
                              settingsProvider.notificationSoundEnabled,
                              (value) {
                                settingsProvider.setNotificationSound(value);
                              },
                              colors,
                            ),
                          ],
                          colors,
                          isDark,
                          _otherExpanded,
                          (expanded) => setState(() => _otherExpanded = expanded),
                        ),
                      ]),
                      SizedBox(height: 24.h),

                      _buildSectionHeader("Privacy & Security", colors),
                      _buildSection(isDark, colors, [
                        _buildSubsectionHeader("Location Services", colors),
                        _buildActionTile("Permission Status", Assets.icons.lock, "Manage permissions", () async {
                          final hasPermission = await LocationService.hasPermission();
                          if (!hasPermission) {
                            await LocationService.openAppSettings();
                          }
                        }, colors),
                        _buildActionTile(
                          "Clear Location Cache",
                          Assets.icons.brushCleaning,
                          "Remove cached location",
                          () async {
                            LocationService.clearCache();
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Location cache cleared'), backgroundColor: Colors.green),
                              );
                            }
                          },
                          colors,
                        ),

                        _buildSubsectionHeader("Data & Storage", colors),
                        _buildActionTile("Clear Cache", Assets.icons.brushCleaning, _cacheSize, _clearCache, colors),
                        _buildActionTile(
                          "Clear Search History",
                          Assets.icons.brushCleaning,
                          "Remove recent searches",
                          () {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Search history cleared'), backgroundColor: Colors.green),
                              );
                            }
                          },
                          colors,
                        ),
                        _buildActionTile("Download My Data", Assets.icons.download, "Export your data", () {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Data export feature coming soon'),
                                backgroundColor: Colors.blue,
                              ),
                            );
                          }
                        }, colors),

                        _buildSubsectionHeader("Account Security", colors),
                        _buildActionTile("Change Password", Assets.icons.lock, "Update your password", () {
                          context.push("/orderTracking");
                        }, colors),
                        _buildToggleTile(
                          "Biometric Login",
                          Assets.icons.fingerprintScan,
                          settingsProvider.biometricLoginEnabled,
                          (value) {
                            settingsProvider.setBiometricLogin(value);
                          },
                          colors,
                        ),
                      ]),
                      SizedBox(height: 24.h),

                      _buildSectionHeader("App Preferences", colors),
                      _buildSection(isDark, colors, [
                        _buildLanguageSelector(settingsProvider, colors),
                        _buildActionTile(
                          "Default Pickup Location",
                          Assets.icons.mapPin,
                          settingsProvider.defaultPickupLocation.isEmpty
                              ? "Set location"
                              : settingsProvider.defaultPickupLocation,
                          () {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Location picker coming soon'),
                                  backgroundColor: Colors.blue,
                                ),
                              );
                            }
                          },
                          colors,
                        ),
                      ]),
                      SizedBox(height: 24.h),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(String title, AppColorsExtension colors) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
      color: colors.backgroundSecondary,
      child: Text(
        title,
        style: TextStyle(color: colors.textPrimary, fontSize: 16.sp, fontWeight: FontWeight.w800),
      ),
    );
  }

  Widget _buildSection(bool isDark, AppColorsExtension colors, List<Widget> children) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 8.r, horizontal: 0.w),
      decoration: BoxDecoration(
        color: colors.backgroundPrimary,
        borderRadius: BorderRadius.circular(KBorderSize.borderRadius15),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildToggleTile(String title, String icon, bool value, Function(bool) onChanged, AppColorsExtension colors) {
    return Material(
      color: Colors.transparent,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 14.h),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(fontSize: 14.sp, color: colors.textPrimary, fontWeight: FontWeight.w600),
              ),
            ),
            CustomSwitch(
              value: value,
              onChanged: (newValue) {
                HapticFeedback.lightImpact();
                onChanged(newValue);
              },
              activeColor: colors.accentOrange,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionTile(String title, String icon, String subtitle, VoidCallback onTap, AppColorsExtension colors) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: colors.backgroundSecondary,
        highlightColor: colors.backgroundSecondary,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 14.h),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(fontSize: 14.sp, color: colors.textPrimary, fontWeight: FontWeight.w600),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 12.sp, color: colors.textSecondary, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              SvgPicture.asset(
                Assets.icons.navArrowRight,
                package: "grab_go_shared",
                height: 18.h,
                width: 18.w,
                colorFilter: ColorFilter.mode(colors.textSecondary, BlendMode.srcIn),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThemeSelector(ThemeProvider themeProvider, AppColorsExtension colors, bool isDark) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 14.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                "Theme Mode",
                style: TextStyle(fontSize: 14.sp, color: colors.textPrimary, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Container(
            decoration: BoxDecoration(
              color: colors.backgroundSecondary,
              borderRadius: BorderRadius.circular(KBorderSize.borderMedium),
            ),
            child: Row(
              children: [
                _buildThemeOption("Light", ThemeMode.light, themeProvider, colors),
                _buildThemeOption("Dark", ThemeMode.dark, themeProvider, colors),
                _buildThemeOption("System", ThemeMode.system, themeProvider, colors),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeOption(String label, ThemeMode mode, ThemeProvider themeProvider, AppColorsExtension colors) {
    final isSelected = themeProvider.themeMode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () => themeProvider.setThemeMode(mode),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 12.h),
          decoration: BoxDecoration(
            color: isSelected ? colors.accentOrange : Colors.transparent,
            borderRadius: BorderRadius.circular(KBorderSize.borderMedium),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13.sp,
                color: isSelected ? Colors.white : colors.textSecondary,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFontSizeSelector(SettingsProvider settingsProvider, AppColorsExtension colors) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 14.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                "Font Size",
                style: TextStyle(fontSize: 14.sp, color: colors.textPrimary, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              Text(
                settingsProvider.fontSizeName,
                style: TextStyle(fontSize: 13.sp, color: colors.textSecondary, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 5.h,
              activeTrackColor: colors.accentOrange,
              inactiveTrackColor: colors.backgroundSecondary,
              thumbColor: colors.accentOrange,
              thumbShape: CustomSliderThumbShape(enabledThumbRadius: 16.r, thumbColor: colors.accentOrange),
              overlayColor: colors.accentOrange.withValues(alpha: 0.2),
            ),
            child: Slider(
              value: settingsProvider.fontScale,
              min: 0.85,
              max: 1.3,
              divisions: 3,
              onChanged: (value) {
                settingsProvider.setFontScale(value);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageSelector(SettingsProvider settingsProvider, AppColorsExtension colors) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 14.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                "Language",
                style: TextStyle(fontSize: 14.sp, color: colors.textPrimary, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Container(
            decoration: BoxDecoration(
              color: colors.backgroundSecondary,
              borderRadius: BorderRadius.circular(KBorderSize.borderMedium),
            ),
            child: Row(
              children: [
                _buildLanguageOption("English", "en", settingsProvider, colors),
                _buildLanguageOption("Twi", "tw", settingsProvider, colors),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageOption(String label, String code, SettingsProvider settingsProvider, AppColorsExtension colors) {
    final isSelected = settingsProvider.language == code;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          settingsProvider.setLanguage(code);
        },
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 12.h),
          decoration: BoxDecoration(
            color: isSelected ? colors.accentOrange : Colors.transparent,
            borderRadius: BorderRadius.circular(KBorderSize.borderMedium),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13.sp,
                color: isSelected ? Colors.white : colors.textSecondary,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSubsectionHeader(String title, AppColorsExtension colors) {
    return Padding(
      padding: EdgeInsets.only(left: 20.w, right: 20.w, top: 16.h, bottom: 8.h),
      child: Text(
        title,
        style: TextStyle(color: colors.textSecondary, fontSize: 12.sp, fontWeight: FontWeight.w700, letterSpacing: 0.5),
      ),
    );
  }

  Widget _buildCollapsibleSection(
    String title,
    String icon,
    List<Widget> children,
    AppColorsExtension colors,
    bool isDark,
    bool isExpanded,
    ValueChanged<bool> onExpansionChanged,
  ) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 4.h),
        childrenPadding: EdgeInsets.only(left: 12.w),
        initiallyExpanded: isExpanded,
        onExpansionChanged: onExpansionChanged,
        trailing: SvgPicture.asset(
          Assets.icons.navArrowDown,
          package: "grab_go_shared",
          height: 18.h,
          width: 18.w,
          colorFilter: ColorFilter.mode(colors.textSecondary, BlendMode.srcIn),
        ),
        title: Text(
          title,
          style: TextStyle(fontSize: 14.sp, color: colors.textPrimary, fontWeight: FontWeight.w700),
        ),
        iconColor: colors.textSecondary,
        collapsedIconColor: colors.textSecondary,
        children: children,
      ),
    );
  }
}
