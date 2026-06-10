import 'package:flutter/material.dart';
import 'package:get_right/utils/image_url_sanitizer.dart';

/// Remembers URLs that failed to load so we do not retry them in the same session.
abstract final class FailedNetworkImageUrls {
  static final Set<String> _failed = {};

  static bool contains(String url) => _failed.contains(url);

  static void markFailed(String url) => _failed.add(url);
}

/// Network image with sanitized URLs and a session-scoped failure cache.
class SafeNetworkImage extends StatelessWidget {
  const SafeNetworkImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    required this.fallback,
  });

  final String? url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget fallback;

  @override
  Widget build(BuildContext context) {
    final resolved = ImageUrlSanitizer.resolveMediaUrl(url);
    if (resolved == null || FailedNetworkImageUrls.contains(resolved)) {
      return fallback;
    }

    return Image.network(
      resolved,
      width: width,
      height: height,
      fit: fit,
      gaplessPlayback: true,
      errorBuilder: (_, __, ___) {
        FailedNetworkImageUrls.markFailed(resolved);
        return fallback;
      },
    );
  }
}
