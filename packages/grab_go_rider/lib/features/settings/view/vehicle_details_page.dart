import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';

class VehicleDetailsPage extends StatefulWidget {
  const VehicleDetailsPage({super.key});

  @override
  State<VehicleDetailsPage> createState() => _VehicleDetailsPageState();
}

class _VehicleDetailsPageState extends State<VehicleDetailsPage> {
  String _vehicleType = "Motorcycle";
  String _vehicleMake = "Honda";
  String _vehicleModel = "CG 125";
  String _vehicleYear = "2020";
  String _plateNumber = "GR-1234-20";
  String _color = "Black";
  String _insuranceNumber = "INS-123456789";
  String _insuranceExpiry = "2025-12-31";
  String _registrationNumber = "REG-987654321";
  String _registrationExpiry = "2026-06-30";

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
            "Vehicle Details",
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
              Center(
                child: Container(
                  width: 120.w,
                  height: 120.w,
                  decoration: BoxDecoration(
                    color: colors.accentGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
                    border: Border.all(color: colors.accentGreen.withValues(alpha: 0.3), width: 2),
                  ),
                  child: Center(
                    child: SvgPicture.asset(
                      Assets.icons.deliveryGuyIcon,
                      package: 'grab_go_shared',
                      width: 64.w,
                      height: 64.w,
                      colorFilter: ColorFilter.mode(colors.accentGreen, BlendMode.srcIn),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 24.h),

              _buildSectionHeader("BASIC INFORMATION", colors),
              SizedBox(height: 12.h),
              _buildInfoCard(
                colors: colors,
                label: "Vehicle Type",
                value: _vehicleType,
                icon: Assets.icons.deliveryTruck,
                iconColor: colors.accentGreen,
                isEditing: _isEditing,
                onChanged: (value) => setState(() => _vehicleType = value),
              ),
              SizedBox(height: 12.h),
              _buildInfoCard(
                colors: colors,
                label: "Brand",
                value: _vehicleMake,
                icon: Assets.icons.infoCircle,
                iconColor: colors.accentOrange,
                isEditing: _isEditing,
                onChanged: (value) => setState(() => _vehicleMake = value),
              ),
              SizedBox(height: 12.h),
              _buildInfoCard(
                colors: colors,
                label: "Model",
                value: _vehicleModel,
                icon: Assets.icons.infoCircle,
                iconColor: colors.accentViolet,
                isEditing: _isEditing,
                onChanged: (value) => setState(() => _vehicleModel = value),
              ),
              SizedBox(height: 12.h),
              _buildInfoCard(
                colors: colors,
                label: "Year",
                value: _vehicleYear,
                icon: Assets.icons.calendar,
                iconColor: colors.accentGreen,
                isEditing: _isEditing,
                onChanged: (value) => setState(() => _vehicleYear = value),
              ),
              SizedBox(height: 12.h),
              _buildInfoCard(
                colors: colors,
                label: "Color",
                value: _color,
                icon: Assets.icons.infoCircle,
                iconColor: colors.accentOrange,
                isEditing: _isEditing,
                onChanged: (value) => setState(() => _color = value),
              ),
              SizedBox(height: 32.h),

              _buildSectionHeader("REGISTRATION", colors),
              SizedBox(height: 12.h),
              _buildInfoCard(
                colors: colors,
                label: "Plate Number",
                value: _plateNumber,
                icon: Assets.icons.idCard,
                iconColor: colors.accentGreen,
                isEditing: _isEditing,
                onChanged: (value) => setState(() => _plateNumber = value),
              ),
              SizedBox(height: 12.h),
              _buildInfoCard(
                colors: colors,
                label: "Registration Number",
                value: _registrationNumber,
                icon: Assets.icons.idCard,
                iconColor: colors.accentViolet,
                isEditing: _isEditing,
                onChanged: (value) => setState(() => _registrationNumber = value),
              ),
              SizedBox(height: 12.h),
              _buildInfoCard(
                colors: colors,
                label: "Registration Expiry",
                value: _registrationExpiry,
                icon: Assets.icons.calendar,
                iconColor: colors.accentOrange,
                isEditing: _isEditing,
                onChanged: (value) => setState(() => _registrationExpiry = value),
              ),
              SizedBox(height: 32.h),

              _buildSectionHeader("INSURANCE", colors),
              SizedBox(height: 12.h),
              _buildInfoCard(
                colors: colors,
                label: "Insurance Number",
                value: _insuranceNumber,
                icon: Assets.icons.shieldCheck,
                iconColor: colors.accentGreen,
                isEditing: _isEditing,
                onChanged: (value) => setState(() => _insuranceNumber = value),
              ),
              SizedBox(height: 12.h),
              _buildInfoCard(
                colors: colors,
                label: "Insurance Expiry",
                value: _insuranceExpiry,
                icon: Assets.icons.calendar,
                iconColor: colors.accentOrange,
                isEditing: _isEditing,
                onChanged: (value) => setState(() => _insuranceExpiry = value),
              ),
              SizedBox(height: 32.h),

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
                              content: const Text("Vehicle details updated successfully!"),
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
  }) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: colors.backgroundPrimary,
        borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
        border: Border.all(color: colors.border, width: 1),
      ),
      child: Row(
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
                    ? TextField(
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
