import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';

class SafetyGuideline {
  final String title;
  final String description;
  final String icon;

  SafetyGuideline({required this.title, required this.description, required this.icon});
}

class SafetyGuidelinesPage extends StatefulWidget {
  const SafetyGuidelinesPage({super.key});

  @override
  State<SafetyGuidelinesPage> createState() => _SafetyGuidelinesPageState();
}

class _SafetyGuidelinesPageState extends State<SafetyGuidelinesPage> {
  final List<SafetyGuideline> _guidelines = [
    SafetyGuideline(
      title: "Vehicle Safety",
      description:
          "Always ensure your vehicle is in good working condition before starting your shift. Check brakes, tires, lights, and fuel levels. Regular maintenance is essential for your safety and that of others on the road.",
      icon: Assets.icons.deliveryTruck,
    ),
    SafetyGuideline(
      title: "Personal Safety",
      description:
          "Prioritize your safety at all times. If you feel unsafe at any location, contact support immediately. Trust your instincts and never compromise your safety for a delivery. Keep your phone charged and accessible at all times.",
      icon: Assets.icons.shieldCheck,
    ),
    SafetyGuideline(
      title: "Traffic Rules",
      description:
          "Always follow traffic rules and regulations. Obey speed limits, traffic signals, and road signs. Use indicators when turning, and maintain a safe distance from other vehicles. Never use your phone while driving.",
      icon: Assets.icons.infoCircle,
    ),
    SafetyGuideline(
      title: "Weather Conditions",
      description:
          "Exercise extra caution during adverse weather conditions. Slow down during rain, fog, or poor visibility. If conditions become too dangerous, consider going offline until conditions improve. Safety comes first.",
      icon: Assets.icons.warningCircle,
    ),
    SafetyGuideline(
      title: "Customer Interactions",
      description:
          "Maintain professional and respectful communication with customers. If you encounter any issues or feel uncomfortable, contact support immediately. Always verify customer information before handing over orders.",
      icon: Assets.icons.user,
    ),
    SafetyGuideline(
      title: "Food Handling",
      description:
          "Handle food orders with care to maintain hygiene and quality. Keep food containers secure and at appropriate temperatures. Use clean delivery bags and ensure orders are properly sealed before delivery.",
      icon: Assets.icons.deliveryTruck,
    ),
    SafetyGuideline(
      title: "Emergency Procedures",
      description:
          "In case of an emergency, prioritize your safety first. Contact emergency services if needed, then inform support. Know your exact location and be prepared to provide it to emergency services or support staff.",
      icon: Assets.icons.phone,
    ),
    SafetyGuideline(
      title: "Working Hours",
      description:
          "Take regular breaks to avoid fatigue. Don't work excessive hours that could compromise your alertness. Rest adequately between shifts to ensure you're always operating at your best and maintaining safety standards.",
      icon: Assets.icons.clock,
    ),
  ];

  final Set<int> _expandedItems = {};

