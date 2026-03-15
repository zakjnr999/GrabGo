import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';

class AllCategoriesSheet<T> extends StatelessWidget {
  final String title;
  final List<T> categories;
  final String Function(T) getName;
  final String Function(T) getEmoji;
  final String? Function(T)? getImage;
  final String Function(T) getId;
  final ValueChanged<T> onCategorySelected;
  final Color? accentColor;
  final String? selectedCategoryId;
  final bool closeOnSelect;

  const AllCategoriesSheet({
    super.key,
    required this.title,
    required this.categories,
    required this.getName,
    required this.getEmoji,
    this.getImage,
    required this.getId,
    required this.onCategorySelected,
    this.accentColor,
    this.selectedCategoryId,
    this.closeOnSelect = true,
  });

  static Future<void> show<T>({
    required BuildContext context,
    required String title,
    required List<T> categories,
    required String Function(T) getName,
    required String Function(T) getEmoji,
    String? Function(T)? getImage,
    required String Function(T) getId,
    required ValueChanged<T> onCategorySelected,
    Color? accentColor,
    String? selectedCategoryId,
    bool closeOnSelect = true,
  }) {
    if (categories.isEmpty) return Future.value();

    return showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return AllCategoriesSheet<T>(
          title: title,
          categories: categories,
          getName: getName,
          getEmoji: getEmoji,
          getImage: getImage,
          getId: getId,
          onCategorySelected: onCategorySelected,
          accentColor: accentColor,
          selectedCategoryId: selectedCategoryId,
          closeOnSelect: closeOnSelect,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final size = MediaQuery.sizeOf(context);
    final effectiveAccentColor = accentColor ?? colors.accentOrange;
    const crossAxisCount = 3;
    final horizontalPadding = 20.w;
    final crossSpacing = 14.w;
    final availableWidth = size.width - (horizontalPadding * 2) - ((crossAxisCount - 1) * crossSpacing);
    final tileWidth = availableWidth / crossAxisCount;
    final avatarSize = (tileWidth * 0.92).clamp(98.0, 132.0);
    final emojiSize = (avatarSize * 0.34).clamp(28.0, 38.0);
    const labelHeight = 42.0;
    const labelSpacing = 10.0;
    final tileHeight = avatarSize + labelSpacing + labelHeight;

    return FractionallySizedBox(
      heightFactor: 0.76,
      child: Container(
        decoration: BoxDecoration(
          color: colors.backgroundPrimary,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(KBorderSize.borderRadius20),
            topRight: Radius.circular(KBorderSize.borderRadius20),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 10.h),
            Align(
              alignment: Alignment.center,
              child: Container(
                width: 40.w,
                height: 4.h,
                decoration: BoxDecoration(color: colors.inputBorder, borderRadius: BorderRadius.circular(999.r)),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(20.w, 14.h, 20.w, 8.h),
              child: Text(
                title,
                style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w700, color: colors.textPrimary),
              ),
            ),
            Expanded(
              child: GridView.builder(
                padding: EdgeInsets.fromLTRB(horizontalPadding, 8.h, horizontalPadding, 20.h),
                itemCount: categories.length,
                physics: const AlwaysScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: crossSpacing,
                  mainAxisSpacing: 14.h,
                  mainAxisExtent: tileHeight,
                ),
                itemBuilder: (context, index) {
                  final category = categories[index];
                  final categoryId = getId(category);
                  final isSelected = selectedCategoryId == categoryId;
                  final imageUrl = getImage?.call(category)?.trim();
                  final hasImage = imageUrl != null && imageUrl.isNotEmpty;

                  return GestureDetector(
                    onTap: () {
                      if (closeOnSelect && Navigator.of(context).canPop()) {
                        Navigator.of(context).pop();
                      }
                      onCategorySelected(category);
                    },
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOut,
                          width: tileWidth,
                          height: avatarSize,
                          alignment: Alignment.center,
                          padding: EdgeInsets.symmetric(
                            horizontal: hasImage ? 16.w : 10.w,
                            vertical: hasImage ? 16.h : 10.h,
                          ),
                          decoration: BoxDecoration(
                            color: effectiveAccentColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(KBorderSize.borderMedium),
                          ),
                          child: hasImage
                              ? CachedNetworkImage(
                                  imageUrl: ImageOptimizer.getPreviewUrl(imageUrl, width: 180),
                                  fit: BoxFit.contain,
                                  memCacheWidth: 180,
                                  maxHeightDiskCache: 360,
                                  placeholder: (context, url) =>
                                      _buildCategoryImageFallback(effectiveAccentColor, (emojiSize * 0.82).sp),
                                  errorWidget: (context, url, error) =>
                                      _buildCategoryImageFallback(effectiveAccentColor, (emojiSize * 0.82).sp),
                                )
                              : _buildCategoryImageFallback(effectiveAccentColor, (emojiSize * 0.82).sp),
                        ),
                        const SizedBox(height: labelSpacing),
                        SizedBox(
                          height: labelHeight,
                          child: Text(
                            getName(category),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13.sp,
                              height: 1.2,
                              fontWeight: FontWeight.w600,
                              color: isSelected ? effectiveAccentColor : colors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryImageFallback(Color accentColor, double iconSize) {
    return Center(
      child: SvgPicture.asset(
        Assets.icons.cart,
        package: 'grab_go_shared',
        width: iconSize,
        height: iconSize,
        colorFilter: ColorFilter.mode(accentColor, BlendMode.srcIn),
      ),
    );
  }
}
