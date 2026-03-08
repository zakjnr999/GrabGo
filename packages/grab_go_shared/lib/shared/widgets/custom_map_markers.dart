import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_svg/flutter_svg.dart';

class CustomMapMarkers {
  static const String _riderVehicleSvgAsset =
      'packages/grab_go_shared/lib/assets/icons/rider_marker_icon.svg';
  static const String _personMarkerSvgAsset =
      'packages/grab_go_shared/lib/assets/icons/person_marker.svg';

  static const double _minRiderVehicleMarkerSize = 36.0;
  static const double _maxRiderVehicleMarkerSize = 120.0;

  /// Create a compact rider vehicle marker from SVG.
  /// The icon points "up" in source SVG so rotation=0 aligns with map north.
  static Future<BitmapDescriptor> createRiderVehicleMarker({
    double size = 60,
  }) async {
    final double markerSize = size.clamp(
      _minRiderVehicleMarkerSize,
      _maxRiderVehicleMarkerSize,
    );

    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    final Paint paint = Paint();

    try {
      final String svgString = await rootBundle.loadString(
        _riderVehicleSvgAsset,
      );
      final SvgStringLoader loader = SvgStringLoader(svgString);
      final PictureInfo pictureInfo = await vg.loadPicture(loader, null);

      final double shortestSide = math.min(
        pictureInfo.size.width,
        pictureInfo.size.height,
      );
      final double scale = markerSize / shortestSide;
      final double renderedWidth = pictureInfo.size.width * scale;
      final double renderedHeight = pictureInfo.size.height * scale;
      final double dx = (markerSize - renderedWidth) / 2;
      final double dy = (markerSize - renderedHeight) / 2;

      canvas.save();
      canvas.translate(dx, dy);
      canvas.scale(scale, scale);
      canvas.drawPicture(pictureInfo.picture);
      canvas.restore();
    } catch (e) {
      debugPrint('Error drawing rider vehicle SVG: $e');

      // Fallback marker if SVG fails to load.
      final Offset center = Offset(markerSize / 2, markerSize / 2);
      paint.color = const Color(0xFF2A9D8F);
      canvas.drawCircle(center, markerSize * 0.4, paint);
      final icon = Icons.motorcycle_rounded;
      final iconPainter = TextPainter(
        text: TextSpan(
          text: String.fromCharCode(icon.codePoint),
          style: TextStyle(
            fontSize: markerSize * 0.48,
            fontFamily: icon.fontFamily,
            package: icon.fontPackage,
            color: Colors.white,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      iconPainter.layout();
      iconPainter.paint(
        canvas,
        Offset(
          center.dx - iconPainter.width / 2,
          center.dy - iconPainter.height / 2,
        ),
      );
    }

    final ui.Image finalImage = await pictureRecorder.endRecording().toImage(
      markerSize.toInt(),
      markerSize.toInt(),
    );
    final ByteData? byteData = await finalImage.toByteData(
      format: ui.ImageByteFormat.png,
    );
    return BitmapDescriptor.bytes(byteData!.buffer.asUint8List());
  }

  static Future<BitmapDescriptor> createOrderPinMarker({
    required Color primaryColor,
    required Color highlightColor,
    bool isHighlighted = false,
    int itemCount = 0,
  }) async {
    const double width = 140;
    const double height = 168;
    const double cardWidth = 98;
    const double cardHeight = 98;
    const double cornerRadius = 20;

    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    final Paint paint = Paint();

    final double cardX = (width - cardWidth) / 2;
    const double cardY = 4.0;
    final RRect cardRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(cardX, cardY, cardWidth, cardHeight),
      Radius.circular(cornerRadius),
    );

    paint.color = isHighlighted ? highlightColor : primaryColor;
    canvas.drawRRect(cardRect, paint);

    final iconCenter = Offset(width / 2, cardY + cardHeight / 2);

    try {
      final String svgString = await rootBundle.loadString(
        'packages/grab_go_shared/lib/assets/icons/store.svg',
      );
      final SvgStringLoader loader = SvgStringLoader(svgString);
      final PictureInfo pictureInfo = await vg.loadPicture(loader, null);

      const double svgSize = 50.0;

      canvas.save();
      canvas.translate(
        iconCenter.dx - svgSize / 2,
        iconCenter.dy - svgSize / 2,
      );
      final double scale = svgSize / pictureInfo.size.width;
      canvas.scale(scale, scale);

      final Paint tintPaint = Paint()
        ..colorFilter = const ColorFilter.mode(Colors.white, BlendMode.srcIn);
      canvas.saveLayer(
        Rect.fromLTWH(0, 0, pictureInfo.size.width, pictureInfo.size.height),
        tintPaint,
      );
      canvas.drawPicture(pictureInfo.picture);
      canvas.restore();
      canvas.restore();
    } catch (e) {
      debugPrint('Error drawing store SVG: $e');
      final icon = Icons.local_shipping_rounded;
      final iconPainter = TextPainter(
        text: TextSpan(
          text: String.fromCharCode(icon.codePoint),
          style: TextStyle(
            fontSize: 44,
            fontFamily: icon.fontFamily,
            package: icon.fontPackage,
            color: Colors.white,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      iconPainter.layout();
      iconPainter.paint(
        canvas,
        Offset(
          iconCenter.dx - iconPainter.width / 2,
          iconCenter.dy - iconPainter.height / 2,
        ),
      );
    }

    final pointerTop = cardY + cardHeight - 2;
    final Path pointer = Path();
    pointer.moveTo(width / 2 - 14, pointerTop);
    pointer.quadraticBezierTo(
      width / 2 - 8,
      pointerTop + 8,
      width / 2,
      pointerTop + 22,
    );
    pointer.quadraticBezierTo(
      width / 2 + 8,
      pointerTop + 8,
      width / 2 + 14,
      pointerTop,
    );
    pointer.close();
    paint.color = isHighlighted ? highlightColor : primaryColor;
    canvas.drawPath(pointer, paint);

    if (itemCount > 0) {
      final badgeText = itemCount > 99 ? '99+' : '$itemCount';
      final badgePainter = TextPainter(
        text: TextSpan(
          text: badgeText,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      badgePainter.layout();

      final badgeWidth = badgePainter.width + 20;
      final badgeHeight = 28.0;
      final badgeX = cardX + cardWidth - badgeWidth / 2 - 4;
      final badgeY = cardY - 2;

      paint.color = isHighlighted
          ? const Color(0xFF10B981)
          : const Color(0xFFEF4444);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(badgeX, badgeY, badgeWidth, badgeHeight),
          const Radius.circular(9),
        ),
        paint,
      );

      badgePainter.paint(
        canvas,
        Offset(
          badgeX + (badgeWidth - badgePainter.width) / 2,
          badgeY + (badgeHeight - badgePainter.height) / 2,
        ),
      );
    }

    if (isHighlighted) {
      paint.color = highlightColor.withValues(alpha: 0.3);
      paint.style = PaintingStyle.stroke;
      paint.strokeWidth = 3;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(cardX - 4, cardY - 4, cardWidth + 8, cardHeight + 8),
          Radius.circular(cornerRadius + 4),
        ),
        paint,
      );
      paint.style = PaintingStyle.fill;
    }

    // Convert to Bitmap
    final ui.Image finalImage = await pictureRecorder.endRecording().toImage(
      width.toInt(),
      height.toInt(),
    );
    final ByteData? byteData = await finalImage.toByteData(
      format: ui.ImageByteFormat.png,
    );
    return BitmapDescriptor.bytes(byteData!.buffer.asUint8List());
  }

  /// Create rider location marker with simple clean circular design
  static Future<BitmapDescriptor> createRiderLocationMarker({
    required Color primaryColor,
  }) async {
    const double size = 40;
    const double outerRing = 18;
    const double innerDot = 8;

    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    final Paint paint = Paint();

    final Offset center = Offset(size / 2, size / 2);

    // 1. Outer subtle ring (semi-transparent)
    paint.color = primaryColor.withValues(alpha: 0.2);
    canvas.drawCircle(center, outerRing, paint);

    // 2. Middle ring (more opaque)
    paint.color = primaryColor.withValues(alpha: 0.4);
    canvas.drawCircle(center, outerRing * 0.7, paint);

    // 3. Inner solid dot
    paint.color = primaryColor;
    canvas.drawCircle(center, innerDot, paint);

    // 4. White border around inner dot
    paint.color = Colors.white.withValues(alpha: 1);
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 1.5;
    canvas.drawCircle(center, innerDot, paint);
    paint.style = PaintingStyle.fill;

    // Convert to Bitmap
    final ui.Image finalImage = await pictureRecorder.endRecording().toImage(
      size.toInt(),
      size.toInt(),
    );
    final ByteData? byteData = await finalImage.toByteData(
      format: ui.ImageByteFormat.png,
    );
    return BitmapDescriptor.bytes(byteData!.buffer.asUint8List());
  }

  static Future<BitmapDescriptor> createPersonLocationMarker({
    double size = 44,
    required Color primaryColor,
  }) async {
    final double markerSize = size.clamp(32.0, 72.0);

    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    final Paint paint = Paint();

    try {
      final String rawSvgString = await rootBundle.loadString(
        _personMarkerSvgAsset,
      );
      final String svgString = rawSvgString
          .replaceAll(RegExp(r'<defs>[\s\S]*?<\/defs>', multiLine: true), '')
          .replaceAll(RegExp(r'\sfilter=\"url\(#.*?\)\"'), '');
      final SvgStringLoader loader = SvgStringLoader(svgString);
      final PictureInfo pictureInfo = await vg.loadPicture(loader, null);

      final double shortestSide = math.min(
        pictureInfo.size.width,
        pictureInfo.size.height,
      );
      final double scale = markerSize / shortestSide;
      final double renderedWidth = pictureInfo.size.width * scale;
      final double renderedHeight = pictureInfo.size.height * scale;
      final double dx = (markerSize - renderedWidth) / 2;
      final double dy = (markerSize - renderedHeight) / 2;

      canvas.save();
      canvas.translate(dx, dy);
      canvas.scale(scale, scale);
      canvas.drawPicture(pictureInfo.picture);
      canvas.restore();
    } catch (e) {
      debugPrint('Error drawing person marker SVG: $e');

      final Offset center = Offset(markerSize / 2, markerSize / 2);
      paint.color = primaryColor.withValues(alpha: 0.18);
      canvas.drawCircle(center, markerSize * 0.46, paint);

      paint.color = primaryColor;
      canvas.drawCircle(
        center.translate(0, -markerSize * 0.08),
        markerSize * 0.16,
        paint,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: center.translate(0, markerSize * 0.10),
            width: markerSize * 0.36,
            height: markerSize * 0.42,
          ),
          Radius.circular(markerSize * 0.12),
        ),
        paint,
      );
    }

    final ui.Image finalImage = await pictureRecorder.endRecording().toImage(
      markerSize.toInt(),
      markerSize.toInt(),
    );
    final ByteData? byteData = await finalImage.toByteData(
      format: ui.ImageByteFormat.png,
    );
    return BitmapDescriptor.bytes(byteData!.buffer.asUint8List());
  }

  /// Create custom rider marker with avatar and label
  static Future<BitmapDescriptor> createRiderMarker({
    String? imageUrl,
    required String name,
    required Color primaryColor,
  }) async {
    const double width = 200;
    const double height = 230;
    const double avatarRadius = 60;

    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    final Paint paint = Paint();

    // 1. Draw the Name Label Bubble at the top
    final textPainter = TextPainter(
      text: TextSpan(
        text: name,
        style: const TextStyle(
          color: Colors.black,
          fontSize: 28,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();

    final double labelWidth = textPainter.width + 40;
    final double labelHeight = textPainter.height + 20;
    final Rect labelRect = Rect.fromLTWH(
      (width - labelWidth) / 2,
      0,
      labelWidth,
      labelHeight,
    );

    // Draw bubble background (White with slight shadow)
    paint.color = Colors.white;
    canvas.drawRRect(
      RRect.fromRectAndRadius(labelRect, const Radius.circular(30)),
      paint,
    );

    // Draw bubble tail (small triangle pointing down)
    final Path bubbleTail = Path();
    bubbleTail.moveTo(width / 2 - 10, labelHeight);
    bubbleTail.lineTo(width / 2 + 10, labelHeight);
    bubbleTail.lineTo(width / 2, labelHeight + 12);
    bubbleTail.close();
    canvas.drawPath(bubbleTail, paint);

    // Draw the name text
    textPainter.paint(
      canvas,
      Offset(
        (width - textPainter.width) / 2,
        (labelHeight - textPainter.height) / 2,
      ),
    );

    // 2. Draw Avatar (Below the label)
    final double avatarCenterY = labelHeight + 20 + avatarRadius;
    final Offset avatarCenter = Offset(width / 2, avatarCenterY);

    // Outer Border
    paint.color = Colors.white;
    canvas.drawCircle(avatarCenter, avatarRadius + 3, paint);

    // Background color
    paint.color = primaryColor;
    canvas.drawCircle(avatarCenter, avatarRadius, paint);

    // Clip to circle for image
    final Rect avatarRect = Rect.fromCircle(
      center: avatarCenter,
      radius: avatarRadius,
    );
    canvas.save();
    canvas.clipPath(Path()..addOval(avatarRect));

    // Try to load image if available
    ui.Image? avatarImage;
    if (imageUrl != null && imageUrl.isNotEmpty) {
      avatarImage = await _loadNetworkImage(imageUrl);
    }

    if (avatarImage != null) {
      paintImage(
        canvas: canvas,
        rect: avatarRect,
        image: avatarImage,
        fit: BoxFit.cover,
      );
    } else {
      // Draw initials if no image
      final initialsPainter = TextPainter(
        text: TextSpan(
          text: name.isNotEmpty ? name[0].toUpperCase() : 'R',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 50,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      initialsPainter.layout();
      initialsPainter.paint(
        canvas,
        Offset(
          avatarCenter.dx - initialsPainter.width / 2,
          avatarCenter.dy - initialsPainter.height / 2,
        ),
      );
    }
    canvas.restore();

    // 3. Draw marker pointer at the absolute bottom
    final Path bottomPointer = Path();
    bottomPointer.moveTo(width / 2 - 15, avatarCenterY + avatarRadius + 2);
    bottomPointer.lineTo(width / 2 + 15, avatarCenterY + avatarRadius + 2);
    bottomPointer.lineTo(width / 2, avatarCenterY + avatarRadius + 18);
    bottomPointer.close();
    paint.color = Colors.white;
    canvas.drawPath(bottomPointer, paint);

    // Convert to Bitmap
    final ui.Image finalImage = await pictureRecorder.endRecording().toImage(
      width.toInt(),
      height.toInt(),
    );
    final ByteData? byteData = await finalImage.toByteData(
      format: ui.ImageByteFormat.png,
    );
    final Uint8List uint8list = byteData!.buffer.asUint8List();

    return BitmapDescriptor.bytes(uint8list);
  }

  /// Create a standardized circular marker with an icon or count
  static Future<BitmapDescriptor> createStandardMarker({
    String? name,
    required Color primaryColor,
    required String iconAsset,
    int? clusterCount,
    bool isSelected = false,
    bool showLabel = true,
  }) async {
    // Balanced scale factor for selection
    final double scaleFactor = isSelected ? 1.2 : 1.0;
    const double baseSize = 65;
    const double baseRadius = 24;

    final double size = baseSize * scaleFactor;
    final double radius = baseRadius * scaleFactor;

    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    final Paint paint = Paint();

    // 1. Draw individual vendor label bubble - only if NOT a cluster and showLabel is true
    double labelOffset = 0;
    if (name != null && clusterCount == null && showLabel) {
      final textPainter = TextPainter(
        text: TextSpan(
          text: name,
          style: TextStyle(
            color: Colors.black,
            fontSize: 11 * scaleFactor,
            fontWeight: FontWeight.w500,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();

      final double labelHeight = textPainter.height;

      // Label text
      textPainter.paint(canvas, Offset((size - textPainter.width) / 2, 0));

      labelOffset = labelHeight + (3 * scaleFactor);
    }

    final double centerY = labelOffset + radius;
    final Offset center = Offset(size / 2, centerY);

    // 2. Draw Shadow for the circle (Enhanced shadow for better depth)
    final Path shadowPath = Path()
      ..addOval(Rect.fromCircle(center: center, radius: radius));
    canvas.drawShadow(
      shadowPath,
      Colors.black.withValues(alpha: isSelected ? 0.4 : 0.25),
      isSelected ? 6 : 4,
      true,
    );

    // 3. Draw Circle Background with proper opacity
    final markerColor = primaryColor;

    paint.color = markerColor;
    paint.style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, paint);

    if (clusterCount != null) {
      // 4a. Draw Cluster Count
      final countText = clusterCount > 99 ? '99+' : '$clusterCount';
      final countPainter = TextPainter(
        text: TextSpan(
          text: countText,
          style: TextStyle(
            color: Colors.white,
            fontSize: (clusterCount > 9 ? 16 : 22) * scaleFactor,
            fontWeight: FontWeight.w900,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      countPainter.layout();
      countPainter.paint(
        canvas,
        Offset(
          center.dx - countPainter.width / 2,
          center.dy - countPainter.height / 2,
        ),
      );
    } else {
      // 4b. Draw SVG Icon
      try {
        final String svgString = await rootBundle.loadString(iconAsset);
        final SvgStringLoader loader = SvgStringLoader(svgString);
        final PictureInfo pictureInfo = await vg.loadPicture(loader, null);

        final double svgSize = radius * 1.25;

        canvas.save();
        canvas.translate(center.dx - svgSize / 2, center.dy - svgSize / 2);
        final double scale = svgSize / pictureInfo.size.width;
        canvas.scale(scale, scale);

        final Paint tintPaint = Paint()
          ..colorFilter = const ColorFilter.mode(Colors.white, BlendMode.srcIn);
        canvas.saveLayer(
          Rect.fromLTWH(0, 0, pictureInfo.size.width, pictureInfo.size.height),
          tintPaint,
        );
        canvas.drawPicture(pictureInfo.picture);
        canvas.restore();
        canvas.restore();
      } catch (e) {
        debugPrint('Error drawing SVG in StandardMarker: $e');
        // Fallback
        paint.color = Colors.white;
        canvas.drawCircle(center, radius * 0.5, paint);
      }
    }

    final Path pointer = Path();
    pointer.moveTo(
      size / 2 - (6 * scaleFactor),
      centerY + radius - (2 * scaleFactor),
    );
    pointer.lineTo(
      size / 2 + (6 * scaleFactor),
      centerY + radius - (2 * scaleFactor),
    );
    pointer.lineTo(size / 2, centerY + radius + (8 * scaleFactor));
    pointer.close();

    paint.color = markerColor;
    paint.style = PaintingStyle.fill;
    canvas.drawPath(pointer, paint);

    final ui.Image finalImage = await pictureRecorder.endRecording().toImage(
      size.toInt(),
      (centerY + radius + (15 * scaleFactor)).toInt(),
    );
    final ByteData? byteData = await finalImage.toByteData(
      format: ui.ImageByteFormat.png,
    );
    return BitmapDescriptor.bytes(byteData!.buffer.asUint8List());
  }

  static Future<BitmapDescriptor> _createLabeledPinMarker({
    required String name,
    required Color primaryColor,
    required String iconAsset,
    required IconData fallbackIcon,
  }) async {
    const double width = 132;
    const double height = 136;
    const double circleRadius = 26;
    const double labelTop = 6;
    const double labelHorizontalPadding = 14;
    const double labelVerticalPadding = 8;

    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    final Paint paint = Paint();
    final double centerX = width / 2;

    final textPainter = TextPainter(
      text: TextSpan(
        text: name,
        style: const TextStyle(
          color: Colors.black87,
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    );
    textPainter.layout(maxWidth: width - 20);

    final double labelWidth = textPainter.width + (labelHorizontalPadding * 2);
    final double labelHeight = textPainter.height + (labelVerticalPadding * 2);
    final Rect labelRect = Rect.fromLTWH(
      (width - labelWidth) / 2,
      labelTop,
      labelWidth,
      labelHeight,
    );
    final double labelBottom = labelRect.bottom;

    paint.color = Colors.black.withValues(alpha: 0.18);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        labelRect.shift(const Offset(0, 1.5)),
        const Radius.circular(18),
      ),
      paint,
    );

    paint.color = Colors.white;
    canvas.drawRRect(
      RRect.fromRectAndRadius(labelRect, const Radius.circular(18)),
      paint,
    );

    final Path bubbleTail = Path()
      ..moveTo(centerX - 8, labelBottom - 1)
      ..lineTo(centerX + 8, labelBottom - 1)
      ..lineTo(centerX, labelBottom + 8)
      ..close();
    canvas.drawPath(bubbleTail, paint);

    textPainter.paint(
      canvas,
      Offset(
        labelRect.left + (labelRect.width - textPainter.width) / 2,
        labelRect.top + (labelRect.height - textPainter.height) / 2,
      ),
    );

    final double circleCenterY = labelBottom + 14 + circleRadius;
    final Offset circleCenter = Offset(centerX, circleCenterY);
    final double stemTopY = circleCenterY + circleRadius - 2;
    const double stemWidth = 10;
    const double stemHeight = 14;
    const double tipRadius = 4.5;

    final RRect outerStem = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(centerX, stemTopY + (stemHeight / 2)),
        width: stemWidth + 4,
        height: stemHeight + 4,
      ),
      const Radius.circular(8),
    );
    final RRect innerStem = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(centerX, stemTopY + (stemHeight / 2)),
        width: stemWidth,
        height: stemHeight,
      ),
      const Radius.circular(6),
    );

    final Offset tipCenter = Offset(
      centerX,
      stemTopY + stemHeight + tipRadius - 1,
    );

    paint
      ..style = PaintingStyle.fill
      ..color = Colors.white;
    canvas.drawRRect(outerStem, paint);
    canvas.drawCircle(tipCenter, tipRadius + 2, paint);

    paint.color = primaryColor;
    canvas.drawRRect(innerStem, paint);
    canvas.drawCircle(tipCenter, tipRadius, paint);

    paint.color = Colors.white;
    canvas.drawCircle(circleCenter, circleRadius + 3, paint);
    paint.color = primaryColor;
    canvas.drawCircle(circleCenter, circleRadius, paint);

    try {
      final String svgString = await rootBundle.loadString(iconAsset);
      final SvgStringLoader loader = SvgStringLoader(svgString);
      final PictureInfo pictureInfo = await vg.loadPicture(loader, null);
      const double iconSize = 28;
      final double iconScale =
          iconSize / math.max(pictureInfo.size.width, pictureInfo.size.height);
      final double renderedWidth = pictureInfo.size.width * iconScale;
      final double renderedHeight = pictureInfo.size.height * iconScale;

      canvas.save();
      canvas.translate(
        circleCenter.dx - renderedWidth / 2,
        circleCenter.dy - renderedHeight / 2,
      );
      canvas.scale(iconScale, iconScale);

      final Paint tintPaint = Paint()
        ..colorFilter = const ColorFilter.mode(Colors.white, BlendMode.srcIn);
      canvas.saveLayer(
        Rect.fromLTWH(0, 0, pictureInfo.size.width, pictureInfo.size.height),
        tintPaint,
      );
      canvas.drawPicture(pictureInfo.picture);
      canvas.restore();
      canvas.restore();
    } catch (e) {
      debugPrint('Error drawing pin marker SVG ($iconAsset): $e');
      final fallbackPainter = TextPainter(
        text: TextSpan(
          text: String.fromCharCode(fallbackIcon.codePoint),
          style: TextStyle(
            fontSize: 26,
            fontFamily: fallbackIcon.fontFamily,
            package: fallbackIcon.fontPackage,
            color: Colors.white,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      fallbackPainter.layout();
      fallbackPainter.paint(
        canvas,
        Offset(
          circleCenter.dx - (fallbackPainter.width / 2),
          circleCenter.dy - (fallbackPainter.height / 2),
        ),
      );
    }

    final ui.Image finalImage = await pictureRecorder.endRecording().toImage(
      width.toInt(),
      height.toInt(),
    );
    final ByteData? byteData = await finalImage.toByteData(
      format: ui.ImageByteFormat.png,
    );
    return BitmapDescriptor.bytes(byteData!.buffer.asUint8List());
  }

  static Future<BitmapDescriptor> _createIconPinMarker({
    required Color primaryColor,
    required String iconAsset,
    required IconData fallbackIcon,
  }) async {
    const double width = 66;
    const double height = 84;
    const double pinRadius = 20;
    const double circleCenterY = 27;
    const double tipY = 66;
    const double iconBubbleRadius = 13.8;
    const double shadowDotRadius = 3.4;

    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    final Paint paint = Paint();
    final double centerX = width / 2;
    final Offset pinCenter = Offset(centerX, circleCenterY);
    final Rect circleRect = Rect.fromCircle(
      center: pinCenter,
      radius: pinRadius,
    );

    final double leftAngle = 140 * math.pi / 180;
    final double rightAngle = 40 * math.pi / 180;
    final Offset leftJoin = Offset(
      centerX + (pinRadius * math.cos(leftAngle)),
      circleCenterY + (pinRadius * math.sin(leftAngle)),
    );
    final Offset rightJoin = Offset(
      centerX + (pinRadius * math.cos(rightAngle)),
      circleCenterY + (pinRadius * math.sin(rightAngle)),
    );

    final Path tailPath = Path()
      ..moveTo(leftJoin.dx, leftJoin.dy)
      ..quadraticBezierTo(centerX - 10, tipY - 9, centerX, tipY)
      ..quadraticBezierTo(centerX + 10, tipY - 9, rightJoin.dx, rightJoin.dy)
      ..close();

    final Path pinShape = Path()
      ..addOval(circleRect)
      ..addPath(tailPath, Offset.zero);

    // Soft shadow for map contrast.
    canvas.drawShadow(pinShape, Colors.black.withValues(alpha: 0.24), 5, true);

    paint.color = primaryColor;
    paint.style = PaintingStyle.fill;
    canvas.drawOval(circleRect, paint);
    canvas.drawPath(tailPath, paint);

    // Bottom subtle dot like the sample marker.
    final Offset shadowDotCenter = Offset(centerX, tipY + shadowDotRadius + 4);
    paint.color = primaryColor.withValues(alpha: 0.26);
    canvas.drawCircle(shadowDotCenter, shadowDotRadius + 3, paint);
    paint.color = primaryColor.withValues(alpha: 0.62);
    canvas.drawCircle(shadowDotCenter, shadowDotRadius, paint);

    // Icon bubble fully inside the marker's circular head.
    paint.color = Colors.white;
    canvas.drawCircle(pinCenter, iconBubbleRadius, paint);

    try {
      final String svgString = await rootBundle.loadString(iconAsset);
      final SvgStringLoader loader = SvgStringLoader(svgString);
      final PictureInfo pictureInfo = await vg.loadPicture(loader, null);
      const double iconSize = 17;
      final double iconScale =
          iconSize / math.max(pictureInfo.size.width, pictureInfo.size.height);
      final double renderedWidth = pictureInfo.size.width * iconScale;
      final double renderedHeight = pictureInfo.size.height * iconScale;

      canvas.save();
      canvas.translate(
        pinCenter.dx - renderedWidth / 2,
        pinCenter.dy - renderedHeight / 2,
      );
      canvas.scale(iconScale, iconScale);

      final Paint tintPaint = Paint()
        ..colorFilter = ColorFilter.mode(
          primaryColor.withValues(alpha: 0.92),
          BlendMode.srcIn,
        );
      canvas.saveLayer(
        Rect.fromLTWH(0, 0, pictureInfo.size.width, pictureInfo.size.height),
        tintPaint,
      );
      canvas.drawPicture(pictureInfo.picture);
      canvas.restore();
      canvas.restore();
    } catch (e) {
      debugPrint('Error drawing compact pin marker SVG ($iconAsset): $e');
      final fallbackPainter = TextPainter(
        text: TextSpan(
          text: String.fromCharCode(fallbackIcon.codePoint),
          style: TextStyle(
            fontSize: 22,
            fontFamily: fallbackIcon.fontFamily,
            package: fallbackIcon.fontPackage,
            color: primaryColor.withValues(alpha: 0.92),
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      fallbackPainter.layout();
      fallbackPainter.paint(
        canvas,
        Offset(
          pinCenter.dx - (fallbackPainter.width / 2),
          pinCenter.dy - (fallbackPainter.height / 2),
        ),
      );
    }

    final ui.Image finalImage = await pictureRecorder.endRecording().toImage(
      width.toInt(),
      height.toInt(),
    );
    final ByteData? byteData = await finalImage.toByteData(
      format: ui.ImageByteFormat.png,
    );
    return BitmapDescriptor.bytes(byteData!.buffer.asUint8List());
  }

  /// Create custom store/restaurant marker
  static Future<BitmapDescriptor> createStoreMarker({
    required String name,
    required Color primaryColor,
  }) async {
    return _createLabeledPinMarker(
      name: name,
      primaryColor: primaryColor,
      iconAsset: 'packages/grab_go_shared/lib/assets/icons/store.svg',
      fallbackIcon: Icons.storefront_rounded,
    );
  }

  static Future<ui.Image?> _loadNetworkImage(String url) async {
    try {
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final Uint8List bytes = response.bodyBytes;
        final Completer<ui.Image> completer = Completer();
        ui.decodeImageFromList(
          bytes,
          (ui.Image img) => completer.complete(img),
        );
        return await completer.future;
      }
    } catch (e) {
      debugPrint('Error loading marker image: $e');
    }
    return null;
  }

  /// Create a destination marker (Home/Pin) with house icon
  static Future<BitmapDescriptor> createDestinationMarker({
    required String name,
    required Color primaryColor,
  }) async {
    return _createLabeledPinMarker(
      name: name,
      primaryColor: primaryColor,
      iconAsset: 'packages/grab_go_shared/lib/assets/icons/home.svg',
      fallbackIcon: Icons.home_rounded,
    );
  }

  /// Compact no-label store pin (use marker infoWindow for tap labels).
  static Future<BitmapDescriptor> createStoreTapPinMarker({
    required Color primaryColor,
  }) async {
    return _createIconPinMarker(
      primaryColor: primaryColor,
      iconAsset: 'packages/grab_go_shared/lib/assets/icons/store.svg',
      fallbackIcon: Icons.storefront_rounded,
    );
  }

  /// Compact no-label home pin (use marker infoWindow for tap labels).
  static Future<BitmapDescriptor> createHomeTapPinMarker({
    required Color primaryColor,
  }) async {
    return _createIconPinMarker(
      primaryColor: primaryColor,
      iconAsset: 'packages/grab_go_shared/lib/assets/icons/home.svg',
      fallbackIcon: Icons.home_rounded,
    );
  }

  /// Compact no-label pin with custom icon.
  static Future<BitmapDescriptor> createTapPinMarker({
    required Color primaryColor,
    required String iconAsset,
    required IconData fallbackIcon,
  }) async {
    return _createIconPinMarker(
      primaryColor: primaryColor,
      iconAsset: iconAsset,
      fallbackIcon: fallbackIcon,
    );
  }
}
