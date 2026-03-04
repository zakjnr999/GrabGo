import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:grab_go_customer/shared/widgets/custom_input_bottom_sheet.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';

class VendorRating extends StatefulWidget {
  final String? vendorName;
  final String? vendorImage;

  const VendorRating({super.key, this.vendorName, this.vendorImage});

  @override
  State<VendorRating> createState() => _VendorRatingState();
}

class _VendorRatingState extends State<VendorRating> {
  int _vendorRating = 0;
  final bool _showCustomTip = false;

  final List<String> _selectedComment = [];

  // Get dynamic description based on vendor rating
  String _getVendorRatingDescription(int rating) {
    switch (rating) {
      case 5:
        return 'Excellent! Food was perfect';
      case 4:
        return 'Very good, enjoyed it';
      case 3:
        return 'Okay, but room for improvement';
      case 2:
        return 'Below expectations';
      case 1:
        return 'Very poor experience';
      default:
        return 'Tap stars to rate';
    }
  }

  // Get dynamic feedback chips based on vendor rating
  List<String> _getVendorFeedbackChips(int rating) {
    if (rating >= 4) {
      // Positive feedback for 4–5 stars
      return [
        'Delicious food',
        'Good portion size',
        'Fresh ingredients',
        'Well packaged',
        'Order was accurate',
        'Prepared on time',
        'Value for money',
      ];
    } else if (rating == 3) {
      // Neutral / improvement feedback
      return [
        'Food was average',
        'Small portion',
        'Packaging could improve',
        'Slight delay',
        'Taste was okay',
        'Order mostly correct',
      ];
    } else if (rating >= 1) {
      // Negative feedback for 1–2 stars
      return [
        'Cold food',
        'Bad taste',
        'Wrong items',
        'Poor packaging',
        'Food was late',
        'Small portions',
        'Not worth the price',
      ];
    }
    return [];
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    Size size = MediaQuery.sizeOf(context);
    final feedbackChips = _getVendorFeedbackChips(_vendorRating);
    final vendorDisplayName = (widget.vendorName?.trim().isNotEmpty ?? false)
        ? widget.vendorName!.trim()
        : 'Vendor';

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: colors.backgroundPrimary,
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Vendor Rating Section
          SingleChildScrollView(
            child: Column(
              children: [
                _buildRatingSection(
                  title: 'How was your dish from $vendorDisplayName?',
                  starDescription: _getVendorRatingDescription(_vendorRating),
                  image: widget.vendorImage,
                  size: size,
                  rating: _vendorRating,
                  onRatingChanged: (rating) {
                    setState(() {
                      _vendorRating = rating;
                      _selectedComment.clear();
                    });
                  },
                  colors: colors,
                ),

                SizedBox(height: KSpacing.lg25.h),

                // Only show feedback chips if rating is selected
                if (_vendorRating > 0)
                  AnimatedSize(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut,
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
              ],
            ),
          ),
        ],
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
}

Widget _buildRatingSection({
  required String title,
  required String starDescription,
  required String? image,
  required int rating,
  required Size size,
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
                    child: SvgPicture.asset(
                      Assets.icons.store,
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
                    Assets.icons.store,
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
                    starIndex <= rating ? colors.accentOrange : colors.divider,
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
