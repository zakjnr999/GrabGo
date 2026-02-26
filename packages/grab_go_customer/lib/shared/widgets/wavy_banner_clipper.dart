import 'package:flutter/material.dart';

/// Custom clipper that creates a banner with wavy/curved top and bottom edges
/// and rounded left and right sides
class WavyBannerClipper extends CustomClipper<Path> {
  final double waveHeight;
  final int waveCount;
  final double cornerRadius;

  WavyBannerClipper({this.waveHeight = 8, this.waveCount = 8, this.cornerRadius = 16});

  @override
  Path getClip(Size size) {
    final path = Path();
    final waveWidth = size.width / waveCount;

    // Start from top-left corner (after the curve)
    path.moveTo(0, waveHeight + cornerRadius);

    // Top-left rounded corner
    path.quadraticBezierTo(0, waveHeight, cornerRadius, waveHeight);

    // Create wavy top edge
    for (int i = 0; i < waveCount; i++) {
      final x2 = waveWidth * (i + 0.5);
      final x3 = waveWidth * (i + 1);

      if (i == 0) {
        // First wave starts after the corner
        path.quadraticBezierTo(x2, 0, x3, waveHeight);
      } else if (i == waveCount - 1) {
        // Last wave ends before the corner
        path.quadraticBezierTo(x2, 0, size.width - cornerRadius, waveHeight);
      } else {
        path.quadraticBezierTo(x2, 0, x3, waveHeight);
      }
    }

    // Top-right rounded corner
    path.quadraticBezierTo(size.width, waveHeight, size.width, waveHeight + cornerRadius);

    // Right edge
    path.lineTo(size.width, size.height - waveHeight - cornerRadius);

    // Bottom-right rounded corner
    path.quadraticBezierTo(size.width, size.height - waveHeight, size.width - cornerRadius, size.height - waveHeight);

    // Create wavy bottom edge (going backwards)
    for (int i = waveCount; i > 0; i--) {
      final x2 = waveWidth * (i - 0.5);
      final x3 = waveWidth * (i - 1);

      if (i == waveCount) {
        // First wave (from right) starts after corner
        path.quadraticBezierTo(x2, size.height, x3, size.height - waveHeight);
      } else if (i == 1) {
        // Last wave ends before the corner
        path.quadraticBezierTo(x2, size.height, cornerRadius, size.height - waveHeight);
      } else {
        path.quadraticBezierTo(x2, size.height, x3, size.height - waveHeight);
      }
    }

    // Bottom-left rounded corner
    path.quadraticBezierTo(0, size.height - waveHeight, 0, size.height - waveHeight - cornerRadius);

    // Left edge back to start
    path.lineTo(0, waveHeight + cornerRadius);

    path.close();
    return path;
  }

  @override
  bool shouldReclip(WavyBannerClipper oldClipper) {
    return oldClipper.waveHeight != waveHeight ||
        oldClipper.waveCount != waveCount ||
        oldClipper.cornerRadius != cornerRadius;
  }
}
