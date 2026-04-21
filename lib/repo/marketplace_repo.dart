import 'package:get_right/app_url.dart';
import 'package:get_right/network/network_services.dart';

/// Query `section` values supported by `GET /marketplace/sections`.
abstract final class MarketplaceSection {
  static const String featured = 'featured';
  static const String newReleases = 'new_releases';
}

/// One page from `GET /marketplace/bundles`.
class MarketplaceBundlesPage {
  final List<Map<String, dynamic>> bundles;
  final int page;
  final int perPage;
  final int total;
  final bool hasMore;

  const MarketplaceBundlesPage({
    required this.bundles,
    required this.page,
    required this.perPage,
    required this.total,
    required this.hasMore,
  });
}

/// One page from `GET /marketplace/programs`.
class MarketplaceProgramsPage {
  final List<Map<String, dynamic>> programs;
  final int page;
  final int perPage;
  final int total;
  final bool hasMore;

  const MarketplaceProgramsPage({
    required this.programs,
    required this.page,
    required this.perPage,
    required this.total,
    required this.hasMore,
  });
}

/// `GET /marketplace/sections` — paginated programs per [section] (e.g. [MarketplaceSection.featured], [MarketplaceSection.newReleases]).
class MarketplaceRepository {
  final _network = NetworkApiService();

  Future<List<Map<String, dynamic>>> fetchSectionPrograms({
    required String section,
    int page = 1,
    int perPage = 20,
  }) async {
    final url = AppUrl.marketplaceSections(page: page, perPage: perPage, section: section);
    final raw = await _network.get(url);
    return _parseSectionItems(raw);
  }

  /// `GET /marketplace/programs` — flat `data.data[]` program documents (+ `data.meta`).
  Future<MarketplaceProgramsPage> fetchBrowsePrograms({int page = 1, int perPage = 20}) async {
    final raw = await _network.get(AppUrl.marketplacePrograms(page: page, perPage: perPage));
    return _parseBrowseProgramsPage(raw, page, perPage);
  }

  /// `GET /marketplace/bundles`. [programCatalog] is used to resolve `programs: [_id, …]` into card rows (e.g. loaded browse programs).
  Future<MarketplaceBundlesPage> fetchBrowseBundles({
    int page = 1,
    int perPage = 20,
    List<Map<String, dynamic>> programCatalog = const [],
  }) async {
    final raw = await _network.get(AppUrl.marketplaceBundles(page: page, perPage: perPage));
    return _parseBrowseBundlesPage(raw, page, perPage, programCatalog);
  }

  static MarketplaceBundlesPage _parseBrowseBundlesPage(
    dynamic response,
    int page,
    int perPage,
    List<Map<String, dynamic>> programCatalog,
  ) {
    final bundles = <Map<String, dynamic>>[];
    if (!_isOk(response)) {
      return MarketplaceBundlesPage(bundles: bundles, page: page, perPage: perPage, total: 0, hasMore: false);
    }
    final root = Map<String, dynamic>.from(response);
    final data = root['data'];
    if (data is! Map) {
      return MarketplaceBundlesPage(bundles: bundles, page: page, perPage: perPage, total: 0, hasMore: false);
    }
    final dataMap = Map<String, dynamic>.from(data);
    final items = dataMap['data'];
    if (items is! List) {
      return MarketplaceBundlesPage(bundles: bundles, page: page, perPage: perPage, total: 0, hasMore: false);
    }
    for (final item in items) {
      if (item is! Map) continue;
      bundles.add(_bundleCardFromApi(Map<String, dynamic>.from(item), programCatalog));
    }
    int total = bundles.length;
    final meta = dataMap['meta'];
    if (meta is Map) {
      total = (Map<String, dynamic>.from(meta)['total'] as num?)?.toInt() ?? total;
    }
    final hasMore = bundles.length == perPage && (page * perPage) < total;
    return MarketplaceBundlesPage(bundles: bundles, page: page, perPage: perPage, total: total, hasMore: hasMore);
  }

  static double _programCardPrice(Map<String, dynamic> p) => ((p['price'] as num?) ?? 0).toDouble();

  static Map<String, dynamic> _bundleCardFromApi(Map<String, dynamic> b, List<Map<String, dynamic>> programCatalog) {
    final bundleId = b['_id']?.toString() ?? '';
    final bundlePrice = (b['bundlePrice'] as num?)?.toDouble() ?? 0.0;
    final bundleCertified = b['isCertified'] == true;
    final rawPrograms = b['programs'];
    final resolved = <Map<String, dynamic>>[];

    if (rawPrograms is List) {
      for (final e in rawPrograms) {
        final pid = e.toString().trim();
        if (pid.isEmpty) continue;
        Map<String, dynamic>? found;
        for (final p in programCatalog) {
          if (p['id']?.toString() == pid) {
            found = Map<String, dynamic>.from(p);
            break;
          }
        }
        if (found != null) {
          resolved.add(found);
        } else {
          resolved.add({
            'id': pid,
            'title': 'Program',
            'trainer': 'Trainer',
            'trainerImage': 'T',
            'price': 0.0,
            'duration': '—',
            'category': 'Program',
            'goal': '—',
            'certified': bundleCertified,
            'rating': 0.0,
            'students': 0,
          });
        }
      }
    }

    var sumPrices = resolved.fold<double>(0, (s, p) => s + _programCardPrice(p));
    if (sumPrices <= bundlePrice) {
      sumPrices = bundlePrice > 0 ? bundlePrice * 1.12 : 1;
    }
    final totalValue = sumPrices;
    final discount = totalValue > 0 ? (((totalValue - bundlePrice) / totalValue) * 100).round().clamp(0, 95) : 0;

    return {
      'id': bundleId,
      'title': b['title']?.toString() ?? '',
      'subtitle': b['subtitle'],
      'description': b['description']?.toString() ?? '',
      'discount': discount,
      'totalValue': totalValue,
      'bundlePrice': bundlePrice,
      'imageUrl': b['coverImageUrl']?.toString() ?? '',
      'programs': resolved,
      'isHot': b['isHot'] == true,
      'isCertified': bundleCertified,
      '_apiBundle': b,
    };
  }

