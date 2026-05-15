/// Maps API feed documents to the UI map shape used by [FeedScreen] and [FeedVerticalReels].

bool coerceFeedApiBool(dynamic v) {
  if (v == true) return true;
  if (v == false) return false;
  if (v is String) {
    final s = v.trim().toLowerCase();
    return s == 'true' || s == '1' || s == 'yes';
  }
  if (v is num) return v != 0;
  return false;
}

/// List API often omits `savedByMe`; merge IDs the user saved locally (same session / device).
void mergePersistedSaveStateOnFeedPosts(List<Map<String, dynamic>> posts, Set<String> savedPostIds) {
  if (savedPostIds.isEmpty) return;
  for (final post in posts) {
    if (post['isSaved'] == true) continue;
    final id = (post['id'] ?? '').toString();
    if (savedPostIds.contains(id)) {
      post['isSaved'] = true;
    }
  }
}

/// Returns null if string is null or empty after trim.
String? firstNonEmptyUrlString(dynamic v) {
  final s = v?.toString().trim();
  return (s != null && s.isNotEmpty) ? s : null;
}

/// Resolves playback URL from various backend shapes (HLS or progressive).
String? extractFeedVideoUrl(Map<String, dynamic> m, Map<String, dynamic> video) {
  const videoKeys = ['playbackUrl', 'hlsUrl', 'manifestUrl', 'streamUrl', 'm3u8Url', 'url', 'src', 'fileUrl', 'videoUrl', 'link'];
  for (final k in videoKeys) {
    final fromVideo = firstNonEmptyUrlString(video[k]);
    if (fromVideo != null) return fromVideo;
  }
  if (video['hls'] is Map) {
    final hls = Map<String, dynamic>.from(video['hls'] as Map);
    for (final k in videoKeys) {
      final s = firstNonEmptyUrlString(hls[k]);
      if (s != null) return s;
    }
  }
  for (final k in ['videoUrl', 'playbackUrl', 'hlsUrl', 'streamUrl']) {
    final s = firstNonEmptyUrlString(m[k]);
    if (s != null) return s;
  }
  return null;
}

Map<String, dynamic> _metadataMapFromFeed(Map<String, dynamic> m, Map<String, dynamic> video) {
  if (video['metadata'] is Map) {
    return Map<String, dynamic>.from(video['metadata'] as Map);
  }
  if (m['metadata'] is Map) {
    return Map<String, dynamic>.from(m['metadata'] as Map);
  }
  return <String, dynamic>{};
}

/// Parses API `metadata.aspectRatio` (`"4:5"`, `"9:16"`, `"1.778"`) to width/height as a single number (w/h).
double? parseFeedMetadataAspectRatio(dynamic raw) {
  if (raw == null) return null;
  if (raw is num && raw > 0) {
    final n = raw.toDouble();
    if (!n.isNaN) return n;
    return null;
  }
  final s = raw.toString().trim();
  if (s.isEmpty) return null;
  final colon = RegExp(r'\s*[:/]\s*').firstMatch(s);
  if (colon != null) {
    final a = double.tryParse(s.substring(0, colon.start));
    final b = double.tryParse(s.substring(colon.end));
    if (a != null && b != null && b > 0) return a / b;
  }
  final single = double.tryParse(s);
  if (single != null && single > 0 && !single.isNaN) return single;
  return null;
}

