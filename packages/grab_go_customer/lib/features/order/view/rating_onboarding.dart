import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_customer/features/order/view/vendor_rating.dart';
import 'package:grab_go_customer/features/order/view/rider_rating.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';

class RatingOnboarding extends StatefulWidget {
  final String orderId;
  final String? riderName;
  final String? riderImage;
  final String? vendorName;
  final String? vendorLogo;
  const RatingOnboarding({
    super.key,
    required this.orderId,
    this.riderName,
    this.riderImage,
    this.vendorName,
    this.vendorLogo,
  });

  @override
  State<RatingOnboarding> createState() => RatingOnboardingState();
}

class RatingOnboardingState extends State<RatingOnboarding> with SingleTickerProviderStateMixin {
  final PageController controller = PageController();
  int _index = 0;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void skip() => controller.jumpToPage(2);

  void next() async {
    if (_index < 2) {
      controller.nextPage(duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
    } else {
      if (mounted) {
        context.go('/homepage');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarDividerColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        extendBody: true,
        extendBodyBehindAppBar: true,
        backgroundColor: Colors.transparent,
        body: LayoutBuilder(
          builder: (context, _) {
            final padding = MediaQuery.of(context).padding;
            return Stack(
              children: [
                PageView(
                  controller: controller,
                  onPageChanged: (i) {
                    setState(() => _index = i);
                  },
                  children: [
                    RiderRating(orderId: widget.orderId, riderName: widget.riderName, riderImage: widget.riderImage),
                    VendorRating(vendorName: widget.vendorName, vendorImage: widget.vendorLogo),
                  ],
                ),

                Positioned(
                  left: 20.w,
                  right: 20.w,
                  top: padding.top + 10.h,
                  child: StoryStepper(
                    count: 2,
                    index: _index,
                    activeColor: colors.accentOrange,
                    inactiveColor: colors.backgroundSecondary,
                  ),
                ),

                Positioned(
                  left: 10,
                  top: padding.top + 20.h,
                  child: Container(
                    height: 44.h,
                    width: 44.w,
                    decoration: BoxDecoration(color: colors.backgroundPrimary, shape: BoxShape.circle),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => context.pop(),
                        customBorder: const CircleBorder(),
                        child: Padding(
                          padding: EdgeInsets.all(10.r),
                          child: SvgPicture.asset(
                            Assets.icons.xmark,
                            package: 'grab_go_shared',
                            colorFilter: ColorFilter.mode(colors.textPrimary, BlendMode.srcIn),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                Visibility(
                  visible: _index == 0 ? true : false,
                  child: Positioned(
                    right: 10,
                    top: padding.top + 20.h,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => context.pop(),
                        customBorder: const CircleBorder(),
                        child: Padding(
                          padding: EdgeInsets.all(10.r),
                          child: Text(
                            'Skip',
                            style: TextStyle(color: colors.textPrimary, fontSize: 14.sp, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                Positioned(
                  left: 20.w,
                  right: 20.w,
                  bottom: padding.bottom + 20.h,
                  child: AppButton(
                    buttonText: _index == 0 ? "Continue" : "Done",
                    onPressed: next,
                    backgroundColor: colors.accentOrange,
                    borderRadius: KBorderSize.borderRadius15,
                    textStyle: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
