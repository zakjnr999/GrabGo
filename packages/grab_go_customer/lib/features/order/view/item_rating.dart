import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:grab_go_customer/features/order/model/item_review_models.dart';
import 'package:grab_go_customer/features/order/service/order_service_wrapper.dart';
import 'package:grab_go_customer/features/order/viewmodel/order_provider.dart';
import 'package:grab_go_customer/shared/widgets/custom_input_bottom_sheet.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:provider/provider.dart';

class ItemRating extends StatefulWidget {
  final String orderId;
  final String orderItemId;
  final String itemType;
  final String itemName;
  final String? itemImage;
  final bool embedded;
  final Future<void> Function(int? submittedRating)? onCompleted;

  const ItemRating({
    super.key,
    required this.orderId,
    required this.orderItemId,
    required this.itemType,
    required this.itemName,
    this.itemImage,
    this.embedded = false,
    this.onCompleted,
  });

  @override
  State<ItemRating> createState() => _ItemRatingState();
}

class _ItemRatingState extends State<ItemRating> {
  int _itemRating = 0;
  bool _isSubmitting = false;
  final List<String> _selectedComment = [];

  String _getItemRatingDescription(int rating) {
    switch (rating) {
      case 5:
        return 'Excellent! You loved it';
      case 4:
        return 'Very good choice';
      case 3:
        return 'It was okay';
      case 2:
        return 'Below expectations';
      case 1:
        return 'Not good';
      default:
        return 'Tap stars to rate';
    }
  }

  List<String> _getItemFeedbackChips(int rating) {
    if (rating >= 4) {
      return const [
        'Great taste',
        'Fresh',
        'Good portion',
        'Well packaged',
        'Worth the price',
        'Exactly as expected',
      ];
    } else if (rating == 3) {
      return const [
        'Average taste',
        'Could be fresher',
        'Small portion',
        'Packaging could improve',
        'Just okay',
      ];
    } else if (rating >= 1) {
      return const [
        'Bad taste',
        'Not fresh',
        'Poor quality',
        'Small portion',
        'Wrong item',
        'Not worth the price',
      ];
    }
    return const [];
  }

  String? get _customComment {
    for (final entry in _selectedComment) {
      if (entry.startsWith('Custom: ')) {
        return entry.substring('Custom: '.length).trim();
      }
    }
    return null;
  }

