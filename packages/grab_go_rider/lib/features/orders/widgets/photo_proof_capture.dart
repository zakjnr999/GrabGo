import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:image_picker/image_picker.dart';

class PhotoProofCapture extends StatefulWidget {
  final String orderId;
  final String orderNumber;
  final String title;
  final String description;
  final Function(File photo) onPhotoCapture;
  final VoidCallback onSkip;

  const PhotoProofCapture({
    super.key,
    required this.orderId,
    required this.orderNumber,
    this.title = 'Photo Proof of Delivery',
    this.description = 'Take a photo showing the order has been delivered',
    required this.onPhotoCapture,
    required this.onSkip,
  });

  static Future<void> show({
    required BuildContext context,
    required String orderId,
    required String orderNumber,
    String title = 'Photo Proof of Delivery',
    String description = 'Take a photo showing the order has been delivered',
    required Function(File photo) onPhotoCapture,
    required VoidCallback onSkip,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      builder: (context) => PhotoProofCapture(
        orderId: orderId,
        orderNumber: orderNumber,
        title: title,
        description: description,
        onPhotoCapture: onPhotoCapture,
        onSkip: onSkip,
      ),
    );
  }

  @override
  State<PhotoProofCapture> createState() => _PhotoProofCaptureState();
}

class _PhotoProofCaptureState extends State<PhotoProofCapture> {
  File? _capturedPhoto;
  bool _isCapturing = false;
  final ImagePicker _picker = ImagePicker();

  Future<void> _capturePhoto() async {
    setState(() {
      _isCapturing = true;
    });

    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
        imageQuality: 80,
        maxWidth: 1920,
        maxHeight: 1080,
      );

      if (photo != null) {
        setState(() {
          _capturedPhoto = File(photo.path);
        });
      }
    } catch (e) {
      debugPrint('Error capturing photo: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to capture photo')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCapturing = false;
        });
      }
    }
  }

  void _retakePhoto() {
    setState(() {
      _capturedPhoto = null;
    });
  }

  void _confirmPhoto() {
    if (_capturedPhoto != null) {
      Navigator.pop(context);
      widget.onPhotoCapture(_capturedPhoto!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: BoxDecoration(
        color: colors.backgroundPrimary,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(KBorderSize.borderRadius20),
          topRight: Radius.circular(KBorderSize.borderRadius20),
        ),
      ),
      padding: EdgeInsets.only(left: 20.w, right: 20.w, top: 16.h, bottom: bottomPadding + 20.h),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Text(
              widget.title,
              style: TextStyle(color: colors.textPrimary, fontSize: 18.sp, fontWeight: FontWeight.w700),
            ),
            SizedBox(height: 6.h),
            // Description
            Text(
              widget.description,
              style: TextStyle(color: colors.textSecondary, fontSize: 13.sp, fontWeight: FontWeight.w400),
            ),
            SizedBox(height: 20.h),
            // Photo preview or capture area
            if (_capturedPhoto != null) _buildPhotoPreview(colors) else _buildCaptureArea(colors),
            SizedBox(height: 20.h),
            // Action buttons
            if (_capturedPhoto != null)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _retakePhoto,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colors.textPrimary,
                        side: BorderSide(color: colors.border, width: 1.5),
                        padding: EdgeInsets.symmetric(vertical: 14.h),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(KBorderSize.borderRadius4)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.refresh, size: 18.w),
                          SizedBox(width: 8.w),
                          Text(
                            'Retake',
                            style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _confirmPhoto,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.accentGreen,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 14.h),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(KBorderSize.borderRadius4)),
                        elevation: 0,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check, size: 18.w),
                          SizedBox(width: 8.w),
                          Text(
                            'Confirm & Deliver',
                            style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              )
            else
              Column(
                children: [
                  AppButton(
                    onPressed: () => _isCapturing ? null : _capturePhoto,
                    buttonText: 'Take Photo',
                    isLoading: _isCapturing ? true : false,
                    backgroundColor: colors.accentGreen,
                    width: double.infinity,
                    borderRadius: KBorderSize.borderRadius4,
                    height: 60.h,
                    textStyle: TextStyle(color: Colors.white, fontSize: 15.sp, fontWeight: FontWeight.w700),
                  ),
                  SizedBox(height: 12.h),
                  AppButton(
                    onPressed: () {
                      Navigator.pop(context);
                      widget.onSkip();
                    },
                    buttonText: "Skit (Not Recommended)",
                    width: double.infinity,
                    backgroundColor: colors.backgroundSecondary,
                    borderRadius: KBorderSize.borderRadius4,
                    height: 56.h,
                    textStyle: TextStyle(color: colors.textSecondary, fontSize: 13.sp, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCaptureArea(AppColorsExtension colors) {
    return Container(
      height: 200.h,
      width: double.infinity,
      decoration: BoxDecoration(
        color: colors.backgroundSecondary,
        borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SvgPicture.asset(
            Assets.icons.camera,
            package: 'grab_go_shared',
            width: 48.w,
            height: 48.w,
            colorFilter: ColorFilter.mode(colors.textSecondary, BlendMode.srcIn),
          ),
          SizedBox(height: 12.h),
          Text(
            'No photo taken yet',
            style: TextStyle(color: colors.textSecondary, fontSize: 14.sp, fontWeight: FontWeight.w500),
          ),
          SizedBox(height: 4.h),
          Text(
            'Tap the button below to capture',
            style: TextStyle(
              color: colors.textSecondary.withValues(alpha: 0.7),
              fontSize: 12.sp,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoPreview(AppColorsExtension colors) {
    return Container(
      height: 200.h,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
        border: Border.all(color: colors.accentGreen, width: 2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(KBorderSize.borderRadius4 - 2),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.file(_capturedPhoto!, fit: BoxFit.cover),
            Positioned(
              top: 8.h,
              right: 8.w,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                decoration: BoxDecoration(color: colors.accentGreen, borderRadius: BorderRadius.circular(12.r)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle, color: Colors.white, size: 14.w),
                    SizedBox(width: 4.w),
                    Text(
                      'Photo Ready',
                      style: TextStyle(color: Colors.white, fontSize: 11.sp, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
