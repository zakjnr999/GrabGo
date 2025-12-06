import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shimmer/shimmer.dart';

/// Skeleton loader for comment items
class CommentSkeleton extends StatelessWidget {
  const CommentSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar skeleton
          Shimmer.fromColors(
            baseColor: Colors.grey[300]!,
            highlightColor: Colors.grey[100]!,
            child: CircleAvatar(radius: 18.r, backgroundColor: Colors.white),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name skeleton
                Shimmer.fromColors(
                  baseColor: Colors.grey[300]!,
                  highlightColor: Colors.grey[100]!,
                  child: Container(
                    width: 100.w,
                    height: 12.h,
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4.r)),
                  ),
                ),
                SizedBox(height: 8.h),
                // Comment text skeleton (2 lines)
                Shimmer.fromColors(
                  baseColor: Colors.grey[300]!,
                  highlightColor: Colors.grey[100]!,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        height: 10.h,
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4.r)),
                      ),
                      SizedBox(height: 6.h),
                      Container(
                        width: 200.w,
                        height: 10.h,
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4.r)),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 8.h),
                // Action buttons skeleton
                Shimmer.fromColors(
                  baseColor: Colors.grey[300]!,
                  highlightColor: Colors.grey[100]!,
                  child: Row(
                    children: [
                      Container(
                        width: 60.w,
                        height: 8.h,
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4.r)),
                      ),
                      SizedBox(width: 16.w),
                      Container(
                        width: 40.w,
                        height: 8.h,
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4.r)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Skeleton loader for multiple comments
class CommentsListSkeleton extends StatelessWidget {
  final int count;

  const CommentsListSkeleton({super.key, this.count = 3});

  @override
  Widget build(BuildContext context) {
    return Column(children: List.generate(count, (index) => const CommentSkeleton()));
  }
}

/// Skeleton loader for replies list
class RepliesListSkeleton extends StatelessWidget {
  final int count;

  const RepliesListSkeleton({super.key, this.count = 3});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        count,
        (index) => Padding(
          padding: EdgeInsets.symmetric(horizontal: 56.w, vertical: 8.h),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar skeleton
              Shimmer.fromColors(
                baseColor: Colors.grey[300]!,
                highlightColor: Colors.grey[100]!,
                child: CircleAvatar(radius: 14.r, backgroundColor: Colors.white),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name skeleton
                    Shimmer.fromColors(
                      baseColor: Colors.grey[300]!,
                      highlightColor: Colors.grey[100]!,
                      child: Container(
                        width: 80.w,
                        height: 10.h,
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4.r)),
                      ),
                    ),
                    SizedBox(height: 6.h),
                    // Reply text skeleton
                    Shimmer.fromColors(
                      baseColor: Colors.grey[300]!,
                      highlightColor: Colors.grey[100]!,
                      child: Container(
                        width: 150.w,
                        height: 8.h,
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4.r)),
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

/// Shimmer effect for reaction bar while loading
class ReactionBarSkeleton extends StatelessWidget {
  const ReactionBarSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Row(
        children: [
          // Reaction emojis skeleton
          ...List.generate(
            3,
            (index) => Padding(
              padding: EdgeInsets.only(right: 4.w),
              child: Container(
                width: 20.r,
                height: 20.r,
                decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle),
              ),
            ),
          ),
          SizedBox(width: 4.w),
          // Count skeleton
          Container(
            width: 20.w,
            height: 12.h,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4.r)),
          ),
        ],
      ),
    );
  }
}
