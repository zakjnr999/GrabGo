import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:grab_go_shared/grub_go_shared.dart';

class PriceTag extends StatelessWidget {
  final double price;

  /// The currency code (e.g., "GHS", "USD")
  final String currency;

  /// Border color (defaults to accentOrange)
  final Color? borderColor;

  /// Background color for the tag body (defaults to white/backgroundPrimary)
  final Color? backgroundColor;

  /// Text color for the price (defaults to borderColor)
  final Color? priceColor;

  /// Text color for the currency label (defaults to textSecondary)
  final Color? currencyColor;

  /// Size variant: small, medium, large
  final PriceTagSize size;

  /// Whether to show a shadow
  final bool showShadow;

  /// Notch position: left or right
  final NotchPosition notchPosition;

  /// Border width
  final double? borderWidth;

  const PriceTag({
    super.key,
    required this.price,
    this.currency = 'GHS',
    this.borderColor,
    this.backgroundColor,
    this.priceColor,
    this.currencyColor,
    this.size = PriceTagSize.medium,
    this.showShadow = true,
    this.notchPosition = NotchPosition.left,
    this.borderWidth,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Determine effective colors
    final effectiveBorderColor = borderColor ?? colors.accentOrange;
    final effectiveBackgroundColor = backgroundColor ?? (isDark ? colors.backgroundSecondary : Colors.white);
    final effectivePriceColor = priceColor ?? effectiveBorderColor;
    final effectiveCurrencyColor = currencyColor ?? colors.textSecondary;

    // Size configurations
    final sizeConfig = _getSizeConfig();
    final effectiveBorderWidth = borderWidth ?? sizeConfig.borderWidth;

    return CustomPaint(
      painter: PriceTagPainter(
        backgroundColor: effectiveBackgroundColor,
        borderColor: effectiveBorderColor,
        borderWidth: effectiveBorderWidth,
        showShadow: showShadow,
        shadowColor: effectiveBorderColor.withValues(alpha: 0.25),
        notchPosition: notchPosition,
        notchRadius: sizeConfig.notchRadius,
        cornerRadius: sizeConfig.cornerRadius,
        holeRadius: sizeConfig.holeRadius,
      ),
      child: Container(
        width: sizeConfig.width,
        height: sizeConfig.height,
        padding: EdgeInsets.only(
          left: notchPosition == NotchPosition.left
              ? sizeConfig.horizontalPadding + sizeConfig.notchRadius
              : sizeConfig.horizontalPadding,
          right: notchPosition == NotchPosition.right
              ? sizeConfig.horizontalPadding + sizeConfig.notchRadius
              : sizeConfig.horizontalPadding,
          top: sizeConfig.verticalPadding,
          bottom: sizeConfig.verticalPadding,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Currency label
            Text(
              currency,
              style: TextStyle(
                color: effectiveCurrencyColor,
                fontSize: sizeConfig.currencyFontSize,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
                height: 1.0,
              ),
            ),
            SizedBox(height: sizeConfig.spacing),
            // Price
            Text(
              price.toStringAsFixed(2),
              style: TextStyle(
                color: effectivePriceColor,
                fontSize: sizeConfig.priceFontSize,
                fontWeight: FontWeight.w800,
                height: 1.0,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  _PriceTagSizeConfig _getSizeConfig() {
    switch (size) {
      case PriceTagSize.small:
        return _PriceTagSizeConfig(
          width: 70.w,
          height: 45.h,
          horizontalPadding: 8.w,
          verticalPadding: 6.h,
          currencyFontSize: 9.sp,
          priceFontSize: 14.sp,
          spacing: 1.h,
          cornerRadius: 8.r,
          notchRadius: 8.r,
          holeRadius: 2.5.r,
          borderWidth: 2.0,
        );
      case PriceTagSize.medium:
        return _PriceTagSizeConfig(
          width: 95.w,
          height: 55.h,
          horizontalPadding: 10.w,
          verticalPadding: 8.h,
          currencyFontSize: 11.sp,
          priceFontSize: 18.sp,
          spacing: 2.h,
          cornerRadius: 10.r,
          notchRadius: 10.r,
          holeRadius: 3.r,
          borderWidth: 2.5,
        );
      case PriceTagSize.large:
        return _PriceTagSizeConfig(
          width: 110.w,
          height: 65.h,
          horizontalPadding: 12.w,
          verticalPadding: 10.h,
          currencyFontSize: 13.sp,
          priceFontSize: 22.sp,
          spacing: 3.h,
          cornerRadius: 12.r,
          notchRadius: 12.r,
          holeRadius: 3.5.r,
          borderWidth: 3.0,
        );
    }
  }
}

/// Custom painter for the price tag shape
class PriceTagPainter extends CustomPainter {
  final Color backgroundColor;
  final Color borderColor;
  final double borderWidth;
  final bool showShadow;
  final Color shadowColor;
  final NotchPosition notchPosition;
  final double notchRadius;
  final double cornerRadius;
  final double holeRadius;

  PriceTagPainter({
    required this.backgroundColor,
    required this.borderColor,
    required this.borderWidth,
    required this.showShadow,
    required this.shadowColor,
    required this.notchPosition,
    required this.notchRadius,
    required this.cornerRadius,
    required this.holeRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final path = _createPriceTagPath(size);

    // Draw shadow
    if (showShadow) {
      final shadowPaint = Paint()
        ..color = shadowColor
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8)
        ..isAntiAlias = true;
      canvas.drawPath(path.shift(const Offset(0, 4)), shadowPaint);
    }

    // Draw background fill
    final fillPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = backgroundColor
      ..isAntiAlias = true;
    canvas.drawPath(path, fillPaint);

    // Draw border
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = borderColor
      ..strokeWidth = borderWidth
      ..isAntiAlias = true;
    canvas.drawPath(path, borderPaint);

    // Draw hole punch
    _drawHolePunch(canvas, size);
  }

  Path _createPriceTagPath(Size size) {
    final path = Path();
    final notchCenterY = size.height / 2;

    if (notchPosition == NotchPosition.left) {
      // Start from top-left, after the notch area
      path.moveTo(notchRadius * 1.5, 0);

      // Top edge
      path.lineTo(size.width - cornerRadius, 0);

      // Top-right corner
      path.arcToPoint(Offset(size.width, cornerRadius), radius: Radius.circular(cornerRadius), clockwise: true);

      // Right edge
      path.lineTo(size.width, size.height - cornerRadius);

      // Bottom-right corner
      path.arcToPoint(
        Offset(size.width - cornerRadius, size.height),
        radius: Radius.circular(cornerRadius),
        clockwise: true,
      );

      // Bottom edge
      path.lineTo(notchRadius * 1.5, size.height);

      // Left side with circular notch
      // Bottom to notch bottom
      path.lineTo(notchRadius * 1.5, notchCenterY + notchRadius);

      // Circular notch cutout (going inward, then back out)
      path.arcToPoint(
        Offset(notchRadius * 1.5, notchCenterY - notchRadius),
        radius: Radius.circular(notchRadius),
        clockwise: false,
        largeArc: false,
      );

      // Notch top to top-left
      path.lineTo(notchRadius * 1.5, 0);
    } else {
      // Right notch position (mirror)
      path.moveTo(cornerRadius, 0);
      path.lineTo(size.width - (notchRadius * 1.5), 0);

      path.lineTo(size.width - (notchRadius * 1.5), notchCenterY - notchRadius);

      path.arcToPoint(
        Offset(size.width - (notchRadius * 1.5), notchCenterY + notchRadius),
        radius: Radius.circular(notchRadius),
        clockwise: true,
        largeArc: false,
      );

      path.lineTo(size.width - (notchRadius * 1.5), size.height);
      path.lineTo(cornerRadius, size.height);

      path.arcToPoint(Offset(0, size.height - cornerRadius), radius: Radius.circular(cornerRadius), clockwise: true);

      path.lineTo(0, cornerRadius);

      path.arcToPoint(Offset(cornerRadius, 0), radius: Radius.circular(cornerRadius), clockwise: true);
    }

    path.close();
    return path;
  }

  void _drawHolePunch(Canvas canvas, Size size) {
    final notchCenterY = size.height / 2;
    final holeX = notchPosition == NotchPosition.left ? notchRadius * 0.75 : size.width - (notchRadius * 0.75);

    final holeCenter = Offset(holeX, notchCenterY);

    // Hole fill (same as border color for the notch area)
    final holeFillPaint = Paint()
      ..color = AppColors.accentOrange
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    canvas.drawCircle(holeCenter, holeRadius, holeFillPaint);
  }

  @override
  bool shouldRepaint(PriceTagPainter oldDelegate) {
    return oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.borderColor != borderColor ||
        oldDelegate.borderWidth != borderWidth ||
        oldDelegate.showShadow != showShadow ||
        oldDelegate.notchPosition != notchPosition;
  }
}

/// Size variants for the price tag
enum PriceTagSize { small, medium, large }

/// Notch position for the price tag
enum NotchPosition { left, right }

/// Internal configuration class for size-specific values
class _PriceTagSizeConfig {
  final double width;
  final double height;
  final double horizontalPadding;
  final double verticalPadding;
  final double currencyFontSize;
  final double priceFontSize;
  final double spacing;
  final double cornerRadius;
  final double notchRadius;
  final double holeRadius;
  final double borderWidth;

  _PriceTagSizeConfig({
    required this.width,
    required this.height,
    required this.horizontalPadding,
    required this.verticalPadding,
    required this.currencyFontSize,
    required this.priceFontSize,
    required this.spacing,
    required this.cornerRadius,
    required this.notchRadius,
    required this.holeRadius,
    required this.borderWidth,
  });
}

/// Animated price tag that can transition between prices
class AnimatedPriceTag extends StatefulWidget {
  final double price;
  final String currency;
  final Color? borderColor;
  final Color? backgroundColor;
  final Color? priceColor;
  final Color? currencyColor;
  final PriceTagSize size;
  final bool showShadow;
  final NotchPosition notchPosition;
  final Duration animationDuration;

  const AnimatedPriceTag({
    super.key,
    required this.price,
    this.currency = 'GHS',
    this.borderColor,
    this.backgroundColor,
    this.priceColor,
    this.currencyColor,
    this.size = PriceTagSize.medium,
    this.showShadow = true,
    this.notchPosition = NotchPosition.left,
    this.animationDuration = const Duration(milliseconds: 300),
  });

  @override
  State<AnimatedPriceTag> createState() => _AnimatedPriceTagState();
}

class _AnimatedPriceTagState extends State<AnimatedPriceTag> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  double _previousPrice = 0;

  @override
  void initState() {
    super.initState();
    _previousPrice = widget.price;
    _controller = AnimationController(duration: widget.animationDuration, vsync: this);
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));
  }

  @override
  void didUpdateWidget(AnimatedPriceTag oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.price != widget.price) {
      _previousPrice = oldWidget.price;
      _controller.forward(from: 0).then((_) {
        if (mounted) {
          _controller.reverse();
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: PriceTag(
        price: widget.price,
        currency: widget.currency,
        borderColor: widget.borderColor,
        backgroundColor: widget.backgroundColor,
        priceColor: widget.priceColor,
        currencyColor: widget.currencyColor,
        size: widget.size,
        showShadow: widget.showShadow,
        notchPosition: widget.notchPosition,
      ),
    );
  }
}
