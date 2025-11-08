import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../utils/app_colors_extension.dart';
import '../utils/constants.dart';

class AnimatedTabBar extends StatefulWidget {
  final List<String> tabs;
  final int selectedIndex;
  final ValueChanged<int> onTabChanged;
  final double? height;
  final EdgeInsets? padding;

  const AnimatedTabBar({
    super.key,
    required this.tabs,
    required this.selectedIndex,
    required this.onTabChanged,
    this.height,
    this.padding,
  });

  @override
  State<AnimatedTabBar> createState() => _AnimatedTabBarState();
}

class _AnimatedTabBarState extends State<AnimatedTabBar> with TickerProviderStateMixin {
  late AnimationController _slideController;
  late Animation<double> _slideAnimation;
  late ScrollController _scrollController;
  int _previousIndex = 0;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(duration: const Duration(milliseconds: 300), vsync: this);
    _slideAnimation = CurvedAnimation(parent: _slideController, curve: Curves.easeInOut);
    _scrollController = ScrollController();
    _scrollController.addListener(() {
      if (_scrollController.hasClients) {
        setState(() {});
      }
    });
    _previousIndex = widget.selectedIndex;
  }

  @override
  void didUpdateWidget(AnimatedTabBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex != widget.selectedIndex) {
      _previousIndex = oldWidget.selectedIndex;
      _slideController.reset();
      _slideController.forward();

      _scrollToSelectedTab();
    }
  }

  void _scrollToSelectedTab() {
    Future.delayed(const Duration(milliseconds: 50), () {
      if (!_scrollController.hasClients) return;

      final double tabWidth = 80.w;
      final double targetOffset = widget.selectedIndex * tabWidth;
      final double maxScroll = _scrollController.position.maxScrollExtent;
      final double viewportWidth = _scrollController.position.viewportDimension;

      final double idealOffset = (targetOffset - viewportWidth / 2 + tabWidth / 2).clamp(0.0, maxScroll);

      _scrollController.animateTo(idealOffset, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    });
  }

  @override
  void dispose() {
    _slideController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Container(
      height: widget.height ?? 50.h,
      width: double.infinity,
      padding: widget.padding ?? EdgeInsets.symmetric(horizontal: 20.w),
      child: Container(
        decoration: BoxDecoration(
          color: colors.backgroundTertiary,
          borderRadius: BorderRadius.circular(KBorderSize.borderRadius8),
        ),
        child: Padding(
          padding: const EdgeInsets.only(left: 2),
          child: Stack(
            children: [
              AnimatedBuilder(
                animation: _slideAnimation,
                builder: (context, child) {
                  final double tabWidth = 80.w;

                  final double startPosition = _previousIndex * tabWidth;
                  final double endPosition = widget.selectedIndex * tabWidth;
                  final double currentPosition = startPosition + (endPosition - startPosition) * _slideAnimation.value;

                  return Positioned(
                    left: currentPosition + -1.w - (_scrollController.hasClients ? _scrollController.offset : 0),
                    top: 4.h,
                    child: Container(
                      width: tabWidth - 1.w,
                      height: (widget.height ?? 50.h) - 8.h,
                      margin: EdgeInsets.symmetric(horizontal: 2.w),
                      decoration: BoxDecoration(
                        color: colors.backgroundPrimary,
                        borderRadius: BorderRadius.circular(KBorderSize.borderRadius8),
                      ),
                    ),
                  );
                },
              ),
              SingleChildScrollView(
                controller: _scrollController,
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: widget.tabs.asMap().entries.map((entry) {
                    final index = entry.key;
                    final tab = entry.value;
                    final isSelected = index == widget.selectedIndex;

                    return GestureDetector(
                      onTap: () {
                        if (index != widget.selectedIndex) {
                          widget.onTabChanged(index);
                        }
                      },
                      child: SizedBox(
                        height: (widget.height ?? 50.h) - 8.h,
                        width: 80.w,
                        child: Center(
                          child: AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeInOut,
                            style: TextStyle(
                              fontFamily: "Lato",
                              fontSize: 12.sp,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w600,
                              color: isSelected ? colors.accentOrange : colors.textSecondary,
                              height: 2,
                            ),
                            child: Text(
                              tab,
                              style: TextStyle(fontFamily: "Lato", package: 'grab_go_shared', height: 2),
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
