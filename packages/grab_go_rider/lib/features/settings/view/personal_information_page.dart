import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';

class PersonalInformationPage extends StatefulWidget {
  const PersonalInformationPage({super.key});

  @override
  State<PersonalInformationPage> createState() => _PersonalInformationPageState();
}

class _PersonalInformationPageState extends State<PersonalInformationPage> {
  // Personal information
  String _fullName = "John Mensah";
  String _email = "john.mensah@example.com";
  String _phoneNumber = "+233 123 456 789";
  String _dateOfBirth = "1990-05-15";
  String _address = "123 Main Street, East Legon, Accra";
  String _city = "Accra";
  String _country = "Ghana";
  String _emergencyContactName = "Jane Mensah";
  String _emergencyContactPhone = "+233 987 654 321";
  String _nationalId = "GHA-123456789-0";

  bool _isEditing = false;

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
            "Personal Information",
            style: TextStyle(
              fontFamily: "Lato",
              package: "grab_go_shared",
              color: colors.textPrimary,
              fontSize: 18.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
          centerTitle: true,
          actions: [
            if (!_isEditing)
              IconButton(
                icon: SvgPicture.asset(
                  Assets.icons.edit,
                  package: 'grab_go_shared',
                  width: 24.w,
                  height: 24.w,
                  colorFilter: ColorFilter.mode(colors.textPrimary, BlendMode.srcIn),
                ),
                onPressed: () {
                  setState(() {
                    _isEditing = true;
                  });
                },
              ),
          ],
        ),
        body: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profile Avatar Section
              Center(
                child: Stack(
                  children: [
                    Container(
                      width: 100.w,
                      height: 100.w,
                      decoration: BoxDecoration(
                        color: colors.accentGreen.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                        border: Border.all(color: colors.accentGreen.withValues(alpha: 0.3), width: 2),
                      ),
                      child: Center(
                        child: SvgPicture.asset(
                          Assets.icons.user,
                          package: 'grab_go_shared',
                          width: 50.w,
                          height: 50.w,
                          colorFilter: ColorFilter.mode(colors.accentGreen, BlendMode.srcIn),
                        ),
                      ),
                    ),
                    if (_isEditing)
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 32.w,
                          height: 32.w,
                          decoration: BoxDecoration(
                            color: colors.accentGreen,
                            shape: BoxShape.circle,
                            border: Border.all(color: colors.backgroundPrimary, width: 2),
                          ),
                          child: Center(
                            child: Icon(Icons.camera_alt, size: 16.w, color: Colors.white),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              SizedBox(height: 24.h),

              // Personal Details Section
              _buildSectionHeader("PERSONAL DETAILS", colors),
              SizedBox(height: 12.h),
              _buildInfoCard(
                colors: colors,
                label: "Full Name",
                value: _fullName,
                icon: Assets.icons.user,
                iconColor: colors.accentGreen,
                isEditing: _isEditing,
                onChanged: (value) => setState(() => _fullName = value),
              ),
              SizedBox(height: 12.h),
              _buildInfoCard(
                colors: colors,
                label: "Email",
                value: _email,
                icon: Assets.icons.mail,
                iconColor: colors.accentOrange,
                isEditing: _isEditing,
                onChanged: (value) => setState(() => _email = value),
              ),
              SizedBox(height: 12.h),
              _buildInfoCard(
                colors: colors,
                label: "Phone Number",
                value: _phoneNumber,
                icon: Assets.icons.phone,
                iconColor: colors.accentViolet,
                isEditing: _isEditing,
                onChanged: (value) => setState(() => _phoneNumber = value),
              ),
              SizedBox(height: 12.h),
              _buildInfoCard(
                colors: colors,
                label: "Date of Birth",
                value: _dateOfBirth,
                icon: Assets.icons.calendar,
                iconColor: colors.accentGreen,
                isEditing: _isEditing,
                onChanged: (value) => setState(() => _dateOfBirth = value),
              ),
              SizedBox(height: 12.h),
              _buildInfoCard(
                colors: colors,
                label: "National ID",
                value: _nationalId,
                icon: Assets.icons.idCard,
                iconColor: colors.accentOrange,
                isEditing: _isEditing,
                onChanged: (value) => setState(() => _nationalId = value),
              ),
              SizedBox(height: 32.h),

              // Address Information
              _buildSectionHeader("ADDRESS", colors),
              SizedBox(height: 12.h),
              _buildInfoCard(
                colors: colors,
                label: "Address",
                value: _address,
                icon: Assets.icons.mapPin,
                iconColor: colors.accentGreen,
                isEditing: _isEditing,
                onChanged: (value) => setState(() => _address = value),
                isMultiline: true,
              ),
              SizedBox(height: 12.h),
              Row(
                children: [
                  Expanded(
                    child: _buildInfoCard(
                      colors: colors,
                      label: "City",
                      value: _city,
                      icon: Assets.icons.mapPin,
                      iconColor: colors.accentOrange,
                      isEditing: _isEditing,
                      onChanged: (value) => setState(() => _city = value),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: _buildInfoCard(
                      colors: colors,
                      label: "Country",
                      value: _country,
                      icon: Assets.icons.mapPin,
                      iconColor: colors.accentViolet,
                      isEditing: _isEditing,
                      onChanged: (value) => setState(() => _country = value),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 32.h),

              // Emergency Contact
              _buildSectionHeader("EMERGENCY CONTACT", colors),
              SizedBox(height: 12.h),
              _buildInfoCard(
                colors: colors,
                label: "Contact Name",
                value: _emergencyContactName,
                icon: Assets.icons.user,
                iconColor: colors.accentGreen,
                isEditing: _isEditing,
                onChanged: (value) => setState(() => _emergencyContactName = value),
              ),
              SizedBox(height: 12.h),
              _buildInfoCard(
                colors: colors,
                label: "Contact Phone",
                value: _emergencyContactPhone,
                icon: Assets.icons.phone,
                iconColor: colors.accentOrange,
                isEditing: _isEditing,
                onChanged: (value) => setState(() => _emergencyContactPhone = value),
              ),
              SizedBox(height: 32.h),

              // Action Buttons
              if (_isEditing) ...[
                Row(
                  children: [
                    Expanded(
                      child: _buildActionButton(
                        label: "Cancel",
                        backgroundColor: colors.backgroundSecondary,
                        textColor: colors.textPrimary,
                        borderColor: colors.border,
                        onPressed: () {
                          setState(() {
                            _isEditing = false;
                          });
                        },
                        colors: colors,
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: _buildActionButton(
                        label: "Save Changes",
                        backgroundColor: colors.accentGreen,
                        textColor: Colors.white,
                        borderColor: colors.accentGreen,
                        onPressed: () {
                          setState(() {
                            _isEditing = false;
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text("Personal information updated successfully!"),
                              backgroundColor: colors.accentGreen,
                            ),
                          );
                        },
                        colors: colors,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 32.h),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, AppColorsExtension colors) {
    return Text(
      title,
      style: TextStyle(color: colors.textSecondary, fontSize: 12.sp, fontWeight: FontWeight.w600, letterSpacing: 0.5),
    );
  }

  Widget _buildInfoCard({
    required AppColorsExtension colors,
    required String label,
    required String value,
    required String icon,
    required Color iconColor,
    required bool isEditing,
    required Function(String) onChanged,
    bool isMultiline = false,
  }) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: colors.backgroundPrimary,
        borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
        border: Border.all(color: colors.border, width: 1),
      ),
      child: Row(
        crossAxisAlignment: isMultiline ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          Container(
            width: 40.w,
            height: 40.w,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
            ),
            child: Center(
              child: SvgPicture.asset(
                icon,
                package: 'grab_go_shared',
                width: 20.w,
                height: 20.w,
                colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
              ),
            ),
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(color: colors.textSecondary, fontSize: 12.sp, fontWeight: FontWeight.w500),
                ),
                SizedBox(height: 4.h),
                isEditing
                    ? isMultiline
                          ? TextField(
                              controller: TextEditingController(text: value),
                              maxLines: 2,
                              style: TextStyle(color: colors.textPrimary, fontSize: 15.sp, fontWeight: FontWeight.w600),
                              decoration: InputDecoration(
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                                border: InputBorder.none,
                                enabledBorder: UnderlineInputBorder(
                                  borderSide: BorderSide(color: colors.accentGreen, width: 1.5),
                                ),
                                focusedBorder: UnderlineInputBorder(
                                  borderSide: BorderSide(color: colors.accentGreen, width: 2),
                                ),
                              ),
                              onChanged: onChanged,
                            )
                          : TextField(
                              controller: TextEditingController(text: value),
                              style: TextStyle(color: colors.textPrimary, fontSize: 15.sp, fontWeight: FontWeight.w600),
                              decoration: InputDecoration(
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                                border: InputBorder.none,
                                enabledBorder: UnderlineInputBorder(
                                  borderSide: BorderSide(color: colors.accentGreen, width: 1.5),
                                ),
                                focusedBorder: UnderlineInputBorder(
                                  borderSide: BorderSide(color: colors.accentGreen, width: 2),
                                ),
                              ),
                              onChanged: onChanged,
                            )
                    : Text(
                        value,
                        style: TextStyle(color: colors.textPrimary, fontSize: 15.sp, fontWeight: FontWeight.w600),
                        maxLines: isMultiline ? 2 : 1,
                        overflow: TextOverflow.ellipsis,
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required Color backgroundColor,
    required Color textColor,
    required Color borderColor,
    required VoidCallback onPressed,
    required AppColorsExtension colors,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 14.h),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
            border: Border.all(color: borderColor, width: 1),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(color: textColor, fontSize: 15.sp, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ),
    );
  }
}
