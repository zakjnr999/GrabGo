import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:grab_go_customer/shared/widgets/segmented_circle_painter.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';

enum StatusCategory { dailySpecial, discount, newItem, video }

class StatusStory {
  final String restaurantName;
  final StatusCategory category;
  final AssetGenImage logo;
  final int statusCount;
  final bool isViewed;

  StatusStory({
    required this.restaurantName,
    required this.category,
    required this.logo,
    required this.statusCount,
    this.isViewed = false,
  });
}

class StatusPost {
  final String restaurantName;
  final StatusCategory category;
  final String timeAgo;
  final AssetGenImage coverImage;
  final AssetGenImage logoImage;
  final bool isRecommended;

  StatusPost({
    required this.restaurantName,
    required this.category,
    required this.timeAgo,
    required this.coverImage,
    required this.logoImage,
    this.isRecommended = false,
  });
}

class StoryRing extends StatelessWidget {
  final double size;
  final int segments;
  final Color color;
  final Color backgroundColor;
  final Widget child;

  const StoryRing({
    super.key,
    required this.size,
    required this.segments,
    required this.color,
    required this.backgroundColor,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size.square(size),
            painter: SegmentedCirclePainter(segments: segments, color: color, strokeWidth: 2.4, gapDegrees: 14),
          ),
          Container(
            width: size - 8.r,
            height: size - 8.r,
            decoration: BoxDecoration(color: backgroundColor, shape: BoxShape.circle),
            child: ClipOval(child: child),
          ),
        ],
      ),
    );
  }
}
