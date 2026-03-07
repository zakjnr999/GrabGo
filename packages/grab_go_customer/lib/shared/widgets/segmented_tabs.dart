import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:grab_go_shared/shared/utils/app_colors_extension.dart';

class SegmentedTabs extends StatelessWidget {
  const SegmentedTabs({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onChanged,
    this.fontSize = 12,
    this.verticalPadding = 12,
    this.outerPadding = 3,
    this.selectedHorizontalInset = 0,
  });

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onChanged;
  final double fontSize;
  final double verticalPadding;
  final double outerPadding;
  final double selectedHorizontalInset;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final tabCount = labels.length;
    final safeIndex = selectedIndex.clamp(0, tabCount - 1);

    return Container(
      padding: EdgeInsets.all(outerPadding.r),
      decoration: BoxDecoration(
        color: colors.backgroundSecondary,
        borderRadius: BorderRadius.circular(999.r),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tabWidth = constraints.maxWidth / tabCount;
          final inset = selectedHorizontalInset.w;
          final selectedWidth = (tabWidth - (inset * 2)).clamp(0.0, tabWidth);
          return Stack(
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                left: (tabWidth * safeIndex) + inset,
                top: 0,
                bottom: 0,
                width: selectedWidth,
                child: Container(
                  decoration: BoxDecoration(
                    color: colors.accentOrange,
                    borderRadius: BorderRadius.circular(999.r),
                  ),
                ),
              ),
              Row(
                children: List.generate(tabCount, (index) {
                  final selected = safeIndex == index;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () {
                        if (safeIndex == index) return;
                        onChanged(index);
                      },
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          vertical: verticalPadding.h,
                          horizontal: 8.w,
                        ),
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOutCubic,
                          style: TextStyle(
                            color: selected
                                ? Colors.white
                                : colors.textSecondary,
                            fontSize: fontSize.sp,
                            fontWeight: selected
                                ? FontWeight.w700
                                : FontWeight.w600,
                            fontFamily: 'Lato',
                            package: 'grab_go_shared',
                          ),
                          child: Text(
                            labels[index],
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            softWrap: false,
                            overflow: TextOverflow.fade,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ],
          );
        },
      ),
    );
  }
}
