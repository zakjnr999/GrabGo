import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ReferralBanner extends StatefulWidget {
  const ReferralBanner({super.key});

  @override
  State<ReferralBanner> createState() => _ReferralBannerState();
}

class _ReferralBannerState extends State<ReferralBanner> with SingleTickerProviderStateMixin {
  late AnimationController _shimmerController;
  late Animation<double> _shimmerAnimation;
  bool _isDismissed = false;

  @override
  void initState() {
    super.initState();
    _checkDismissalStatus();
    _shimmerController = AnimationController(duration: const Duration(milliseconds: 2000), vsync: this)..repeat();

    _shimmerAnimation = Tween<double>(
      begin: -2,
      end: 2,
    ).animate(CurvedAnimation(parent: _shimmerController, curve: Curves.easeInOut));
  }

  Future<void> _checkDismissalStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final dismissed = prefs.getBool('referral_banner_dismissed') ?? false;
    if (mounted) {
      setState(() {
        _isDismissed = dismissed;
      });
    }
  }

  Future<void> _dismissBanner() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('referral_banner_dismissed', true);
    if (mounted) {
      setState(() {
        _isDismissed = true;
      });
    }
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    // Don't show banner if dismissed
    if (_isDismissed) {
      return const SizedBox.shrink();
    }

    return GestureDetector(
      onTap: () {
        context.push('/referral');
      },
      child: Container(
        margin: EdgeInsets.only(left: 20.w, right: 20.w, bottom: KSpacing.lg.h),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(KBorderSize.borderMedium),
          boxShadow: [
            BoxShadow(
              color: colors.accentOrange.withValues(alpha: 0.2),
              blurRadius: 12,
              spreadRadius: 0,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(KBorderSize.borderMedium),
          child: Stack(
            children: [
              Container(
                height: 80.h,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [colors.accentOrange, colors.accentOrange.withValues(alpha: 0.85), const Color(0xFFFFB800)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),

              AnimatedBuilder(
                animation: _shimmerAnimation,
                builder: (context, child) {
                  return Positioned.fill(
                    child: Transform.translate(
                      offset: Offset(_shimmerAnimation.value * 200, 0),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.transparent, Colors.white.withValues(alpha: 0.15), Colors.transparent],
                            stops: const [0.0, 0.5, 1.0],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),

              Positioned(
                right: -20.w,
                top: -20.h,
                child: Container(
                  width: 80.w,
                  height: 80.h,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.1)),
                ),
              ),
              Positioned(
                left: -10.w,
                bottom: -15.h,
                child: Container(
                  width: 60.w,
                  height: 60.h,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.08)),
                ),
              ),

              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
                child: Row(
                  children: [
                    Container(
                      width: 52.w,
                      height: 52.h,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(KBorderSize.borderSmall),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Center(
                        child: SvgPicture.asset(
                          Assets.icons.gift,
                          package: 'grab_go_shared',
                          width: 28.w,
                          height: 28.h,
                          colorFilter: ColorFilter.mode(colors.accentOrange, BlendMode.srcIn),
                        ),
                      ),
                    ),

                    SizedBox(width: 14.w),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Refer & Earn GH₵50',
                            style: TextStyle(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              height: 1.2,
                            ),
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            'Share with friends and get rewarded',
                            style: TextStyle(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withValues(alpha: 0.9),
                              height: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Close button
                    GestureDetector(
                      onTap: () {
                        _dismissBanner();
                      },
                      child: Container(
                        width: 32.w,
                        height: 32.h,
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
                        child: Center(
                          child: Icon(Icons.close, size: 18.sp, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
