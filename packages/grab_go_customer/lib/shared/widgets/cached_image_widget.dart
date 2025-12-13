import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:grab_go_customer/shared/services/image_cache_service.dart';

class CachedImageWidget extends StatefulWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;
  final BorderRadius? borderRadius;
  final bool preload;
  final Widget? overlay; // Added

  const CachedImageWidget({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
    this.borderRadius,
    this.preload = false,
    this.overlay,
  });

  @override
  State<CachedImageWidget> createState() => _CachedImageWidgetState();
}

class _CachedImageWidgetState extends State<CachedImageWidget> {
  // ... (Lines 36-167 remain unchanged, skipping for brevity) ...
  File? _cachedFile;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void didUpdateWidget(CachedImageWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _loadImage();
    }
  }

  Future<void> _loadImage() async {
    if (!mounted) return;

    if (widget.imageUrl.startsWith('lib/assets/') || widget.imageUrl.startsWith('packages/')) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = false;
        });
      }
      return;
    }

    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      if (ImageCacheService.isImageCached(widget.imageUrl)) {
        final cachedFile = ImageCacheService.getCachedImageFile(widget.imageUrl);
        if (cachedFile != null && mounted) {
          setState(() {
            _cachedFile = cachedFile;
            _isLoading = false;
          });
          return;
        }
      }

      final cachedFile = await ImageCacheService.cacheImage(widget.imageUrl);

      if (mounted) {
        setState(() {
          _cachedFile = cachedFile;
          _isLoading = false;
          _hasError = cachedFile == null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.imageUrl.startsWith('lib/assets/') || widget.imageUrl.startsWith('packages/')) {
      return _buildImage();
    }

    if (_isLoading) {
      return _buildPlaceholder();
    }

    if (_hasError || _cachedFile == null) {
      return _buildErrorWidget();
    }

    return _buildImage();
  }

  Widget _buildPlaceholder() {
    if (widget.placeholder != null) {
      return widget.placeholder!;
    }

    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(color: context.appColors.inputBorder, borderRadius: widget.borderRadius),
      child: Center(
        child: SizedBox(
          width: 40.w,
          height: 40.h,
          child: SvgPicture.asset(
            Assets.icons.utensilsCrossed,
            package: 'grab_go_shared',
            colorFilter: ColorFilter.mode(context.appColors.textSecondary, BlendMode.srcIn),
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    if (widget.errorWidget != null) {
      return widget.errorWidget!;
    }

    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(color: context.appColors.inputBorder, borderRadius: widget.borderRadius),
      child: Center(
        child: SizedBox(
          width: 40.w,
          height: 40.h,
          child: SvgPicture.asset(
            Assets.icons.utensilsCrossed,
            package: 'grab_go_shared',
            colorFilter: ColorFilter.mode(context.appColors.textSecondary, BlendMode.srcIn),
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }

  Widget _buildImage() {
    Widget image;

    if (widget.imageUrl.startsWith('lib/assets/') || widget.imageUrl.startsWith('packages/')) {
      image = Image.asset(
        widget.imageUrl,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        package: 'grab_go_shared',
      );
    } else {
      image = Image.file(_cachedFile!, width: widget.width, height: widget.height, fit: widget.fit);
    }

    if (widget.overlay != null) {
      image = Stack(
        children: [
          image,
          Positioned.fill(child: widget.overlay!),
        ],
      );
    }

    if (widget.borderRadius != null) {
      image = ClipRRect(borderRadius: widget.borderRadius!, child: image);
    }

    return image;
  }
}
