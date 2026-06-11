import 'package:get_right/utils/image_url_sanitizer.dart';

/// Bundle-level pricing from API (`price`, `netPrice`, `discount`) — not summed program prices.
Map<String, dynamic> resolveBundlePricingFromApi(Map<String, dynamic> b) {
  final pricing = b['pricing_summary'];
  if (pricing is Map) {
    final pm = Map<String, dynamic>.from(pricing);
    final listPrice = (pm['original_list_price'] as num?)?.toDouble();
    final sellingPrice = (pm['bundle_price'] as num?)?.toDouble();
    final savingsPercent = (pm['savings_percent'] as num?)?.toDouble();
    if (sellingPrice != null && sellingPrice > 0) {
      final totalValue = (listPrice != null && listPrice > sellingPrice) ? listPrice : sellingPrice;
      final discount = savingsPercent != null
          ? savingsPercent.round().clamp(0, 95)
          : (totalValue > sellingPrice ? (((totalValue - sellingPrice) / totalValue) * 100).round().clamp(0, 95) : 0);
      return {'totalValue': totalValue, 'bundlePrice': sellingPrice, 'discount': discount};
    }
  }

  final listPrice = (b['price'] as num?)?.toDouble() ?? 0.0;
  final discountPct = (b['discount'] as num?)?.toDouble() ?? 0.0;
  final netPrice = (b['netPrice'] as num?)?.toDouble();
  final legacyBundlePrice = (b['bundlePrice'] as num?)?.toDouble();

  double sellingPrice;
  if (netPrice != null && netPrice > 0) {
    sellingPrice = netPrice;
  } else if (legacyBundlePrice != null && legacyBundlePrice > 0) {
    sellingPrice = legacyBundlePrice;
  } else if (listPrice > 0 && discountPct > 0) {
    sellingPrice = listPrice * (1 - discountPct / 100);
  } else {
    sellingPrice = listPrice > 0 ? listPrice : 0.0;
  }

  var totalValue = listPrice > 0 ? listPrice : sellingPrice;
  if (totalValue < sellingPrice) totalValue = sellingPrice;

  var discount = discountPct.round().clamp(0, 95);
  if (discount == 0 && totalValue > sellingPrice) {
    discount = (((totalValue - sellingPrice) / totalValue) * 100).round().clamp(0, 95);
  }

  return {
    'totalValue': totalValue,
    'bundlePrice': sellingPrice,
    'discount': discount,
  };
}

/// Normalizes API / trainer-profile bundle maps for marketplace bundle cards.
Map<String, dynamic> normalizeBundleForCard(Map<String, dynamic> b, {String defaultTrainer = 'Trainer'}) {
  if (b['bundlePrice'] is num && b['programs'] is List) {
    return Map<String, dynamic>.from(b);
  }

  final pricing = resolveBundlePricingFromApi(b);
  final price = (pricing['bundlePrice'] as num?)?.toDouble() ?? 0.0;
  final totalValue = (pricing['totalValue'] as num?)?.toDouble() ?? price;
  final discount = (pricing['discount'] as num?)?.toInt() ?? 0;

  final programs = b['programs'];
  final List<Map<String, dynamic>> resolvedPrograms;
  if (programs is List && programs.isNotEmpty) {
    resolvedPrograms = programs.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  } else {
    final trainer = (b['trainer'] ?? defaultTrainer).toString();
    resolvedPrograms = [
      {
        'trainer': trainer,
        'rating': (b['rating'] as num?)?.toDouble() ?? (b['ratingAvg'] as num?)?.toDouble() ?? 0.0,
        'students': (b['students'] as num?)?.toInt() ?? 0,
        'ratingCount': (b['ratingCount'] as num?)?.toInt() ?? (b['reviews'] as num?)?.toInt() ?? 0,
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
    'discount': discount,
    'totalValue': totalValue,
    'bundlePrice': price,
    'imageUrl': imageUrl ?? '',
    'programs': resolvedPrograms,
    'rating': bundleCardAverageRating({'programs': resolvedPrograms, ...b}),
    'ratingCount': bundleCardReviewCount({'programs': resolvedPrograms, ...b}),
    'isHot': b['isHot'] == true,
    'isCertified': b['isCertified'] == true,
    if (b['_apiBundle'] != null) '_apiBundle': b['_apiBundle'],
  };
}

double _programCardRating(Map<String, dynamic> program) {
  final direct = (program['rating'] as num?)?.toDouble();
  if (direct != null && direct > 0) return direct;

  final api = program['_apiProgram'];
  if (api is Map) {
    final fromApi = (api['ratingAvg'] as num?)?.toDouble();
    if (fromApi != null && fromApi > 0) return fromApi;
    final display = api['display'];
    if (display is Map) {
      return (display['average_rating'] as num?)?.toDouble() ?? 0.0;
    }
  }
  return 0.0;
}

int _programCardReviewCount(Map<String, dynamic> program) {
  final direct = (program['ratingCount'] as num?)?.toInt() ?? (program['reviews'] as num?)?.toInt();
  if (direct != null && direct > 0) return direct;

  final api = program['_apiProgram'];
  if (api is Map) {
    final fromApi = (api['ratingCount'] as num?)?.toInt();
    if (fromApi != null && fromApi > 0) return fromApi;
    final display = api['display'];
    if (display is Map) {
      return (display['review_count'] as num?)?.toInt() ?? 0;
    }
  }
  return 0;
}

/// Average star rating for a normalized bundle card map.
double bundleCardAverageRating(Map<String, dynamic> bundle) {
  final direct = (bundle['rating'] as num?)?.toDouble() ?? (bundle['ratingAvg'] as num?)?.toDouble();
  if (direct != null && direct > 0) return direct;

  final api = bundle['_apiBundle'];
  if (api is Map) {
    final fromApi = (api['ratingAvg'] as num?)?.toDouble() ?? (api['averageRating'] as num?)?.toDouble();
    if (fromApi != null && fromApi > 0) return fromApi;
  }

  final programs = bundle['programs'];
  if (programs is! List || programs.isEmpty) return 0.0;

  final ratings = <double>[];
  for (final item in programs) {
    if (item is! Map) continue;
    final rating = _programCardRating(Map<String, dynamic>.from(item));
    if (rating > 0) ratings.add(rating);
  }
  if (ratings.isEmpty) return 0.0;
  return ratings.reduce((a, b) => a + b) / ratings.length;
}

/// Total review count for a normalized bundle card map.
int bundleCardReviewCount(Map<String, dynamic> bundle) {
  final direct = (bundle['ratingCount'] as num?)?.toInt() ?? (bundle['reviews'] as num?)?.toInt();
  if (direct != null && direct > 0) return direct;

  final api = bundle['_apiBundle'];
  if (api is Map) {
    final fromApi = (api['ratingCount'] as num?)?.toInt() ?? (api['reviewCount'] as num?)?.toInt();
    if (fromApi != null && fromApi > 0) return fromApi;
  }

  final programs = bundle['programs'];
  if (programs is! List || programs.isEmpty) return 0;

  var total = 0;
  for (final item in programs) {
    if (item is! Map) continue;
    total += _programCardReviewCount(Map<String, dynamic>.from(item));
  }
  return total;
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
          'price': m['price'],
          'netPrice': m['netPrice'],
          'bundlePrice': m['bundlePrice'],
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
