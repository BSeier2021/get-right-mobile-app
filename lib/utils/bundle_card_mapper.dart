import 'package:get_right/utils/image_url_sanitizer.dart';

/// Normalizes API / trainer-profile bundle maps for marketplace bundle cards.
Map<String, dynamic> normalizeBundleForCard(Map<String, dynamic> b, {String defaultTrainer = 'Trainer'}) {
  if (b['bundlePrice'] is num && b['programs'] is List) {
    return Map<String, dynamic>.from(b);
  }

  final price = (b['bundlePrice'] as num?)?.toDouble() ?? (b['price'] as num?)?.toDouble() ?? 0.0;
  var totalValue = (b['totalValue'] as num?)?.toDouble() ?? 0.0;
  if (totalValue <= price) {
    totalValue = price > 0 ? price * 1.12 : 0;
  }

  final programs = b['programs'];
  final List<Map<String, dynamic>> resolvedPrograms;
  if (programs is List && programs.isNotEmpty) {
    resolvedPrograms = programs.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  } else {
    final trainer = (b['trainer'] ?? defaultTrainer).toString();
    resolvedPrograms = [
      {
        'trainer': trainer,
        'rating': (b['rating'] as num?)?.toDouble() ?? 4.5,
        'students': (b['students'] as num?)?.toInt() ?? 0,
      },
    ];
  }

  String? imageUrl = ImageUrlSanitizer.asHttpUrlOrNull(b['imageUrl']?.toString());
  imageUrl ??= () {
    final promo = b['promoMedia'];
    if (promo is Map) return ImageUrlSanitizer.asHttpUrlOrNull(promo['url']?.toString());
    final th = b['thumbnail'];
    if (th is Map) return ImageUrlSanitizer.asHttpUrlOrNull(th['url']?.toString());
    return null;
  }();

  return {
    'id': (b['id'] ?? b['_id'] ?? '').toString(),
    '_id': (b['_id'] ?? b['id'] ?? '').toString(),
    'title': (b['title'] ?? b['name'] ?? 'Bundle').toString(),
    'subtitle': b['subtitle'],
    'description': (b['description'] ?? '').toString(),
    'discount': (b['discount'] as num?)?.toInt() ?? 0,
    'totalValue': totalValue,
    'bundlePrice': price,
    'imageUrl': imageUrl ?? '',
    'programs': resolvedPrograms,
    'isHot': b['isHot'] == true,
    'isCertified': b['isCertified'] == true,
    if (b['_apiBundle'] != null) '_apiBundle': b['_apiBundle'],
  };
}

List<Map<String, dynamic>> parseProfileBundlesList(dynamic raw, {String trainerName = 'Trainer'}) {
  final data = raw is Map ? raw['data'] : null;
  if (data is! Map) return [];
  final block = data['bundles'];
  List? list;
  if (block is Map && block['bundles'] is List) {
    list = block['bundles'] as List;
  } else if (block is List) {
    list = block;
  } else if (data['bundles'] is List) {
    list = data['bundles'] as List;
  }
  if (list == null) return [];

  return list
      .whereType<Map>()
      .map((e) {
        final m = Map<String, dynamic>.from(e);
        final promo = m['promoMedia'];
        String? imageUrl;
        if (promo is Map) imageUrl = promo['url']?.toString();
        final id = (m['_id'] ?? m['id'] ?? '').toString();
        return normalizeBundleForCard({
          '_id': id,
          'id': id,
          'title': m['title'] ?? m['name'],
          'description': m['description'],
          'price': m['bundlePrice'] ?? m['price'],
          'discount': m['discount'],
          'imageUrl': imageUrl,
          'promoMedia': promo,
          'programs': m['programs'],
          'trainer': trainerName,
          '_apiBundle': m,
        }, defaultTrainer: trainerName);
      })
      .where((e) => (e['id'] ?? '').toString().isNotEmpty)
      .toList();
}

bool readPaginatedHasNext(Map<String, dynamic> data, {String nestedKey = 'bundles'}) {
  final block = data[nestedKey];
  if (block is Map && block['hasNextPage'] == true) return true;
  if (data['hasNextPage'] == true) return true;
  final cp = block is Map ? block['currentPage'] : data['currentPage'];
  final tp = block is Map ? block['totalPages'] : data['totalPages'];
  if (cp is num && tp is num) return cp.toInt() < tp.toInt();
  return false;
}

int readPaginatedTotalDocs(Map<String, dynamic> data, {String nestedKey = 'bundles', int fallback = 0}) {
  final block = data[nestedKey];
  if (block is Map && block['totalDocs'] is num) return (block['totalDocs'] as num).toInt();
  if (data['totalDocs'] is num) return (data['totalDocs'] as num).toInt();
  return fallback;
}

/// Profile details — `data.user.bundleCount`, name, avatar.
Map<String, dynamic>? parseProfileDetailsHeader(dynamic raw) {
  if (raw is! Map) return null;
  final data = raw['data'];
  if (data is! Map) return null;
  final user = data['user'];
  if (user is! Map) return null;
  final um = Map<String, dynamic>.from(user);
  final profile = um['profile'] is Map ? Map<String, dynamic>.from(um['profile'] as Map) : <String, dynamic>{};
  final name = (profile['fullName'] ?? um['email'] ?? '').toString();
  final bundleCount = um['bundleCount'];
  String? avatarUrl;
  final pic = profile['profilePicture'];
  if (pic is Map) avatarUrl = pic['url']?.toString();
  return {
    'userId': um['_id']?.toString(),
    'name': name,
    'bundleCount': bundleCount is num ? bundleCount.toInt() : 0,
    'avatarUrl': avatarUrl,
  };
}
