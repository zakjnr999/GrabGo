import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:grab_go_customer/features/home/model/promotional_banner.dart';
import 'package:grab_go_customer/shared/widgets/wavy_banner_clipper.dart';
import 'package:grab_go_shared/grub_go_shared.dart';

class PromotionalBannerCarousel extends StatefulWidget {
  final List<PromotionalBanner> banners;
  final Duration autoPlayDuration;

  const PromotionalBannerCarousel({
    super.key,
    required this.banners,
    this.autoPlayDuration = const Duration(seconds: 5),
  });

  @override
  State<PromotionalBannerCarousel> createState() => _PromotionalBannerCarouselState();
}

class _PromotionalBannerCarouselState extends State<PromotionalBannerCarousel> with SingleTickerProviderStateMixin {
  late PageController _pageController;
  late AnimationController _shimmerController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 1.0);
    _shimmerController = AnimationController(duration: const Duration(milliseconds: 2000), vsync: this)..repeat();

    Future.delayed(widget.autoPlayDuration, _autoPlay);
  }

  void _autoPlay() {
    if (!mounted) return;

    final nextPage = (_currentPage + 1) % widget.banners.length;
    _pageController.animateToPage(nextPage, duration: const Duration(milliseconds: 600), curve: Curves.easeInOutCubic);

    Future.delayed(widget.autoPlayDuration, _autoPlay);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    if (widget.banners.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 150.h,
      child: PageView.builder(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _currentPage = index;
          });
        },
        itemCount: widget.banners.length,
        itemBuilder: (context, index) {
          return AnimatedBuilder(
            animation: _pageController,
            builder: (context, child) {
              double value = 1.0;
              if (_pageController.position.haveDimensions) {
                value = _pageController.page! - index;
                value = (1 - (value.abs() * 0.15)).clamp(0.85, 1.0);
              }
              return Center(
                child: SizedBox(height: Curves.easeOut.transform(value) * 180.h, child: child),
              );
            },
            child: _buildBannerCard(widget.banners[index], colors),
          );
        },
      ),
    );
  }

  Widget _buildBannerCard(PromotionalBanner banner, AppColorsExtension colors) {
    return GestureDetector(
      onTap: banner.onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Main card
          Container(
            width: double.infinity,
            margin: EdgeInsets.symmetric(horizontal: 20.w),

            child: ClipPath(
              clipper: WavyBannerClipper(waveHeight: 8, waveCount: 12, cornerRadius: 16),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: banner.gradientColors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Stack(
                  children: [
                    Padding(
                      padding: EdgeInsets.fromLTRB(24.w, 32.h, 24.w, 20.h),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            banner.title,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22.sp,
                              fontWeight: FontWeight.w800,
                              height: 1.2,
                            ),
                          ),
                          SizedBox(height: 6.h),
                          Text(
                            banner.subtitle,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.95),
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(height: 12.h),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(100.r),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  banner.actionText,
                                  style: TextStyle(color: Colors.white, fontSize: 13.sp, fontWeight: FontWeight.w700),
                                ),
                                SizedBox(width: 6.w),
                                Icon(Icons.arrow_forward, color: Colors.white, size: 16.sp),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Decorative background emoji
          Positioned(
            right: 14.w,
            bottom: 10.h,
            child: Opacity(
              opacity: 0.65,
              child: Text(banner.emoji, style: TextStyle(fontSize: 80.sp)),
            ),
          ),
        ],
      ),
    );
  }
}
