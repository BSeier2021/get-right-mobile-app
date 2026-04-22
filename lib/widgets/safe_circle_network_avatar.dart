import 'package:flutter/material.dart';
import 'package:get_right/utils/image_url_sanitizer.dart';

/// Circular avatar that loads a network URL without throwing on 404 / decode errors.
/// Prefer this over [CircleAvatar] + [NetworkImage], which still reports failures to the image service.
class SafeCircleNetworkAvatar extends StatelessWidget {
  const SafeCircleNetworkAvatar({
    super.key,
    required this.imageUrl,
    this.radius = 16,
    this.backgroundColor,
    required this.fallback,
  });

  final String? imageUrl;
  final double radius;
  final Color? backgroundColor;
  final Widget fallback;

  @override
  Widget build(BuildContext context) {
    final url = ImageUrlSanitizer.asHttpUrlOrNull(imageUrl);
    final bg = backgroundColor ?? Colors.grey.shade300;
    final d = radius * 2;

    if (url == null || url.isEmpty) {
      return CircleAvatar(radius: radius, backgroundColor: bg, child: fallback);
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: bg,
      child: ClipOval(
        child: SizedBox(
          width: d,
          height: d,
          child: Image.network(
            url,
            width: d,
            height: d,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            errorBuilder: (_, __, ___) => fallback,
          ),
        ),
      ),
    );
  }
}
