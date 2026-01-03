import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class StoryStepper extends StatelessWidget {
  final int count;
  final int index;
  final Color activeColor;
  final Color inactiveColor;

  const StoryStepper({
    super.key,
    required this.count,
    required this.index,
    required this.activeColor,
    required this.inactiveColor,
  });

  @override
  Widget build(BuildContext context) {
    final items = List.generate(count, (i) => i);
    final current = index;
    return Row(
      children: [
        for (final i in items) ...[
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final double fill = i == current ? 1.0 : 0.0;

                return Stack(
                  children: [
                    Container(
                      height: 4.r,
                      decoration: BoxDecoration(color: inactiveColor, borderRadius: BorderRadius.circular(4.r)),
                    ),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeInOut,
                      height: 4.r,
                      width: constraints.maxWidth * fill,
                      decoration: BoxDecoration(color: activeColor, borderRadius: BorderRadius.circular(4.r)),
                    ),
                  ],
                );
              },
            ),
          ),
          if (i != count - 1) SizedBox(width: 6.w),
        ],
      ],
    );
  }
}
