import 'package:get_right/app_url.dart';
import 'package:get_right/utils/feed_post_mapper.dart';
import 'package:get_right/utils/image_url_sanitizer.dart';

/// Normalize feed video URLs (absolute http(s) or join with API base path).
String? resolveFeedMediaUrl(String? raw) {
  final input = raw?.trim();
  if (input == null || input.isEmpty) return null;
  final absolute = ImageUrlSanitizer.asHttpUrlOrNull(input);
  if (absolute != null) return absolute;
  if (input.startsWith('/')) {
    final base = Uri.parse(AppUrl.baseUrl);
    return '${base.scheme}://${base.authority}$input';
  }
  return null;
}

/// Resolves the URL [FeedVerticalReels] / [video_player] should open.
String? playbackUrlForFeedPost(Map<String, dynamic> post) {
  final raw =
      firstNonEmptyUrlString(post['videoUrl']) ??
      firstNonEmptyUrlString(post['playbackUrl']) ??
      firstNonEmptyUrlString(post['hlsUrl']) ??
      firstNonEmptyUrlString(post['streamUrl']);
  return resolveFeedMediaUrl(raw);
}

/// Image-only post (e.g. multipart `images[]`) — show full-screen photo, not video player.
bool feedPostIsPhotoOnly(Map<String, dynamic> post) {
  if (post['isVideo'] == true) return false;
  if (post['isVideo'] == false) {
    return feedPostDisplayImageUrl(post) != null;
  }
  if (playbackUrlForFeedPost(post) != null) return false;
  return feedPostDisplayImageUrl(post) != null;
}

/// All display URLs for a photo post (`imageUrls` from API `images[]`, else single thumbnail).
List<String> feedPostImageUrls(Map<String, dynamic> post) {
  final raw = post['imageUrls'];
  if (raw is List) {
    final out = <String>[];
    for (final item in raw) {
      final resolved = ImageUrlSanitizer.asHttpUrlOrNull(item?.toString());
      if (resolved != null) out.add(resolved);
    }
    if (out.isNotEmpty) return out;
  }
  final single = feedPostDisplayImageUrl(post);
  return single != null ? [single] : const [];
}

/// Thumbnail / first image URL for grid and photo reel backdrop.
String? feedPostDisplayImageUrl(Map<String, dynamic> post) {
  final urls = feedPostImageUrls(post);
  if (urls.isNotEmpty) return urls.first;
  return ImageUrlSanitizer.asHttpUrlOrNull((post['thumbnail'] ?? '').toString()) ??
      ImageUrlSanitizer.asHttpUrlOrNull((post['imageUrl'] ?? '').toString());
}
