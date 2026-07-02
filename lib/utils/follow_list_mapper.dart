/// Maps `GET /user/follow/:userId/followers|following` list entries to UI rows.
import 'package:get_right/utils/trainer_certification_helper.dart';

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

Map<String, dynamic> mapFollowPersonToUi(Map<String, dynamic> person, {bool isFollowing = false}) {
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
  final id = (person['_id'] ?? person['id'] ?? '').toString();
  final certificationsVerified = isCertificationsVerifiedFromApiNodes([person, profile]);

  final relationFollowing =
      isFollowing ||
      person['isFollowing'] == true ||
      person['isFollowedByMe'] == true ||
      person['isFollowedBack'] == true;

  return <String, dynamic>{
    'id': id,
    'name': name,
    'username': username,
    'email': email,
    'avatarUrl': avatarUrl,
    'initials': initials,
    'role': role,
    'isTrainer': role.toLowerCase() == 'trainer',
    'isCertificationsVerified': certificationsVerified,
    'certified': certificationsVerified,
    'isCertified': certificationsVerified,
    'isFollowing': relationFollowing,
  };
}

bool _isRelationFollowing(Map<String, dynamic> item) {
  if (item['isFollowing'] == true) return true;
  if (item['isFollowedByMe'] == true) return true;
  if (item['isFollowedBack'] == true) return true;
  return false;
}

Map<String, dynamic>? _personFromFollowItem(Map<String, dynamic> item, {required bool followers}) {
  final personKeys = followers
      ? const ['followedBy', 'follower', 'user']
      : const ['user', 'following', 'followed', 'followedBy'];

  for (final key in personKeys) {
    final raw = item[key];
    if (raw is Map) return Map<String, dynamic>.from(raw);
  }

  if (item['_id'] != null && (item['email'] != null || item['profile'] != null)) {
    return item;
  }
  return null;
}

List<Map<String, dynamic>> _usersFromFollowsList(List follows, {required bool followers}) {
  final users = <Map<String, dynamic>>[];
  for (final item in follows) {
    if (item is! Map) continue;
    final m = Map<String, dynamic>.from(item);
    final person = _personFromFollowItem(m, followers: followers);
    if (person == null) continue;
    final mapped = mapFollowPersonToUi(person, isFollowing: _isRelationFollowing(m));
    if ((mapped['id'] ?? '').toString().isNotEmpty) {
      users.add(mapped);
    }
  }
  return users;
}

FollowListPageResult? parseFollowListResponse(dynamic raw, {required bool followers}) {
  if (raw is! Map) return null;
  if (raw['success'] == false) return null;

  final data = raw['data'];
  if (data is! Map) return null;

  final blockKey = followers ? 'followers' : 'following';
  final block = data[blockKey];

  List<Map<String, dynamic>> users;
  int totalDocs;
  bool hasNextPage;
  int currentPage;

  if (block is Map) {
    final followsRaw = block['follows'];
    final follows = followsRaw is List ? followsRaw : const [];
    users = _usersFromFollowsList(follows, followers: followers);
    totalDocs = block['totalDocs'] is num ? (block['totalDocs'] as num).toInt() : users.length;
    hasNextPage = block['hasNextPage'] == true;
    currentPage = block['currentPage'] is num ? (block['currentPage'] as num).toInt() : 1;
  } else if (block is List) {
    users = _usersFromFollowsList(block, followers: followers);
    totalDocs = users.length;
    hasNextPage = false;
    currentPage = 1;
  } else {
    final altList = data['follows'] ?? data['docs'] ?? data['results'];
    if (altList is List) {
      users = _usersFromFollowsList(altList, followers: followers);
      totalDocs = data['totalDocs'] is num ? (data['totalDocs'] as num).toInt() : users.length;
      hasNextPage = data['hasNextPage'] == true;
      currentPage = data['currentPage'] is num ? (data['currentPage'] as num).toInt() : 1;
    } else {
      return const FollowListPageResult(users: [], totalDocs: 0, hasNextPage: false, currentPage: 1);
    }
  }

  return FollowListPageResult(
    users: users,
    totalDocs: totalDocs,
    hasNextPage: hasNextPage,
    currentPage: currentPage,
  );
}
