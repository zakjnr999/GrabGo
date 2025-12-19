import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';

class ReferralBanner extends StatefulWidget {
  const ReferralBanner({super.key});

  @override
  State<ReferralBanner> createState() => _ReferralBannerState();
}

class _ReferralBannerState extends State<ReferralBanner> with SingleTickerProviderStateMixin {
  late AnimationController _shimmerController;
  late Animation<double> _shimmerAnimation;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(duration: const Duration(milliseconds: 2000), vsync: this)..repeat();

    _shimmerAnimation = Tween<double>(
      begin: -2,
      end: 2,
    ).animate(CurvedAnimation(parent: _shimmerController, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return GestureDetector(
      onTap: () {
        // Navigate to referral page
        context.push('/referral');
      },
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 20.w),
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
              // Gradient Background
              Container(
                height: 80.h,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      colors.accentOrange,
                      colors.accentOrange.withValues(alpha: 0.85),
                      Color(0xFFFFB800), // Golden yellow
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),

              // Shimmer Effect Overlay
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

              // Decorative Circles
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

              // Content
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
                child: Row(
                  children: [
                    // Gift Icon
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

                    // Text Content
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

                    // Arrow Icon
                    Container(
                      width: 32.w,
                      height: 32.h,
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
                      child: Center(
                        child: SvgPicture.asset(
                          Assets.icons.navArrowRight,
                          package: 'grab_go_shared',
                          width: 16.w,
                          height: 16.h,
                          colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
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
