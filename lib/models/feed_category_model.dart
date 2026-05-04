/// One row from `GET /user/feed-categories` → `data.categories[]`.
class FeedCategory {
  final String id;
  final String name;
  final String? description;
  final String? icon;

  FeedCategory({
    required this.id,
    required this.name,
    this.description,
    this.icon,
  });

  static String? _idString(dynamic raw) {
    if (raw == null) return null;
    if (raw is String) {
      final s = raw.trim();
      return s.isEmpty ? null : s;
    }
    if (raw is Map && raw[r'$oid'] != null) {
      final o = raw[r'$oid'].toString().trim();
      return o.isEmpty ? null : o;
    }
    return null;
  }

  factory FeedCategory.fromJson(Map<String, dynamic> json) {
    return FeedCategory(
      id: _idString(json['_id']) ?? _idString(json['id']) ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString(),
      icon: json['icon']?.toString(),
    );
  }

  static List<FeedCategory> listFromResponse(dynamic response) {
    if (response is! Map) return [];
    final data = response['data'];
    if (data is! Map) return [];
    final raw = data['categories'];
    if (raw is! List) return [];
    return raw.map((e) {
          if (e is! Map<String, dynamic>) return null;
          if (e['isDeleted'] == true) return null;
          final c = FeedCategory.fromJson(e);
          if (c.id.isEmpty || c.name.isEmpty) return null;
          return c;
        }).whereType<FeedCategory>().toList();
  }
}