  void _toggleExpansion(int index) {
    setState(() {
      if (_expandedItems.contains(index)) {
        _expandedItems.remove(index);
      } else {
        _expandedItems.add(index);
      }
    });
  }

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
            "Safety & Guidelines",
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
                padding: EdgeInsets.all(20.w),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [colors.accentViolet.withValues(alpha: 0.15), colors.accentViolet.withValues(alpha: 0.05)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
                  border: Border.all(color: colors.accentViolet.withValues(alpha: 0.3), width: 1),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(12.w),
                      decoration: BoxDecoration(
                        color: colors.accentViolet.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
                      ),
                      child: SvgPicture.asset(
                        Assets.icons.shieldCheck,
                        package: 'grab_go_shared',
                        width: 32.w,
                        height: 32.w,
                        colorFilter: ColorFilter.mode(colors.accentViolet, BlendMode.srcIn),
                      ),
                    ),
                    SizedBox(width: 16.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Safety First",
                            style: TextStyle(color: colors.textPrimary, fontSize: 18.sp, fontWeight: FontWeight.w700),
                          ),
                          SizedBox(height: 6.h),
                          Text(
                            "Your safety is our top priority. Follow these guidelines to ensure safe and efficient deliveries.",
                            style: TextStyle(
                              color: colors.textSecondary,
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w400,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 24.h),
              Text(
                "SAFETY GUIDELINES",
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              SizedBox(height: 12.h),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _guidelines.length,
                separatorBuilder: (context, index) => SizedBox(height: 12.h),
                itemBuilder: (context, index) {
                  final guideline = _guidelines[index];
                  final isExpanded = _expandedItems.contains(index);

                  return _buildGuidelineItem(colors, guideline, index, isExpanded);
                },
              ),
              SizedBox(height: 24.h),
              Container(
                padding: EdgeInsets.all(16.w),
                decoration: BoxDecoration(
                  color: colors.accentOrange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
                  border: Border.all(color: colors.accentOrange.withValues(alpha: 0.3), width: 1),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: EdgeInsets.all(8.w),
                      decoration: BoxDecoration(
                        color: colors.accentOrange.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
                      ),
                      child: SvgPicture.asset(
                        Assets.icons.warningCircle,
                        package: 'grab_go_shared',
                        width: 20.w,
                        height: 20.w,
                        colorFilter: ColorFilter.mode(colors.accentOrange, BlendMode.srcIn),
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Emergency Contact",
                            style: TextStyle(color: colors.textPrimary, fontSize: 15.sp, fontWeight: FontWeight.w600),
                          ),
                          SizedBox(height: 6.h),
                          Text(
                            "In case of emergency, call 911 or your local emergency services immediately. Then contact GrabGo support at +233 536 997 662 for assistance.",
                            style: TextStyle(
                              color: colors.textSecondary,
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w400,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 32.h),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGuidelineItem(AppColorsExtension colors, SafetyGuideline guideline, int index, bool isExpanded) {
    Color iconColor;
    switch (index % 4) {
      case 0:
        iconColor = colors.accentGreen;
        break;
      case 1:
        iconColor = colors.accentOrange;
        break;
      case 2:
        iconColor = colors.accentViolet;
        break;
      default:
        iconColor = colors.accentGreen;
    }

    return Container(
      decoration: BoxDecoration(
        color: colors.backgroundPrimary,
        borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
        border: Border.all(color: colors.border, width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _toggleExpansion(index),
          borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.all(16.w),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                          guideline.icon,
                          package: 'grab_go_shared',
                          width: 24.w,
                          height: 24.w,
                          colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
                        ),
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Text(
                        guideline.title,
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w600,
                          height: 1.4,
                        ),
                      ),
                    ),
                    SizedBox(width: 8.w),
                    AnimatedRotation(
                      turns: isExpanded ? 0.5 : 0.0,
                      duration: const Duration(milliseconds: 200),
                      child: SvgPicture.asset(
                        Assets.icons.navArrowDown,
                        package: 'grab_go_shared',
                        width: 20.w,
                        height: 20.w,
                        colorFilter: ColorFilter.mode(colors.textSecondary, BlendMode.srcIn),
                      ),
                    ),
                  ],
                ),
              ),
              AnimatedCrossFade(
                firstChild: const SizedBox.shrink(),
                secondChild: Container(
                  padding: EdgeInsets.only(left: 16.w, right: 16.w, bottom: 16.w),
                  child: Column(
                    children: [
                      Divider(color: colors.border, height: 1, thickness: 1),
                      SizedBox(height: 12.h),
                      Padding(
                        padding: EdgeInsets.only(left: 60.w),
                        child: Text(
                          guideline.description,
                          style: TextStyle(
                            color: colors.textSecondary,
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w400,
                            height: 1.6,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                crossFadeState: isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 200),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
