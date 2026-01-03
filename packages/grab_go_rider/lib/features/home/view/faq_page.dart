import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';

class FAQItem {
  final String question;
  final String answer;

  FAQItem({required this.question, required this.answer});
}

class FAQPage extends StatefulWidget {
  const FAQPage({super.key});

  @override
  State<FAQPage> createState() => _FAQPageState();
}

class _FAQPageState extends State<FAQPage> {
  final List<FAQItem> _faqs = [
    FAQItem(
      question: "How do I get started as a rider?",
      answer:
          "To get started, download the GrabGo Rider app and complete the registration process. You'll need to provide your personal information, vehicle details, and necessary documents. Once verified, you can start accepting delivery orders.",
    ),
    FAQItem(
      question: "What documents do I need to become a rider?",
      answer:
          "You'll need a valid driver's license, vehicle registration documents, proof of insurance, and a valid ID. Additional documents may be required depending on your location. All documents will be verified during the registration process.",
    ),
    FAQItem(
      question: "How do I receive payment for deliveries?",
      answer:
          "Payments are processed automatically after each completed delivery. You can view your earnings in the Wallet section and withdraw funds to your registered bank account. Payments are typically processed within 24-48 hours.",
    ),
    FAQItem(
      question: "What happens if I can't complete a delivery?",
      answer:
          "If you encounter any issues during delivery, contact support immediately through the app. Depending on the situation, we may reassign the order or provide guidance on how to proceed. Always prioritize your safety and communicate any problems promptly.",
    ),
    FAQItem(
      question: "How do I track my earnings?",
      answer:
          "You can view all your earnings in the Earnings History section of the app. This includes delivery fees, tips, bonuses, and any deductions. The Wallet section shows your current balance and withdrawal history.",
    ),
    FAQItem(
      question: "What are the delivery bonuses?",
      answer:
          "Delivery bonuses are incentives offered during peak hours, special promotions, or for achieving certain milestones. Check the Bonuses section regularly to see available bonuses and how to qualify for them.",
    ),
    FAQItem(
      question: "How do I update my profile information?",
      answer:
          "Go to the Profile section in the app menu, then tap on the information you want to update. You can change your personal details, contact information, and vehicle information. Some changes may require verification.",
    ),
    FAQItem(
      question: "What should I do if I have an issue with an order?",
      answer:
          "If you encounter any issues with an order, use the 'Report an Issue' feature in the Support section or contact support directly through the app. Include details about the problem, order ID, and any relevant photos if applicable.",
    ),
    FAQItem(
      question: "How do I go online or offline?",
      answer:
          "Use the toggle switch on the home screen to go online or offline. When online, you'll receive delivery requests. When offline, you won't receive any new orders. Make sure you're ready to accept deliveries before going online.",
    ),
    FAQItem(
      question: "What are the performance ratings?",
      answer:
          "Your performance is rated based on delivery completion rate, customer ratings, on-time delivery, and overall reliability. You can view your performance metrics in the Performance section. Higher ratings may qualify you for better bonuses and more delivery opportunities.",
    ),
    FAQItem(
      question: "How do I contact customer support?",
      answer:
          "You can contact support through the app's Support section. Options include calling support, sending an email, or using the live chat feature. Support is available during business hours, and urgent matters are handled promptly.",
    ),
    FAQItem(
      question: "Can I cancel an accepted order?",
      answer:
          "Cancelling an accepted order should be avoided as it affects your performance rating. However, if you have a valid reason (emergency, safety concern, etc.), contact support immediately. Frequent cancellations may result in account review or suspension.",
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
            "Frequently Asked Questions",
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
                  color: colors.accentGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
                  border: Border.all(color: colors.accentGreen.withValues(alpha: 0.3), width: 1),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(10.w),
                      decoration: BoxDecoration(
                        color: colors.accentGreen.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
                      ),
                      child: SvgPicture.asset(
                        Assets.icons.infoCircle,
                        package: 'grab_go_shared',
                        width: 24.w,
                        height: 24.w,
                        colorFilter: ColorFilter.mode(colors.accentGreen, BlendMode.srcIn),
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Text(
                        "Can't find what you're looking for? Contact our support team for assistance.",
                        style: TextStyle(color: colors.textPrimary, fontSize: 13.sp, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 24.h),
              Text(
                "COMMON QUESTIONS",
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
                itemCount: _faqs.length,
                separatorBuilder: (context, index) => SizedBox(height: 12.h),
                itemBuilder: (context, index) {
                  final faq = _faqs[index];
                  final isExpanded = _expandedItems.contains(index);

                  return _buildFAQItem(colors, faq, index, isExpanded);
                },
              ),
              SizedBox(height: 32.h),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFAQItem(AppColorsExtension colors, FAQItem faq, int index, bool isExpanded) {
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
                      width: 32.w,
                      height: 32.w,
                      decoration: BoxDecoration(
                        color: colors.accentGreen.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
                      ),
                      child: Center(
                        child: Text(
                          "${index + 1}",
                          style: TextStyle(color: colors.accentGreen, fontSize: 14.sp, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Text(
                        faq.question,
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 15.sp,
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
                        padding: EdgeInsets.only(left: 44.w),
                        child: Text(
                          faq.answer,
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
