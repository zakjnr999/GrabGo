import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';

class RiderRatingOnboardingPage extends StatefulWidget {
  final String orderId;
  final String vendorName;
  final String? vendorLogo;
  final String customerName;
  final String? customerPhoto;

  const RiderRatingOnboardingPage({
    super.key,
    required this.orderId,
    required this.vendorName,
    this.vendorLogo,
    required this.customerName,
    this.customerPhoto,
  });

  @override
  State<RiderRatingOnboardingPage> createState() => _RiderRatingOnboardingPageState();
}

class _RiderRatingOnboardingPageState extends State<RiderRatingOnboardingPage> {
  final PageController _controller = PageController();
  int _index = 0;
  int _vendorRating = 0;
  int _customerRating = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _vendorDescription(int rating) {
    switch (rating) {
      case 5:
        return "Excellent pickup experience";
      case 4:
        return "Smooth and reliable";
      case 3:
        return "Average handoff";
      case 2:
        return "Needs improvement";
      case 1:
        return "Poor pickup experience";
      default:
        return "Tap stars to rate vendor";
    }
  }

  String _customerDescription(int rating) {
    switch (rating) {
      case 5:
        return "Great drop-off experience";
      case 4:
        return "Good and cooperative";
      case 3:
        return "Manageable delivery";
      case 2:
        return "Difficult drop-off";
      case 1:
        return "Problematic delivery";
      default:
        return "Tap stars to rate customer";
    }
  }

  List<String> _vendorFeedback(int rating) {
    if (rating >= 4) {
      return const <String>[
        'Prepared on time',
        'Friendly vendor staff',
        'Order well packed',
        'Accurate items',
        'Quick handoff',
        'Easy pickup process',
      ];
    }
    if (rating == 3) {
      return const <String>['Average wait time', 'Some delays', 'Packaging was okay', 'Could be more organized'];
    }
    if (rating >= 1) {
      return const <String>[
        'Order not ready',
        'Long waiting time',
        'Missing items',
        'Poor packaging',
        'Unclear pickup process',
      ];
    }
    return const <String>[];
  }

  List<String> _customerFeedback(int rating) {
    if (rating >= 4) {
      return const <String>[
        'Accurate address',
        'Responsive on phone',
        'Respectful behavior',
        'Easy drop-off',
        'Clear instructions',
      ];
    }
    if (rating == 3) {
      return const <String>['Address partly unclear', 'Slow response', 'Minor wait at gate', 'Average cooperation'];
    }
    if (rating >= 1) {
      return const <String>[
        'Wrong address',
        'Unreachable customer',
        'Long wait at gate',
        'Rude behavior',
        'Unsafe drop-off area',
        'Suspicious complaint risk',
      ];
    }
    return const <String>[];
  }

  void _closeFlow() => context.go('/home');

