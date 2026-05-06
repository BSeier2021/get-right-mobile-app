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
