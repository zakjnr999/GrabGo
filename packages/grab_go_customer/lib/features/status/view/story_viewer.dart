import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:flutter_blurhash/flutter_blurhash.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import 'package:grab_go_customer/features/status/model/status_model.dart';
import 'package:grab_go_customer/features/status/viewmodel/status_provider.dart';
import 'package:grab_go_shared/grub_go_shared.dart';

class StoryViewer extends StatefulWidget {
  final String restaurantId;
  final String restaurantName;
  final String? restaurantLogo;
  final String? initialBlurHash; // Show while loading
  final VoidCallback? onNextRestaurant; // Swipe left to next restaurant
  final VoidCallback? onPreviousRestaurant; // Swipe right to previous restaurant

  const StoryViewer({
    super.key,
    required this.restaurantId,
    required this.restaurantName,
    this.restaurantLogo,
    this.initialBlurHash,
    this.onNextRestaurant,
    this.onPreviousRestaurant,
  });

  @override
  State<StoryViewer> createState() => _StoryViewerState();
}

class _StoryViewerState extends State<StoryViewer> with TickerProviderStateMixin {
  int _currentIndex = 0;
  late AnimationController _progressController;
  late AnimationController _heartAnimationController;
  late Animation<double> _heartScaleAnimation;
  late Animation<double> _heartOpacityAnimation;
  late StatusProvider _statusProvider; // Cache provider reference for dispose

  // Use a map to prevent duplicate entries and limit memory usage
  final Map<String, BatchViewItem> _viewedItemsMap = {};
  DateTime? _currentViewStartTime;
  bool _isInitialized = false;
  bool _isPreloading = false;
  bool _isImageLoading = true; // Track if current image is still loading
  String? _currentLoadingStatusId; // Track which status we're loading
  bool _showHeartAnimation = false; // Track heart animation visibility
  Offset? _doubleTapPosition; // Position of double tap for heart animation
  bool _isLikeAnimation = true; // True for like (red), false for unlike (white)

  // Vertical swipe gesture tracking (for dismiss)
  double _dragStartY = 0;
  double _dragCurrentY = 0;
  bool _isDraggingVertical = false;
  static const double _dismissThreshold = 100; // Pixels to drag before dismissing

  // Track if cleanup has been done to avoid double-processing
  bool _hasCleanedUp = false;

  // Maximum items to track (prevents unbounded growth)
  static const int _maxViewedItems = 50;
  static const Duration _storyDuration = Duration(seconds: 5);
  static const Duration _videoDuration = Duration(seconds: 15);

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(vsync: this, duration: _storyDuration);
    _statusProvider = context.read<StatusProvider>(); // Cache reference

