/// Maps `GET /user/follow/:userId/followers|following` list entries to UI rows.
class FollowListPageResult {
  const FollowListPageResult({
    required this.users,
    required this.totalDocs,
    required this.hasNextPage,
    required this.currentPage,
  });

  final List<Map<String, dynamic>> users;
  final int totalDocs;
  final bool hasNextPage;
  final int currentPage;
}

Map<String, dynamic> mapFollowPersonToUi(Map<String, dynamic> person) {
  final profile = person['profile'] is Map ? Map<String, dynamic>.from(person['profile'] as Map) : <String, dynamic>{};
  final pic = profile['profilePicture'];
  String? avatarUrl;
  if (pic is Map) {
    avatarUrl = pic['url']?.toString().trim();
  }

  final email = (person['email'] ?? '').toString().trim();
  final fullName = (profile['fullName'] ?? '').toString().trim();
  final name = fullName.isNotEmpty ? fullName : (email.isNotEmpty ? email.split('@').first : 'User');
  final username = email.isNotEmpty ? email.split('@').first.toLowerCase() : name.toLowerCase().replaceAll(' ', '_');

  final parts = name.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).take(2).map((p) => p[0].toUpperCase());
  final initials = parts.isEmpty ? 'U' : parts.join();

  final role = (person['role'] ?? '').toString();
  final id = (person['_id'] ?? '').toString();

  return <String, dynamic>{
    'id': id,
    'name': name,
    'username': username,
    'email': email,
    'avatarUrl': avatarUrl,
    'initials': initials,
    'role': role,
    'isTrainer': role.toLowerCase() == 'trainer',
    'isFollowing': false,
  };
}

FollowListPageResult? parseFollowListResponse(dynamic raw, {required bool followers}) {
  if (raw is! Map) return null;
  final data = raw['data'];
  if (data is! Map) return null;

  final blockKey = followers ? 'followers' : 'following';
  final block = data[blockKey];
  if (block is! Map) return null;

  final followsRaw = block['follows'];
  final follows = followsRaw is List ? followsRaw : const [];

  final users = <Map<String, dynamic>>[];
  for (final item in follows) {
    if (item is! Map) continue;
    final m = Map<String, dynamic>.from(item);
    final personRaw = followers ? m['followedBy'] : m['user'];
    if (personRaw is! Map) continue;
    final mapped = mapFollowPersonToUi(Map<String, dynamic>.from(personRaw));
    if ((mapped['id'] ?? '').toString().isNotEmpty) {
      users.add(mapped);
    }
  }

  final totalDocs = block['totalDocs'];
  final currentPage = block['currentPage'];

  return FollowListPageResult(
    users: users,
    totalDocs: totalDocs is num ? totalDocs.toInt() : users.length,
    hasNextPage: block['hasNextPage'] == true,
    currentPage: currentPage is num ? currentPage.toInt() : 1,
  );
}