  void _onNext(AppColorsExtension colors) {
    final hasCurrentRating = _index == 0 ? _vendorRating > 0 : _customerRating > 0;
    if (!hasCurrentRating) {
      AppToastMessage.show(
        context: context,
        showIcon: false,
        backgroundColor: colors.error,
        maxLines: 2,
        radius: KBorderSize.borderRadius4,
        message: "Please select a rating before continuing.",
      );
      return;
    }

    if (_index == 0) {
      _controller.nextPage(duration: const Duration(milliseconds: 320), curve: Curves.easeInOut);
      return;
    }

    AppToastMessage.show(
      context: context,
      showIcon: false,
      backgroundColor: colors.accentGreen,
      maxLines: 2,
      radius: KBorderSize.borderRadius4,
      message: "Thanks! Ratings submitted.",
    );
    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final bottomSafeArea = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: colors.backgroundPrimary,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(14.w, 8.h, 14.w, 10.h),
              child: Row(
                children: [
                  _CircleIconButton(iconPath: Assets.icons.xmark, onTap: _closeFlow),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: StoryStepper(
                      count: 2,
                      index: _index,
                      activeColor: colors.accentGreen,
                      inactiveColor: colors.inputBorder,
                    ),
                  ),
                  SizedBox(width: 8.w),
                  GestureDetector(
                    onTap: _closeFlow,
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 6.h),
                      child: Text(
                        "Skip",
                        style: TextStyle(color: colors.textSecondary, fontSize: 13.sp, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView(
                controller: _controller,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _index = i),
                children: [
                  _RiderRatingStep(
                    heading: "Rate Vendor",
                    name: widget.vendorName,
                    avatarIconPath: Assets.icons.store,
                    avatarImageUrl: widget.vendorLogo,
                    question: "How was pickup at ${widget.vendorName}?",
                    descriptionBuilder: _vendorDescription,
                    feedbackBuilder: _vendorFeedback,
                    onRatingChanged: (value) => _vendorRating = value,
                  ),
                  _RiderRatingStep(
                    heading: "Rate Customer",
                    name: widget.customerName,
                    avatarIconPath: Assets.icons.user,
                    avatarImageUrl: widget.customerPhoto,
                    question: "How was delivery to ${widget.customerName}?",
                    descriptionBuilder: _customerDescription,
                    feedbackBuilder: _customerFeedback,
                    onRatingChanged: (value) => _customerRating = value,
                  ),
                ],
              ),
            ),
            Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, bottomSafeArea + 12.h),
              child: AppButton(
                onPressed: () => _onNext(colors),
                buttonText: _index == 0 ? "Continue" : "Done",
                backgroundColor: colors.accentGreen,
                borderRadius: KBorderSize.borderRadius4,
                height: 60.h,
                textStyle: TextStyle(color: Colors.white, fontSize: 15.sp, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RiderRatingStep extends StatefulWidget {
  final String heading;
  final String name;
  final String avatarIconPath;
  final String? avatarImageUrl;
  final String question;
  final String Function(int rating) descriptionBuilder;
  final List<String> Function(int rating) feedbackBuilder;
  final ValueChanged<int> onRatingChanged;

  const _RiderRatingStep({
    required this.heading,
    required this.name,
    required this.avatarIconPath,
    this.avatarImageUrl,
    required this.question,
    required this.descriptionBuilder,
    required this.feedbackBuilder,
    required this.onRatingChanged,
  });

  @override
  State<_RiderRatingStep> createState() => _RiderRatingStepState();
}

class _RiderRatingStepState extends State<_RiderRatingStep> {
  int _rating = 0;
  String? _customFeedback;
  final List<String> _selectedFeedback = <String>[];

  Future<void> _openCustomFeedbackInput(AppColorsExtension colors) async {
    final controller = TextEditingController(text: _customFeedback ?? "");
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.backgroundPrimary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(KBorderSize.borderRadius20)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20.w,
            right: 20.w,
            top: 16.h,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20.h,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: colors.textSecondary.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
              ),
              SizedBox(height: 16.h),
              Text(
                "Add feedback",
                style: TextStyle(color: colors.textPrimary, fontSize: 18.sp, fontWeight: FontWeight.w700),
              ),
              SizedBox(height: 12.h),
              TextField(
                controller: controller,
                maxLines: 4,
                maxLength: 200,
                style: TextStyle(color: colors.textPrimary, fontSize: 14.sp),
                decoration: InputDecoration(
                  hintText: "Share details...",
                  filled: true,
                  fillColor: colors.backgroundSecondary,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
                    borderSide: BorderSide(color: colors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
                    borderSide: BorderSide(color: colors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
                    borderSide: BorderSide(color: colors.accentGreen),
                  ),
                ),
              ),
              SizedBox(height: 12.h),
              SizedBox(
                width: double.infinity,
                child: AppButton(
                  onPressed: () =>
                      Navigator.of(sheetContext).pop(controller.text.trim().isEmpty ? null : controller.text.trim()),
                  buttonText: "Save feedback",
                  backgroundColor: colors.accentGreen,
                  borderRadius: KBorderSize.borderRadius4,
                  height: 60.h,
                  textStyle: TextStyle(color: Colors.white, fontSize: 14.sp, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        );
      },
    );

    controller.dispose();
    if (!mounted || result == null) return;
    setState(() => _customFeedback = result);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final chips = widget.feedbackBuilder(_rating);

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20.w, 6.h, 20.w, 12.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            widget.heading,
            style: TextStyle(color: colors.textPrimary, fontSize: 18.sp, fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 20.h),
          Center(
            child: Container(
              width: 85,
              height: 85,
              decoration: BoxDecoration(color: colors.accentGreen.withValues(alpha: 0.12), shape: BoxShape.circle),
              child: _buildAvatarWidget(colors),
            ),
          ),
          SizedBox(height: 10.h),
          Text(
            widget.name,
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.textPrimary, fontSize: 18.sp, fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 8.h),
          Text(
            widget.question,
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.textPrimary, fontSize: 16.sp, fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 20.h),
          Text(
            widget.descriptionBuilder(_rating),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _rating > 0 ? colors.accentGreen : colors.textSecondary,
              fontSize: 13.sp,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 16.h),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: List<Widget>.generate(5, (index) {
              final starIndex = index + 1;
              final selected = starIndex <= _rating;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _rating = starIndex;
                    _selectedFeedback.clear();
                    _customFeedback = null;
                  });
                  widget.onRatingChanged(_rating);
                },
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6.w),
                  child: SvgPicture.asset(
                    selected ? Assets.icons.starSolid : Assets.icons.star,
                    package: 'grab_go_shared',
                    width: 40.w,
                    height: 40.w,
                    colorFilter: ColorFilter.mode(selected ? colors.accentGreen : colors.divider, BlendMode.srcIn),
                  ),
                ),
              );
            }),
          ),
          SizedBox(height: 20.h),
          if (_rating > 0) ...[
            Text(
              "What stood out?",
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.textPrimary, fontSize: 13.sp, fontWeight: FontWeight.w700),
            ),
            SizedBox(height: 10.h),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8.w,
              runSpacing: 8.h,
              children: [
                ...chips.map(
                  (chip) => _FeedbackChip(
                    label: chip,
                    isSelected: _selectedFeedback.contains(chip),
                    onTap: () {
                      setState(() {
                        if (_selectedFeedback.contains(chip)) {
                          _selectedFeedback.remove(chip);
                        } else {
                          _selectedFeedback.add(chip);
                        }
                      });
                    },
                  ),
                ),
                _FeedbackChip(
                  label: _customFeedback == null ? "Custom" : "Custom added",
                  isSelected: _customFeedback != null,
                  onTap: () => _openCustomFeedbackInput(colors),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAvatarWidget(AppColorsExtension colors) {
    final avatarUrl = widget.avatarImageUrl?.trim();
    final hasAvatar = avatarUrl != null && avatarUrl.isNotEmpty;

    if (hasAvatar) {
      return ClipOval(
        child: CachedNetworkImage(
          imageUrl: ImageOptimizer.getPreviewUrl(avatarUrl, width: 240),
          fit: BoxFit.cover,
          width: 85,
          height: 85,
          memCacheWidth: 240,
          maxHeightDiskCache: 240,
          errorWidget: (context, url, error) => Center(
            child: SvgPicture.asset(
              widget.avatarIconPath,
              package: 'grab_go_shared',
              width: 34.w,
              height: 34.w,
              colorFilter: ColorFilter.mode(colors.accentGreen, BlendMode.srcIn),
            ),
          ),
        ),
      );
    }

    return Center(
      child: SvgPicture.asset(
        widget.avatarIconPath,
        package: 'grab_go_shared',
        width: 34.w,
        height: 34.w,
        colorFilter: ColorFilter.mode(colors.accentGreen, BlendMode.srcIn),
      ),
    );
  }
}

class _FeedbackChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FeedbackChip({required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: isSelected ? colors.accentGreen : colors.backgroundSecondary,
          borderRadius: BorderRadius.circular(24.r),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : colors.textPrimary,
            fontSize: 12.sp,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  final String iconPath;
  final VoidCallback onTap;

  const _CircleIconButton({required this.iconPath, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Container(
      height: 44.h,
      width: 44.w,
      decoration: BoxDecoration(color: colors.backgroundPrimary, shape: BoxShape.circle),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Padding(
            padding: EdgeInsets.all(10.r),
            child: SvgPicture.asset(
              iconPath,
              package: 'grab_go_shared',
              colorFilter: ColorFilter.mode(colors.textPrimary, BlendMode.srcIn),
            ),
          ),
        ),
      ),
    );
  }
}
