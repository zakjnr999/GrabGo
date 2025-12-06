import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/shared/utils/app_colors_extension.dart';
import 'package:image_picker/image_picker.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';

class ImagePickerSheet extends StatefulWidget {
  final int maxImages;
  final Function(List<String> imagePaths) onImagesSelected;
  final ScrollController sc;

  const ImagePickerSheet({super.key, this.maxImages = 10, required this.onImagesSelected, required this.sc});

  /// Show the image picker bottom sheet
  static Future<void> show(
    BuildContext context, {
    int maxImages = 10,
    required Function(List<String> imagePaths) onImagesSelected,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return ImagePickerSheet(maxImages: maxImages, onImagesSelected: onImagesSelected, sc: scrollController);
          },
        );
      },
    );
  }

  @override
  State<ImagePickerSheet> createState() => _ImagePickerSheetState();
}

class _ImagePickerSheetState extends State<ImagePickerSheet> {
  final ImagePicker _picker = ImagePicker();
  List<AssetEntity> _recentImages = [];
  final Set<AssetEntity> _selectedImages = {};
  bool _isLoading = true;
  bool _hasPermission = false;
  bool _isProcessing = false; // For showing loading when getting file paths

  @override
  void initState() {
    super.initState();
    _loadRecentImages();
  }

  Future<void> _loadRecentImages() async {
    final permission = await PhotoManager.requestPermissionExtend();

    if (!permission.isAuth) {
      setState(() {
        _isLoading = false;
        _hasPermission = false;
      });
      return;
    }

    setState(() {
      _hasPermission = true;
    });

    // Get recent images from gallery
    final albums = await PhotoManager.getAssetPathList(
      type: RequestType.image,
      filterOption: FilterOptionGroup(
        imageOption: const FilterOption(sizeConstraint: SizeConstraint(ignoreSize: true)),
        orders: [const OrderOption(type: OrderOptionType.createDate, asc: false)],
      ),
    );

    if (albums.isEmpty) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    // Get images from "Recent" or first album
    final recentAlbum = albums.first;
    final images = await recentAlbum.getAssetListRange(start: 0, end: 100);

    setState(() {
      _recentImages = images;
      _isLoading = false;
    });
  }

  void _toggleSelection(AssetEntity image) {
    if (_selectedImages.contains(image)) {
      HapticFeedback.selectionClick();
      setState(() {
        _selectedImages.remove(image);
      });
    } else if (_selectedImages.length < widget.maxImages) {
      HapticFeedback.selectionClick();
      setState(() {
        _selectedImages.add(image);
      });
    } else {
      // Max limit reached - show feedback
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Maximum ${widget.maxImages} images allowed'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _openCamera() async {
    Navigator.pop(context);

    final XFile? photo = await _picker.pickImage(source: ImageSource.camera, imageQuality: 85);

    if (photo != null) {
      widget.onImagesSelected([photo.path]);
    }
  }

  Future<void> _openGalleryPicker() async {
    Navigator.pop(context);

    final List<XFile> images = await _picker.pickMultiImage(imageQuality: 85, limit: widget.maxImages);

    if (images.isNotEmpty) {
      widget.onImagesSelected(images.map((e) => e.path).toList());
    }
  }

  Future<void> _openFileBrowser() async {
    // Close bottom sheet first
    Navigator.pop(context);

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'gif', 'webp', 'heic', 'heif'],
        allowMultiple: true,
      );

      debugPrint('FilePicker result: $result');

