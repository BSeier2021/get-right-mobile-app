/// Strips known placeholder / dev image hosts so [Image.network] never tries to resolve them.
abstract final class ImageUrlSanitizer {
  static const String _fallbackUnsplashThumb = 'https://images.unsplash.com/photo-1534438327276-14e5300c3a48?w=800&h=400&fit=crop';

  /// Public URL safe to pass to [Image.network], or `null` to mean "use UI fallback".
  static String? asHttpUrlOrNull(String? v) {
    final s = v?.trim() ?? '';
    if (s.isEmpty || s == 'null') return null;
    final lower = s.toLowerCase();
    if (!lower.startsWith('http://') && !lower.startsWith('https://')) return null;

    final uri = Uri.tryParse(s);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) return null;

    final host = uri.host.toLowerCase();
    if (host == 'cdn.example.com') return null;
    if (host == 'example.com' || host.endsWith('.example.com')) return null;
    if (lower.contains('example.com/seed')) return null;

    return s;
  }

  /// Non-empty URL for widgets that need a string; replaces bad values with a real image.
  static String asHttpUrlOrFallback(String? v, {String? fallback}) {
    return asHttpUrlOrNull(v) ?? (fallback ?? _fallbackUnsplashThumb);
  }
}