  Future<void> _finish(int? submittedRating) async {
    if (widget.onCompleted != null) {
      await widget.onCompleted!(submittedRating);
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pop(submittedRating);
  }

  Future<void> _handlePrimaryAction() async {
    if (_isSubmitting) return;

    if (_itemRating <= 0) {
      await _finish(null);
      return;
    }

    setState(() => _isSubmitting = true);

    final colors = context.appColors;
    try {
      final result = await OrderServiceWrapper().submitItemReviews(
        orderId: widget.orderId,
        request: ItemReviewSubmissionRequest(
          reviews: [
            ItemReviewSubmissionEntryRequest(
              orderItemId: widget.orderItemId,
              rating: _itemRating,
              feedbackTags: _selectedComment
                  .where((entry) => !entry.startsWith('Custom: '))
                  .toList(growable: false),
              comment: _customComment,
            ),
          ],
        ),
      );

      try {
        await context.read<OrderProvider>().markItemReviewsSubmitted(
          orderId: widget.orderId,
          submittedReviews: result.reviews
              .map(
                (entry) => {
                  'orderItemId': entry.orderItemId,
                  'rating': entry.rating,
                  'submittedAt': entry.submittedAt?.toIso8601String(),
                },
              )
              .toList(growable: false),
        );
      } catch (_) {
        // Submission already succeeded.
      }

      if (!mounted) return;
      AppToastMessage.show(
        context: context,
        message: 'Thanks for rating ${widget.itemName}.',
        backgroundColor: colors.accentGreen,
      );
      await _finish(_itemRating);
    } catch (e) {
      if (!mounted) return;
      final message = e
          .toString()
          .replaceFirst('Exception: ', '')
          .replaceFirst('Failed to submit item reviews: ', '');
      AppToastMessage.show(
        context: context,
        message: message,
        backgroundColor: colors.error,
        maxLines: 3,
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final size = MediaQuery.sizeOf(context);
    final feedbackChips = _getItemFeedbackChips(_itemRating);

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: colors.backgroundPrimary,
      body: SafeArea(
        child: Column(
          children: [
            if (!widget.embedded)
              Padding(
                padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 0),
                child: Row(
                  children: [
                    Container(
                      height: 42.h,
                      width: 42.w,
                      decoration: BoxDecoration(
                        color: colors.backgroundSecondary,
                        shape: BoxShape.circle,
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => Navigator.of(context).pop(),
                          customBorder: const CircleBorder(),
                          child: Padding(
                            padding: EdgeInsets.all(10.r),
                            child: SvgPicture.asset(
                              Assets.icons.xmark,
                              package: 'grab_go_shared',
                              colorFilter: ColorFilter.mode(
                                colors.textPrimary,
                                BlendMode.srcIn,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  20.w,
                  widget.embedded ? 12.h : 20.h,
                  20.w,
                  20.h,
                ),
                child: Column(
                  children: [
                    _buildItemRatingSection(
                      title: 'How was ${widget.itemName}?',
                      starDescription: _getItemRatingDescription(_itemRating),
                      image: widget.itemImage,
                      size: size,
                      rating: _itemRating,
                      onRatingChanged: (rating) {
                        setState(() {
                          _itemRating = rating;
                          _selectedComment.clear();
                        });
                      },
                      colors: colors,
                    ),
                    SizedBox(height: KSpacing.lg25.h),
                    if (_itemRating > 0)
                      AnimatedSize(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut,
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
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 20.h),
              child: AppButton(
                buttonText: _isSubmitting
                    ? 'Submitting...'
                    : (_itemRating > 0 ? 'Submit rating' : 'Rate later'),
                onPressed: _handlePrimaryAction,
                backgroundColor: _isSubmitting
                    ? colors.accentOrange.withValues(alpha: 0.65)
                    : colors.accentOrange,
                borderRadius: KBorderSize.borderMedium,
                width: double.infinity,
                height: KWidgetSize.buttonHeight.h,
                textStyle: TextStyle(
                  color: Colors.white,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomCommentChip(AppColorsExtension colors) {
    return GestureDetector(
      onTap: () async {
        final result = await showCustomInputBottomSheet(
          context: context,
          title: 'Add Item Feedback',
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
        child: Text(
          'Custom',
          style: TextStyle(
            color: _selectedComment.any((c) => c.startsWith('Custom: '))
                ? Colors.white
                : colors.textPrimary,
            fontSize: 13.sp,
            fontWeight: _selectedComment.any((c) => c.startsWith('Custom: '))
                ? FontWeight.w700
                : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildCommentChip(String label, AppColorsExtension colors) {
    final isSelected = _selectedComment.contains(label);

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

Widget _buildItemRatingSection({
  required String title,
  required String starDescription,
  required String? image,
  required int rating,
  required Size size,
  required Function(int) onRatingChanged,
  required AppColorsExtension colors,
}) {
  final hasImage = (image?.trim().isNotEmpty ?? false);

  return Column(
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
                    Assets.icons.package,
                    package: 'grab_go_shared',
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
                  Assets.icons.package,
                  package: 'grab_go_shared',
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
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 14.sp,
          fontWeight: FontWeight.w400,
          color: colors.textPrimary,
        ),
      ),
      SizedBox(height: 5.h),
      Text(
        starDescription,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 22.sp,
          fontWeight: FontWeight.w800,
          color: colors.accentOrange,
        ),
      ),
      SizedBox(height: KSpacing.lg.h),
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
                package: 'grab_go_shared',
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
  );
}