      if (result != null && result.files.isNotEmpty) {
        final paths = result.files.where((f) => f.path != null).map((f) => f.path!).toList();
        debugPrint('FilePicker paths: $paths');
        if (paths.isNotEmpty) {
          // Limit to maxImages
          final limitedPaths = paths.take(widget.maxImages).toList();
          widget.onImagesSelected(limitedPaths);
        }
      }
    } catch (e) {
      debugPrint('FilePicker error: $e');
    }
  }

  Future<void> _confirmSelection() async {
    if (_selectedImages.isEmpty || _isProcessing) return;

    HapticFeedback.mediumImpact();

    setState(() {
      _isProcessing = true;
    });

    // Get file paths for selected images
    final paths = <String>[];
    for (final asset in _selectedImages) {
      final file = await asset.file;
      if (file != null) {
        paths.add(file.path);
      }
    }

    if (!mounted) return;

    Navigator.pop(context);

    if (paths.isNotEmpty) {
      widget.onImagesSelected(paths);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColorsExtension>()!;
    final bottomPadding = MediaQuery.of(context).viewPadding.bottom;

    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: BoxDecoration(
        color: colors.backgroundPrimary,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.w)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: EdgeInsets.symmetric(vertical: 12.h),
            width: 40.w,
            height: 4.h,
            decoration: BoxDecoration(color: colors.border, borderRadius: BorderRadius.circular(2.w)),
          ),

          // Header
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Select Photos',
                  style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w700, color: colors.textPrimary),
                ),
                if (_selectedImages.isNotEmpty)
                  GestureDetector(
                    onTap: _confirmSelection,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                      decoration: BoxDecoration(color: colors.accentGreen, borderRadius: BorderRadius.circular(20.w)),
                      child: _isProcessing
                          ? SizedBox(
                              width: 20.w,
                              height: 20.w,
                              child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Text(
                              'Send (${_selectedImages.length})',
                              style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600, color: Colors.white),
                            ),
                    ),
                  ),
              ],
            ),
          ),

          SizedBox(height: 12.h),

          // Quick actions row
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: Row(
              children: [
                Expanded(
                  child: _buildQuickAction(
                    icon: Assets.icons.camera,
                    label: 'Camera',
                    onTap: _openCamera,
                    colors: colors,
                  ),
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: _buildQuickAction(
                    icon: Assets.icons.mediaImage,
                    label: 'Gallery',
                    onTap: _openGalleryPicker,
                    colors: colors,
                  ),
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: _buildQuickAction(
                    icon: Assets.icons.folder,
                    label: 'Browse',
                    onTap: _openFileBrowser,
                    colors: colors,
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 16.h),

          // Divider
          Divider(height: 1, color: colors.border),

          // Image grid
          Expanded(child: _buildImageGrid(colors)),

          SizedBox(height: bottomPadding),
        ],
      ),
    );
  }

  Widget _buildQuickAction({
    required String icon,
    required String label,
    required VoidCallback onTap,
    required AppColorsExtension colors,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
        decoration: BoxDecoration(
          color: colors.backgroundSecondary,
          borderRadius: BorderRadius.circular(12.w),
          border: Border.all(color: colors.border),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.asset(
              icon,
              package: "grab_go_shared",
              height: 18.h,
              width: 18.w,
              colorFilter: ColorFilter.mode(colors.textPrimary, BlendMode.srcIn),
            ),
            SizedBox(width: 6.w),
            Flexible(
              child: Text(
                label,
                style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w500, color: colors.textPrimary),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageGrid(AppColorsExtension colors) {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: colors.accentGreen));
    }

    if (!_hasPermission) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(32.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.photo_library_outlined, size: 48.w, color: colors.textSecondary),
              SizedBox(height: 16.h),
              Text(
                'Photo access required',
                style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600, color: colors.textPrimary),
              ),
              SizedBox(height: 8.h),
              Text(
                'Please grant photo access in settings to select images from your gallery.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14.sp, color: colors.textSecondary),
              ),
              SizedBox(height: 16.h),
              TextButton(
                onPressed: () => PhotoManager.openSetting(),
                child: Text(
                  'Open Settings',
                  style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600, color: colors.accentGreen),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_recentImages.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.asset(
              Assets.icons.mediaImageXmark,
              package: "grab_go_shared",
              height: 48.h,
              width: 48.w,
              colorFilter: ColorFilter.mode(colors.textSecondary, BlendMode.srcIn),
            ),
            SizedBox(height: 10.h),
            Text(
              'No images found',
              style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600, color: colors.textPrimary),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      controller: widget.sc,
      padding: EdgeInsets.all(2.w),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 2.w,
        mainAxisSpacing: 2.w,
      ),
      itemCount: _recentImages.length,
      itemBuilder: (context, index) {
        final image = _recentImages[index];
        final isSelected = _selectedImages.contains(image);
        final selectionIndex = _selectedImages.toList().indexOf(image);

        return GestureDetector(
          onTap: () => _toggleSelection(image),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Thumbnail
              AssetEntityImage(
                image,
                isOriginal: false,
                thumbnailSize: const ThumbnailSize.square(300),
                thumbnailFormat: ThumbnailFormat.jpeg,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: colors.backgroundSecondary,
                    child: Icon(Icons.broken_image, color: colors.textSecondary),
                  );
                },
              ),

              // Selection overlay
              if (isSelected) Container(color: colors.accentGreen.withValues(alpha: 0.3)),

              // Selection indicator
              Positioned(
                top: 6.w,
                right: 6.w,
                child: Container(
                  width: 24.w,
                  height: 24.w,
                  decoration: BoxDecoration(
                    color: isSelected ? colors.accentGreen : Colors.black.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: isSelected
                      ? Center(
                          child: Text(
                            '${selectionIndex + 1}',
                            style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w700, color: Colors.white),
                          ),
                        )
                      : null,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
