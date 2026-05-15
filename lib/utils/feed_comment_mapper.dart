import 'package:get_right/utils/helpers.dart';

/// Maps `data.comments[]` items from `GET /user/feed/:feedId/comments`.
Map<String, dynamic> mapApiFeedCommentToUi(dynamic raw) {
  final m = (raw is Map) ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
  final user = (m['user'] is Map) ? Map<String, dynamic>.from(m['user'] as Map) : <String, dynamic>{};
  final profile = (user['profile'] is Map) ? Map<String, dynamic>.from(user['profile'] as Map) : <String, dynamic>{};
  final profilePicture =
      (profile['profilePicture'] is Map) ? Map<String, dynamic>.from(profile['profilePicture'] as Map) : <String, dynamic>{};

  final fullName = (profile['fullName'] ?? '').toString().trim();
  final email = (user['email'] ?? '').toString().trim();
  final displayName = fullName.isNotEmpty ? fullName : (email.isNotEmpty ? email.split('@').first : 'User');

  final initials = displayName.isEmpty
      ? 'U'
      : displayName.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).take(2).map((p) => p[0].toUpperCase()).join();

  final createdAtRaw = (m['createdAt'] ?? '').toString();
  final createdAt = DateTime.tryParse(createdAtRaw);

  return <String, dynamic>{
    'id': (m['_id'] ?? '').toString(),
    'authorId': (user['_id'] ?? '').toString(),
    'text': (m['text'] ?? '').toString(),
    'authorName': displayName,
    'authorInitials': initials,
    'avatarUrl': (profilePicture['url'] ?? '').toString(),
    'timestamp': createdAt != null ? Helpers.getRelativeTime(createdAt.toLocal()) : '',
  };
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
