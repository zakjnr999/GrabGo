import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:grab_go_customer/shared/widgets/promo_banner_card.dart';
import 'package:grab_go_customer/shared/widgets/promo_skeleton.dart';
import 'package:grab_go_customer/shared/widgets/section_header.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';

class PromoSection extends StatefulWidget {
  final VoidCallback onSeeAll;
  final bool isLoading;

  const PromoSection({super.key, required this.onSeeAll, this.isLoading = false});

  @override
  State<PromoSection> createState() => _PromoSectionState();
}

class _PromoSectionState extends State<PromoSection> {
  late PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(
      viewportFraction: 0.85, // Show parts of adjacent cards
      initialPage: 0,
    );

    // Auto-scroll every 5 seconds
    Future.delayed(const Duration(seconds: 5), _autoScroll);
  }

  void _autoScroll() {
    if (!mounted) return;

    final nextPage = (_currentPage + 1) % 3; // 3 promos
    _pageController.animateToPage(nextPage, duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);

    Future.delayed(const Duration(seconds: 5), _autoScroll);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Mock promotional data
    final promos = [
      {
        'title': 'Slice & Save on\nPizza Hut',
        'subtitle': 'Savour your favourite\npizza for just GHS43',
        'imageUrl': 'https://images.unsplash.com/photo-1513104890138-7c749659a591?w=400',
        'discount': '-50%',
        'backgroundColor': const Color(0xFFFFF4E6),
      },
      {
        'title': 'Fresh Burgers\nat KFC',
        'subtitle': 'Crispy chicken burgers\nstarting at GHS35',
        'imageUrl': 'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=400',
        'discount': '-40%',
        'backgroundColor': const Color(0xFFFFEBEE),
      },
      {
        'title': 'Sushi Special\nat Zen Garden',
        'subtitle': 'Premium sushi rolls\nfrom GHS55',
        'imageUrl': 'https://images.unsplash.com/photo-1579584425555-c3ce17fd4351?w=400',
        'discount': '-30%',
        'backgroundColor': const Color(0xFFE8F5E9),
      },
    ];

    return Column(
      children: [
        SectionHeader(
          title: "Special Offers",
          icon: Assets.icons.tag,
          accentColor: colors.accentOrange,
          onSeeAll: widget.onSeeAll,
        ),
        SizedBox(height: 16.h),
        if (widget.isLoading)
          PromoSkeleton(colors: colors, isDark: isDark)
        else
          SizedBox(
            height: 170.h,
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() {
                  _currentPage = index;
                });
              },
              itemCount: promos.length,
              itemBuilder: (context, index) {
                final promo = promos[index];
                return AnimatedBuilder(
                  animation: _pageController,
                  builder: (context, child) {
                    double value = 1.0;
                    if (_pageController.position.haveDimensions) {
                      value = _pageController.page! - index;
                      value = (1 - (value.abs() * 0.15)).clamp(0.85, 1.0);
                    }
                    return Center(
                      child: SizedBox(height: Curves.easeInOut.transform(value) * 160.h, child: child),
                    );
                  },
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8.w),
                    child: PromoBannerCard(
                      title: promo['title'] as String,
                      subtitle: promo['subtitle'] as String,
                      imageUrl: promo['imageUrl'] as String,
                      discount: promo['discount'] as String,
                      backgroundColor: promo['backgroundColor'] as Color,
                      onTap: () {
                        debugPrint('Promo tapped: ${promo['title']}');
                      },
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}
