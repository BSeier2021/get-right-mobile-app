import 'package:flutter/material.dart';

/// Renders bundled GR catalog PNGs without showing black square corners.
class GrCatalogImage extends StatelessWidget {
  const GrCatalogImage({
    super.key,
    required this.assetPath,
    this.fit = BoxFit.contain,
    this.borderRadius = 14,
    this.backgroundColor = const Color(0xFFFFFFFF),
    this.scale = 1.04,
    this.width,
    this.height,
  });

  final String assetPath;
  final BoxFit fit;
  final double borderRadius;
  final Color backgroundColor;
  final double scale;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: ColoredBox(
        color: backgroundColor,
        child: Transform.scale(
          scale: scale,
          child: Image.asset(
            assetPath,
            fit: fit,
            width: width,
            height: height,
            errorBuilder: (_, __, ___) => Icon(Icons.fitness_center, color: Colors.grey.shade500, size: (width ?? height ?? 32) * 0.55),
          ),
        ),
      ),
    );
  }
}
