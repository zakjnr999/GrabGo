import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';

class RiderVendorRatingPage extends StatefulWidget {
  final String orderId;
  final String vendorName;

  const RiderVendorRatingPage({super.key, required this.orderId, required this.vendorName});

  @override
  State<RiderVendorRatingPage> createState() => _RiderVendorRatingPageState();
}

class _RiderVendorRatingPageState extends State<RiderVendorRatingPage> {
  int _rating = 0;
  bool _isSubmitting = false;
  String? _customFeedback;
  final List<String> _selectedFeedback = <String>[];

  String _ratingDescription(int rating) {
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
        return "Tap stars to rate vendor pickup";
    }
  }

  List<String> _feedbackOptions(int rating) {
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
                  hintText: "Share details about this pickup...",
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
                  textStyle: TextStyle(color: Colors.white, fontSize: 14.sp, fontWeight: FontWeight.w700),
                  height: 60.h,
                ),
              ),
            ],
          ),
        );
      },
    );

    controller.dispose();
    if (!mounted || result == null) return;

    setState(() {
      _customFeedback = result;
    });
  }

  Future<void> _submitRating(AppColorsExtension colors) async {
    if (_rating == 0 || _isSubmitting) return;

    setState(() {
      _isSubmitting = true;
    });

    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (!mounted) return;

    AppToastMessage.show(
      context: context,
      showIcon: false,
      backgroundColor: colors.accentGreen,
      maxLines: 2,
      radius: KBorderSize.borderRadius4,
      message: "Vendor rating submitted. Nice delivery.",
    );

    context.go("/home");
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final chips = _feedbackOptions(_rating);

    return Scaffold(
      backgroundColor: colors.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: colors.backgroundPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: SvgPicture.asset(
            Assets.icons.navArrowLeft,
            package: 'grab_go_shared',
            width: 24.w,
            height: 24.w,
            colorFilter: ColorFilter.mode(colors.textPrimary, BlendMode.srcIn),
          ),
          onPressed: () => context.go("/home"),
        ),
        title: Text(
          "Rate Vendor",
          style: TextStyle(
            fontFamily: "Lato",
            package: "grab_go_shared",
            color: colors.textPrimary,
            fontSize: 18.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20.w, 4.h, 20.w, 12.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(height: 12.h),
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: colors.accentGreen.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Center(
                        child: SvgPicture.asset(
                          Assets.icons.store,
                          package: 'grab_go_shared',
                          width: 50,
                          height: 50,
                          colorFilter: ColorFilter.mode(colors.accentGreen, BlendMode.srcIn),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 16.h),
                  Text(
                    widget.vendorName,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: colors.textPrimary, fontSize: 18.sp, fontWeight: FontWeight.w700),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    "How was pickup at ${widget.vendorName}?",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: colors.textPrimary, fontSize: 16.sp, fontWeight: FontWeight.w700),
                  ),
                  SizedBox(height: 20.h),
                  Text(
                    _ratingDescription(_rating),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _rating > 0 ? colors.accentGreen : colors.textSecondary,
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 16.h),
                  Center(
                    child: Row(
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
                          },
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 6.w),
                            child: SvgPicture.asset(
                              selected ? Assets.icons.starSolid : Assets.icons.star,
                              package: 'grab_go_shared',
                              width: 40.w,
                              height: 40.w,
                              colorFilter: ColorFilter.mode(
                                selected ? colors.accentGreen : colors.divider,
                                BlendMode.srcIn,
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
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
            ),
          ),
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, MediaQuery.of(context).padding.bottom + 12.h),
            decoration: BoxDecoration(
              color: colors.backgroundPrimary,
              boxShadow: [
                BoxShadow(color: colors.shadow.withValues(alpha: 0.08), blurRadius: 8, offset: const Offset(0, -2)),
              ],
            ),
            child: AppButton(
              onPressed: _rating == 0 || _isSubmitting ? () {} : () => _submitRating(colors),
              buttonText: _isSubmitting ? "Submitting..." : "Submit Rating",
              isLoading: _isSubmitting,
              backgroundColor: _rating == 0 ? colors.accentGreen.withValues(alpha: 0.4) : colors.accentGreen,
              borderRadius: KBorderSize.borderRadius4,
              height: 60.h,
              textStyle: TextStyle(color: Colors.white, fontSize: 15.sp, fontWeight: FontWeight.w700),
            ),
          ),
        ],
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
          color: isSelected ? colors.accentGreen : colors.backgroundPrimary,
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
