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
import 'package:grab_go_customer/features/status/model/comment_model.dart';
import 'package:grab_go_customer/features/status/viewmodel/status_provider.dart';
import 'package:grab_go_shared/grub_go_shared.dart';

class StoryViewer extends StatefulWidget {
  final String restaurantId;
  final String restaurantName;
  final String? restaurantLogo;
  final String? initialBlurHash;
  final VoidCallback? onNextRestaurant;
  final VoidCallback? onPreviousRestaurant;

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
  late StatusProvider _statusProvider;

  final Map<String, BatchViewItem> _viewedItemsMap = {};
  DateTime? _currentViewStartTime;
  bool _isInitialized = false;
  bool _isPreloading = false;
  bool _isImageLoading = true;
  String? _currentLoadingStatusId;
  bool _showHeartAnimation = false;
  Offset? _doubleTapPosition;
  bool _isLikeAnimation = true;

  // Track preloaded images to avoid re-downloading
  final Set<int> _preloadedIndices = {};

  // Comments swipe area
  final GlobalKey _commentsSwipeKey = GlobalKey();
  double _dragStartX = 0;

  double _dragStartY = 0;
  double _dragCurrentY = 0;
  bool _isDraggingVertical = false;

  bool _hasCleanedUp = false;

  // Comment input controller
  final TextEditingController _commentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(vsync: this, duration: KStatusConstants.imageDuration);
    _statusProvider = context.read<StatusProvider>();

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
    if (!_hasCleanedUp) {
      _performCleanup();
    }
    _progressController.dispose();
    _heartAnimationController.dispose();
    _commentController.dispose();
    super.dispose();
  }

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

    final duration = status.isVideo ? KStatusConstants.videoDuration : KStatusConstants.imageDuration;
    _progressController.duration = duration;

    _isImageLoading = true;
    _currentLoadingStatusId = status.id;
    _progressController.reset();
  }

  void _onImageLoaded(String statusId) {
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

        if (_viewedItemsMap.containsKey(statusId)) {
          final existing = _viewedItemsMap[statusId]!;
          _viewedItemsMap[statusId] = BatchViewItem(statusId: statusId, duration: existing.duration + duration);
        } else {
          if (_viewedItemsMap.length >= KStatusConstants.maxViewedItems) {
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
      _viewedItemsMap.clear();
    }
  }

  Future<void> _preloadNextImages(List<StatusModel> statuses) async {
    if (_isPreloading) return;
    _isPreloading = true;

    try {
      final futures = <Future>[];
      for (int i = _currentIndex + 1; i <= _currentIndex + 2 && i < statuses.length; i++) {
        // Skip if already preloaded
        if (_preloadedIndices.contains(i)) continue;

        final status = statuses[i];
        if (!status.isVideo) {
          futures.add(
            precacheImage(
              CachedNetworkImageProvider(status.mediaUrl),
              context,
            ).then((_) => _preloadedIndices.add(i)).catchError((e) => false),
          );
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

  Widget _buildBlurHashPlaceholder(String? blurHash) {
    if (blurHash != null && blurHash.isNotEmpty) {
      return BlurHash(hash: blurHash, imageFit: BoxFit.cover, decodingWidth: 32, decodingHeight: 32);
    }
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

  void _onDoubleTap(TapDownDetails details, String? statusId) {
    if (statusId == null) return;

    final isCurrentlyLiked = _statusProvider.isLiked(statusId);

    setState(() {
      _doubleTapPosition = details.localPosition;
      _showHeartAnimation = true;
      _isLikeAnimation = !isCurrentlyLiked;
    });

    _statusProvider.toggleLike(statusId);

    _heartAnimationController.forward(from: 0);
  }

  // Swipe gesture handlers
  void _onVerticalDragStart(DragStartDetails details) {
    _dragStartY = details.globalPosition.dy;
    _dragStartX = details.globalPosition.dx;
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

    // Swipe up from comments area -> open comments sheet
    if (dragDistance < -KStatusConstants.swipeDismissThreshold &&
        _isPointInsideCommentsArea(Offset(_dragStartX, _dragStartY))) {
      _openCommentsForCurrent();
      _isDraggingVertical = false;
      return;
    }

    if (dragDistance > KStatusConstants.swipeDismissThreshold) {
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

  bool _isPointInsideCommentsArea(Offset globalPos) {
    final ctx = _commentsSwipeKey.currentContext;
    if (ctx == null) return false;
    final renderObject = ctx.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.attached) return false;
    final position = renderObject.localToGlobal(Offset.zero);
    final size = renderObject.size;
    final rect = Rect.fromLTWH(position.dx, position.dy, size.width, size.height);
    return rect.contains(globalPos);
  }

  void _openCommentsForCurrent() {
    final statuses = _statusProvider.currentRestaurantStatuses;
    if (statuses.isEmpty) {
      _showCommentsBottomSheet(null);
      return;
    }
    final safeIndex = _currentIndex.clamp(0, statuses.length - 1);
    _showCommentsBottomSheet(statuses[safeIndex]);
  }

  Future<void> _showCommentsBottomSheet(StatusModel? status) async {
    if (mounted) _progressController.stop();

    // Load comments when sheet opens
    if (status != null) {
      final provider = context.read<StatusProvider>();
      if (provider.getComments(status.id).isEmpty) {
        provider.fetchComments(status.id);
      }
    }

    final colors = context.appColors;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.backgroundPrimary,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return SafeArea(
              top: false,
              child: Column(
                children: [
                  SizedBox(height: 8.h),
                  Container(
                    width: 40.w,
                    height: 4.h,
                    decoration: BoxDecoration(color: colors.inputBorder, borderRadius: BorderRadius.circular(2.r)),
                  ),
                  SizedBox(height: 12.h),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.w),
                    child: Row(
                      children: [
                        Text(
                          'Comments',
                          style: TextStyle(color: colors.textPrimary, fontSize: 16.sp, fontWeight: FontWeight.w700),
                        ),
                        const Spacer(),
                        if (status != null)
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                            decoration: BoxDecoration(
                              color: colors.accentOrange.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20.r),
                            ),
                            child: Text(
                              status.category.label,
                              style: TextStyle(
                                color: status.category.getColor(context),
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Expanded(
                    child: Consumer<StatusProvider>(
                      builder: (context, provider, _) {
                        if (status == null) return const SizedBox();

                        final comments = provider.getComments(status.id);
                        final isLoading = provider.isLoadingComments(status.id);
                        final error = provider.getCommentError(status.id);

                        // Show loading shimmer on first load
                        if (isLoading && comments.isEmpty) {
                          return _buildCommentsLoading(colors, scrollController);
                        }

                        // Show error state
                        if (error != null && comments.isEmpty) {
                          return _buildCommentsError(colors, error, () {
                            provider.fetchComments(status.id);
                          });
                        }

                        // Show empty state
                        if (comments.isEmpty) {
                          return _buildEmptyComments(colors);
                        }

                        // Show comments list
                        return ListView.builder(
                          controller: scrollController,
                          padding: EdgeInsets.symmetric(horizontal: 16.w),
                          itemCount: comments.length,
                          itemBuilder: (context, index) {
                            return _buildCommentItem(comments[index], colors, status.id);
                          },
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.only(
                      left: 16.w,
                      right: 16.w,
                      bottom: MediaQuery.of(context).viewInsets.bottom + 16.h,
                      top: 8.h,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _commentController,
                            decoration: InputDecoration(
                              hintText: 'Add a comment...',
                              filled: true,
                              fillColor: colors.backgroundSecondary,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24.r),
                                borderSide: BorderSide(color: colors.inputBorder),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24.r),
                                borderSide: BorderSide(color: colors.inputBorder),
                              ),
                              contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                            ),
                            style: TextStyle(color: colors.textPrimary, fontSize: 14.sp),
                            maxLength: 500,
                            buildCounter: (context, {required currentLength, required isFocused, maxLength}) {
                              if (!isFocused) return null;
                              return Text(
                                '$currentLength/$maxLength',
                                style: TextStyle(fontSize: 10.sp, color: colors.textSecondary),
                              );
                            },
                            onChanged: (_) => setState(() {}), // Rebuild to enable/disable button
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Consumer<StatusProvider>(
                          builder: (context, provider, _) {
                            final isPosting = provider.isLoadingComments(status?.id ?? '');
                            final canSend = _commentController.text.trim().isNotEmpty && !isPosting;

                            return ElevatedButton(
                              onPressed: canSend
                                  ? () async {
                                      if (status == null) return;
                                      final text = _commentController.text.trim();
                                      _commentController.clear();
                                      final success = await provider.addComment(status.id, text);
                                      if (!success && mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(SnackBar(content: Text('Failed to post comment')));
                                      }
                                    }
                                  : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: canSend ? colors.accentOrange : colors.inputBorder,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24.r)),
                                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                              ),
                              child: isPosting
                                  ? SizedBox(
                                      width: 16.w,
                                      height: 16.h,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation(Colors.white),
                                      ),
                                    )
                                  : Text(
                                      'Send',
                                      style: TextStyle(
                                        color: canSend ? Colors.white : colors.textSecondary,
                                        fontSize: 14.sp,
                                      ),
                                    ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (mounted && !_isImageLoading) {
      _progressController.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final dragOffset = _isDraggingVertical ? (_dragCurrentY - _dragStartY).clamp(0.0, 200.0) : 0.0;
    final scale = 1.0 - (dragOffset / 1000);
    final opacity = 1.0 - (dragOffset / 400);

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
                                _buildProgressBars(isLoading ? 1 : statuses.length),
                                SizedBox(height: 12.h),
                                _buildHeader(colors, currentStatus),
                                const Spacer(),
                                _buildBottomContent(colors, currentStatus, provider),
                                SizedBox(height: 20.h),
                                Divider(
                                  indent: 40.w,
                                  endIndent: 40.w,
                                  height: 0.5,
                                  color: Colors.white.withValues(alpha: 0.3),
                                ),
                                _buildSwipeUpToComments(currentStatus),
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
          SvgPicture.asset(
            Assets.icons.moreVert,
            package: "grab_go_shared",
            height: 24.h,
            width: 24.w,
            colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomContent(AppColorsExtension colors, StatusModel? status, StatusProvider provider) {
    if (status == null) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
          ],
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
          // Row(
          //   children: [
          //     // _buildActionButton(
          //     //   icon: provider.isLiked(status.id) ? Assets.icons.heartSolid : Assets.icons.heart,
          //     //   label: '${status.likeCount}',
          //     //   onTap: () => provider.toggleLike(status.id),
          //     //   isLiked: provider.isLiked(status.id),
          //     // ),
          //     // SizedBox(width: 24.w),
          //     // _buildActionButton(icon: Assets.icons.eye, label: '${status.viewCount}', onTap: null),
          //     const Spacer(),
          //     if (status.linkedFood != null)
          //       ElevatedButton(
          //         onPressed: () {
          //           // Navigate to food detail
          //         },
          //         style: ElevatedButton.styleFrom(
          //           backgroundColor: colors.accentOrange,
          //           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
          //         ),
          //         child: Row(
          //           children: [
          //             SvgPicture.asset(
          //               Assets.icons.cart,
          //               package: "grab_go_shared",
          //               height: 16.h,
          //               width: 16.w,
          //               colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
          //             ),
          //             SizedBox(width: 10.w),
          //             Text(
          //               'Add to cart',
          //               style: TextStyle(color: Colors.white, fontSize: 14.sp, fontWeight: FontWeight.w400),
          //             ),
          //           ],
          //         ),
          //       ),
          //   ],
          // ),
        ],
      ),
    );
  }

  Widget _buildSwipeUpToComments(StatusModel? status) {
    return GestureDetector(
      key: _commentsSwipeKey,
      onTap: () => _showCommentsBottomSheet(status),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(10.r),
        child: Center(
          child: Text(
            'Tap to view comments',
            style: TextStyle(color: Colors.white70, fontSize: 12.sp),
          ),
        ),
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

  // ============================================================
  // Comment Helper Widgets
  // ============================================================

  Widget _buildCommentsLoading(AppColorsExtension colors, ScrollController scrollController) {
    return ListView.builder(
      controller: scrollController,
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      itemCount: 5,
      itemBuilder: (context, index) {
        return Padding(
          padding: EdgeInsets.symmetric(vertical: 10.h),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(radius: 16.r, backgroundColor: colors.inputBorder),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 100.w,
                      height: 12.h,
                      decoration: BoxDecoration(color: colors.inputBorder, borderRadius: BorderRadius.circular(4.r)),
                    ),
                    SizedBox(height: 6.h),
                    Container(
                      width: double.infinity,
                      height: 12.h,
                      decoration: BoxDecoration(color: colors.inputBorder, borderRadius: BorderRadius.circular(4.r)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCommentsError(AppColorsExtension colors, String error, VoidCallback onRetry) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 48.r, color: colors.textSecondary),
          SizedBox(height: 16.h),
          Text(
            error,
            style: TextStyle(color: colors.textSecondary, fontSize: 14.sp),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 16.h),
          ElevatedButton(
            onPressed: onRetry,
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.accentOrange,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
            ),
            child: Text('Retry', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyComments(AppColorsExtension colors) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline, size: 48.r, color: colors.textSecondary),
          SizedBox(height: 16.h),
          Text(
            'No comments yet',
            style: TextStyle(color: colors.textSecondary, fontSize: 16.sp, fontWeight: FontWeight.w500),
          ),
          SizedBox(height: 8.h),
          Text(
            'Be the first to comment!',
            style: TextStyle(color: colors.textSecondary, fontSize: 14.sp),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentItem(CommentModel comment, AppColorsExtension colors, String statusId) {
    // Check if this is the current user's comment (simplified - you may need actual user ID)
    final isOwnComment = comment.user.name == 'You';

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 10.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16.r,
            backgroundImage: comment.user.profileImage != null
                ? CachedNetworkImageProvider(comment.user.profileImage!)
                : null,
            backgroundColor: colors.accentOrange.withOpacity(0.2),
            child: comment.user.profileImage == null
                ? Text(
                    comment.user.name[0].toUpperCase(),
                    style: TextStyle(color: colors.accentOrange, fontSize: 14.sp, fontWeight: FontWeight.w600),
                  )
                : null,
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      comment.user.name,
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14.sp, color: colors.textPrimary),
                    ),
                    SizedBox(width: 8.w),
                    Text(
                      comment.timeAgo,
                      style: TextStyle(color: colors.textSecondary, fontSize: 12.sp),
                    ),
                  ],
                ),
                SizedBox(height: 4.h),
                Text(
                  comment.text,
                  style: TextStyle(fontSize: 14.sp, color: colors.textPrimary),
                ),
              ],
            ),
          ),
          if (isOwnComment)
            IconButton(
              icon: Icon(Icons.delete_outline, size: 20.r, color: colors.textSecondary),
              padding: EdgeInsets.zero,
              constraints: BoxConstraints(),
              onPressed: () async {
                final provider = context.read<StatusProvider>();
                final success = await provider.deleteComment(statusId, comment.id);
                if (!success && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete comment')));
                }
              },
            ),
        ],
      ),
    );
  }
}
