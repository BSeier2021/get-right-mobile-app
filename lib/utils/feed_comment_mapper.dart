import 'package:get_right/utils/helpers.dart';

/// Extracts `data.comments[]` from `GET /user/feed/:feedId/comments` (and replies list).
List<dynamic> feedCommentsListFromApiResponse(dynamic raw) {
  if (raw is! Map) return const <dynamic>[];
  final data = raw['data'];
  if (data is! Map) return const <dynamic>[];

  final root = Map<String, dynamic>.from(data);
  final commentsNode = root['comments'];
  if (commentsNode is List) return List<dynamic>.from(commentsNode);
  if (commentsNode is Map) {
    for (final key in ['docs', 'items', 'list', 'data', 'comments']) {
      final inner = commentsNode[key];
      if (inner is List) return List<dynamic>.from(inner);
    }
  }

  for (final key in ['docs', 'items', 'list']) {
    final inner = root[key];
    if (inner is List) return List<dynamic>.from(inner);
  }
  return const <dynamic>[];
}

/// Top-level comments have no `parentComment` id on the API document.
bool isTopLevelFeedCommentRaw(Map<String, dynamic> m) {
  final parentRaw = m['parentComment'] ?? m['parentCommentId'];
  if (parentRaw == null) return true;
  if (parentRaw is Map) {
    return (parentRaw['_id'] ?? '').toString().trim().isEmpty;
  }
  final id = parentRaw.toString().trim();
  return id.isEmpty || id.toLowerCase() == 'null';
}

/// Maps `data.comments[]` items from `GET /user/feed/:feedId/comments`.
Map<String, dynamic> mapApiFeedCommentToUi(dynamic raw) {
  final m = (raw is Map) ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
  final userNode = m['user'] ?? m['creator'] ?? m['author'];
  final user = (userNode is Map) ? Map<String, dynamic>.from(userNode) : <String, dynamic>{};
  final profile = (user['profile'] is Map) ? Map<String, dynamic>.from(user['profile'] as Map) : <String, dynamic>{};
  final profilePicture = (profile['profilePicture'] is Map) ? Map<String, dynamic>.from(profile['profilePicture'] as Map) : <String, dynamic>{};

  final fullName = (profile['fullName'] ?? '').toString().trim();
  final email = (user['email'] ?? '').toString().trim();
  final displayName = fullName.isNotEmpty ? fullName : (email.isNotEmpty ? email.split('@').first : 'User');

  final initials = displayName.isEmpty ? 'U' : displayName.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).take(2).map((p) => p[0].toUpperCase()).join();

  final createdAtRaw = (m['createdAt'] ?? '').toString();
  final createdAt = DateTime.tryParse(createdAtRaw);

  final parentRaw = m['parentComment'];
  final parentId = parentRaw is Map ? (parentRaw['_id'] ?? '').toString() : (parentRaw ?? m['parentCommentId'] ?? '').toString();

  final repliesCount = m['repliesCount'] ?? m['replyCount'];
  final replyCountInt = repliesCount is num ? repliesCount.toInt() : null;

  return <String, dynamic>{
    'id': (m['_id'] ?? '').toString(),
    'authorId': (user['_id'] ?? '').toString(),
    'parentCommentId': parentId.trim(),
    'text': (m['text'] ?? '').toString(),
    'authorName': displayName,
    'authorInitials': initials,
    'avatarUrl': (profilePicture['url'] ?? '').toString(),
    'timestamp': createdAt != null ? Helpers.getRelativeTime(createdAt.toLocal()) : '',
    if (createdAt != null) 'createdAt': createdAt.toUtc().toIso8601String(),
    if (replyCountInt != null && replyCountInt > 0) 'repliesCount': replyCountInt,
  };
}

DateTime feedCommentSortTime(Map<String, dynamic> comment) {
  final raw = comment['createdAt'];
  if (raw is DateTime) return raw;
  if (raw is String) {
    return DateTime.tryParse(raw) ?? DateTime.fromMillisecondsSinceEpoch(0);
  }
  return DateTime.fromMillisecondsSinceEpoch(0);
}

/// Oldest first — used for reply threads regardless of API sort order.
void sortFeedCommentsChronologically(List<Map<String, dynamic>> comments) {
  comments.sort((a, b) => feedCommentSortTime(a).compareTo(feedCommentSortTime(b)));
}

bool readFeedCommentsHasNextPage(Map<String, dynamic> data) {
  final direct = data['hasNextPage'];
  if (direct == true) return true;
  if (direct == false) return false;
  final cp = data['currentPage'];
  final tp = data['totalPages'];
  if (cp is num && tp is num) {
    return cp.toInt() < tp.toInt();
  }
  return false;
}
