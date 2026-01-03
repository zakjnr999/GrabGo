import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';

class DocumentsPage extends StatefulWidget {
  const DocumentsPage({super.key});

  @override
  State<DocumentsPage> createState() => _DocumentsPageState();
}

class _DocumentsPageState extends State<DocumentsPage> {
  final Map<String, DocumentStatus> _documents = {
    "National ID": DocumentStatus.verified,
    "Driver's License": DocumentStatus.verified,
    "Vehicle Registration": DocumentStatus.pending,
    "Insurance Certificate": DocumentStatus.verified,
    "Profile Photo": DocumentStatus.verified,
    "Vehicle Photo": DocumentStatus.pending,
  };

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
            "Documents",
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
                        "Upload clear, high-quality documents. All documents are securely stored and verified by our team.",
                        style: TextStyle(color: colors.textPrimary, fontSize: 12.sp, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 24.h),

              _buildSectionHeader("REQUIRED DOCUMENTS", colors),
              SizedBox(height: 12.h),
              _buildDocumentCard(
                colors: colors,
                title: "National ID",
                description: "Government-issued identification card",
                status: _documents["National ID"]!,
                icon: Assets.icons.idCard,
                iconColor: colors.accentGreen,
                onTap: () => _showDocumentOptions(context, colors, "National ID"),
              ),
              SizedBox(height: 12.h),
              _buildDocumentCard(
                colors: colors,
                title: "Driver's License",
                description: "Valid driving license",
                status: _documents["Driver's License"]!,
                icon: Assets.icons.idCard,
                iconColor: colors.accentOrange,
                onTap: () => _showDocumentOptions(context, colors, "Driver's License"),
              ),
              SizedBox(height: 12.h),
              _buildDocumentCard(
                colors: colors,
                title: "Vehicle Registration",
                description: "Vehicle registration certificate",
                status: _documents["Vehicle Registration"]!,
                icon: Assets.icons.deliveryTruck,
                iconColor: colors.accentViolet,
                onTap: () => _showDocumentOptions(context, colors, "Vehicle Registration"),
              ),
              SizedBox(height: 12.h),
              _buildDocumentCard(
                colors: colors,
                title: "Insurance Certificate",
                description: "Valid vehicle insurance certificate",
                status: _documents["Insurance Certificate"]!,
                icon: Assets.icons.shieldCheck,
                iconColor: colors.accentGreen,
                onTap: () => _showDocumentOptions(context, colors, "Insurance Certificate"),
              ),
              SizedBox(height: 32.h),