    // Initialize heart animation controller
    _heartAnimationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));

    _heartScaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.2), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 1.2, end: 0.9), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 0.9, end: 1.0), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 30),
    ]).animate(CurvedAnimation(parent: _heartAnimationController, curve: Curves.easeOut));

    _heartOpacityAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 30),
    ]).animate(CurvedAnimation(parent: _heartAnimationController, curve: Curves.easeOut));

    _heartAnimationController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _showHeartAnimation = false;
        });
        _heartAnimationController.reset();
      }
    });

    _progressController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _nextStory();
      }
    });
  }

  @override
  void dispose() {
    // Only cleanup if not already done (e.g., by _close or _goToNextRestaurantOrClose)
    if (!_hasCleanedUp) {
      _performCleanup();
    }
    _progressController.dispose();
    _heartAnimationController.dispose();
    super.dispose();
  }

  /// Perform cleanup - record views, send batch, mark as viewed
  void _performCleanup() {
    if (_hasCleanedUp) return;
    _hasCleanedUp = true;
    _recordCurrentView();
    _sendBatchViews();
    _statusProvider.markStoryAsViewed(widget.restaurantId);
  }

  void _startProgress(StatusModel status) {
    _recordCurrentView();
    _currentViewStartTime = DateTime.now();

    final duration = status.isVideo ? _videoDuration : _storyDuration;
    _progressController.duration = duration;

    // Reset loading state - progress will start when image loads
    _isImageLoading = true;
    _currentLoadingStatusId = status.id;
    _progressController.reset();
  }

  /// Called when image finishes loading - starts the progress bar
  void _onImageLoaded(String statusId) {
    // Only start progress if this is still the current status being loaded
    if (_isImageLoading && mounted && _currentLoadingStatusId == statusId) {
      setState(() {
        _isImageLoading = false;
      });
      _progressController.forward(from: 0);
    }
  }

  void _recordCurrentView() {
    if (_currentViewStartTime != null) {
      final statuses = _statusProvider.currentRestaurantStatuses;

      if (_currentIndex < statuses.length) {
        final statusId = statuses[_currentIndex].id;
        final duration = DateTime.now().difference(_currentViewStartTime!).inMilliseconds;

        // Update existing or add new (prevents duplicates)
        if (_viewedItemsMap.containsKey(statusId)) {
          // Add duration to existing view
          final existing = _viewedItemsMap[statusId]!;
          _viewedItemsMap[statusId] = BatchViewItem(statusId: statusId, duration: existing.duration + duration);
        } else {
          // Add new view (with limit check)
          if (_viewedItemsMap.length >= _maxViewedItems) {
            // Remove oldest entry
            _viewedItemsMap.remove(_viewedItemsMap.keys.first);
          }
          _viewedItemsMap[statusId] = BatchViewItem(statusId: statusId, duration: duration);
        }
      }
      _currentViewStartTime = null;
    }
  }

  void _sendBatchViews() {
    if (_viewedItemsMap.isNotEmpty) {
      _statusProvider.recordBatchViews(_viewedItemsMap.values.toList());
      _viewedItemsMap.clear(); // Clear after sending
    }
  }

  /// Preload next images for smoother UX
  Future<void> _preloadNextImages(List<StatusModel> statuses) async {
    if (_isPreloading) return;
    _isPreloading = true;

    try {
      // Preload next 2 images
      final futures = <Future>[];
      for (int i = _currentIndex + 1; i <= _currentIndex + 2 && i < statuses.length; i++) {
        final status = statuses[i];
        if (!status.isVideo) {
          futures.add(precacheImage(CachedNetworkImageProvider(status.mediaUrl), context).catchError((_) {}));
        }
      }
      await Future.wait(futures);
    } finally {
      _isPreloading = false;
    }
  }

  void _nextStory() {
    final statuses = _statusProvider.currentRestaurantStatuses;

    if (_currentIndex < statuses.length - 1) {
      setState(() => _currentIndex++);
      _startProgress(statuses[_currentIndex]);
      _preloadNextImages(statuses);
    } else {
      // Last status in this restaurant - go to next restaurant or close
      _goToNextRestaurantOrClose();
    }
  }

  void _previousStory() {
    final statuses = _statusProvider.currentRestaurantStatuses;
    if (_currentIndex > 0 && statuses.isNotEmpty) {
      setState(() => _currentIndex--);
      _startProgress(statuses[_currentIndex]);
    }
  }

  void _goToNextRestaurantOrClose() {
    _performCleanup();

    if (widget.onNextRestaurant != null) {
      widget.onNextRestaurant!();
    } else {
      Navigator.of(context).pop();
    }
  }

  void _close() {
    _performCleanup();
    Navigator.of(context).pop();
  }

  /// Build blur hash placeholder for image loading
  Widget _buildBlurHashPlaceholder(String? blurHash) {
    if (blurHash != null && blurHash.isNotEmpty) {
      return BlurHash(hash: blurHash, imageFit: BoxFit.cover, decodingWidth: 32, decodingHeight: 32);
    }
    // Fallback to black container if no blur hash
    return Container(color: Colors.black);
  }

  void _onTapUp(TapUpDetails details) {
    final screenWidth = MediaQuery.of(context).size.width;
    final tapX = details.globalPosition.dx;

    if (tapX < screenWidth / 3) {
      _previousStory();
    } else if (tapX > screenWidth * 2 / 3) {
      _nextStory();
    }
  }

  /// Handle double-tap to like/unlike with heart animation
  void _onDoubleTap(TapDownDetails details, String? statusId) {
    if (statusId == null) return;

    // Check current like state before toggling
    final isCurrentlyLiked = _statusProvider.isLiked(statusId);

    // Store tap position and animation type for heart animation
    setState(() {
      _doubleTapPosition = details.localPosition;
      _showHeartAnimation = true;
      _isLikeAnimation = !isCurrentlyLiked; // Red for like, white for unlike
    });

    // Toggle like state
    _statusProvider.toggleLike(statusId);

    // Start heart animation
    _heartAnimationController.forward(from: 0);
  }

  // Swipe gesture handlers
  void _onVerticalDragStart(DragStartDetails details) {
    _dragStartY = details.globalPosition.dy;
    _dragCurrentY = _dragStartY;
    _isDraggingVertical = true;
    if (!_isImageLoading) _progressController.stop();
  }

  void _onVerticalDragUpdate(DragUpdateDetails details) {
    if (!_isDraggingVertical) return;
    setState(() {
      _dragCurrentY = details.globalPosition.dy;
    });
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    if (!_isDraggingVertical) return;

    final dragDistance = _dragCurrentY - _dragStartY;

    if (dragDistance > _dismissThreshold) {
      // Swipe down - close viewer
      _close();
    } else {
      // Reset position and resume
      setState(() {
        _dragCurrentY = _dragStartY;
      });
      if (!_isImageLoading) _progressController.forward();
    }
    _isDraggingVertical = false;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final dragOffset = _isDraggingVertical ? (_dragCurrentY - _dragStartY).clamp(0.0, 200.0) : 0.0;
    final scale = 1.0 - (dragOffset / 1000); // Subtle scale effect
    final opacity = 1.0 - (dragOffset / 400); // Fade out as dragging

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: GestureDetector(
          onVerticalDragStart: _onVerticalDragStart,
          onVerticalDragUpdate: _onVerticalDragUpdate,
          onVerticalDragEnd: _onVerticalDragEnd,
          // Horizontal swiping is handled by parent PageView
          child: Container(
            color: Colors.black.withValues(alpha: opacity.clamp(0.0, 1.0)),
            child: Transform.translate(
              offset: Offset(0, dragOffset),
              child: Transform.scale(
                scale: scale.clamp(0.8, 1.0),
                child: Consumer<StatusProvider>(
                  builder: (context, provider, child) {
                    final statuses = provider.currentRestaurantStatuses;
                    final isLoading = statuses.isEmpty;

                    // Get current status or use placeholder data
                    // Safety check: ensure _currentIndex is within bounds
                    final safeIndex = _currentIndex.clamp(0, statuses.isEmpty ? 0 : statuses.length - 1);
                    final currentStatus = isLoading ? null : statuses[safeIndex];

                    // Reset index if it was out of bounds
                    if (!isLoading && _currentIndex != safeIndex) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) setState(() => _currentIndex = safeIndex);
                      });
                    }
                    final currentBlurHash = currentStatus?.blurHash ?? widget.initialBlurHash;
                    final currentMediaUrl = currentStatus?.mediaUrl;

                    if (!_isInitialized && statuses.isNotEmpty) {
                      _isInitialized = true;
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) {
                          _startProgress(statuses[safeIndex]);
                          // Preload upcoming images
                          _preloadNextImages(statuses);
                        }
                      });
                    }

                    return GestureDetector(
                      onTapUp: isLoading ? null : _onTapUp,
                      onDoubleTapDown: isLoading ? null : (details) => _onDoubleTap(details, currentStatus?.id),
                      onDoubleTap: () {}, // Required for onDoubleTapDown to work
                      onLongPressStart: (_) {
                        if (!_isImageLoading) _progressController.stop();
                      },
                      onLongPressEnd: (_) {
                        if (!_isImageLoading) _progressController.forward();
                      },
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          // Show blur hash or actual image
                          if (currentMediaUrl != null)
                            CachedNetworkImage(
                              key: ValueKey(currentStatus!.id),
                              imageUrl: currentMediaUrl,
                              fit: BoxFit.cover,
                              imageBuilder: (context, imageProvider) {
                                final statusId = currentStatus.id;
                                WidgetsBinding.instance.addPostFrameCallback((_) => _onImageLoaded(statusId));
                                return Image(image: imageProvider, fit: BoxFit.cover);
                              },
                              progressIndicatorBuilder: (context, url, progress) => Stack(
                                fit: StackFit.expand,
                                children: [
                                  _buildBlurHashPlaceholder(currentStatus.blurHash),
                                  Center(
                                    child: SizedBox(
                                      width: 44.w,
                                      height: 44.w,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 3,
                                        color: Colors.white,
                                        value: progress.progress,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              errorWidget: (context, url, error) => Container(color: Colors.grey[900]),
                            )
                          else
                            // Show initial blur hash while statuses are loading
                            Stack(
                              fit: StackFit.expand,
                              children: [
                                _buildBlurHashPlaceholder(currentBlurHash),
                                Center(
                                  child: SizedBox(
                                    width: 44.w,
                                    height: 44.w,
                                    child: const CircularProgressIndicator(strokeWidth: 3, color: Colors.white),
                                  ),
                                ),
                              ],
                            ),
                          // Gradient overlay
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.black.withValues(alpha: 0.6),
                                  Colors.transparent,
                                  Colors.transparent,
                                  Colors.black.withValues(alpha: 0.8),
                                ],
                                stops: const [0.0, 0.2, 0.7, 1.0],
                              ),
                            ),
                          ),
                          SafeArea(
                            child: Column(
                              children: [
                                // Offline indicator
                                if (provider.isOffline)
                                  Container(
                                    width: double.infinity,
                                    padding: EdgeInsets.symmetric(vertical: 4.h),
                                    color: Colors.orange.withValues(alpha: 0.9),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        SvgPicture.asset(
                                          Assets.icons.wifiOff,
                                          package: "grab_go_shared",
                                          height: 15.h,
                                          width: 15.w,
                                          colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                                        ),
                                        SizedBox(width: 6.w),
                                        Text(
                                          'No internet connection',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 12.sp,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                // Always show progress bar (1 segment when loading)
                                _buildProgressBars(isLoading ? 1 : statuses.length),
                                SizedBox(height: 12.h),
                                _buildHeader(colors, currentStatus),
                                const Spacer(),
                                _buildBottomContent(colors, currentStatus, provider),
                                SizedBox(height: 20.h),
                              ],
                            ),
                          ),
                          // Heart animation overlay
                          if (_showHeartAnimation && _doubleTapPosition != null)
                            Positioned(
                              left: _doubleTapPosition!.dx - 50,
                              top: _doubleTapPosition!.dy - 50,
                              child: AnimatedBuilder(
                                animation: _heartAnimationController,
                                builder: (context, child) {
                                  return Opacity(
                                    opacity: _heartOpacityAnimation.value,
                                    child: Transform.scale(
                                      scale: _heartScaleAnimation.value,
                                      child: SvgPicture.asset(
                                        _isLikeAnimation ? Assets.icons.heartSolid : Assets.icons.heart,
                                        colorFilter: ColorFilter.mode(
                                          _isLikeAnimation ? AppColors.errorRed : Colors.white,
                                          BlendMode.srcIn,
                                        ),
                                        height: 100.h,
                                        width: 100.w,
                                        package: "grab_go_shared",
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProgressBars(int count) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      child: Row(
        children: List.generate(count, (index) {
          return Expanded(
            child: Container(
              margin: EdgeInsets.symmetric(horizontal: 2.w),
              height: 3.h,
              child: AnimatedBuilder(
                animation: _progressController,
                builder: (context, child) {
                  double progress = 0;
                  if (index < _currentIndex) {
                    progress = 1;
                  } else if (index == _currentIndex) {
                    progress = _progressController.value;
                  }
                  return LinearProgressIndicator(
                    value: progress,
                    borderRadius: BorderRadius.circular(999),
                    backgroundColor: Colors.white.withValues(alpha: 0.3),
                    valueColor: const AlwaysStoppedAnimation(Colors.white),
                  );
                },
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildHeader(AppColorsExtension colors, StatusModel? status) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20.r,
            backgroundImage: widget.restaurantLogo != null ? CachedNetworkImageProvider(widget.restaurantLogo!) : null,
            child: widget.restaurantLogo == null ? Icon(Icons.restaurant, size: 20.r) : null,
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.restaurantName,
                  style: TextStyle(color: Colors.white, fontSize: 14.sp, fontWeight: FontWeight.w600),
                ),
                if (status != null)
                  Text(
                    status.timeAgo,
                    style: TextStyle(color: Colors.white70, fontSize: 12.sp),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomContent(AppColorsExtension colors, StatusModel? status, StatusProvider provider) {
    // Show placeholder content while loading
    if (status == null) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Category badge placeholder
            Container(
              width: 80.w,
              height: 28.h,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20.r),
              ),
            ),
            SizedBox(height: 12.h),
            // Title placeholder
            Container(
              width: 200.w,
              height: 24.h,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4.r),
              ),
            ),
            SizedBox(height: 8.h),
            // Description placeholder
            Container(
              width: 280.w,
              height: 16.h,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4.r),
              ),
            ),
            SizedBox(height: 16.h),
            // Action buttons placeholder
            Row(
              children: [
                _buildActionButton(icon: Assets.icons.heart, label: '-', onTap: null),
                SizedBox(width: 24.w),
                _buildActionButton(icon: Assets.icons.eye, label: '-', onTap: null),
                SizedBox(width: 24.w),
                _buildActionButton(icon: Assets.icons.shareAndroid, label: 'Share', onTap: null),
              ],
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
            decoration: BoxDecoration(
              color: status.category.getColor(context),
              borderRadius: BorderRadius.circular(20.r),
            ),
            child: Text(
              status.category.label,
              style: TextStyle(color: Colors.white, fontSize: 12.sp, fontWeight: FontWeight.w600),
            ),
          ),
          if (status.title != null) ...[
            SizedBox(height: 12.h),
            Text(
              status.title!,
              style: TextStyle(color: Colors.white, fontSize: 20.sp, fontWeight: FontWeight.bold),
            ),
          ],
          if (status.description != null) ...[
            SizedBox(height: 8.h),
            Text(
              status.description!,
              style: TextStyle(color: Colors.white70, fontSize: 14.sp),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (status.discountPercentage != null || status.promoCode != null) ...[
            SizedBox(height: 12.h),
            Row(
              children: [
                if (status.discountPercentage != null)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                    decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(8.r)),
                    child: Text(
                      '${status.discountPercentage!.toInt()}% OFF',
                      style: TextStyle(color: Colors.white, fontSize: 16.sp, fontWeight: FontWeight.bold),
                    ),
                  ),
                if (status.promoCode != null) ...[
                  SizedBox(width: 12.w),
                  GestureDetector(
                    onTap: () => _copyPromoCode(status.promoCode!),
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8.r),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SvgPicture.asset(
                            Assets.icons.copy,
                            package: "grab_go_shared",
                            height: 16.h,
                            width: 16.w,
                            colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                          ),
                          SizedBox(width: 6.w),
                          Text(
                            status.promoCode!,
                            style: TextStyle(color: Colors.white, fontSize: 14.sp, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
          SizedBox(height: 16.h),
          Row(
            children: [
              _buildActionButton(
                icon: provider.isLiked(status.id) ? Assets.icons.heartSolid : Assets.icons.heart,
                label: '${status.likeCount}',
                onTap: () => provider.toggleLike(status.id),
                isLiked: provider.isLiked(status.id),
              ),
              SizedBox(width: 24.w),
              _buildActionButton(icon: Assets.icons.eye, label: '${status.viewCount}', onTap: null),
              SizedBox(width: 24.w),
              _buildActionButton(icon: Assets.icons.shareAndroid, label: 'Share', onTap: () => _shareStatus(status)),
              const Spacer(),
              if (status.linkedFood != null)
                ElevatedButton(
                  onPressed: () {
                    // Navigate to food detail
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.accentOrange,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
                  ),
                  child: Text(
                    'Order Now',
                    style: TextStyle(color: Colors.white, fontSize: 14.sp, fontWeight: FontWeight.w600),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({required String icon, required String label, VoidCallback? onTap, bool isLiked = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          SvgPicture.asset(
            icon,
            package: "grab_go_shared",
            height: 20.h,
            width: 20.w,
            colorFilter: ColorFilter.mode(isLiked ? Colors.red : Colors.white, BlendMode.srcIn),
          ),
          SizedBox(width: 6.w),
          Text(
            label,
            style: TextStyle(color: Colors.white, fontSize: 14.sp, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  void _copyPromoCode(String code) {
    Clipboard.setData(ClipboardData(text: code));
    _progressController.stop();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Promo code "$code" copied!'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.green,
      ),
    );

    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        _progressController.forward();
      }
    });
  }

  void _shareStatus(StatusModel status) {
    _progressController.stop();

    String shareText = widget.restaurantName;
    if (status.title != null) {
      shareText += '\n${status.title}';
    }
    if (status.discountPercentage != null) {
      shareText += '\n${status.discountPercentage!.toInt()}% OFF!';
    }
    if (status.promoCode != null) {
      shareText += '\nUse code: ${status.promoCode}';
    }
    shareText += '\n\nCheck it out on GrabGo!';

    Share.share(shareText).then((_) {
      if (mounted) {
        _progressController.forward();
      }
    });
  }
}
