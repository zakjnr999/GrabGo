import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:grab_go_customer/features/home/model/promo_banner.dart';
import 'package:grab_go_customer/shared/widgets/promo_banner_card.dart';
import 'package:grab_go_customer/shared/widgets/promo_skeleton.dart';
import 'package:grab_go_customer/shared/widgets/section_header.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';

class PromoSection extends StatefulWidget {
  final List<PromoBanner> banners;
  final VoidCallback onSeeAll;
  final bool isLoading;

  const PromoSection({super.key, required this.banners, required this.onSeeAll, this.isLoading = false});

  @override
  State<PromoSection> createState() => _PromoSectionState();
}

class _PromoSectionState extends State<PromoSection> {
  late PageController _pageController;
  int _currentPage = 0;
  bool _autoScrollStarted = false;
  Timer? _autoScrollTimer;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.85, initialPage: 0);
  }

  @override
  void didUpdateWidget(PromoSection oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Start auto-scroll when banners become available
    if (!_autoScrollStarted && widget.banners.isNotEmpty && !widget.isLoading) {
      _autoScrollStarted = true;
      _startAutoScroll();
    }
  }

  void _startAutoScroll() {
    // Cancel existing timer if any
    _autoScrollTimer?.cancel();

    // Create new periodic timer
    _autoScrollTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (!mounted || widget.banners.isEmpty) {
        timer.cancel();
        return;
      }

      final nextPage = (_currentPage + 1) % widget.banners.length;
      _currentPage = nextPage;

      if (_pageController.hasClients) {
        _pageController.animateToPage(nextPage, duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
      }
    });
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    // Show skeleton ONLY if loading AND no banners
    if (widget.isLoading && widget.banners.isEmpty) {
      return Column(
        children: [
          SectionHeader(
            title: "Special Offers",
            sectionIcon: Assets.icons.tag,
            sectionTotal: widget.banners.length,
            accentColor: colors.accentOrange,
            onSeeAll: widget.onSeeAll,
          ),
          SizedBox(height: 15.h),
          PromoSkeleton(colors: colors, isDark: Theme.of(context).brightness == Brightness.dark),
        ],
      );
    }

    // Hide section if no banners
    if (widget.banners.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        SectionHeader(
          title: "Special Offers",
          sectionIcon: Assets.icons.tag,
          sectionTotal: widget.banners.length,
          accentColor: colors.accentOrange,
          onSeeAll: widget.onSeeAll,
        ),
        SizedBox(height: 15.h),
        SizedBox(
          height: 140.h,
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
              });
            },
            itemCount: widget.banners.length,
            itemBuilder: (context, index) {
              final banner = widget.banners[index];
              return AnimatedBuilder(
                animation: _pageController,
                builder: (context, child) {
                  double value = 1.0;
                  if (_pageController.position.haveDimensions) {
                    value = _pageController.page! - index;
                    value = (1 - (value.abs() * 0.1)).clamp(0.9, 1.0);
                  }
                  return Center(
                    child: SizedBox(height: Curves.easeInOut.transform(value) * 180.h, child: child),
                  );
                },
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8.w),
                  child: PromoBannerCard(
                    title: banner.title,
                    subtitle: banner.subtitle!,
                    imageUrl: banner.imageUrl,
                    discount: banner.discount!,
                    backgroundColor: _parseColor(banner.backgroundColor),
                    onTap: () {
                      debugPrint('Tapped banner: ${banner.title}');
                      // TODO: Navigate to targetUrl
                    },
                  ),
                ),
              );
            },
          ),
        ),
        SizedBox(height: KSpacing.lg.h),
      ],
    );
  }

  Color _parseColor(String hexColor) {
    try {
      return Color(int.parse(hexColor.substring(1, 7), radix: 16) + 0xFF000000);
    } catch (e) {
      return Colors.orange;
    }
  }
}