              _buildSectionHeader("ADDITIONAL DOCUMENTS", colors),
              SizedBox(height: 12.h),
              _buildDocumentCard(
                colors: colors,
                title: "Profile Photo",
                description: "Clear profile photo",
                status: _documents["Profile Photo"]!,
                icon: Assets.icons.user,
                iconColor: colors.accentOrange,
                onTap: () => _showDocumentOptions(context, colors, "Profile Photo"),
              ),
              SizedBox(height: 12.h),
              _buildDocumentCard(
                colors: colors,
                title: "Vehicle Photo",
                description: "Photo of your vehicle",
                status: _documents["Vehicle Photo"]!,
                icon: Assets.icons.deliveryTruck,
                iconColor: colors.accentViolet,
                onTap: () => _showDocumentOptions(context, colors, "Vehicle Photo"),
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
      style: TextStyle(color: colors.textSecondary, fontSize: 12.sp, fontWeight: FontWeight.w600, letterSpacing: 0.5),
    );
  }

  Widget _buildDocumentCard({
    required AppColorsExtension colors,
    required String title,
    required String description,
    required DocumentStatus status,
    required String icon,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: colors.backgroundPrimary,
        borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
        border: Border.all(color: colors.border, width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
          child: Padding(
            padding: EdgeInsets.all(16.w),
            child: Row(
              children: [
                Container(
                  width: 48.w,
                  height: 48.w,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
                  ),
                  child: Center(
                    child: SvgPicture.asset(
                      icon,
                      package: 'grab_go_shared',
                      width: 24.w,
                      height: 24.w,
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
                        title,
                        style: TextStyle(color: colors.textPrimary, fontSize: 15.sp, fontWeight: FontWeight.w600),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        description,
                        style: TextStyle(color: colors.textSecondary, fontSize: 12.sp, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 12.w),
                _buildStatusBadge(colors, status),
                SizedBox(width: 8.w),
                SvgPicture.asset(
                  Assets.icons.navArrowRight,
                  package: 'grab_go_shared',
                  width: 20.w,
                  height: 20.w,
                  colorFilter: ColorFilter.mode(colors.textSecondary, BlendMode.srcIn),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(AppColorsExtension colors, DocumentStatus status) {
    Color backgroundColor;
    Color textColor;
    String text;
    IconData icon;

    switch (status) {
      case DocumentStatus.verified:
        backgroundColor = colors.accentGreen.withValues(alpha: 0.1);
        textColor = colors.accentGreen;
        text = "Verified";
        icon = Icons.check_circle;
        break;
      case DocumentStatus.pending:
        backgroundColor = colors.accentOrange.withValues(alpha: 0.1);
        textColor = colors.accentOrange;
        text = "Pending";
        icon = Icons.pending;
        break;
      case DocumentStatus.rejected:
        backgroundColor = colors.error.withValues(alpha: 0.1);
        textColor = colors.error;
        text = "Rejected";
        icon = Icons.cancel;
        break;
      case DocumentStatus.missing:
        backgroundColor = colors.textSecondary.withValues(alpha: 0.1);
        textColor = colors.textSecondary;
        text = "Missing";
        icon = Icons.upload_file;
        break;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
      decoration: BoxDecoration(color: backgroundColor, borderRadius: BorderRadius.circular(KBorderSize.borderRadius4)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14.w, color: textColor),
          SizedBox(width: 4.w),
          Text(
            text,
            style: TextStyle(color: textColor, fontSize: 11.sp, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  void _showDocumentOptions(BuildContext context, AppColorsExtension colors, String documentType) {
    final status = _documents[documentType]!;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.all(20.w),
        decoration: BoxDecoration(color: colors.backgroundPrimary),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: colors.border,
                  borderRadius: BorderRadius.circular(KBorderSize.borderRadius20),
                ),
              ),
            ),
            SizedBox(height: 20.h),
            Text(
              documentType,
              style: TextStyle(color: colors.textPrimary, fontSize: 18.sp, fontWeight: FontWeight.w700),
            ),
            SizedBox(height: 20.h),
            if (status == DocumentStatus.verified || status == DocumentStatus.pending) ...[
              _buildOptionTile(
                context: context,
                colors: colors,
                icon: Assets.icons.eye,
                title: "View Document",
                onTap: () {
                  Navigator.pop(context);
                },
              ),
              SizedBox(height: 12.h),
            ],
            _buildOptionTile(
              context: context,
              colors: colors,
              icon: Assets.icons.camera,
              title: status == DocumentStatus.missing ? "Upload Document" : "Replace Document",
              onTap: () {
                Navigator.pop(context);
                _uploadDocument(context, colors, documentType);
              },
            ),
            if (status == DocumentStatus.rejected) ...[
              SizedBox(height: 12.h),
              _buildOptionTile(
                context: context,
                colors: colors,
                icon: Assets.icons.infoCircle,
                title: "View Rejection Reason",
                onTap: () {
                  Navigator.pop(context);
                  _showRejectionReason(context, colors);
                },
              ),
            ],
            SizedBox(height: 20.h),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionTile({
    required BuildContext context,
    required AppColorsExtension colors,
    required String icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 12.w),
          child: Row(
            children: [
              Container(
                width: 40.w,
                height: 40.w,
                decoration: BoxDecoration(
                  color: colors.backgroundSecondary,
                  borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
                ),
                child: Center(
                  child: SvgPicture.asset(
                    icon,
                    package: 'grab_go_shared',
                    width: 20.w,
                    height: 20.w,
                    colorFilter: ColorFilter.mode(colors.textPrimary, BlendMode.srcIn),
                  ),
                ),
              ),
              SizedBox(width: 16.w),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(color: colors.textPrimary, fontSize: 15.sp, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _uploadDocument(BuildContext context, AppColorsExtension colors, String documentType) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.all(20.w),
        decoration: BoxDecoration(color: colors.backgroundPrimary),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: colors.border,
                  borderRadius: BorderRadius.circular(KBorderSize.borderRadius20),
                ),
              ),
            ),
            SizedBox(height: 20.h),
            Text(
              "Upload $documentType",
              style: TextStyle(color: colors.textPrimary, fontSize: 18.sp, fontWeight: FontWeight.w700),
            ),
            SizedBox(height: 20.h),
            _buildOptionTile(
              context: context,
              colors: colors,
              icon: Assets.icons.camera,
              title: "Take Photo",
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Camera feature coming soon!"), backgroundColor: colors.accentGreen),
                );
              },
            ),
            SizedBox(height: 12.h),
            _buildOptionTile(
              context: context,
              colors: colors,
              icon: Assets.icons.mediaImage,
              title: "Choose from Gallery",
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Gallery picker coming soon!"), backgroundColor: colors.accentGreen),
                );
              },
            ),
            SizedBox(height: 20.h),
          ],
        ),
      ),
    );
  }

  void _showRejectionReason(BuildContext context, AppColorsExtension colors) {
    AppDialog.show(
      context: context,
      title: "Document Rejected",
      message:
          "Your document was rejected due to:\n\n• Image quality is too low\n• Document is expired\n• Information is not clearly visible\n\nPlease upload a new, clear document.",
      type: AppDialogType.error,
      primaryButtonText: "Upload New Document",
      secondaryButtonText: "Cancel",
      borderRadius: KBorderSize.borderRadius4,
      buttonBorderRadius: KBorderSize.borderRadius4,
      onPrimaryPressed: () {
        Navigator.pop(context);
      },
      onSecondaryPressed: () => Navigator.pop(context),
    );
  }
}

enum DocumentStatus { verified, pending, rejected, missing }
