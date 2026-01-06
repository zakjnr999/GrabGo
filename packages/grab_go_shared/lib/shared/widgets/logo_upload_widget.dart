// ignore_for_file: deprecated_member_use

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import '../utils/app_colors_extension.dart';
import '../utils/constants.dart';
import '../widgets/app_toast_message.dart';
import 'package:image_picker/image_picker.dart';

class ImageUploadWidget extends StatefulWidget {
  final String label;
  final String? hintText;
  final double? height;
  final double? width;
  final Function(File?)? onImageSelected;
  final File? initialImage;
  final bool showRemoveButton;
  final String? successMessage;
  final EdgeInsetsGeometry? padding;
  final double? borderRadius;

  const ImageUploadWidget({
    super.key,
    required this.label,
    this.hintText,
    this.height,
    this.width,
    this.onImageSelected,
    this.initialImage,
    this.showRemoveButton = true,
    this.successMessage,
    this.padding,
    this.borderRadius,
  });

  @override
  State<ImageUploadWidget> createState() => _ImageUploadWidgetState();
}

class _ImageUploadWidgetState extends State<ImageUploadWidget> {
  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _selectedImage = widget.initialImage;
  }

  @override
  void didUpdateWidget(ImageUploadWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialImage != oldWidget.initialImage) {
      _selectedImage = widget.initialImage;
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
        widget.onImageSelected?.call(_selectedImage);
      }
    } catch (e) {
      // Handle error
      if (mounted) {
        AppToastMessage.show(
          context: context,
          message: "Failed to pick image. Please try again.",
          backgroundColor: Colors.red,
        );
      }
    }
  }

  void _removeImage() {
    setState(() {
      _selectedImage = null;
    });
    widget.onImageSelected?.call(null);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final height = widget.height ?? 120.h;
    final width = widget.width ?? double.infinity;
    final borderRadius = widget.borderRadius ?? 12.r;
    final successMessage = widget.successMessage ?? "${widget.label} uploaded successfully";

    return Container(
      padding: widget.padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.label,
            style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600, color: colors.textPrimary),
          ),
          SizedBox(height: KSpacing.sm.h),
          GestureDetector(
            onTap: _pickImage,
            child: Container(
              width: width,
              height: height,
              decoration: BoxDecoration(
                color: colors.inputBackground,
                borderRadius: BorderRadius.circular(borderRadius),
                border: Border.all(color: colors.inputBorder, width: 1),
              ),
              child: _selectedImage != null
                  ? Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(borderRadius),
                          child: Image.file(_selectedImage!, width: width, height: height, fit: BoxFit.cover),
                        ),
                        if (widget.showRemoveButton)
                          Positioned(
                            top: 8.h,
                            right: 8.w,
                            child: GestureDetector(
                              onTap: _removeImage,
                              child: Container(
                                padding: EdgeInsets.all(4.r),
                                decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), shape: BoxShape.circle),
                                child: Icon(Icons.close, color: Colors.white, size: 16.sp),
                              ),
                            ),
                          ),
                      ],
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 48.w,
                          height: 48.h,
                          padding: EdgeInsets.all(KSpacing.md12.r),
                          decoration: BoxDecoration(
                            color: colors.accentOrange.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: SvgPicture.asset(
                            Assets.icons.mediaImagePlus,
                            package: 'grab_go_shared',
                            colorFilter: ColorFilter.mode(colors.accentOrange, BlendMode.srcIn),
                          ),
                        ),
                        SizedBox(height: KSpacing.sm.h),
                        Text(
                          "Upload ${widget.label}",
                          style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600, color: colors.textPrimary),
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          widget.hintText ?? "Tap to select image",
                          style: TextStyle(fontSize: 12.sp, color: colors.textSecondary),
                        ),
                      ],
                    ),
            ),
          ),
          if (_selectedImage != null) ...[
            SizedBox(height: KSpacing.sm.h),
            Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 16.sp),
                SizedBox(width: KSpacing.xs.w),
                Expanded(
                  child: Text(
                    successMessage,
                    style: TextStyle(fontSize: 12.sp, color: Colors.green, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
