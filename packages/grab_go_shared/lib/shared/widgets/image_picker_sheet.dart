import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/shared/utils/app_colors_extension.dart';
import 'package:grab_go_shared/shared/widgets/shimmer_loading.dart';
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

  // Pagination state
  static const int _pageSize = 30; // Load 30 images per page
  int _currentPage = 0;
  bool _hasMoreImages = true;
  bool _isLoadingMore = false;

  // Album selection state
  List<AssetPathEntity> _albums = [];
  Map<String, int> _albumCounts = {}; // Store album counts
  AssetPathEntity? _currentAlbum; // Store current album for pagination
  int _selectedAlbumIndex = 0;

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
    // Get all albums from gallery
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
        _hasMoreImages = false;
      });
      return;
    }
    // Store all albums and select first one (filter out empty ones)
    final albumsWithCounts = await Future.wait(
      albums.map((album) async {
        final count = await album.assetCountAsync;
        return {'album': album, 'count': count};
      }),
    );

    _albums = albumsWithCounts
        .where((item) => (item['count'] as int) > 0)
        .map((item) => item['album'] as AssetPathEntity)
        .toList();

    // Store counts for display
    for (var item in albumsWithCounts) {
      final album = item['album'] as AssetPathEntity;
      final count = item['count'] as int;
      _albumCounts[album.id] = count;
    }

    if (_albums.isEmpty) {
      setState(() {
        _isLoading = false;
        _hasMoreImages = false;
      });
      return;
    }

    _currentAlbum = _albums.first;
    _selectedAlbumIndex = 0;

    // Load first page of images from selected album
    await _loadImagesFromAlbum(_currentAlbum!);
  }

  Future<void> _loadImagesFromAlbum(AssetPathEntity album) async {
    setState(() {
      _isLoading = true;
    });

    final totalCount = await album.assetCountAsync;
    final endIndex = _pageSize < totalCount ? _pageSize : totalCount;
    final images = await album.getAssetListRange(start: 0, end: endIndex);

    if (!mounted) return;

    setState(() {
      _recentImages = images;
      _currentPage = 0;
      _hasMoreImages = endIndex < totalCount;
      _isLoading = false;
    });
  }

  Future<void> _switchAlbum(int index) async {
    if (index == _selectedAlbumIndex || index >= _albums.length) return;

    setState(() {
      _selectedAlbumIndex = index;
      _currentAlbum = _albums[index];
      _selectedImages.clear(); // Clear selections when switching albums
    });

    await _loadImagesFromAlbum(_currentAlbum!);
  }

  Future<void> _loadMoreImages() async {
    if (_isLoadingMore || !_hasMoreImages || _currentAlbum == null) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final totalCount = await _currentAlbum!.assetCountAsync;
      final startIndex = (_currentPage + 1) * _pageSize;
      final endIndex = startIndex + _pageSize < totalCount ? startIndex + _pageSize : totalCount;

      if (startIndex >= totalCount) {
        setState(() {
          _hasMoreImages = false;
          _isLoadingMore = false;
        });
        return;
      }

      final newImages = await _currentAlbum!.getAssetListRange(start: startIndex, end: endIndex);

      if (!mounted) return;

      setState(() {
        _recentImages.addAll(newImages);
        _currentPage++;
        _hasMoreImages = endIndex < totalCount;
        _isLoadingMore = false;
      });
    } catch (e) {
      debugPrint('Error loading more images: $e');
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  void _toggleSelection(AssetEntity image) async {
    // If maxImages is 1, auto-select and return immediately (profile picture mode)
    if (widget.maxImages == 1) {
      HapticFeedback.selectionClick();
      final file = await image.file;
      if (file != null && mounted) {
        Navigator.pop(context);
        widget.onImagesSelected([file.path]);
      }
      return;
    }

    // Multi-selection mode (for chat, etc.)
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
      child: RefreshIndicator(
        onRefresh: () async {
          if (_currentAlbum != null) {
            await _loadImagesFromAlbum(_currentAlbum!);
          }
        },
        color: colors.accentGreen,
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
                  // Album dropdown
                  Expanded(
                    child: PopupMenuButton<int>(
                      offset: Offset(0, 50.h),
                      color: colors.backgroundPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.w),
                        side: BorderSide(color: colors.border),
                      ),
                      itemBuilder: (context) {
                        return _albums.asMap().entries.map((entry) {
                          final index = entry.key;
                          final album = entry.value;
                          final isSelected = index == _selectedAlbumIndex;

                          return PopupMenuItem<int>(
                            value: index,
                            child: Row(
                              children: [
                                Icon(
                                  Icons.photo_library,
                                  size: 20.w,
                                  color: isSelected ? colors.accentGreen : colors.textSecondary,
                                ),
                                SizedBox(width: 12.w),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        album.name,
                                        style: TextStyle(
                                          fontSize: 15.sp,
                                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                          color: isSelected ? colors.accentGreen : colors.textPrimary,
                                        ),
                                      ),
                                      Text(
                                        '${_albumCounts[album.id] ?? 0}',
                                        style: TextStyle(
                                          fontSize: 12.sp,
                                          fontWeight: FontWeight.w400,
                                          color: colors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (isSelected) Icon(Icons.check, size: 18.w, color: colors.accentGreen),
                              ],
                            ),
                          );
                        }).toList();
                      },
                      onSelected: (index) => _switchAlbum(index),
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                        decoration: BoxDecoration(
                          color: colors.backgroundSecondary,
                          borderRadius: BorderRadius.circular(12.w),
                          border: Border.all(color: colors.border),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _albums.isNotEmpty ? _albums[_selectedAlbumIndex].name : 'Select Photos',
                                    style: TextStyle(
                                      fontSize: 16.sp,
                                      fontWeight: FontWeight.w700,
                                      color: colors.textPrimary,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (_albums.isNotEmpty)
                                    Text(
                                      '${_albumCounts[_albums[_selectedAlbumIndex].id] ?? 0}',
                                      style: TextStyle(
                                        fontSize: 11.sp,
                                        fontWeight: FontWeight.w400,
                                        color: colors.textSecondary,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            SizedBox(width: 8.w),
                            Icon(Icons.keyboard_arrow_down, size: 20.w, color: colors.textPrimary),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  // Send button
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

  Widget _buildSkeletonGrid(AppColorsExtension colors) {
    return GridView.builder(
      controller: widget.sc,
      padding: EdgeInsets.all(2.w),
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 2.w,
        mainAxisSpacing: 2.w,
      ),
      itemCount: 30,
      itemBuilder: (context, index) {
        return ShimmerLoading(
          isLoading: true,
          child: Container(
            decoration: BoxDecoration(color: colors.backgroundSecondary, borderRadius: BorderRadius.circular(4.w)),
          ),
        );
      },
    );
  }

  Widget _buildImageGrid(AppColorsExtension colors) {
    if (_isLoading) {
      return _buildSkeletonGrid(colors);
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

    // if (_recentImages.isEmpty) {
    //   return Center(
    //     child: Column(
    //       mainAxisSize: MainAxisSize.min,
    //       children: [
    //         SvgPicture.asset(
    //           Assets.icons.mediaImageXmark,
    //           package: "grab_go_shared",
    //           height: 48.h,
    //           width: 48.w,
    //           colorFilter: ColorFilter.mode(colors.textSecondary, BlendMode.srcIn),
    //         ),
    //         SizedBox(height: 10.h),
    //         Text(
    //           'No images found',
    //           style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600, color: colors.textPrimary),
    //         ),
    //       ],
    //     ),
    //   );
    // }

    if (_recentImages.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(24.w),
              decoration: BoxDecoration(color: colors.backgroundSecondary.withOpacity(0.5), shape: BoxShape.circle),
              child: SvgPicture.asset(
                Assets.icons.mediaImageXmark,
                package: "grab_go_shared",
                height: 48.h,
                width: 48.w,
                colorFilter: ColorFilter.mode(colors.textSecondary, BlendMode.srcIn),
              ),
            ),
            SizedBox(height: 16.h),
            Text(
              'No images found',
              style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w600, color: colors.textPrimary),
            ),
            SizedBox(height: 8.h),
            Text(
              'Try selecting a different album or\ntake a photo with the camera',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14.sp, color: colors.textSecondary, height: 1.5),
            ),
          ],
        ),
      );
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (ScrollNotification scrollInfo) {
        // Detect when user scrolls near bottom (prevent duplicate triggers)
        if (!_isLoadingMore && scrollInfo.metrics.pixels >= scrollInfo.metrics.maxScrollExtent * 0.8) {
          _loadMoreImages();
        }
        return false;
      },
      child: GridView.builder(
        controller: widget.sc,
        padding: EdgeInsets.all(2.w),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 2.w,
          mainAxisSpacing: 2.w,
        ),
        itemCount: _recentImages.length + (_hasMoreImages ? 1 : 0),
        itemBuilder: (context, index) {
          // Show loading indicator at the end
          if (index == _recentImages.length) {
            return Center(
              child: Padding(
                padding: EdgeInsets.all(16.w),
                child: CircularProgressIndicator(color: colors.accentGreen, strokeWidth: 2),
              ),
            );
          }

          final image = _recentImages[index];
          final isSelected = _selectedImages.contains(image);
          final selectionIndex = _selectedImages.toList().indexOf(image);

          return AnimatedScale(
            duration: const Duration(milliseconds: 150),
            scale: isSelected ? 0.95 : 1.0,
            curve: Curves.easeInOut,
            child: GestureDetector(
              onTap: () => _toggleSelection(image),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Thumbnail with fade-in
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 300),
                    opacity: 1.0,
                    curve: Curves.easeIn,
                    child: AssetEntityImage(
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
                  ),

                  // Selection overlay with animation
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    color: isSelected ? colors.accentGreen.withValues(alpha: 0.3) : Colors.transparent,
                  ),

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
            ),
          );
        },
      ),
    );
  }
}
