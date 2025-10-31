// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:grab_go_shared/shared/utils/colors.dart';
import 'package:grab_go_shared/shared/widgets/responsive.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool isRestaurantOpen = true;
  bool autoAcceptOrders = false;
  bool notificationsEnabled = true;
  String selectedLanguage = 'English';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isMobile = Responsive.isMobile(context);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: Responsive.getScreenPadding(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Restaurant Status
          _buildSettingsSection('Restaurant Status', [
            _buildSwitchTile(
              'Restaurant Open',
              'Toggle restaurant availability',
              isRestaurantOpen,
              (value) => setState(() => isRestaurantOpen = value),
              Icons.store,
              isDark,
            ),
            _buildSwitchTile(
              'Auto Accept Orders',
              'Automatically accept incoming orders',
              autoAcceptOrders,
              (value) => setState(() => autoAcceptOrders = value),
              Icons.auto_awesome,
              isDark,
            ),
          ], isDark),

          SizedBox(height: Responsive.getCardSpacing(context)),

          // Notifications
          _buildSettingsSection('Notifications', [
            _buildSwitchTile(
              'Push Notifications',
              'Receive notifications for new orders',
              notificationsEnabled,
              (value) => setState(() => notificationsEnabled = value),
              Icons.notifications,
              isDark,
            ),
          ], isDark),

          SizedBox(height: Responsive.getCardSpacing(context)),

          // General Settings
          _buildSettingsSection('General', [
            _buildDropdownTile(
              'Language',
              'Select your preferred language',
              selectedLanguage,
              ['English', 'Spanish', 'French', 'German'],
              (value) => setState(() => selectedLanguage = value!),
              Icons.language,
              isDark,
            ),
          ], isDark),

          SizedBox(height: Responsive.getCardSpacing(context)),

          // Restaurant Information
          _buildRestaurantInfo(isDark, isMobile),

          SizedBox(height: Responsive.getCardSpacing(context)),

          // Action Buttons
          _buildActionButtons(isDark, isMobile),
        ],
      ),
    );
  }

  Widget _buildSettingsSection(String title, List<Widget> children, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(isDark ? 0.3 : 0.05), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.lato(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.white : AppColors.primary,
            ),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildSwitchTile(
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
    IconData icon,
    bool isDark,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.accentOrange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: AppColors.accentOrange, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.lato(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.white : AppColors.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(subtitle, style: GoogleFonts.lato(fontSize: 14, color: AppColors.grey)),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged, activeColor: AppColors.accentOrange),
        ],
      ),
    );
  }

  Widget _buildDropdownTile(
    String title,
    String subtitle,
    String value,
    List<String> options,
    ValueChanged<String?> onChanged,
    IconData icon,
    bool isDark,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.blueAccent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: AppColors.blueAccent, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.lato(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.white : AppColors.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(subtitle, style: GoogleFonts.lato(fontSize: 14, color: AppColors.grey)),
              ],
            ),
          ),
          DropdownButton<String>(
            value: value,
            underline: const SizedBox(),
            style: GoogleFonts.lato(color: isDark ? AppColors.white : AppColors.primary, fontSize: 14),
            dropdownColor: isDark ? AppColors.darkSurface : AppColors.white,
            items: options.map((option) {
              return DropdownMenuItem(value: option, child: Text(option));
            }).toList(),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildRestaurantInfo(bool isDark, bool isMobile) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(isDark ? 0.3 : 0.05), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Restaurant Information',
            style: GoogleFonts.lato(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.white : AppColors.primary,
            ),
          ),
          const SizedBox(height: 16),
          _buildInfoRow('Restaurant Name', 'GrabGo Restaurant', isDark),
          _buildInfoRow('Address', '123 Accra Madina, City, State', isDark),
          _buildInfoRow('Phone', '+233 536997662', isDark),
          _buildInfoRow('Email', 'info@grabgo.com', isDark),
          _buildInfoRow('Opening Hours', '9:00 AM - 10:00 PM', isDark),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  // Edit restaurant info
                },
                splashColor: AppColors.grey.withOpacity(0.2),
                highlightColor: AppColors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkBackground : Colors.transparent,
                    border: Border.all(
                      color: isDark ? AppColors.darkBackground : AppColors.secondaryBackground,
                      width: 1,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.edit, size: 18, color: isDark ? AppColors.white : AppColors.primary),
                      const SizedBox(width: 8),
                      Text(
                        'Edit Information',
                        style: GoogleFonts.lato(
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.white : AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: GoogleFonts.lato(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.grey),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.lato(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: isDark ? AppColors.white : AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(bool isDark, bool isMobile) {
    return Row(
      children: [
        Expanded(
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Settings saved successfully!', style: GoogleFonts.lato(fontWeight: FontWeight.w600)),
                    backgroundColor: AppColors.accentGreen,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                );
              },
              splashColor: AppColors.grey.withOpacity(0.2),
              highlightColor: AppColors.grey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkBackground : Colors.transparent,
                  border: Border.all(color: isDark ? AppColors.darkBackground : AppColors.grey.withAlpha(50), width: 1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.edit, size: 18, color: isDark ? AppColors.white : AppColors.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Reset to Defaults',
                      style: GoogleFonts.lato(
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.white : AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // child: Material(
          //   color: Colors.transparent,
          //   child: InkWell(
          //     onTap: () {
          //       // Reset to defaults
          //     },
          //     splashColor: AppColors.grey.withOpacity(0.2),
          //     highlightColor: AppColors.grey.withOpacity(0.1),
          //     borderRadius: BorderRadius.circular(8),
          //     child: Container(
          //       padding: EdgeInsets.symmetric(vertical: isMobile ? 16 : 20),
          //       decoration: BoxDecoration(
          //         border: Border.all(
          //           color: isDark
          //               ? AppColors.darkSidebar
          //               : AppColors.secondaryBackground,
          //           width: 1,
          //         ),
          //         borderRadius: BorderRadius.circular(8),
          //       ),
          //       child: Center(
          //         child: Text(
          //           'Reset to Defaults',
          //           style: GoogleFonts.lato(
          //             fontSize: 16,
          //             fontWeight: FontWeight.w600,
          //             color: isDark ? AppColors.white : AppColors.primary,
          //           ),
          //         ),
          //       ),
          //     ),
          //   ),
          // ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton(
            onPressed: () {
              // Save settings
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Settings saved successfully!', style: GoogleFonts.lato(fontWeight: FontWeight.w600)),
                  backgroundColor: AppColors.accentOrange,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentOrange,
              foregroundColor: AppColors.white,
              padding: EdgeInsets.symmetric(vertical: isMobile ? 16 : 20),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('Save Settings', style: GoogleFonts.lato(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }
}
