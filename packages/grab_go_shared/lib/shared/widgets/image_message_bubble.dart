import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blurhash/flutter_blurhash.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:grab_go_shared/shared/utils/app_colors_extension.dart';

/// Widget for displaying image messages in chat
class ImageMessageBubble extends StatelessWidget {
  final List<String> imageUrls;
  final List<String> blurHashes; // BlurHash for instant previews
  final bool isSent;
  final bool isPending;
  final bool isFailed;
  final VoidCallback? onRetry;
  final Function(int index)? onImageTap;

  const ImageMessageBubble({
    super.key,
    required this.imageUrls,
    this.blurHashes = const [],
    required this.isSent,
    this.isPending = false,
    this.isFailed = false,
    this.onRetry,
    this.onImageTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColorsExtension>()!;

    if (imageUrls.isEmpty) {
      return const SizedBox.shrink();
    }

    // Single image
    if (imageUrls.length == 1) {
      return _buildSingleImage(context, colors, imageUrls.first, 0);
    }

    // Multiple images - grid layout
    return _buildImageGrid(context, colors);
  }

  /// Get blurHash for a specific index, or null if not available
  String? _getBlurHash(int index) {
    if (index < blurHashes.length && blurHashes[index].isNotEmpty) {
      return blurHashes[index];
    }
    return null;
  }

  Widget _buildSingleImage(BuildContext context, AppColorsExtension colors, String url, int index) {
    return GestureDetector(
      onTap: () => onImageTap?.call(index),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12.w),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 220.w, maxHeight: 280.h, minWidth: 150.w, minHeight: 150.h),
          child: Stack(
            fit: StackFit.passthrough,
            children: [
              _buildImage(url, colors, _getBlurHash(index)),
              if (isPending)
                Positioned.fill(
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.3),
                    child: Center(
                      child: SizedBox(
                        width: 24.w,
                        height: 24.w,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      ),
                    ),
                  ),
                ),
              if (isFailed)
                Positioned.fill(
                  child: GestureDetector(
                    onTap: onRetry,
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.5),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.error_outline, color: Colors.white, size: 28.w),
                            SizedBox(height: 4.h),
                            Text(
                              'Tap to retry',
                              style: TextStyle(color: Colors.white, fontSize: 12.sp, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageGrid(BuildContext context, AppColorsExtension colors) {
    final displayCount = imageUrls.length > 4 ? 4 : imageUrls.length;
    final extraCount = imageUrls.length - 4;

    return ClipRRect(
      borderRadius: BorderRadius.circular(12.w),
      child: SizedBox(
        width: 220.w,
        child: Stack(
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // First row
                Row(
                  children: [
                    Expanded(
                      child: AspectRatio(
                        aspectRatio: displayCount == 2 ? 1 : (displayCount >= 3 ? 1 : 1.5),
                        child: _buildGridImage(colors, imageUrls[0], 0),
                      ),
                    ),
                    if (displayCount >= 2) ...[
                      SizedBox(width: 2.w),
                      Expanded(
                        child: AspectRatio(
                          aspectRatio: displayCount == 2 ? 1 : 1,
                          child: _buildGridImage(colors, imageUrls[1], 1),
                        ),
                      ),
                    ],
                  ],
                ),
                // Second row (if 3+ images)
                if (displayCount >= 3) ...[
                  SizedBox(height: 2.h),
                  Row(
                    children: [
                      Expanded(child: AspectRatio(aspectRatio: 1, child: _buildGridImage(colors, imageUrls[2], 2))),
                      if (displayCount >= 4) ...[
                        SizedBox(width: 2.w),
                        Expanded(
                          child: AspectRatio(
                            aspectRatio: 1,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                _buildGridImage(colors, imageUrls[3], 3),
                                if (extraCount > 0)
                                  Container(
                                    color: Colors.black.withValues(alpha: 0.6),
                                    child: Center(
                                      child: Text(
                                        '+$extraCount',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 24.sp,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
            // Pending overlay for grid
            if (isPending)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12.w),
                  ),
                  child: Center(
                    child: SizedBox(
                      width: 32.w,
                      height: 32.w,
                      child: const CircularProgressIndicator(strokeWidth: 3, color: Colors.white),
                    ),
                  ),
                ),
              ),
            // Failed overlay for grid
            if (isFailed)
              Positioned.fill(
                child: GestureDetector(
                  onTap: onRetry,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(12.w),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.error_outline, color: Colors.white, size: 32.w),
                          SizedBox(height: 8.h),
                          Text(
                            'Tap to retry',
                            style: TextStyle(color: Colors.white, fontSize: 14.sp, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildGridImage(AppColorsExtension colors, String url, int index) {
    return GestureDetector(onTap: () => onImageTap?.call(index), child: _buildImage(url, colors, _getBlurHash(index)));
  }

  Widget _buildImage(String url, AppColorsExtension colors, String? blurHash) {
    // Check if it's a local file path
    if (url.startsWith('/') || url.startsWith('file://')) {
      final filePath = url.startsWith('file://') ? url.substring(7) : url;
      final file = File(filePath);
      return FutureBuilder<bool>(
        future: file.exists(),
        builder: (context, snapshot) {
          if (snapshot.data == true) {
            return Image.file(
              file,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              errorBuilder: (context, error, stackTrace) {
                debugPrint('Image.file error: $error for path: $filePath');
                return _buildErrorPlaceholder(colors);
              },
            );
          }
          // File doesn't exist yet or still checking - show placeholder
          return Container(
            color: colors.backgroundSecondary,
            child: Center(
              child: Icon(Icons.image, color: colors.textSecondary, size: 32.w),
            ),
          );
        },
      );
    }

    // Network image - use BlurHash as placeholder for instant preview
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      placeholder: (context, url) => blurHash != null
          ? BlurHash(hash: blurHash, imageFit: BoxFit.cover, decodingWidth: 32, decodingHeight: 32)
          : Container(color: colors.backgroundSecondary),
      errorWidget: (context, url, error) => _buildErrorPlaceholder(colors),
    );
  }

  Widget _buildErrorPlaceholder(AppColorsExtension colors) {
    return Container(
      color: colors.backgroundSecondary,
      child: Center(
        child: Icon(Icons.broken_image_outlined, color: colors.textSecondary, size: 32.w),
      ),
    );
  }
}

/// Full screen image viewer for viewing images in detail
class ImageViewerScreen extends StatefulWidget {
  final List<String> imageUrls;
  final int initialIndex;

  const ImageViewerScreen({super.key, required this.imageUrls, this.initialIndex = 0});

  static void show(BuildContext context, List<String> imageUrls, {int initialIndex = 0}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ImageViewerScreen(imageUrls: imageUrls, initialIndex: initialIndex),
      ),
    );
  }

  @override
  State<ImageViewerScreen> createState() => _ImageViewerScreenState();
}

class _ImageViewerScreenState extends State<ImageViewerScreen> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: widget.imageUrls.length > 1 ? Text('${_currentIndex + 1} / ${widget.imageUrls.length}') : null,
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.imageUrls.length,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        itemBuilder: (context, index) {
          final url = widget.imageUrls[index];
          return InteractiveViewer(minScale: 0.5, maxScale: 4.0, child: Center(child: _buildFullImage(url)));
        },
      ),
    );
  }

  Widget _buildFullImage(String url) {
    if (url.startsWith('/') || url.startsWith('file://')) {
      final filePath = url.startsWith('file://') ? url.substring(7) : url;
      return Image.file(
        File(filePath),
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return Icon(Icons.broken_image, color: Colors.white54, size: 64.w);
        },
      );
    }

    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.contain,
      placeholder: (context, url) => Center(child: CircularProgressIndicator(color: Colors.white)),
      errorWidget: (context, url, error) => Icon(Icons.broken_image, color: Colors.white54, size: 64.w),
    );
  }
}
