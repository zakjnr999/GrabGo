// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_customer/shared/services/storage_service.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:grab_go_shared/grub_go_shared.dart';

class RestaurantAccountCreationTracking extends StatefulWidget {
  const RestaurantAccountCreationTracking({super.key});

  @override
  State<RestaurantAccountCreationTracking> createState() => _RestaurantAccountCreationTrackingState();
}

class _RestaurantAccountCreationTrackingState extends State<RestaurantAccountCreationTracking> {
  int currentStep = 1; // "Under Review" is the current step (0-3)

  @override
  void initState() {
    super.initState();
    loadCurrentStepFromStorage();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: colors.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: colors.backgroundPrimary,
        automaticallyImplyLeading: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          "Track Application Status",
          style: TextStyle(fontFamily: "Lato", fontSize: 18.sp, fontWeight: FontWeight.w600, color: colors.textPrimary),
        ),
        centerTitle: true,
        leadingWidth: 72,
        leading: SizedBox(
          height: KWidgetSize.buttonHeightSmall.h,
          width: KWidgetSize.buttonHeightSmall.w,
          child: Material(
            color: colors.backgroundPrimary,
            shape: const CircleBorder(),
            child: InkWell(
              onTap: () {
                context.go("/login");
              },
              customBorder: const CircleBorder(),
              splashColor: colors.iconSecondary.withAlpha(50),
              child: Padding(
                padding: EdgeInsets.all(KSpacing.md12.r),
                child: SvgPicture.asset(
                  Assets.icons.navArrowLeft,
                  package: 'grab_go_shared',
                  colorFilter: ColorFilter.mode(colors.iconPrimary, BlendMode.srcIn),
                ),
              ),
            ),
          ),
        ),
      ),

      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle(
          statusBarColor: colors.backgroundSecondary,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          systemNavigationBarColor: colors.backgroundSecondary,
          systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(KSpacing.lg.r),
                  decoration: BoxDecoration(
                    color: colors.accentOrange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(KBorderSize.borderMedium),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 50.h,
                        width: 50.w,
                        padding: EdgeInsets.all(KSpacing.md12.r),
                        decoration: BoxDecoration(color: colors.accentOrange, shape: BoxShape.circle),
                        child: SvgPicture.asset(
                          Assets.icons.checkBig,
                          package: 'grab_go_shared',
                          colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                        ),
                      ),
                      SizedBox(width: KSpacing.lg.w),

                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Registration Submitted Successfully",
                              style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w600, color: colors.textPrimary),
                            ),
                            SizedBox(height: KSpacing.sm.h),
                            Text(
                              "Your application is under review. You can track your application status below.",
                              style: TextStyle(
                                fontSize: 14.sp,
                                color: colors.textSecondary,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: KSpacing.lg.h),

                Text(
                  "Application Status",
                  style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.w600, color: colors.textPrimary),
                ),
                SizedBox(height: KSpacing.lg.h),
                _buildCustomStepper(colors),
                SizedBox(height: KSpacing.xl.h),
                _buildStepActionButton(colors),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCustomStepper(dynamic colors) {
    final steps = [
      {
        'title': 'Submitted',
        'subtitle': 'Application received',
        'icon': Assets.icons.check,
        'isCompleted': true,
        'isActive': false,
      },
      {
        'title': 'Under Review',
        'subtitle': 'Documents are being verified',
        'icon': Assets.icons.timer,
        'isCompleted': true,
        'isActive': false,
      },
      {
        'title': 'Approved',
        'subtitle': 'Verification successful',
        'icon': Assets.icons.check,
        'isCompleted': false,
        'isActive': false,
      },
      {
        'title': 'Account Active',
        'subtitle': 'Your account is live! You can now continue to setup your restaurant.',
        'icon': Assets.icons.check,
        'isCompleted': false,
        'isActive': false,
      },
    ];

    return Column(
      children: steps.asMap().entries.map((entry) {
        final index = entry.key;
        final step = entry.value;
        final isLast = index == steps.length - 1;

        return Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Step Icon
                Container(
                  width: 40.w,
                  height: 40.h,
                  decoration: BoxDecoration(
                    color: step['isCompleted'] as bool
                        ? colors.accentOrange
                        : step['isActive'] as bool
                        ? colors.backgroundSecondary
                        : colors.backgroundSecondary,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: SvgPicture.asset(
                      step['icon'] as String,
                      width: 20.w,
                      height: 20.h,
                      colorFilter: ColorFilter.mode(
                        step['isCompleted'] as bool ? Colors.white : colors.textSecondary,
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: KSpacing.md.w),
                // Step Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        step['title'] as String,
                        style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600, color: colors.textPrimary),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        step['subtitle'] as String,
                        style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w400, color: colors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            // Connector Line
            if (!isLast) ...[
              SizedBox(height: KSpacing.lg.h),
              Container(
                margin: EdgeInsets.only(left: 20.w),
                height: 40.h,
                child: CustomPaint(
                  painter: DashedLinePainter(
                    color: step['isCompleted'] as bool ? colors.accentOrange : colors.inputBorder,
                    strokeWidth: 2.0,
                    dashWidth: 4.0,
                    dashSpace: 4.0,
                  ),
                ),
              ),
              SizedBox(height: KSpacing.lg.h),
            ],
          ],
        );
      }).toList(),
    );
  }

  // Get current step information
  Map<String, dynamic> getCurrentStepInfo() {
    final steps = [
      {
        'title': 'Submitted',
        'subtitle': 'Application received',
        'buttonText': 'CONTACT SUPPORT',
        'buttonAction': 'view_details',
      },
      {
        'title': 'Under Review',
        'subtitle': 'Documents are being verified',
        'buttonText': 'CONTACT SUPPORT',
        'buttonAction': 'check_status',
      },
      {
        'title': 'Approved',
        'subtitle': 'Verification successful',
        'buttonText': 'CONTINUE TO SETUP',
        'buttonAction': 'complete_setup',
      },
      {
        'title': 'Account Active',
        'subtitle': 'Your account is live',
        'buttonText': 'GO TO DASHBOARD',
        'buttonAction': 'go_dashboard',
      },
    ];

    return steps[currentStep];
  }

  // Load current step from storage (set by admin via API)
  Future<void> loadCurrentStepFromStorage() async {
    final status = await StorageService.getRestaurantApplicationStatus();
    if (status != null) {
      // Map status string to step index
      final stepMap = {'Submitted': 0, 'Under Review': 1, 'Approved': 2, 'Account Active': 3};

      final stepIndex = stepMap[status] ?? 1;

      if (mounted) {
        setState(() {
          currentStep = stepIndex;
        });
      }
    }
  }

  // Build action button based on current step
  Widget _buildStepActionButton(dynamic colors) {
    final stepInfo = getCurrentStepInfo();

    return AppButton(
      width: double.infinity,
      onPressed: () => _handleStepAction(stepInfo['buttonAction']),
      backgroundColor: colors.accentOrange,
      borderRadius: KBorderSize.borderRadius50,
      buttonText: stepInfo['buttonText'],
    );
  }

  // Handle button actions based on current step
  void _handleStepAction(String action) async {
    switch (action) {
      case 'view_details':
        // Contact support via Gmail
        await _launchGmailSupport('Application Details Inquiry');
        break;
      case 'check_status':
        // Contact support via Gmail
        await _launchGmailSupport('Review Status Inquiry');
        break;
      case 'complete_setup':
        // Complete account setup
        AppToastMessage.show(
          context: context,
          icon: Icons.check_circle_outline,
          message: 'Completing account setup...',
          backgroundColor: context.appColors.success,
        );
        break;
      case 'go_dashboard':
        // Navigate to dashboard
        context.push('/homepage');
        break;
      default:
        break;
    }
  }

  // Launch Gmail with pre-filled support email
  Future<void> _launchGmailSupport(String subject) async {
    try {
      // Try Gmail app first with compose intent
      final String gmailComposeUrl =
          'googlegmail://co?to=zakjnr165@gmail.com&subject=${Uri.encodeComponent('GrabGo Restaurant Registration - $subject')}&body=${Uri.encodeComponent('Hello GrabGo Support Team,\n\nI need assistance with my restaurant registration application.\n\nSubject: $subject\n\nPlease provide me with the necessary information.\n\nThank you.')}';

      if (await canLaunchUrl(Uri.parse(gmailComposeUrl))) {
        await launchUrl(Uri.parse(gmailComposeUrl));
        return;
      }

      // Try Gmail app basic
      const String gmailAppUrl = 'googlegmail://';

      if (await canLaunchUrl(Uri.parse(gmailAppUrl))) {
        await launchUrl(Uri.parse(gmailAppUrl));
        return;
      }

      // Fallback to Gmail web version
      const String gmailWebUrl = 'https://mail.google.com/';

      if (await canLaunchUrl(Uri.parse(gmailWebUrl))) {
        await launchUrl(Uri.parse(gmailWebUrl));
        return;
      }

      // Show manual contact info since no email client is available
      if (mounted) {
        AppToastMessage.show(
          context: context,
          icon: Icons.info_outline,
          message: 'No email app found. Please contact zakjnr165@gmail.com directly for support.',
          backgroundColor: context.appColors.accentOrange,
        );
      }
    } catch (e) {
      if (mounted) {
        AppToastMessage.show(
          context: context,
          icon: Icons.error_outline,
          message: 'Unable to open email client. Please contact zakjnr165@gmail.com directly.',
          backgroundColor: context.appColors.error,
        );
      }
    }
  }
}
