import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get_right/utils/image_url_sanitizer.dart';
import 'package:get_right/widgets/safe_network_image.dart';

/// Circular avatar that loads a network URL without retrying known-bad URLs.
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
    final url = ImageUrlSanitizer.resolveMediaUrl(imageUrl);
    final bg = backgroundColor ?? Colors.grey.shade300;
    final d = radius * 2;

    if (url == null || url.isEmpty || FailedNetworkImageUrls.contains(url)) {
      return CircleAvatar(radius: radius, backgroundColor: bg, child: fallback);
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: bg,
      child: ClipOval(
        child: SizedBox(
          width: d,
          height: d,
          child: CachedNetworkImage(
            imageUrl: url,
            width: d,
            height: d,
            fit: BoxFit.cover,
            fadeInDuration: Duration.zero,
            fadeOutDuration: Duration.zero,
            placeholder: (_, __) => fallback,
            errorWidget: (_, __, ___) {
              FailedNetworkImageUrls.markFailed(url);
              return fallback;
            },
          ),
        ),
      ),
    );
  }
}
