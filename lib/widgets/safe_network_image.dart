import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get_right/utils/image_url_sanitizer.dart';

/// Remembers URLs that failed to load so we do not retry them in the same session.
abstract final class FailedNetworkImageUrls {
  static final Set<String> _failed = {};

  static bool contains(String url) => _failed.contains(url);

  static void markFailed(String url) => _failed.add(url);
}

/// Network image with sanitized URLs, a session-scoped failure cache, and a safe fallback.
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
      return _sizedFallback();
    }

    return CachedNetworkImage(
      imageUrl: resolved,
      width: width,
      height: height,
      fit: fit,
      fadeInDuration: Duration.zero,
      fadeOutDuration: Duration.zero,
      placeholder: (_, __) => _sizedFallback(),
      errorWidget: (_, __, ___) {
        FailedNetworkImageUrls.markFailed(resolved);
        return _sizedFallback();
      },
    );
  }

  Widget _sizedFallback() {
    if (width != null || height != null) {
      return SizedBox(width: width, height: height, child: fallback);
    }
    return fallback;
  }
}
