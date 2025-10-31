import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class SvgIcon extends StatelessWidget {
  final String svgImage;
  final double? width;
  final double? height;
  final Color? color;
  final double? padding;

  const SvgIcon({super.key, required this.svgImage, this.width, this.height, this.color, this.padding});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(padding ?? 0),
      child: SvgPicture.asset(
        svgImage,
        package: 'grab_go_shared',
        width: width,
        height: height,
        colorFilter: color != null ? ColorFilter.mode(color!, BlendMode.srcIn) : null,
      ),
    );
  }
}
