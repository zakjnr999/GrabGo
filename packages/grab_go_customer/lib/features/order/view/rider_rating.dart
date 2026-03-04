import 'package:cached_network_image/cached_network_image.dart';
import 'package:dotted_line/dotted_line.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import '../../../shared/widgets/custom_input_bottom_sheet.dart';

class RiderRating extends StatefulWidget {
  final String orderId;
  final String? riderName;
  final String? riderImage;

  const RiderRating({
    super.key,
    required this.orderId,
    this.riderName,
    this.riderImage,
  });

  @override
  State<RiderRating> createState() => RiderRatingState();
}

class RiderRatingState extends State<RiderRating> {
  int _riderRating = 0;
  final TextEditingController _commentController = TextEditingController();
  bool isSubmitting = false;
  bool _showCustomTip = false;
  double _tipAmount = 0.0;

  final List<String> _selectedComment = [];

  String _getRatingDescription(int rating) {
    switch (rating) {
      case 5:
        return 'Amazing! Perfect delivery!';
      case 4:
        return 'Great! Very satisfied';
      case 3:
        return 'Good, but could improve';
      case 2:
        return 'Not great, had issues';
      case 1:
        return 'Poor experience';
      default:
        return 'Tap stars to rate';
    }
  }

  List<String> _getFeedbackChips(int rating) {
    if (rating >= 4) {
      return [
        'Friendly rider',
        'On time delivery',
        'Careful handling',
        'Professional',
        'Great communication',
        'Followed instructions',
      ];
    } else if (rating == 3) {
      return [
        'Slightly late',
        'Could be friendlier',
        'Missed instructions',
        'Average service',
        'Needs improvement',
      ];
    } else if (rating >= 1) {
      return [
        'Very late',
        'Rude behavior',
        'Damaged items',
        'Wrong location',
        'Poor communication',
        'Ignored instructions',
      ];
    }
    return [];
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    Size size = MediaQuery.sizeOf(context);
    final feedbackChips = _getFeedbackChips(_riderRating);

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: colors.backgroundPrimary,
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Rider Rating Section
          SingleChildScrollView(
            child: Column(
              children: [
                _buildRatingSection(
                  title: 'How was your order with ${widget.riderName} ?',
                  starDescription: _getRatingDescription(_riderRating),
                  image: widget.riderImage,
                  size: size,
                  rating: _riderRating,
                  onRatingChanged: (rating) {
                    setState(() {
                      _riderRating = rating;
                      _selectedComment.clear();
                    });
                  },
                  colors: colors,
                ),

                SizedBox(height: KSpacing.lg25.h),

                // Only show feedback chips if rating is selected
                if (_riderRating > 0)
                  AnimatedSize(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20.w),
                      child: Wrap(
                        spacing: 8.w,
                        runSpacing: 8.h,
                        children: [
                          ...feedbackChips.asMap().entries.map((entry) {
                            final index = entry.key;
                            final chip = entry.value;
                            return TweenAnimationBuilder<double>(
                              duration: Duration(
                                milliseconds: 200 + (index * 50),
                              ),
                              tween: Tween(begin: 0.0, end: 1.0),
                              curve: Curves.easeOut,
                              builder: (context, value, child) {
                                return Opacity(
                                  opacity: value,
                                  child: Transform.translate(
                                    offset: Offset(0, 10 * (1 - value)),
                                    child: child,
                                  ),
                                );
                              },
                              child: _buildCommentChip(chip, colors),
                            );
                          }),
                          TweenAnimationBuilder<double>(
                            duration: Duration(
                              milliseconds: 200 + (feedbackChips.length * 50),
                            ),
                            tween: Tween(begin: 0.0, end: 1.0),
                            curve: Curves.easeOut,
                            builder: (context, value, child) {
                              return Opacity(
                                opacity: value,
                                child: Transform.translate(
                                  offset: Offset(0, 10 * (1 - value)),
                                  child: child,
                                ),
                              );
                            },
                            child: _buildCustomCommentChip(colors),
                          ),
                        ],
                      ),
                    ),
                  ),

                SizedBox(height: KSpacing.lg25.h),

                DottedLine(
                  dashLength: 6,
                  dashGapLength: 4,
                  lineThickness: 1,
                  dashColor: colors.textSecondary.withAlpha(50),
                ),

                SizedBox(height: KSpacing.lg25.h),

                Text(
                  "Tip Your Rider",
                  style: TextStyle(
                    fontSize: 22.sp,
                    fontWeight: FontWeight.w800,
                    color: colors.textPrimary,
                  ),
                ),

                SizedBox(height: 5.h),

                Text(
                  "We share the full tip amount to the rider.",
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w400,
                    color: colors.textPrimary,
                  ),
                ),

                SizedBox(height: KSpacing.lg.h),

                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20.w),
                  child: Wrap(
                    spacing: 8.w,
                    runSpacing: 8.h,
                    children: [
                      ...[
                        (0.0, "No tip"),
                        (2.0, "GHS 2"),
                        (5.0, "GHS 5"),
                        (10.0, "GHS 10"),
                      ].asMap().entries.map((entry) {
                        final index = entry.key;
                        final tipData = entry.value;
                        return TweenAnimationBuilder<double>(
                          duration: Duration(milliseconds: 200 + (index * 50)),
                          tween: Tween(begin: 0.0, end: 1.0),
                          curve: Curves.easeOut,
                          builder: (context, value, child) {
                            return Opacity(
                              opacity: value,
                              child: Transform.translate(
                                offset: Offset(0, 10 * (1 - value)),
                                child: child,
                              ),
                            );
                          },
                          child: _buildTipChip(tipData.$1, tipData.$2, colors),
                        );
                      }),
                      TweenAnimationBuilder<double>(
                        duration: const Duration(milliseconds: 400),
                        tween: Tween(begin: 0.0, end: 1.0),
                        curve: Curves.easeOut,
                        builder: (context, value, child) {
                          return Opacity(
                            opacity: value,
                            child: Transform.translate(
                              offset: Offset(0, 10 * (1 - value)),
                              child: child,
                            ),
                          );
                        },
                        child: _buildCustomTipChip(colors),
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

  Widget _buildRatingSection({
    required String title,
    required String starDescription,
    required String? image,
    required Size size,
    required int rating,
    required Function(int) onRatingChanged,
    required AppColorsExtension colors,
  }) {
    final hasImage = (image?.trim().isNotEmpty ?? false);

    return Container(
      color: colors.backgroundPrimary,
      child: Column(
        children: [
          ClipOval(
            child: hasImage
                ? CachedNetworkImage(
                    height: size.width * 0.15,
                    width: size.width * 0.15,
                    fit: BoxFit.cover,
                    imageUrl: ImageOptimizer.getPreviewUrl(image!, width: 200),
                    memCacheWidth: 200,
                    maxHeightDiskCache: 200,
                    placeholder: (context, url) => Container(
                      height: size.width * 0.15,
                      width: size.width * 0.15,
                      decoration: BoxDecoration(
                        color: colors.backgroundPrimary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      height: size.width * 0.15,
                      width: size.width * 0.15,
                      padding: EdgeInsets.all(12.r),
                      decoration: BoxDecoration(
                        color: colors.backgroundSecondary,
                        shape: BoxShape.circle,
                      ),
                      child: SvgPicture.asset(
                        Assets.icons.user,
                        package: "grab_go_shared",
                        colorFilter: ColorFilter.mode(
                          colors.textPrimary,
                          BlendMode.srcIn,
                        ),
                      ),
                    ),
                  )
                : Container(
                    height: size.width * 0.15,
                    width: size.width * 0.15,
                    padding: EdgeInsets.all(12.r),
                    decoration: BoxDecoration(
                      color: colors.backgroundSecondary,
                      shape: BoxShape.circle,
                    ),
                    child: SvgPicture.asset(
                      Assets.icons.user,
                      package: "grab_go_shared",
                      colorFilter: ColorFilter.mode(
                        colors.textPrimary,
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
          ),

          SizedBox(height: 20.h),

          Text(
            title,
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w400,
              color: colors.textPrimary,
            ),
          ),

          SizedBox(height: 5.h),

          Text(
            starDescription,
            style: TextStyle(
              fontSize: 22.sp,
              fontWeight: FontWeight.w800,
              color: colors.accentOrange,
            ),
          ),

          SizedBox(height: KSpacing.lg.h),

          // Star Rating
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              final starIndex = index + 1;
              return GestureDetector(
                onTap: () => onRatingChanged(starIndex),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8.w),
                  child: SvgPicture.asset(
                    starIndex <= rating
                        ? Assets.icons.starSolid
                        : Assets.icons.star,
                    package: "grab_go_shared",
                    colorFilter: ColorFilter.mode(
                      starIndex <= rating
                          ? colors.accentOrange
                          : colors.divider,
                      BlendMode.srcIn,
                    ),
                    height: 42.h,
                    width: 42.w,
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentChip(String label, AppColorsExtension colors) {
    final bool isSelected = _selectedComment.contains(label);

    return GestureDetector(
      onTap: () {
        setState(() {
          if (isSelected) {
            _selectedComment.remove(label);
          } else {
            _selectedComment.add(label);
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: isSelected ? colors.accentOrange : colors.backgroundSecondary,
          borderRadius: BorderRadius.circular(20.r),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : colors.textPrimary,
            fontSize: 13.sp,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildCustomCommentChip(AppColorsExtension colors) {
    return GestureDetector(
      onTap: () async {
        final result = await showCustomInputBottomSheet(
          context: context,
          title: 'Add Custom Feedback',
          hintText: 'Share your experience...',
          inputType: CustomInputType.comment,
          maxLength: 200,
        );

        if (result != null && result.isNotEmpty) {
          setState(() {
            _selectedComment.removeWhere((c) => c.startsWith('Custom: '));
            _selectedComment.add('Custom: $result');
          });
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: _selectedComment.any((c) => c.startsWith('Custom: '))
              ? colors.accentOrange
              : colors.backgroundSecondary,
          borderRadius: BorderRadius.circular(20.r),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Custom",
              style: TextStyle(
                color: _selectedComment.any((c) => c.startsWith('Custom: '))
                    ? Colors.white
                    : colors.textPrimary,
                fontSize: 13.sp,
                fontWeight:
                    _selectedComment.any((c) => c.startsWith('Custom: '))
                    ? FontWeight.w700
                    : FontWeight.w500,
              ),
            ),
            SizedBox(width: 4.w),
            SvgPicture.asset(
              _showCustomTip
                  ? Assets.icons.navArrowUp
                  : Assets.icons.navArrowDown,
              package: 'grab_go_shared',
              height: 16.h,
              width: 16.w,
              colorFilter: ColorFilter.mode(
                _showCustomTip ? Colors.white : colors.textPrimary,
                BlendMode.srcIn,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTipChip(double amount, String label, AppColorsExtension colors) {
    final bool isSelected = _tipAmount == amount;

    return GestureDetector(
      onTap: () {
        setState(() {
          _tipAmount = amount;
          _showCustomTip = false;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: isSelected ? colors.accentOrange : colors.backgroundSecondary,
          borderRadius: BorderRadius.circular(20.r),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : colors.textPrimary,
            fontSize: 13.sp,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildCustomTipChip(AppColorsExtension colors) {
    return GestureDetector(
      onTap: () async {
        final result = await showCustomInputBottomSheet(
          context: context,
          title: 'Enter Custom Tip',
          hintText: '0.00',
          inputType: CustomInputType.tip,
        );

        if (result != null && result.isNotEmpty) {
          final amount = double.tryParse(result);
          if (amount != null && amount > 0) {
            setState(() {
              _tipAmount = amount;
              _showCustomTip = true;
            });
          }
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: _showCustomTip
              ? colors.accentOrange
              : colors.backgroundSecondary,
          borderRadius: BorderRadius.circular(20.r),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _showCustomTip && _tipAmount > 0
                  ? "GHS ${_tipAmount.toStringAsFixed(2)}"
                  : "Custom",
              style: TextStyle(
                color: _showCustomTip ? Colors.white : colors.textPrimary,
                fontSize: 13.sp,
                fontWeight: _showCustomTip ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
            SizedBox(width: 4.w),
            SvgPicture.asset(
              _showCustomTip
                  ? Assets.icons.navArrowUp
                  : Assets.icons.navArrowDown,
              package: 'grab_go_shared',
              height: 16.h,
              width: 16.w,
              colorFilter: ColorFilter.mode(
                _showCustomTip ? Colors.white : colors.textPrimary,
                BlendMode.srcIn,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
