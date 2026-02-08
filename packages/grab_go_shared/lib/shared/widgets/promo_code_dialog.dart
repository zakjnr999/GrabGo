import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/shared/widgets/app_button.dart';
import '../utils/constants.dart';
import '../utils/app_colors_extension.dart';

class PromoCodeDialog extends StatefulWidget {
  final Function(String)? onApply;
  final String? currentPromoCode;

  const PromoCodeDialog({super.key, this.onApply, this.currentPromoCode});

  static Future<String?> show({required BuildContext context, Function(String)? onApply, String? currentPromoCode}) {
    return showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (context) => PromoCodeDialog(onApply: onApply, currentPromoCode: currentPromoCode),
    );
  }

  @override
  State<PromoCodeDialog> createState() => _PromoCodeDialogState();
}

class _PromoCodeDialogState extends State<PromoCodeDialog> with SingleTickerProviderStateMixin {
  final TextEditingController _promoController = TextEditingController();
  final FocusNode _promoFocusNode = FocusNode();
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  final List<Map<String, dynamic>> _suggestedPromos = [
    {'code': 'WELCOME10', 'discount': '10% OFF', 'description': 'First order discount'},
    {'code': 'SAVE20', 'discount': '20% OFF', 'description': 'On orders above GHC50'},
    {'code': 'FREESHIP', 'discount': 'FREE DELIVERY', 'description': 'Free delivery today'},
  ];

  @override
  void initState() {
    super.initState();

    if (widget.currentPromoCode != null) {
      _promoController.text = widget.currentPromoCode!;
    }

    _animationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));

    _scaleAnimation = CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack);

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeIn));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _animationController.forward();
      Future.delayed(const Duration(milliseconds: 300), () {
        _promoFocusNode.requestFocus();
      });
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _promoController.dispose();
    _promoFocusNode.dispose();
    super.dispose();
  }

  void _applyPromo(String code) {
    if (code.isEmpty) return;

    if (widget.onApply != null) {
      widget.onApply!(code);
    }

    Navigator.of(context).pop(code);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: Container(
            constraints: BoxConstraints(maxHeight: 600.h),
            decoration: BoxDecoration(
              color: colors.backgroundPrimary,
              borderRadius: BorderRadius.circular(KBorderSize.borderRadius20),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 20, offset: const Offset(0, 10)),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(KSpacing.lg25.r),
                  decoration: BoxDecoration(
                    color: colors.accentViolet.withValues(alpha: 0.15),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(KBorderSize.borderRadius20),
                      topRight: Radius.circular(KBorderSize.borderRadius20),
                    ),
                  ),
                  child: Column(
                    children: [
                      Container(
                        height: 70.h,
                        width: 70.h,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: colors.accentViolet.withValues(alpha: 0.15),
                        ),
                        child: Center(
                          child: SvgPicture.asset(
                            Assets.icons.badgePercent,
                            package: "grab_go_shared",
                            height: 35.h,
                            width: 35.h,
                            colorFilter: ColorFilter.mode(colors.accentViolet, BlendMode.srcIn),
                          ),
                        ),
                      ),
                      SizedBox(height: KSpacing.md.h),

                      Text(
                        'Apply Promo Code',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 20.sp,
                          fontWeight: FontWeight.w700,
                          color: colors.textPrimary,
                          height: 1.3,
                        ),
                      ),
                      SizedBox(height: 4.h),

                      Text(
                        'Enter your code to get amazing discounts',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w400,
                          color: colors.textSecondary,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),

                Flexible(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(KSpacing.lg25.r),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: _promoController,
                          focusNode: _promoFocusNode,
                          textCapitalization: TextCapitalization.characters,
                          inputFormatters: [UpperCaseTextFormatter()],
                          decoration: InputDecoration(
                            hintText: 'Enter promo code',
                            hintStyle: TextStyle(color: colors.textSecondary.withValues(alpha: 0.5), fontSize: 14.sp),
                            filled: true,
                            fillColor: colors.backgroundSecondary,
                            contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(KBorderSize.borderMedium),
                              borderSide: BorderSide(color: colors.inputBorder, width: 1),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(KBorderSize.borderMedium),
                              borderSide: BorderSide(color: colors.inputBorder, width: 1),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(KBorderSize.borderMedium),
                              borderSide: BorderSide(color: colors.accentViolet, width: 1.5),
                            ),
                          ),
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.5,
                          ),
                          onSubmitted: _applyPromo,
                        ),

                        SizedBox(height: KSpacing.lg25.h),

                        Text(
                          'Available Offers',
                          style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w700, color: colors.textPrimary),
                        ),
                        SizedBox(height: KSpacing.md.h),

                        ...List.generate(_suggestedPromos.length, (index) {
                          final promo = _suggestedPromos[index];
                          return Padding(
                            padding: EdgeInsets.only(bottom: 12.h),
                            child: GestureDetector(
                              onTap: () {
                                _promoController.text = promo['code'];
                              },
                              child: Container(
                                padding: EdgeInsets.all(14.r),
                                decoration: BoxDecoration(
                                  color: colors.backgroundSecondary,
                                  borderRadius: BorderRadius.circular(KBorderSize.borderMedium),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            colors.accentViolet.withValues(alpha: 0.2),
                                            colors.accentOrange.withValues(alpha: 0.2),
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(KBorderSize.borderMedium),
                                      ),
                                      child: Text(
                                        promo['discount'],
                                        style: TextStyle(
                                          fontSize: 11.sp,
                                          fontWeight: FontWeight.w700,
                                          color: colors.accentViolet,
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 12.w),

                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            promo['code'],
                                            style: TextStyle(
                                              fontSize: 14.sp,
                                              fontWeight: FontWeight.w700,
                                              color: colors.textPrimary,
                                              letterSpacing: 1,
                                            ),
                                          ),
                                          SizedBox(height: 2.h),
                                          Text(
                                            promo['description'],
                                            style: TextStyle(
                                              fontSize: 12.sp,
                                              fontWeight: FontWeight.w400,
                                              color: colors.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    SvgPicture.asset(
                                      _promoController.text == promo['code']
                                          ? Assets.icons.check
                                          : Assets.icons.navArrowRight,
                                      package: "grab_go_shared",
                                      height: 18.h,
                                      width: 18.h,
                                      colorFilter: ColorFilter.mode(
                                        _promoController.text == promo['code']
                                            ? colors.accentViolet
                                            : colors.textSecondary,
                                        BlendMode.srcIn,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),

                        SizedBox(height: KSpacing.md.h),

                        Row(
                          children: [
                            Expanded(
                              child: AppButton(
                                width: double.infinity,
                                onPressed: () => Navigator.of(context).pop(),
                                buttonText: "Cancel",
                                textStyle: TextStyle(
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w800,
                                  color: colors.textSecondary,
                                ),
                                backgroundColor: colors.backgroundSecondary,
                                padding: EdgeInsets.symmetric(vertical: 16.h),
                                borderRadius: KBorderSize.borderMedium,
                              ),
                            ),

                            SizedBox(width: KSpacing.md.w),

                            Expanded(
                              child: AppButton(
                                width: double.infinity,
                                onPressed: () => _applyPromo(_promoController.text),
                                buttonText: "Apply Code",
                                textStyle: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w800, color: Colors.white),
                                backgroundColor: colors.accentViolet,
                                padding: EdgeInsets.symmetric(vertical: 16.h),
                                borderRadius: KBorderSize.borderMedium,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    return TextEditingValue(text: newValue.text.toUpperCase(), selection: newValue.selection);
  }
}
