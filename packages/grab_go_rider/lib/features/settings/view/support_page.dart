import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_rider/features/chat/view/chat_detail_page.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:url_launcher/url_launcher.dart';

class SupportPage extends StatelessWidget {
  const SupportPage({super.key});

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
            "Support",
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
              _buildSectionHeader("CONTACT US", colors),
              SizedBox(height: 12.h),
              _buildContactCard(
                colors: colors,
                icon: Assets.icons.phone,
                iconColor: colors.accentGreen,
                title: "Call Support",
                subtitle: "Speak with our support team",
                phoneNumber: "+233 536 997 662",
                onTap: () => _makePhoneCall("+233536997662"),
              ),
              SizedBox(height: 12.h),
              _buildContactCard(
                colors: colors,
                icon: Assets.icons.mail,
                iconColor: colors.accentOrange,
                title: "Email Support",
                subtitle: "Send us an email",
                email: "support@grabgo.com",
                onTap: () => _sendEmail("support@grabgo.com", false),
              ),
              SizedBox(height: 12.h),
              _buildContactCard(
                colors: colors,
                icon: Assets.icons.headsetHelp,
                iconColor: colors.accentViolet,
                title: "Live Chat",
                subtitle: "Chat with us instantly",
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          const ChatDetailPage(chatId: "support", senderName: "GrabGo Support", isSupport: true),
                    ),
                  );
                },
              ),
              SizedBox(height: 32.h),
              _buildSectionHeader("HELP & INFORMATION", colors),
              SizedBox(height: 12.h),
              _buildHelpCard(
                colors: colors,
                icon: Assets.icons.infoCircle,
                iconColor: colors.accentGreen,
                title: "Frequently Asked Questions",
                subtitle: "Find answers to common questions",
                onTap: () {
                  context.push("/faq");
                },
              ),
              SizedBox(height: 12.h),
              _buildHelpCard(
                colors: colors,
                icon: Assets.icons.warningCircle,
                iconColor: colors.accentOrange,
                title: "Report an Issue",
                subtitle: "Report bugs or technical problems",
                onTap: () => _sendEmail("support@grabgo.com", true),
              ),
              SizedBox(height: 12.h),
              _buildHelpCard(
                colors: colors,
                icon: Assets.icons.shieldCheck,
                iconColor: colors.accentViolet,
                title: "Safety & Guidelines",
                subtitle: "Learn about safety protocols",
                onTap: () {
                  context.push("/safety-guidelines");
                },
              ),
              SizedBox(height: 32.h),
              _buildSectionHeader("OFFICE HOURS", colors),
              SizedBox(height: 12.h),
              _buildHoursCard(
                colors: colors,
                weekdays: "Monday - Friday: 8:00 AM - 8:00 PM",
                weekend: "Saturday - Sunday: 9:00 AM - 6:00 PM",
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

  Widget _buildContactCard({
    required AppColorsExtension colors,
    required String icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    String? phoneNumber,
    String? email,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
        child: Container(
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            color: colors.backgroundPrimary,
            borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
            border: Border.all(color: colors.border, width: 1),
          ),
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
                      style: TextStyle(color: colors.textPrimary, fontSize: 16.sp, fontWeight: FontWeight.w600),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      phoneNumber ?? email ?? subtitle,
                      style: TextStyle(color: colors.textSecondary, fontSize: 12.sp, fontWeight: FontWeight.w400),
                    ),
                  ],
                ),
              ),
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
    );
  }

  Widget _buildHelpCard({
    required AppColorsExtension colors,
    required String icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
        child: Container(
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            color: colors.backgroundPrimary,
            borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
            border: Border.all(color: colors.border, width: 1),
          ),
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
                      style: TextStyle(color: colors.textPrimary, fontSize: 16.sp, fontWeight: FontWeight.w600),
                    ),
                    SizedBox(height: 4.h),
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
                width: 20.w,
                height: 20.w,
                colorFilter: ColorFilter.mode(colors.textSecondary, BlendMode.srcIn),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHoursCard({required AppColorsExtension colors, required String weekdays, required String weekend}) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: colors.backgroundPrimary,
        borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
        border: Border.all(color: colors.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8.w),
                decoration: BoxDecoration(
                  color: colors.accentGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
                ),
                child: SvgPicture.asset(
                  Assets.icons.clock,
                  package: 'grab_go_shared',
                  width: 20.w,
                  height: 20.w,
                  colorFilter: ColorFilter.mode(colors.accentGreen, BlendMode.srcIn),
                ),
              ),
              SizedBox(width: 12.w),
              Text(
                "Support Hours",
                style: TextStyle(color: colors.textPrimary, fontSize: 16.sp, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          _buildHoursRow(colors, weekdays),
          SizedBox(height: 12.h),
          _buildHoursRow(colors, weekend),
        ],
      ),
    );
  }

  Widget _buildHoursRow(AppColorsExtension colors, String time) {
    return Row(
      children: [
        Container(
          width: 6.w,
          height: 6.w,
          decoration: BoxDecoration(color: colors.accentGreen, shape: BoxShape.circle),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: Text(
            time,
            style: TextStyle(color: colors.textPrimary, fontSize: 14.sp, fontWeight: FontWeight.w400),
          ),
        ),
      ],
    );
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri phoneUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(phoneUri)) {
      await launchUrl(phoneUri);
    }
  }

  Future<void> _sendEmail(String email, bool isReportIssue) async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: email,
      query:
          'subject=${isReportIssue ? 'Report Issue' : 'Support Request'} &body=${isReportIssue ? 'I need to report an issue' : 'Hello, I need help with...'}',
    );
    if (await canLaunchUrl(emailUri)) {
      await launchUrl(emailUri);
    }
  }
}
