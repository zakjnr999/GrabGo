// ignore_for_file: deprecated_member_use

import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:grab_go_shared/shared/utils/app_colors_extension.dart';
import 'package:grab_go_shared/shared/utils/colors.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'svg_icon.dart';
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
  Uint8List? _selectedImageBytes; // For web compatibility
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
      File? selectedFile;
      Uint8List? selectedBytes;

      if (kIsWeb) {
        final XFile? image = await _picker.pickImage(
          source: ImageSource.gallery,
          maxWidth: 800,
          maxHeight: 800,
          imageQuality: 85,
        );

        if (image != null) {
          // For web, store bytes instead of File
          selectedBytes = await image.readAsBytes();
        }
      } else if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
        // For desktop platforms, use file_picker with path
        FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.image, allowMultiple: false);

        if (result != null && result.files.single.path != null) {
          selectedFile = File(result.files.single.path!);
        }
      } else {
        final ImageSource? source = await _showImageSourceDialog();
        if (source != null) {
          final XFile? image = await _picker.pickImage(source: source, maxWidth: 800, maxHeight: 800, imageQuality: 85);

          if (image != null) {
            selectedFile = File(image.path);
          }
        }
      }

      if (selectedFile != null || selectedBytes != null) {
        setState(() {
          _selectedImage = selectedFile;
          _selectedImageBytes = selectedBytes;
        });

        // For web, we need to create a File from the bytes for the callback
        File? fileForCallback = selectedFile;
        if (kIsWeb && selectedBytes != null && selectedFile == null) {
          // Create a temporary file path for web
          fileForCallback = File('web_image_${DateTime.now().millisecondsSinceEpoch}.jpg');
        }

        widget.onImageSelected?.call(fileForCallback);
      }
    } catch (e) {
      // Handle error with more detailed information
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick image: ${e.toString()}'), backgroundColor: AppColors.errorRed),
        );
      }
    }
  }

  Future<ImageSource?> _showImageSourceDialog() async {
    return showDialog<ImageSource>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Select Image Source'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.camera_alt),
                title: Text('Camera'),
                onTap: () => Navigator.of(context).pop(ImageSource.camera),
              ),
              ListTile(
                leading: Icon(Icons.photo_library),
                title: Text('Gallery'),
                onTap: () => Navigator.of(context).pop(ImageSource.gallery),
              ),
            ],
          ),
        );
      },
    );
  }

  void _removeImage() {
    setState(() {
      _selectedImage = null;
      _selectedImageBytes = null;
    });
    widget.onImageSelected?.call(null);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final height = widget.height ?? 120;
    final width = widget.width ?? double.infinity;
    final successMessage = widget.successMessage ?? "${widget.label} uploaded successfully";

    return Container(
      padding: widget.padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.label,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: colors.textPrimary),
          ),
          SizedBox(height: 8),
          GestureDetector(
            onTap: _pickImage,
            child: Container(
              width: width,
              height: height,
              decoration: BoxDecoration(
                color: colors.border,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors.border, width: 1),
              ),
              child: (_selectedImage != null || _selectedImageBytes != null)
                  ? Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: kIsWeb && _selectedImageBytes != null
                              ? Image.memory(_selectedImageBytes!, width: width, height: height, fit: BoxFit.cover)
                              : Image.file(
                                  _selectedImage!,
                                  width: width,
                                  height: height,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      width: width,
                                      height: height,
                                      color: colors.border,
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.error_outline, color: colors.textSecondary, size: 32),
                                          SizedBox(height: 8),
                                          Text(
                                            'Failed to load image',
                                            style: TextStyle(color: colors.textSecondary, fontSize: 12),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                        ),
                        if (widget.showRemoveButton)
                          Positioned(
                            top: 8,
                            right: 8,
                            child: GestureDetector(
                              onTap: _removeImage,
                              child: Container(
                                padding: EdgeInsets.all(4),
                                decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), shape: BoxShape.circle),
                                child: Icon(Icons.close, color: Colors.white, size: 16),
                              ),
                            ),
                          ),
                      ],
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.accentOrange.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: SvgIcon(
                            svgImage: Assets.icons.mediaImagePlus,
                            color: AppColors.accentOrange,
                            width: 24,
                            height: 24,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          "Upload ${widget.label}",
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: colors.textPrimary),
                        ),
                        SizedBox(height: 4),
                        Text(
                          widget.hintText ??
                              (kIsWeb || Platform.isWindows || Platform.isMacOS || Platform.isLinux
                                  ? "Click to select image"
                                  : "Tap to select image"),
                          style: TextStyle(fontSize: 12, color: colors.textSecondary),
                        ),
                      ],
                    ),
            ),
          ),
          if (_selectedImage != null || _selectedImageBytes != null) ...[
            SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 16),
                SizedBox(width: 4),
                Expanded(
                  child: Text(
                    successMessage,
                    style: TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.w500),
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
