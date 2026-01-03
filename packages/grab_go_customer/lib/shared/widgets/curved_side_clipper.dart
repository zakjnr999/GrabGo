import 'package:flutter/material.dart';

/// Custom clipper for creating curved left edge on side images
/// Used for promo banners where image is on the right side
class CurvedSideClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();

    // Start from top left with ultra-smooth curve
    path.moveTo(12, 0);

    // Top edge
    path.lineTo(size.width, 0);

    // Right edge
    path.lineTo(size.width, size.height);

    // Bottom edge
    path.lineTo(12, size.height);

    // Create ultra-smooth, flowing S-curve with no sharp edges
    path.cubicTo(
      6,
      size.height * 0.8, // First control point (very gentle)
      0,
      size.height * 0.6, // Second control point (minimal inward)
      0,
      size.height * 0.5, // Middle point (subtle depth)
    );

    path.cubicTo(
      0,
      size.height * 0.4, // Third control point
      6,
      size.height * 0.2, // Fourth control point (very gentle outward)
      12,
      0, // End point at top
    );

    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