/// One feed item from list or detail APIs (`data.feeds[]` / `data.feed`).
Map<String, dynamic> mapApiFeedDocumentToUiPost(
  dynamic raw, {
  bool likedByMe = false,
  bool savedByMe = false,
}) {
  final m = (raw is Map) ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
  final creator = (m['creator'] is Map) ? Map<String, dynamic>.from(m['creator']) : <String, dynamic>{};
  final profile = (creator['profile'] is Map) ? Map<String, dynamic>.from(creator['profile']) : <String, dynamic>{};
  final profilePicture = (profile['profilePicture'] is Map) ? Map<String, dynamic>.from(profile['profilePicture']) : <String, dynamic>{};
  final category = (m['category'] is Map) ? Map<String, dynamic>.from(m['category']) : <String, dynamic>{};
  final video = (m['video'] is Map) ? Map<String, dynamic>.from(m['video']) : <String, dynamic>{};

  final tagsRaw = (m['tags'] is List) ? List.from(m['tags']) : const [];
  final tags = tagsRaw.map((e) => e.toString()).where((t) => t.trim().isNotEmpty).map((t) => t.startsWith('#') ? t : '#$t').toList();

  final fullName = (profile['fullName'] ?? '').toString().trim();
  final initials = fullName.isEmpty
      ? 'U'
      : fullName.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).take(2).map((p) => p[0].toUpperCase()).join();

  final meta = _metadataMapFromFeed(m, video);

  // Prefer display / aspectRatio for how the reel is framed; encoded width×height is often the transcode size (e.g. 16:9) not the crop.
  final rawDisplayW = meta['displayWidth'];
  final rawDisplayH = meta['displayHeight'];
  final rawEncW = meta['width'];
  final rawEncH = meta['height'];

  double? displayW;
  double? displayH;
  if (rawDisplayW is num && rawDisplayH is num) {
    final dw = rawDisplayW.toDouble();
    final dh = rawDisplayH.toDouble();
    if (dw > 0 && dh > 0) {
      displayW = dw;
      displayH = dh;
    }
  }

  double? encW;
  double? encH;
  if (rawEncW is num && rawEncH is num) {
    final ew = rawEncW.toDouble();
    final eh = rawEncH.toDouble();
    if (ew > 0 && eh > 0) {
      encW = ew;
      encH = eh;
    }
  }

  final aspectFromMeta = parseFeedMetadataAspectRatio(meta['aspectRatio']);

  double? videoAspectRatio;
  if (aspectFromMeta != null) {
    videoAspectRatio = aspectFromMeta;
  } else if (displayW != null && displayH != null) {
    videoAspectRatio = displayW / displayH;
  } else if (encW != null && encH != null) {
    videoAspectRatio = encW / encH;
  }

  double? frameW;
  double? frameH;
  if (displayW != null && displayH != null) {
    frameW = displayW;
    frameH = displayH;
  } else if (encW != null && encH != null && aspectFromMeta == null) {
    frameW = encW;
    frameH = encH;
  }

  double? durationSeconds = (m['duration'] is num) ? (m['duration'] as num).toDouble() : (meta['duration'] is num ? (meta['duration'] as num).toDouble() : null);
  final durationLabel = durationSeconds == null
      ? null
      : durationSeconds >= 60
      ? '${(durationSeconds ~/ 60)}:${((durationSeconds % 60).round()).toString().padLeft(2, '0')}'
      : durationSeconds >= 10
      ? '${durationSeconds.toStringAsFixed(0)}s'
      : '${durationSeconds.toStringAsFixed(1)}s';

  final resolvedVideoUrl = extractFeedVideoUrl(m, video) ?? '';
  final thumb =
      firstNonEmptyUrlString(video['thumbnail']) ?? firstNonEmptyUrlString(video['poster']) ?? firstNonEmptyUrlString(m['thumbnail']) ?? '';

  final viewer = (m['viewer'] is Map) ? Map<String, dynamic>.from(m['viewer'] as Map) : <String, dynamic>{};

  final liked =
      coerceFeedApiBool(m['likedByMe']) ||
      coerceFeedApiBool(m['isLikedByMe']) ||
      coerceFeedApiBool(m['isLiked']) ||
      coerceFeedApiBool(m['liked']) ||
      coerceFeedApiBool(viewer['likedByMe']) ||
      likedByMe;
  final saved =
      coerceFeedApiBool(m['savedByMe']) ||
      coerceFeedApiBool(m['isSavedByMe']) ||
      coerceFeedApiBool(m['isSaved']) ||
      coerceFeedApiBool(m['saved']) ||
      coerceFeedApiBool(viewer['savedByMe']) ||
      savedByMe;

  return <String, dynamic>{
    'id': (m['_id'] ?? '').toString(),
    'creatorId': (creator['_id'] ?? '').toString(),
    'creatorRole': (creator['role'] ?? '').toString(),
    'isTrainer': (creator['role']?.toString() ?? '').trim() == 'Trainer',
    'creator': fullName.isEmpty ? (creator['email'] ?? 'user').toString() : fullName,
    'creatorImage': initials,
    'creatorAvatarUrl': (profilePicture['url'] ?? '').toString(),
    'title': (m['title'] ?? '').toString(),
    'description': (m['description'] ?? '').toString(),
    'category': (category['name'] ?? '').toString(),
    'tags': tags,
    'videoUrl': resolvedVideoUrl,
    'thumbnail': thumb,
    'likes': (m['likesCount'] is num) ? (m['likesCount'] as num).toInt() : 0,
    'comments': (m['commentsCount'] is num) ? (m['commentsCount'] as num).toInt() : 0,
    'shares': (m['sharesCount'] is num) ? (m['sharesCount'] as num).toInt() : 0,
    'saves': (m['savesCount'] is num) ? (m['savesCount'] as num).toInt() : 0,
    'isLiked': liked,
    'isSaved': saved,
    'duration': durationLabel,
    if (videoAspectRatio != null) 'videoAspectRatio': videoAspectRatio,
    if (frameW != null) 'videoPixelWidth': frameW,
    if (frameH != null) 'videoPixelHeight': frameH,
    if (meta['format'] != null) 'videoFormat': meta['format'].toString(),
    if (meta['qualities'] is List) 'videoQualities': (meta['qualities'] as List).map((e) => e.toString()).toList(),
  };
}
