// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../app_colors.dart';

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

class _AnimatedTabBarState extends State<AnimatedTabBar>
    with TickerProviderStateMixin {
  late AnimationController _slideController;
  late Animation<double> _slideAnimation;
  late ScrollController _scrollController;
  int _previousIndex = 0;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideAnimation = CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeInOut,
    );
    _scrollController = ScrollController();
    _scrollController.addListener(() {
      if (_scrollController.hasClients) {
        setState(() {}); // Rebuild when scrolling
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

      // Auto-scroll to selected tab
      _scrollToSelectedTab();
    }
  }

  void _scrollToSelectedTab() {
    // Add a small delay to ensure the scroll controller is attached
    Future.delayed(const Duration(milliseconds: 50), () {
      if (!_scrollController.hasClients) return;

      final double tabWidth = 80;
      final double targetOffset = widget.selectedIndex * tabWidth;
      final double maxScroll = _scrollController.position.maxScrollExtent;
      final double viewportWidth = _scrollController.position.viewportDimension;

      // Calculate the ideal scroll position to center the selected tab
      final double idealOffset =
          (targetOffset - viewportWidth / 2 + tabWidth / 2).clamp(
            0.0,
            maxScroll,
          );

      _scrollController.animateTo(
        idealOffset,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: widget.height ?? 50,
      padding: widget.padding ?? const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSidebar : AppColors.lightSurface,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.only(left: 2),
          child: Stack(
            children: [
              // Animated sliding selector
              AnimatedBuilder(
                animation: _slideAnimation,
                builder: (context, child) {
                  // Use fixed tab width for consistent selector positioning
                  final double tabWidth = 80; // Fixed width matching the tab width

                  final double startPosition = _previousIndex * tabWidth;
                  final double endPosition = widget.selectedIndex * tabWidth;
                  final double currentPosition =
                      startPosition +
                      (endPosition - startPosition) * _slideAnimation.value;

                  return Positioned(
                    left:
                        currentPosition +
                        -1 -
                        (_scrollController.hasClients
                            ? _scrollController.offset
                            : 0), // Subtract scroll offset safely
                    top: 4,
                    child: Container(
                      width:
                          tabWidth -
                          1, // Match the tab width minus margins exactly
                      height: (widget.height ?? 50) - 8,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkBackground : AppColors.primary,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(isDark ? 0.3 : 0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              // Scrollable tab buttons
              SingleChildScrollView(
                controller: _scrollController,
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
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
                        height: (widget.height ?? 50) - 6,
                        width: 80, // Fixed width
                        child: Center(
                          child: AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeInOut,
                            style: GoogleFonts.lato(
                              fontSize: 12, // Slightly smaller font for better fit
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                              color: isSelected
                                  ? (isDark ? AppColors.accentOrange : AppColors.white)
                                  : (isDark ? AppColors.white.withOpacity(0.7) : AppColors.primary.withOpacity(0.7)),
                              height: 1.2, // Better line height for centering
                            ),
                            child: Text(
                              tab,
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1, // Ensure single line
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
