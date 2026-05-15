/// Maps API feed documents to the UI map shape used by [FeedScreen] and [FeedVerticalReels].

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
  double? metaW;
  double? metaH;
  double? videoAspectRatio;
  final rawMetaW = meta['width'];
  final rawMetaH = meta['height'];
  if (rawMetaW is num && rawMetaH is num) {
    metaW = rawMetaW.toDouble();
    metaH = rawMetaH.toDouble();
    if (metaW > 0 && metaH > 0) {
      videoAspectRatio = metaW / metaH;
    }
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

  final liked =
      m['likedByMe'] == true ||
      m['isLiked'] == true ||
      m['liked'] == true ||
      likedByMe;
  final saved =
      m['savedByMe'] == true ||
      m['isSaved'] == true ||
      m['saved'] == true ||
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
    if (metaW != null) 'videoPixelWidth': metaW,
    if (metaH != null) 'videoPixelHeight': metaH,
    if (meta['format'] != null) 'videoFormat': meta['format'].toString(),
    if (meta['qualities'] is List) 'videoQualities': (meta['qualities'] as List).map((e) => e.toString()).toList(),
  };
}
