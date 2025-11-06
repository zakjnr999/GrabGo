import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';

class BankAccountPage extends StatefulWidget {
  const BankAccountPage({super.key});

  @override
  State<BankAccountPage> createState() => _BankAccountPageState();
}

class _BankAccountPageState extends State<BankAccountPage> {
  String _accountHolderName = "John Mensah";
  String _bankName = "Ghana Commercial Bank";
  String _accountNumber = "1234567890";
  String _accountType = "Savings";
  String _branchName = "East Legon Branch";
  String _swiftCode = "GCBIGHAC";
  String _routingNumber = "123456";

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
            "Bank Account",
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
                      Assets.icons.creditCard,
                      package: 'grab_go_shared',
                      width: 64.w,
                      height: 64.w,
                      colorFilter: ColorFilter.mode(colors.accentGreen, BlendMode.srcIn),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 24.h),

              _buildSectionHeader("ACCOUNT INFORMATION", colors),
              SizedBox(height: 12.h),
              _buildInfoCard(
                colors: colors,
                label: "Account Holder Name",
                value: _accountHolderName,
                icon: Assets.icons.user,
                iconColor: colors.accentGreen,
                isEditing: _isEditing,
                onChanged: (value) => setState(() => _accountHolderName = value),
              ),
              SizedBox(height: 12.h),
              _buildInfoCard(
                colors: colors,
                label: "Bank Name",
                value: _bankName,
                icon: Assets.icons.creditCard,
                iconColor: colors.accentOrange,
                isEditing: _isEditing,
                onChanged: (value) => setState(() => _bankName = value),
              ),
              SizedBox(height: 12.h),
              _buildInfoCard(
                colors: colors,
                label: "Account Number",
                value: _accountNumber,
                icon: Assets.icons.creditCard,
                iconColor: colors.accentViolet,
                isEditing: _isEditing,
                onChanged: (value) => setState(() => _accountNumber = value),
                isSecure: !_isEditing,
              ),
              SizedBox(height: 12.h),
              _buildInfoCard(
                colors: colors,
                label: "Account Type",
                value: _accountType,
                icon: Assets.icons.infoCircle,
                iconColor: colors.accentGreen,
                isEditing: _isEditing,
                onChanged: (value) => setState(() => _accountType = value),
                isDropdown: _isEditing,
                dropdownOptions: ["Savings", "Current", "Checking"],
              ),
              SizedBox(height: 32.h),

              _buildSectionHeader("BANK DETAILS", colors),
              SizedBox(height: 12.h),
              _buildInfoCard(
                colors: colors,
                label: "Branch Name",
                value: _branchName,
                icon: Assets.icons.mapPin,
                iconColor: colors.accentGreen,
                isEditing: _isEditing,
                onChanged: (value) => setState(() => _branchName = value),
              ),
              SizedBox(height: 12.h),
              _buildInfoCard(
                colors: colors,
                label: "SWIFT Code",
                value: _swiftCode,
                icon: Assets.icons.infoCircle,
                iconColor: colors.accentOrange,
                isEditing: _isEditing,
                onChanged: (value) => setState(() => _swiftCode = value),
              ),
              SizedBox(height: 12.h),
              _buildInfoCard(
                colors: colors,
                label: "Routing Number",
                value: _routingNumber,
                icon: Assets.icons.infoCircle,
                iconColor: colors.accentViolet,
                isEditing: _isEditing,
                onChanged: (value) => setState(() => _routingNumber = value),
              ),
              SizedBox(height: 32.h),

              Container(
                padding: EdgeInsets.all(16.w),
                decoration: BoxDecoration(
                  color: colors.accentOrange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
                  border: Border.all(color: colors.accentOrange.withValues(alpha: 0.3), width: 1),
                ),
                child: Row(
                  children: [
                    SvgPicture.asset(
                      Assets.icons.infoCircle,
                      package: 'grab_go_shared',
                      width: 20.w,
                      height: 20.w,
                      colorFilter: ColorFilter.mode(colors.accentOrange, BlendMode.srcIn),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Text(
                        "Your bank account details are encrypted and secure. Payments will be processed to this account.",
                        style: TextStyle(color: colors.textPrimary, fontSize: 12.sp, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
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
                              content: const Text("Bank account details updated successfully!"),
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
    bool isSecure = false,
    bool isDropdown = false,
    List<String>? dropdownOptions,
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
                    ? isDropdown && dropdownOptions != null
                          ? DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: value,
                                isDense: true,
                                icon: Icon(Icons.arrow_drop_down, color: colors.accentGreen, size: 20.w),
                                style: TextStyle(
                                  color: colors.textPrimary,
                                  fontSize: 15.sp,
                                  fontWeight: FontWeight.w600,
                                ),
                                items: dropdownOptions.map((String option) {
                                  return DropdownMenuItem<String>(value: option, child: Text(option));
                                }).toList(),
                                onChanged: (String? newValue) {
                                  if (newValue != null) {
                                    onChanged(newValue);
                                  }
                                },
                              ),
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
                        isSecure ? "•••• ${value.substring(value.length - 4)}" : value,
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
