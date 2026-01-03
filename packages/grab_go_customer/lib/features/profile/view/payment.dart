import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_credit_card/flutter_credit_card.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';

class Payment extends StatelessWidget {
  const Payment({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Size size = MediaQuery.sizeOf(context);

    return Scaffold(
      backgroundColor: colors.backgroundSecondary,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        backgroundColor: colors.backgroundSecondary,
        title: Row(
          children: [
            Container(
              height: 44.h,
              width: 44.w,
              decoration: BoxDecoration(
                color: colors.backgroundPrimary,
                shape: BoxShape.circle,
                border: Border.all(color: colors.inputBorder.withValues(alpha: 0.3), width: 0.5),
                boxShadow: [
                  BoxShadow(
                    color: isDark ? Colors.black.withAlpha(20) : Colors.black.withAlpha(5),
                    spreadRadius: 0,
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => context.pop(),
                  customBorder: const CircleBorder(),
                  child: Padding(
                    padding: EdgeInsets.all(10.r),
                    child: SvgPicture.asset(
                      Assets.icons.navArrowLeft,
                      package: 'grab_go_shared',
                      colorFilter: ColorFilter.mode(colors.textPrimary, BlendMode.srcIn),
                    ),
                  ),
                ),
              ),
            ),

            const Spacer(),

            Container(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
              decoration: BoxDecoration(
                color: colors.backgroundPrimary,
                borderRadius: BorderRadius.circular(20.r),
                border: Border.all(color: colors.inputBorder.withValues(alpha: 0.3), width: 0.5),
                boxShadow: [
                  BoxShadow(
                    color: isDark ? Colors.black.withAlpha(20) : Colors.black.withAlpha(5),
                    spreadRadius: 0,
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: EdgeInsets.all(6.r),
                    decoration: BoxDecoration(
                      color: colors.accentViolet.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: SvgPicture.asset(
                      Assets.icons.creditCard,
                      package: 'grab_go_shared',
                      height: 16.h,
                      width: 16.w,
                      colorFilter: ColorFilter.mode(colors.accentViolet, BlendMode.srcIn),
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Text(
                    "Payment Methods",
                    style: TextStyle(
                      fontFamily: "Lato",
                      package: 'grab_go_shared',
                      color: colors.textPrimary,
                      fontSize: 17.sp,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),

            const Spacer(),

            Container(
              height: 44.h,
              width: 44.w,
              decoration: BoxDecoration(
                color: colors.backgroundPrimary,
                shape: BoxShape.circle,
                border: Border.all(color: colors.inputBorder.withValues(alpha: 0.3), width: 0.5),
                boxShadow: [
                  BoxShadow(
                    color: isDark ? Colors.black.withAlpha(20) : Colors.black.withAlpha(5),
                    spreadRadius: 0,
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {},
                  customBorder: const CircleBorder(),
                  child: Padding(
                    padding: EdgeInsets.all(10.r),
                    child: Icon(Icons.add, size: 22.sp, color: colors.accentOrange),
                  ),
                ),
              ),
            ),
          ],
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
          top: false,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(6.r),
                      decoration: BoxDecoration(
                        color: colors.accentOrange.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: SvgPicture.asset(
                        Assets.icons.creditCard,
                        package: 'grab_go_shared',
                        height: 14.h,
                        width: 14.w,
                        colorFilter: ColorFilter.mode(colors.accentOrange, BlendMode.srcIn),
                      ),
                    ),
                    SizedBox(width: 10.w),
                    Text(
                      "My Card",
                      style: TextStyle(color: colors.textPrimary, fontSize: 16.sp, fontWeight: FontWeight.w800),
                    ),
                    const Spacer(),
                    Container(
                      padding: EdgeInsets.all(8.r),
                      decoration: BoxDecoration(
                        color: colors.backgroundPrimary,
                        borderRadius: BorderRadius.circular(10.r),
                        border: Border.all(color: colors.inputBorder.withValues(alpha: 0.3), width: 0.5),
                      ),
                      child: SvgPicture.asset(
                        Assets.icons.editPencil,
                        package: 'grab_go_shared',
                        height: 16.h,
                        width: 16.w,
                        colorFilter: ColorFilter.mode(colors.accentOrange, BlendMode.srcIn),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12.h),

                CreditCardWidget(
                  showBackView: true,
                  cardNumber: "1234123412341234",
                  expiryDate: "xx/xx",
                  cardHolderName: "Zak Jnr",
                  cvvCode: "xxx",
                  bankName: "GCB Bank",
                  isHolderNameVisible: true,
                  enableFloatingCard: true,
                  cardBgColor: colors.accentOrange,
                  floatingConfig: FloatingConfig(
                    isGlareEnabled: true,
                    isShadowEnabled: true,
                    shadowConfig: FloatingShadowConfig(
                      color: Colors.black.withAlpha(20),
                      blurRadius: KBorderSize.border,
                      offset: const Offset(0, 4),
                    ),
                  ),
                  onCreditCardWidgetChange: (_) {},
                ),

                SizedBox(height: 24.h),

                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(6.r),
                      decoration: BoxDecoration(
                        color: colors.accentViolet.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: SvgPicture.asset(
                        Assets.icons.idCard,
                        package: 'grab_go_shared',
                        height: 14.h,
                        width: 14.w,
                        colorFilter: ColorFilter.mode(colors.accentViolet, BlendMode.srcIn),
                      ),
                    ),
                    SizedBox(width: 10.w),
                    Text(
                      "Other Methods",
                      style: TextStyle(color: colors.textPrimary, fontSize: 16.sp, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),

                SizedBox(height: 12.h),

                _paymentMethodCard(size, Assets.icons.mom.path, "MTN MOMO", context),

                _paymentMethodCard(size, Assets.icons.vodafoneCash.path, "Vodafone Cash", context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _paymentMethodCard(Size size, String imagePath, String title, BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: EdgeInsets.symmetric(vertical: 6.h),
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: colors.backgroundPrimary,
        borderRadius: BorderRadius.circular(KBorderSize.borderRadius15),
        border: Border.all(color: colors.inputBorder.withValues(alpha: 0.3), width: 0.5),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withAlpha(30) : Colors.black.withAlpha(8),
            spreadRadius: 0,
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            // Handle payment method selection
          },
          borderRadius: BorderRadius.circular(KBorderSize.borderRadius15),
          child: Row(
            children: [
              // Payment Logo Container
              Container(
                height: 60.h,
                width: 70.w,
                decoration: BoxDecoration(
                  color: colors.backgroundSecondary,
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(color: colors.inputBorder.withValues(alpha: 0.3), width: 0.5),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12.r),
                  child: Image.asset(imagePath, package: 'grab_go_shared', fit: BoxFit.cover),
                ),
              ),
              SizedBox(width: 16.w),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(fontSize: 15.sp, color: colors.textPrimary, fontWeight: FontWeight.w700),
                ),
              ),
              Icon(Icons.arrow_forward_ios, size: 18.sp, color: colors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}
