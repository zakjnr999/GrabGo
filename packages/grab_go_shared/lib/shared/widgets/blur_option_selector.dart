import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/shared/utils/app_colors_extension.dart';
import 'package:grab_go_shared/shared/utils/constants.dart';

class BlurOptionItem<T> {
  final T value;
  final String label;
  final String? subtitle;
  final String? iconPath;
  final bool isDestructive;

  const BlurOptionItem({
    required this.value,
    required this.label,
    this.subtitle,
    this.iconPath,
    this.isDestructive = false,
  });
}

class BlurOptionSelector {
  static Future<T?> show<T>({
    required BuildContext context,
    required String title,
    required List<BlurOptionItem<T>> options,
    T? selectedValue,
    String? subtitle,
    bool barrierDismissible = true,
  }) {
    final colors = context.appColors;

    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      barrierLabel: 'blur_option_selector',
      barrierColor: Colors.transparent,
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        final dialogFade = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        final dialogScale = Tween<double>(begin: 0.92, end: 1.0).animate(
          CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutBack,
            reverseCurve: Curves.easeInCubic,
          ),
        );
        final dialogSlide =
            Tween<Offset>(
              begin: const Offset(0, 0.03),
              end: Offset.zero,
            ).animate(
              CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
                reverseCurve: Curves.easeInCubic,
              ),
            );

        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: () {
                  if (barrierDismissible) Navigator.of(dialogContext).pop();
                },
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 9, sigmaY: 9),
                  child: Container(color: Colors.black.withValues(alpha: 0.22)),
                ),
              ),
            ),
            SafeArea(
              child: Center(
                child: FadeTransition(
                  opacity: dialogFade,
                  child: SlideTransition(
                    position: dialogSlide,
                    child: ScaleTransition(
                      scale: dialogScale,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Material(
                          color: colors.backgroundPrimary,
                          borderRadius: BorderRadius.circular(
                            KBorderSize.borderRadius8,
                          ),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 360),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    18,
                                    16,
                                    18,
                                    10,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        title,
                                        style: TextStyle(
                                          color: colors.textPrimary,
                                          fontSize: 18,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      if (subtitle != null) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          subtitle,
                                          style: TextStyle(
                                            color: colors.textSecondary,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                Divider(
                                  height: 1,
                                  color: colors.border.withValues(alpha: 0.7),
                                ),
                                Flexible(
                                  child: ListView.separated(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 8,
                                    ),
                                    shrinkWrap: true,
                                    itemCount: options.length,
                                    separatorBuilder: (context, index) =>
                                        Divider(
                                          height: 1,
                                          indent: 16,
                                          endIndent: 16,
                                          color: colors.border.withValues(
                                            alpha: 0.5,
                                          ),
                                        ),
                                    itemBuilder: (context, index) {
                                      final option = options[index];
                                      final bool isSelected =
                                          option.value == selectedValue;
                                      final Color textColor =
                                          option.isDestructive
                                          ? colors.error
                                          : colors.textPrimary;

                                      return InkWell(
                                        onTap: () => Navigator.of(
                                          dialogContext,
                                        ).pop(option.value),
                                        borderRadius: BorderRadius.circular(
                                          KBorderSize.borderRadius4,
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 12,
                                          ),
                                          child: Row(
                                            children: [
                                              if (option.iconPath != null) ...[
                                                Container(
                                                  width: 34,
                                                  height: 34,
                                                  decoration: BoxDecoration(
                                                    color: isSelected
                                                        ? colors.accentGreen
                                                              .withValues(
                                                                alpha: 0.14,
                                                              )
                                                        : colors
                                                              .backgroundSecondary,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          KBorderSize
                                                              .borderRadius4,
                                                        ),
                                                  ),
                                                  child: Center(
                                                    child: SvgPicture.asset(
                                                      option.iconPath!,
                                                      package: 'grab_go_shared',
                                                      width: KIconSize.sm,
                                                      height: KIconSize.sm,
                                                      colorFilter:
                                                          ColorFilter.mode(
                                                            isSelected
                                                                ? colors
                                                                      .accentGreen
                                                                : textColor,
                                                            BlendMode.srcIn,
                                                          ),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                              ],
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      option.label,
                                                      style: TextStyle(
                                                        color: textColor,
                                                        fontSize: 14,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
                                                    if (option.subtitle !=
                                                        null) ...[
                                                      const SizedBox(height: 2),
                                                      Text(
                                                        option.subtitle!,
                                                        style: TextStyle(
                                                          color: colors
                                                              .textSecondary,
                                                          fontSize: 11,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                        ),
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                              ),
                                              if (isSelected)
                                                SvgPicture.asset(
                                                  Assets.icons.checkCircleSolid,
                                                  package: 'grab_go_shared',
                                                  width: 20,
                                                  height: 20,
                                                  colorFilter: ColorFilter.mode(
                                                    colors.accentGreen,
                                                    BlendMode.srcIn,
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
      transitionDuration: const Duration(milliseconds: 280),
      transitionBuilder:
          (transitionContext, animation, secondaryAnimation, child) => child,
    );
  }
}
