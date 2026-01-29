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
  // ============================================================
  // ORDER PIN MARKER - Modern floating card style with gradient
  // ============================================================

  /// Create order pin marker for available orders map
  /// [isHighlighted] - true for closest/best ETA orders (accent color)
  /// [itemCount] - number of items in the order
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

    // Colors
    final Color mainColor = isHighlighted ? highlightColor : primaryColor;
    final Color gradientStart = isHighlighted ? highlightColor : const Color(0xFF6B7280); // Modern grey
    final Color gradientEnd = isHighlighted ? highlightColor.withOpacity(0.8) : const Color(0xFF4B5563);

    // Card position (centered)
    final double cardX = (width - cardWidth) / 2;
    const double cardY = 4.0;
    final RRect cardRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(cardX, cardY, cardWidth, cardHeight),
      Radius.circular(cornerRadius),
    );

    // 2. Draw card with solid color (no gradient)
    paint.color = isHighlighted ? highlightColor : primaryColor;
    canvas.drawRRect(cardRect, paint);

    // 4. Draw store SVG icon
    final iconCenter = Offset(width / 2, cardY + cardHeight / 2);

    try {
      final String svgString = await rootBundle.loadString('packages/grab_go_shared/lib/assets/icons/store.svg');
      final SvgStringLoader loader = SvgStringLoader(svgString);
      final PictureInfo pictureInfo = await vg.loadPicture(loader, null);

      const double svgSize = 50.0;

      canvas.save();
      canvas.translate(iconCenter.dx - svgSize / 2, iconCenter.dy - svgSize / 2);
      final double scale = svgSize / pictureInfo.size.width;
      canvas.scale(scale, scale);

      final Paint tintPaint = Paint()..colorFilter = const ColorFilter.mode(Colors.white, BlendMode.srcIn);
      canvas.saveLayer(Rect.fromLTWH(0, 0, pictureInfo.size.width, pictureInfo.size.height), tintPaint);
      canvas.drawPicture(pictureInfo.picture);
      canvas.restore();
      canvas.restore();
    } catch (e) {
      debugPrint('Error drawing store SVG: $e');
      // Fallback to Material icon
      final icon = Icons.local_shipping_rounded;
      final iconPainter = TextPainter(
        text: TextSpan(
          text: String.fromCharCode(icon.codePoint),
          style: TextStyle(fontSize: 44, fontFamily: icon.fontFamily, package: icon.fontPackage, color: Colors.white),
        ),
        textDirection: TextDirection.ltr,
      );
      iconPainter.layout();
      iconPainter.paint(canvas, Offset(iconCenter.dx - iconPainter.width / 2, iconCenter.dy - iconPainter.height / 2));
    }

    // 5. Draw elegant pointer (curved triangle)
    final pointerTop = cardY + cardHeight - 2;
    final Path pointer = Path();
    pointer.moveTo(width / 2 - 14, pointerTop);
    pointer.quadraticBezierTo(width / 2 - 8, pointerTop + 8, width / 2, pointerTop + 22);
    pointer.quadraticBezierTo(width / 2 + 8, pointerTop + 8, width / 2 + 14, pointerTop);
    pointer.close();
    paint.color = isHighlighted ? highlightColor : primaryColor;
    canvas.drawPath(pointer, paint);

    // 6. Draw item count badge (modern pill shape)
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

      // Badge background with solid color
      paint.color = isHighlighted
          ? const Color(0xFF10B981) // Green
          : const Color(0xFFEF4444); // Red
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(badgeX, badgeY, badgeWidth, badgeHeight), const Radius.circular(9)),
        paint,
      );

      // Badge text
      badgePainter.paint(
        canvas,
        Offset(badgeX + (badgeWidth - badgePainter.width) / 2, badgeY + (badgeHeight - badgePainter.height) / 2),
      );
    }

    // 7. Draw highlight ring for closest order
    if (isHighlighted) {
      paint.color = highlightColor.withOpacity(0.3);
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
    final ui.Image finalImage = await pictureRecorder.endRecording().toImage(width.toInt(), height.toInt());
    final ByteData? byteData = await finalImage.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.fromBytes(byteData!.buffer.asUint8List());
  }

  // ============================================================
  // RIDER LOCATION MARKER - Modern pulsing navigation style
  // ============================================================

  /// Create rider location marker with simple clean circular design
  static Future<BitmapDescriptor> createRiderLocationMarker({
    required Color primaryColor,
  }) async {
    const double size = 60;
    const double outerRing = 28;
    const double innerDot = 16;

    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    final Paint paint = Paint();

    final Offset center = Offset(size / 2, size / 2);

    // 1. Outer subtle ring (semi-transparent)
    paint.color = primaryColor.withOpacity(0.2);
    canvas.drawCircle(center, outerRing, paint);

    // 2. Middle ring (more opaque)
    paint.color = primaryColor.withOpacity(0.4);
    canvas.drawCircle(center, outerRing * 0.7, paint);

    // 3. Inner solid dot
    paint.color = primaryColor;
    canvas.drawCircle(center, innerDot, paint);

    // 4. White border around inner dot
    paint.color = Colors.white;
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 3;
    canvas.drawCircle(center, innerDot, paint);
    paint.style = PaintingStyle.fill;

    // Convert to Bitmap
    final ui.Image finalImage = await pictureRecorder.endRecording().toImage(size.toInt(), size.toInt());
    final ByteData? byteData = await finalImage.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.fromBytes(byteData!.buffer.asUint8List());
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
        style: const TextStyle(color: Colors.black, fontSize: 28, fontWeight: FontWeight.w600),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();

    final double labelWidth = textPainter.width + 40;
    final double labelHeight = textPainter.height + 20;
    final Rect labelRect = Rect.fromLTWH((width - labelWidth) / 2, 0, labelWidth, labelHeight);

    // Draw bubble background (White with slight shadow)
    paint.color = Colors.white;
    canvas.drawRRect(RRect.fromRectAndRadius(labelRect, const Radius.circular(30)), paint);

    // Draw bubble tail (small triangle pointing down)
    final Path bubbleTail = Path();
    bubbleTail.moveTo(width / 2 - 10, labelHeight);
    bubbleTail.lineTo(width / 2 + 10, labelHeight);
    bubbleTail.lineTo(width / 2, labelHeight + 12);
    bubbleTail.close();
    canvas.drawPath(bubbleTail, paint);

    // Draw the name text
    textPainter.paint(canvas, Offset((width - textPainter.width) / 2, (labelHeight - textPainter.height) / 2));

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
    final Rect avatarRect = Rect.fromCircle(center: avatarCenter, radius: avatarRadius);
    canvas.save();
    canvas.clipPath(Path()..addOval(avatarRect));

    // Try to load image if available
    ui.Image? avatarImage;
    if (imageUrl != null && imageUrl.isNotEmpty) {
      avatarImage = await _loadNetworkImage(imageUrl);
    }

    if (avatarImage != null) {
      paintImage(canvas: canvas, rect: avatarRect, image: avatarImage, fit: BoxFit.cover);
    } else {
      // Draw initials if no image
      final initialsPainter = TextPainter(
        text: TextSpan(
          text: name.isNotEmpty ? name[0].toUpperCase() : 'R',
          style: const TextStyle(color: Colors.white, fontSize: 50, fontWeight: FontWeight.bold),
        ),
        textDirection: TextDirection.ltr,
      );
      initialsPainter.layout();
      initialsPainter.paint(
        canvas,
        Offset(avatarCenter.dx - initialsPainter.width / 2, avatarCenter.dy - initialsPainter.height / 2),
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
    final ui.Image finalImage = await pictureRecorder.endRecording().toImage(width.toInt(), height.toInt());
    final ByteData? byteData = await finalImage.toByteData(format: ui.ImageByteFormat.png);
    final Uint8List uint8list = byteData!.buffer.asUint8List();

    return BitmapDescriptor.fromBytes(uint8list);
  }

  /// Create custom store/restaurant marker
  static Future<BitmapDescriptor> createStoreMarker({required String name, required Color primaryColor}) async {
    const double width = 200;
    const double height = 230;
    const double radius = 60;

    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    final Paint paint = Paint();

    // 1. Label Bubble
    final textPainter = TextPainter(
      text: TextSpan(
        text: name,
        style: const TextStyle(color: Colors.black, fontSize: 28, fontWeight: FontWeight.w600),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();

    final double labelWidth = textPainter.width + 40;
    final double labelHeight = textPainter.height + 20;
    final Rect labelRect = Rect.fromLTWH((width - labelWidth) / 2, 0, labelWidth, labelHeight);

    paint.color = Colors.white;
    canvas.drawRRect(RRect.fromRectAndRadius(labelRect, const Radius.circular(30)), paint);

    final Path bubbleTail = Path();
    bubbleTail.moveTo(width / 2 - 10, labelHeight);
    bubbleTail.lineTo(width / 2 + 10, labelHeight);
    bubbleTail.lineTo(width / 2, labelHeight + 12);
    bubbleTail.close();
    canvas.drawPath(bubbleTail, paint);

    textPainter.paint(canvas, Offset((width - textPainter.width) / 2, (labelHeight - textPainter.height) / 2));

    // 2. Icon Circle
    final double centerY = labelHeight + 15 + radius;
    final Offset center = Offset(width / 2, centerY);

    paint.color = Colors.white;
    canvas.drawCircle(center, radius + 3, paint);

    paint.color = primaryColor;
    canvas.drawCircle(center, radius, paint);

    // Draw Store SVG
    try {
      final String svgString = await rootBundle.loadString('packages/grab_go_shared/lib/assets/icons/store.svg');
      final SvgStringLoader loader = SvgStringLoader(svgString);
      final PictureInfo pictureInfo = await vg.loadPicture(loader, null);

      // Calculate SVG size (60% of the circle)
      const double svgSize = radius * 1.2;

      canvas.save();
      // Move to center and scale
      canvas.translate(center.dx - svgSize / 2, center.dy - svgSize / 2);
      final double scale = svgSize / pictureInfo.size.width;
      canvas.scale(scale, scale);

      // Apply white color filter to the SVG
      final Paint tintPaint = Paint()..colorFilter = const ColorFilter.mode(Colors.white, BlendMode.srcIn);
      canvas.saveLayer(Rect.fromLTWH(0, 0, pictureInfo.size.width, pictureInfo.size.height), tintPaint);
      canvas.drawPicture(pictureInfo.picture);
      canvas.restore(); // Pop the saveLayer

      canvas.restore(); // Pop the translation/scale
    } catch (e) {
      debugPrint('Error drawing Store SVG: $e');
      // Fallback to Icon if SVG fails
      final icon = Icons.storefront_rounded;
      final iconPainter = TextPainter(
        text: TextSpan(
          text: String.fromCharCode(icon.codePoint),
          style: TextStyle(fontSize: 50, fontFamily: icon.fontFamily, package: icon.fontPackage, color: Colors.white),
        ),
        textDirection: TextDirection.ltr,
      );
      iconPainter.layout();
      iconPainter.paint(canvas, Offset(center.dx - iconPainter.width / 2, center.dy - iconPainter.height / 2));
    }

    // 3. Pointer
    final Path bottomPointer = Path();
    bottomPointer.moveTo(width / 2 - 12, centerY + radius + 2);
    bottomPointer.lineTo(width / 2 + 12, centerY + radius + 2);
    bottomPointer.lineTo(width / 2, centerY + radius + 15);
    bottomPointer.close();
    paint.color = Colors.white;
    canvas.drawPath(bottomPointer, paint);

    final ui.Image finalImage = await pictureRecorder.endRecording().toImage(width.toInt(), height.toInt());
    final ByteData? byteData = await finalImage.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.fromBytes(byteData!.buffer.asUint8List());
  }

  static Future<ui.Image?> _loadNetworkImage(String url) async {
    try {
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final Uint8List bytes = response.bodyBytes;
        final Completer<ui.Image> completer = Completer();
        ui.decodeImageFromList(bytes, (ui.Image img) => completer.complete(img));
        return await completer.future;
      }
    } catch (e) {
      debugPrint('Error loading marker image: $e');
    }
    return null;
  }

  /// Create a destination marker (Home/Pin) with house icon
  static Future<BitmapDescriptor> createDestinationMarker({required String name, required Color primaryColor}) async {
    const double width = 200;
    const double height = 230;
    const double radius = 60;

    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    final Paint paint = Paint();

    // 1. Label Bubble
    final textPainter = TextPainter(
      text: TextSpan(
        text: name,
        style: const TextStyle(color: Colors.black, fontSize: 28, fontWeight: FontWeight.w600),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();

    final double labelWidth = textPainter.width + 40;
    final double labelHeight = textPainter.height + 20;
    final Rect labelRect = Rect.fromLTWH((width - labelWidth) / 2, 0, labelWidth, labelHeight);

    paint.color = Colors.white;
    canvas.drawRRect(RRect.fromRectAndRadius(labelRect, const Radius.circular(30)), paint);

    final Path bubbleTail = Path();
    bubbleTail.moveTo(width / 2 - 10, labelHeight);
    bubbleTail.lineTo(width / 2 + 10, labelHeight);
    bubbleTail.lineTo(width / 2, labelHeight + 12);
    bubbleTail.close();
    canvas.drawPath(bubbleTail, paint);

    textPainter.paint(canvas, Offset((width - textPainter.width) / 2, (labelHeight - textPainter.height) / 2));

    // 2. Icon Circle
    final double centerY = labelHeight + 15 + radius;
    final Offset center = Offset(width / 2, centerY);

    paint.color = Colors.white;
    canvas.drawCircle(center, radius + 3, paint);

    paint.color = primaryColor;
    canvas.drawCircle(center, radius, paint);

    // Draw Home SVG
    try {
      final String svgString = await rootBundle.loadString('packages/grab_go_shared/lib/assets/icons/home.svg');
      final SvgStringLoader loader = SvgStringLoader(svgString);
      final PictureInfo pictureInfo = await vg.loadPicture(loader, null);

      // Calculate SVG size (60% of the circle)
      const double svgSize = radius * 1.2;

      canvas.save();
      // Move to center and scale
      canvas.translate(center.dx - svgSize / 2, center.dy - svgSize / 2);
      final double scale = svgSize / pictureInfo.size.width;
      canvas.scale(scale, scale);

      // Apply white color filter to the SVG
      final Paint tintPaint = Paint()..colorFilter = const ColorFilter.mode(Colors.white, BlendMode.srcIn);
      canvas.saveLayer(Rect.fromLTWH(0, 0, pictureInfo.size.width, pictureInfo.size.height), tintPaint);
      canvas.drawPicture(pictureInfo.picture);
      canvas.restore(); // Pop the saveLayer

      canvas.restore(); // Pop the translation/scale
    } catch (e) {
      debugPrint('Error drawing Home SVG: $e');
      // Fallback to Icon if SVG fails
      final icon = Icons.home_rounded;
      final iconPainter = TextPainter(
        text: TextSpan(
          text: String.fromCharCode(icon.codePoint),
          style: TextStyle(fontSize: 60, fontFamily: icon.fontFamily, package: icon.fontPackage, color: Colors.white),
        ),
        textDirection: TextDirection.ltr,
      );
      iconPainter.layout();
      iconPainter.paint(canvas, Offset(center.dx - iconPainter.width / 2, center.dy - iconPainter.height / 2));
    }

    // 3. Pointer
    final Path bottomPointer = Path();
    bottomPointer.moveTo(width / 2 - 12, centerY + radius + 2);
    bottomPointer.lineTo(width / 2 + 12, centerY + radius + 2);
    bottomPointer.lineTo(width / 2, centerY + radius + 15);
    bottomPointer.close();
    paint.color = Colors.white;
    canvas.drawPath(bottomPointer, paint);

    final ui.Image finalImage = await pictureRecorder.endRecording().toImage(width.toInt(), height.toInt());
    final ByteData? byteData = await finalImage.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.fromBytes(byteData!.buffer.asUint8List());
  }
}
