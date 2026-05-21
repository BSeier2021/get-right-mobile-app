import 'package:get_right/controllers/safety_center_controller.dart';
import 'package:get_right/utils/image_url_sanitizer.dart';

class ParsedBlockedUsersPage {
  const ParsedBlockedUsersPage({
    required this.users,
    required this.totalDocs,
    required this.hasNextPage,
  });

  final List<BlockedUser> users;
  final int totalDocs;
  final bool hasNextPage;
}

/// `GET /user/block` → `data.blocked.blocked[]`.
ParsedBlockedUsersPage parseBlockedUsersListResponse(dynamic raw) {
  const empty = ParsedBlockedUsersPage(users: [], totalDocs: 0, hasNextPage: false);
  if (raw is! Map) return empty;

  final data = raw['data'];
  if (data is! Map) return empty;

  final blockedRoot = data['blocked'];
  if (blockedRoot is! Map) return empty;

  final list = blockedRoot['blocked'];
  if (list is! List) return empty;

  final users = <BlockedUser>[];
  for (final e in list) {
    if (e is! Map) continue;
    final item = _mapBlockedEntry(Map<String, dynamic>.from(e));
    if (item != null) users.add(item);
  }

  users.sort((a, b) => b.blockedAt.compareTo(a.blockedAt));

  final totalDocs = (blockedRoot['totalDocs'] as num?)?.toInt() ?? users.length;
  final hasNext = blockedRoot['hasNextPage'] == true;

  return ParsedBlockedUsersPage(users: users, totalDocs: totalDocs, hasNextPage: hasNext);
}

BlockedUser? _mapBlockedEntry(Map<String, dynamic> json) {
  final blockedNode = json['blocked'];
  if (blockedNode is! Map) return null;

  final blocked = Map<String, dynamic>.from(blockedNode);
  final userId = blocked['_id']?.toString().trim();
  if (userId == null || userId.isEmpty) return null;

  final profile = blocked['profile'] is Map ? Map<String, dynamic>.from(blocked['profile'] as Map) : <String, dynamic>{};
  final fullName = profile['fullName']?.toString().trim();
  final email = blocked['email']?.toString().trim() ?? '';

  var name = fullName?.isNotEmpty == true ? fullName! : email;
  if (name.isEmpty) name = 'User';

  final username = email.isNotEmpty ? '@${email.split('@').first}' : '@user';

  String? avatarUrl;
  final pic = profile['profilePicture'];
  if (pic is Map) {
    avatarUrl = ImageUrlSanitizer.asHttpUrlOrNull(pic['url']?.toString());
  }

  DateTime blockedAt = DateTime.now();
  final createdRaw = json['createdAt']?.toString();
  if (createdRaw != null && createdRaw.isNotEmpty) {
    blockedAt = DateTime.tryParse(createdRaw) ?? blockedAt;
  }

  return BlockedUser(
    id: userId,
    blockRecordId: json['_id']?.toString(),
    name: name,
    username: username,
    avatarUrl: avatarUrl,
    blockedAt: blockedAt,
  );
}
