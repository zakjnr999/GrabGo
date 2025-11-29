import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import 'package:grab_go_customer/features/status/model/status_model.dart';
import 'package:grab_go_customer/features/status/viewmodel/status_provider.dart';
import 'package:grab_go_shared/grub_go_shared.dart';

/// Full-screen story viewer for viewing restaurant statuses
class StoryViewer extends StatefulWidget {
  final String restaurantId;
  final String restaurantName;
  final String? restaurantLogo;

  const StoryViewer({super.key, required this.restaurantId, required this.restaurantName, this.restaurantLogo});

  @override
  State<StoryViewer> createState() => _StoryViewerState();
}

class _StoryViewerState extends State<StoryViewer> with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  late AnimationController _progressController;

  // Use a map to prevent duplicate entries and limit memory usage
  final Map<String, BatchViewItem> _viewedItemsMap = {};
  DateTime? _currentViewStartTime;
  bool _isInitialized = false;
  bool _isPreloading = false;

  // Maximum items to track (prevents unbounded growth)
  static const int _maxViewedItems = 50;
  static const Duration _storyDuration = Duration(seconds: 5);
  static const Duration _videoDuration = Duration(seconds: 15);

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(vsync: this, duration: _storyDuration);

    _progressController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _nextStory();
      }
    });
  }

  @override
  void dispose() {
    _recordCurrentView();
    _sendBatchViews();
    // Mark story as viewed when closing (moves to end of list like WhatsApp)
    context.read<StatusProvider>().markStoryAsViewed(widget.restaurantId);
    _progressController.dispose();
    super.dispose();
  }

  void _startProgress(StatusModel status) {
    _recordCurrentView();
    _currentViewStartTime = DateTime.now();

    final duration = status.isVideo ? _videoDuration : _storyDuration;
    _progressController.duration = duration;
    _progressController.forward(from: 0);
  }

  void _recordCurrentView() {
    if (_currentViewStartTime != null) {
      final provider = context.read<StatusProvider>();
      final statuses = provider.currentRestaurantStatuses;

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
      context.read<StatusProvider>().recordBatchViews(_viewedItemsMap.values.toList());
      _viewedItemsMap.clear(); // Clear after sending
    }
  }

  /// Preload next images for smoother UX
  void _preloadNextImages(List<StatusModel> statuses) {
    if (_isPreloading) return;
    _isPreloading = true;

    // Preload next 2 images
    for (int i = _currentIndex + 1; i <= _currentIndex + 2 && i < statuses.length; i++) {
      final status = statuses[i];
      if (!status.isVideo) {
        precacheImage(CachedNetworkImageProvider(status.mediaUrl), context).catchError((_) {});
      }
    }

    _isPreloading = false;
  }

  void _nextStory() {
    final provider = context.read<StatusProvider>();
    final statuses = provider.currentRestaurantStatuses;

    if (_currentIndex < statuses.length - 1) {
      setState(() => _currentIndex++);
      _startProgress(statuses[_currentIndex]);
      _preloadNextImages(statuses);
    } else {
      _close();
    }
  }

  void _previousStory() {
    if (_currentIndex > 0) {
      final provider = context.read<StatusProvider>();
      final statuses = provider.currentRestaurantStatuses;
      setState(() => _currentIndex--);
      _startProgress(statuses[_currentIndex]);
    }
  }

  void _close() {
    _recordCurrentView();
    _sendBatchViews();
    Navigator.of(context).pop();
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

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Consumer<StatusProvider>(
        builder: (context, provider, child) {
          final statuses = provider.currentRestaurantStatuses;

          if (statuses.isEmpty) {
            return Center(child: CircularProgressIndicator(color: colors.accentOrange));
          }

          if (!_isInitialized && statuses.isNotEmpty) {
            _isInitialized = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _startProgress(statuses[_currentIndex]);
                // Preload upcoming images
                _preloadNextImages(statuses);
              }
            });
          }

          final currentStatus = statuses[_currentIndex];

          return GestureDetector(
            onTapUp: _onTapUp,
            onLongPressStart: (_) => _progressController.stop(),
            onLongPressEnd: (_) => _progressController.forward(),
            child: Stack(
              fit: StackFit.expand,
              children: [
                CachedNetworkImage(
                  imageUrl: currentStatus.mediaUrl,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(color: Colors.black),
                  errorWidget: (_, __, ___) => Container(color: Colors.grey[900]),
                ),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.6),
                        Colors.transparent,
                        Colors.transparent,
                        Colors.black.withOpacity(0.8),
                      ],
                      stops: const [0.0, 0.2, 0.7, 1.0],
                    ),
                  ),
                ),
                SafeArea(
                  child: Column(
                    children: [
                      _buildProgressBars(statuses.length),
                      SizedBox(height: 12.h),
                      _buildHeader(colors, currentStatus),
                      const Spacer(),
                      _buildBottomContent(colors, currentStatus, provider),
                      SizedBox(height: 20.h),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
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
                    backgroundColor: Colors.white.withOpacity(0.3),
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

  Widget _buildHeader(AppColorsExtension colors, StatusModel status) {
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
                Text(
                  status.timeAgo,
                  style: TextStyle(color: Colors.white70, fontSize: 12.sp),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _close,
            icon: const Icon(Icons.close, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomContent(AppColorsExtension colors, StatusModel status, StatusProvider provider) {
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
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8.r),
                        border: Border.all(color: Colors.white.withOpacity(0.5)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.copy, color: Colors.white, size: 16.r),
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
                icon: provider.isLiked(status.id) ? Icons.favorite : Icons.favorite_border,
                label: '${status.likeCount}',
                color: provider.isLiked(status.id) ? Colors.red : Colors.white,
                onTap: () => provider.toggleLike(status.id),
              ),
              SizedBox(width: 24.w),
              _buildActionButton(
                icon: Icons.visibility,
                label: '${status.viewCount}',
                color: Colors.white,
                onTap: null,
              ),
              SizedBox(width: 24.w),
              _buildActionButton(
                icon: Icons.share,
                label: 'Share',
                color: Colors.white,
                onTap: () => _shareStatus(status),
              ),
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

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, color: color, size: 24.r),
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

    String shareText = '${widget.restaurantName}';
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
