import 'package:get_right/utils/image_url_sanitizer.dart';

enum DiscoverSort {
  newest('Newest'),
  nameAsc('NameAsc'),
  mostFollowers('MostFollowers'),
  highestRated('HighestRated');

  const DiscoverSort(this.apiValue);

  final String apiValue;

  String get label {
    switch (this) {
      case DiscoverSort.newest:
        return 'Newest';
      case DiscoverSort.nameAsc:
        return 'Name (A–Z)';
      case DiscoverSort.mostFollowers:
        return 'Most Followers';
      case DiscoverSort.highestRated:
        return 'Highest Rated';
    }
  }
}

class DiscoverUser {
  const DiscoverUser({
    required this.id,
    required this.name,
    required this.role,
    required this.avatarUrl,
    required this.followersCount,
    required this.followingCount,
    required this.avgRating,
    required this.totalReviews,
  });

  final String id;
  final String name;
  final String role;
  final String? avatarUrl;
  final int followersCount;
  final int followingCount;
  final double avgRating;
  final int totalReviews;

  bool get isTrainer => role.toLowerCase() == 'trainer';

  factory DiscoverUser.fromJson(Map<String, dynamic> json) {
    final pic = json['profilePicture'];
    String? avatarUrl;
    if (pic is Map) {
      avatarUrl = ImageUrlSanitizer.asHttpUrlOrNull(pic['url']?.toString());
    }
    avatarUrl ??= ImageUrlSanitizer.asHttpUrlOrNull(json['profilePictureUrl']?.toString());

    return DiscoverUser(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      name: json['name']?.toString().trim().isNotEmpty == true ? json['name'].toString().trim() : 'User',
      role: json['role']?.toString() ?? '',
      avatarUrl: avatarUrl,
      followersCount: _toInt(json['followersCount']),
      followingCount: _toInt(json['followingCount']),
      avgRating: _toDouble(json['avgRating']),
      totalReviews: _toInt(json['totalReviews']),
    );
  }

  Map<String, dynamic> toProfileArgs() {
    return {
      '_id': id,
      'id': id,
      'name': name,
      'avatarUrl': avatarUrl,
      'role': role,
      'followersCount': followersCount,
      'followingCount': followingCount,
      'rating': avgRating,
      'totalReviews': totalReviews,
    };
  }
}

class DiscoverUsersPage {
  const DiscoverUsersPage({
    required this.users,
    required this.totalDocs,
    required this.currentPage,
    required this.totalPages,
    required this.hasNextPage,
    required this.hasPrevPage,
  });

  final List<DiscoverUser> users;
  final int totalDocs;
  final int currentPage;
  final int totalPages;
  final bool hasNextPage;
  final bool hasPrevPage;

  static const empty = DiscoverUsersPage(
    users: [],
    totalDocs: 0,
    currentPage: 1,
    totalPages: 0,
    hasNextPage: false,
    hasPrevPage: false,
  );

  factory DiscoverUsersPage.fromApiResponse(dynamic raw) {
    final payload = _unwrapPayload(raw);
    if (payload == null) return DiscoverUsersPage.empty;

    final usersRaw = payload['users'];
    final users = <DiscoverUser>[];
    if (usersRaw is List) {
      for (final item in usersRaw) {
        if (item is Map) {
          final mapped = DiscoverUser.fromJson(Map<String, dynamic>.from(item));
          if (mapped.id.isNotEmpty) users.add(mapped);
        }
      }
    }

    return DiscoverUsersPage(
      users: users,
      totalDocs: _toInt(payload['totalDocs']),
      currentPage: _toInt(payload['currentPage'], fallback: 1),
      totalPages: _toInt(payload['totalPages']),
      hasNextPage: payload['hasNextPage'] == true,
      hasPrevPage: payload['hasPrevPage'] == true,
    );
  }

  static Map<String, dynamic>? _unwrapPayload(dynamic raw) {
    if (raw is! Map) return null;
    final root = Map<String, dynamic>.from(raw);
    if (root['users'] is List) return root;

    final data = root['data'];
    if (data is Map) {
      final map = Map<String, dynamic>.from(data);
      if (map['users'] is List) return map;
      final nested = map['result'] ?? map['discover'];
      if (nested is Map) {
        final inner = Map<String, dynamic>.from(nested);
        if (inner['users'] is List) return inner;
      }
    }
    return null;
  }
}

int _toInt(dynamic value, {int fallback = 0}) {
  if (value == null) return fallback;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString()) ?? fallback;
}

double _toDouble(dynamic value) {
  if (value == null) return 0;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString()) ?? 0;
}