  static MarketplaceProgramsPage _parseBrowseProgramsPage(dynamic response, int page, int perPage) {
    final programs = <Map<String, dynamic>>[];
    if (!_isOk(response)) {
      return MarketplaceProgramsPage(programs: programs, page: page, perPage: perPage, total: 0, hasMore: false);
    }
    final root = Map<String, dynamic>.from(response);
    final data = root['data'];
    if (data is! Map) {
      return MarketplaceProgramsPage(programs: programs, page: page, perPage: perPage, total: 0, hasMore: false);
    }
    final dataMap = Map<String, dynamic>.from(data);
    final items = dataMap['data'];
    if (items is! List) {
      return MarketplaceProgramsPage(programs: programs, page: page, perPage: perPage, total: 0, hasMore: false);
    }
    for (final item in items) {
      if (item is! Map) continue;
      programs.add(_cardFromBrowseProgram(Map<String, dynamic>.from(item)));
    }
    int total = programs.length;
    final meta = dataMap['meta'];
    if (meta is Map) {
      final mm = Map<String, dynamic>.from(meta);
      total = (mm['total'] as num?)?.toInt() ?? total;
    }
    final hasMore = programs.length == perPage && (page * perPage) < total;
    return MarketplaceProgramsPage(programs: programs, page: page, perPage: perPage, total: total, hasMore: hasMore);
  }

  static Map<String, dynamic> _cardFromBrowseProgram(Map<String, dynamic> p) {
    final card = _cardFromApiProgram(p);
    card['certified'] = p['isCertified'] == true;
    return card;
  }

  static bool _isOk(dynamic response) {
    if (response is! Map) return false;
    final m = Map<String, dynamic>.from(response);
    if (m['success'] == true || m['success'] == 1) return true;
    final st = m['status'];
    return st == 200 || st == '200';
  }

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'[\s_\-]+')).where((s) => s.isNotEmpty).toList();
    if (parts.isEmpty) return 'T';
    if (parts.length == 1) {
      final s = parts[0];
      if (s.length >= 2) return s.substring(0, 2).toUpperCase();
      return s[0].toUpperCase();
    }
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  static Map<String, dynamic> _cardFromApiProgram(Map<String, dynamic> p) {
    final display = p['display'] is Map ? Map<String, dynamic>.from(p['display'] as Map) : <String, dynamic>{};
    final rating = (display['average_rating'] as num?)?.toDouble() ?? 0.0;
    final students = (display['enrollment_count'] as num?)?.toInt() ?? 0;
    final price = (p['price'] as num?)?.toDouble() ?? 0.0;
    final weeks = p['durationWeeks'];
    final duration = weeks is num ? '${weeks.toInt()} weeks' : (p['duration']?.toString().trim().isNotEmpty == true ? p['duration'].toString() : '—');
    final focus = p['focus']?.toString() ?? '';
    final level = p['level']?.toString() ?? '';
    final trainer = display['instructor_name']?.toString().trim().isNotEmpty == true
        ? display['instructor_name'].toString().trim()
        : 'Trainer';

    return {
      'id': p['_id']?.toString(),
      'title': p['title']?.toString() ?? '',
      'subtitle': p['subtitle'],
      'description': p['description']?.toString() ?? '',
      'imageUrl': p['coverImageUrl']?.toString(),
      'trainer': trainer,
      'trainerImage': _initials(trainer),
      'price': price,
      'duration': duration,
      'category': focus.isNotEmpty ? _titleCaseSlug(focus) : 'Program',
      'goal': (p['subtitle']?.toString().trim().isNotEmpty == true) ? p['subtitle'].toString() : (focus.isNotEmpty ? _titleCaseSlug(focus) : 'Fitness'),
      'certified': false,
      'rating': rating,
      'students': students,
      'difficulty': level.isNotEmpty ? _titleCaseSlug(level) : 'All',
      '_apiProgram': p,
    };
  }

  static String _titleCaseSlug(String raw) {
    final s = raw.replaceAll('_', ' ').trim();
    if (s.isEmpty) return raw;
    return s.split(' ').map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.length > 1 ? w.substring(1).toLowerCase() : ''}').join(' ');
  }

  static List<Map<String, dynamic>> _parseSectionItems(dynamic response) {
    final out = <Map<String, dynamic>>[];
    if (!_isOk(response)) return out;
    final root = Map<String, dynamic>.from(response);
    final data = root['data'];
    if (data is! Map) return out;
    final dataMap = Map<String, dynamic>.from(data);
    final items = dataMap['data'];
    if (items is! List) return out;
    for (final item in items) {
      if (item is! Map) continue;
      final wrap = Map<String, dynamic>.from(item);
      final prog = wrap['program'];
      if (prog is! Map) continue;
      final card = _cardFromApiProgram(Map<String, dynamic>.from(prog));
      if (wrap['placement'] is Map) {
        card['_placement'] = Map<String, dynamic>.from(wrap['placement'] as Map);
      }
      out.add(card);
    }
    return out;
  }
}
