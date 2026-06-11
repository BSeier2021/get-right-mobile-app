import 'package:intl/intl.dart';

import 'package:get_right/app_url.dart';
import 'package:get_right/models/exercise_category_option.dart';
import 'package:get_right/models/exercise_detail.dart';
import 'package:get_right/models/exercise_library_category.dart';
import 'package:get_right/models/exercise_library_item.dart';
import 'package:get_right/models/exercise_library_model.dart';
import 'package:get_right/network/network_services.dart';
import 'package:get_right/utils/bundle_card_mapper.dart';
import 'package:get_right/utils/image_url_sanitizer.dart';

/// One page from `GET /customer/program/:id/reviews`.
class ProgramReviewsPage {
  final List<Map<String, dynamic>> reviews;
  final int total;
  final int page;
  final bool hasMore;
  final double? ratingAvg;
  final int? ratingCount;

  const ProgramReviewsPage({
    required this.reviews,
    required this.total,
    required this.page,
    required this.hasMore,
    this.ratingAvg,
    this.ratingCount,
  });
}

/// Query params for `GET /customer/program` (browse / filter).
class CustomerProgramsQuery {
  final int page;
  final int limit;
  final String? type;
  final String? sort;
  final List<String> categories;
  final List<String> difficulties;
  final int? durationMin;
  final int? durationMax;
  final bool certifiedOnly;
  final String? title;

  const CustomerProgramsQuery({
    this.page = 1,
    this.limit = 10,
    this.type,
    this.sort,
    this.categories = const [],
    this.difficulties = const [],
    this.durationMin,
    this.durationMax,
    this.certifiedOnly = false,
    this.title,
  });
}

/// Query `type` values supported by `GET /customer/program`.
abstract final class MarketplaceSection {
  static const String featured = 'Featured';
  static const String newReleases = 'New';
  static const String all = 'All';
}

/// One page from `GET /customer/bundle`.
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

/// One page from `GET /customer/program`.
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

/// `GET /customer/program` — paginated programs per `type`.
class MarketplaceRepository {
  final _network = NetworkApiService();

  Future<List<Map<String, dynamic>>> fetchSectionPrograms({
    required String type,
    int page = 1,
    int perPage = 10,
  }) async {
    final url = AppUrl.customerPrograms(page: page, limit: perPage, type: type);
    final raw = await _network.get(url);
    return _parseProgramsList(raw);
  }

  /// Guest token headers for `/user/exercise-categories` (Bearer JWT returns 410).
  static Map<String, String> get _exerciseCategoryAuthHeaders => {
        'skipAuth': 'true',
        'Authorization': NetworkApiService.guestAuthToken,
      };

  /// `GET /user/exercise-categories` → paginated library categories.
  Future<ExerciseCategoriesPage> fetchExerciseCategoriesPage({int page = 1, int limit = 50}) async {
    const empty = ExerciseCategoriesPage(categories: [], total: 0, page: 1, hasMore: false);
    final raw = await _network.get(
      AppUrl.exerciseCategories(page: page, limit: limit),
      headers: _exerciseCategoryAuthHeaders,
    );
    if (!_isOk(raw)) return empty;

    final items = _exerciseCategoryItemsFromResponse(raw);
    if (items == null) return empty;

    final categories = <ExerciseLibraryCategory>[];
    for (final item in items) {
      if (item is! Map) continue;
      final cat = ExerciseLibraryCategory.fromJson(Map<String, dynamic>.from(item));
      if (cat.id.isNotEmpty && cat.name.isNotEmpty) categories.add(cat);
    }

    final root = Map<String, dynamic>.from(raw as Map);
    final data = root['data'];
    var total = categories.length;
    var currentPage = page;
    var hasMore = false;

    if (data is Map) {
      final m = Map<String, dynamic>.from(data);
      final result = m['result'];
      if (result is Map) {
        final rm = Map<String, dynamic>.from(result);
        total = (rm['totalDocs'] as num?)?.toInt() ?? total;
        currentPage = (rm['currentPage'] as num?)?.toInt() ?? page;
        final hasNext = rm['hasNextPage'];
        hasMore = hasNext == true || (categories.length == limit && (currentPage * limit) < total);
      } else {
        total = (m['totalDocs'] as num?)?.toInt() ?? total;
        final hasNext = m['hasNextPage'];
        hasMore = hasNext == true;
      }
    }

    return ExerciseCategoriesPage(categories: categories, total: total, page: currentPage, hasMore: hasMore);
  }

  /// `GET /user/exercise-categories` → category chips for filters.
  Future<List<ExerciseCategoryOption>> fetchExerciseCategories() async {
    final page = await fetchExerciseCategoriesPage(page: 1, limit: 100);
    return page.categories.map((c) => ExerciseCategoryOption(id: c.id, name: c.name)).toList();
  }

  /// `GET /user/exercises/` → paginated exercises for journal exercise selection.
  Future<UserExercisesPage> fetchUserExercisesPage({int page = 1, int limit = 50}) async {
    const empty = UserExercisesPage(exercises: [], total: 0, page: 1, hasMore: false);
    final raw = await _network.get(
      AppUrl.userExercises(page: page, limit: limit),
      headers: _exerciseCategoryAuthHeaders,
    );
    if (!_isOk(raw)) return empty;

    final items = _exercisesByCategoryItemsFromResponse(raw);
    if (items == null) return empty;

    final exercises = <ExerciseLibraryModel>[];
    for (final item in items) {
      if (item is! Map) continue;
      final ex = ExerciseLibraryModel.fromApiJson(Map<String, dynamic>.from(item));
      if (ex.id.isNotEmpty && ex.name.isNotEmpty) exercises.add(ex);
    }

    final root = Map<String, dynamic>.from(raw as Map);
    final data = root['data'];
    var total = exercises.length;
    var currentPage = page;
    var hasMore = false;

    if (data is Map) {
      final m = Map<String, dynamic>.from(data);
      final result = m['result'];
      if (result is Map) {
        final rm = Map<String, dynamic>.from(result);
        total = (rm['totalDocs'] as num?)?.toInt() ?? total;
        currentPage = (rm['currentPage'] as num?)?.toInt() ?? page;
        final hasNext = rm['hasNextPage'];
        hasMore = hasNext == true || (exercises.length == limit && (currentPage * limit) < total);
      } else {
        total = (m['totalDocs'] as num?)?.toInt() ?? total;
        hasMore = m['hasNextPage'] == true;
      }
    }

    return UserExercisesPage(exercises: exercises, total: total, page: currentPage, hasMore: hasMore);
  }

  /// `GET /user/exercises/category/:categoryId` → paginated exercises for library detail.
  Future<ExercisesByCategoryPage> fetchExercisesByCategoryPage({
    required String categoryId,
    int page = 1,
    int limit = 20,
  }) async {
    const empty = ExercisesByCategoryPage(exercises: [], total: 0, page: 1, hasMore: false);
    final id = categoryId.trim();
    if (id.isEmpty) return empty;

    final raw = await _network.get(
      AppUrl.exerciseCategory(id, page: page, limit: limit),
      headers: _exerciseCategoryAuthHeaders,
    );
    if (!_isOk(raw)) return empty;

    final items = _exercisesByCategoryItemsFromResponse(raw);
    if (items == null) return empty;

    final exercises = <ExerciseLibraryItem>[];
    for (final item in items) {
      if (item is! Map) continue;
      final ex = ExerciseLibraryItem.fromJson(Map<String, dynamic>.from(item));
      if (ex.id.isNotEmpty && ex.name.isNotEmpty) exercises.add(ex);
    }

    final root = Map<String, dynamic>.from(raw as Map);
    final data = root['data'];
    var total = exercises.length;
    var currentPage = page;
    var hasMore = false;

    if (data is Map) {
      final m = Map<String, dynamic>.from(data);
      final result = m['result'];
      if (result is Map) {
        final rm = Map<String, dynamic>.from(result);
        total = (rm['totalDocs'] as num?)?.toInt() ?? total;
        currentPage = (rm['currentPage'] as num?)?.toInt() ?? page;
        final hasNext = rm['hasNextPage'];
        hasMore = hasNext == true || (exercises.length == limit && (currentPage * limit) < total);
      } else {
        total = (m['totalDocs'] as num?)?.toInt() ?? total;
        hasMore = m['hasNextPage'] == true;
      }
    }

    return ExercisesByCategoryPage(exercises: exercises, total: total, page: currentPage, hasMore: hasMore);
  }

  /// `GET /user/exercises/:exerciseId` → full exercise detail for library.
  Future<ExerciseDetail> fetchExerciseDetail(String exerciseId) async {
    final id = exerciseId.trim();
    if (id.isEmpty) throw Exception('Invalid exercise id');

    final raw = await _network.get(
      AppUrl.exerciseDetail(id),
      headers: _exerciseCategoryAuthHeaders,
    );
    if (!_isOk(raw)) throw Exception('Could not load exercise');

    final detail = ExerciseDetail.fromApiResponse(raw);
    if (detail == null || detail.id.isEmpty || detail.name.isEmpty) {
      throw Exception('Invalid exercise response');
    }
    return detail;
  }

  static List<dynamic>? _exercisesByCategoryItemsFromResponse(dynamic response) {
    if (response is! Map) return null;
    final root = Map<String, dynamic>.from(response);
    final data = root['data'];
    if (data is! Map) return null;
    final m = Map<String, dynamic>.from(data);

    final result = m['result'];
    if (result is Map) {
      final rm = Map<String, dynamic>.from(result);
      if (rm['exercises'] is List) return rm['exercises'] as List<dynamic>;
    }
    if (m['exercises'] is List) return m['exercises'] as List<dynamic>;
    return null;
  }

  static List<dynamic>? _exerciseCategoryItemsFromResponse(dynamic response) {
    if (response is! Map) return null;
    final root = Map<String, dynamic>.from(response);
    final data = root['data'];
    if (data is! Map) return null;
    final m = Map<String, dynamic>.from(data);

    final result = m['result'];
    if (result is Map) {
      final rm = Map<String, dynamic>.from(result);
      if (rm['categories'] is List) return rm['categories'] as List<dynamic>;
    }
    if (m['categories'] is List) return m['categories'] as List<dynamic>;
    if (m['data'] is List) return m['data'] as List<dynamic>;
    return null;
  }

  /// `GET /customer/program` — browse list with optional filters ([query]).
  Future<MarketplaceProgramsPage> fetchBrowsePrograms({
    int page = 1,
    int perPage = 10,
    CustomerProgramsQuery? query,
  }) async {
    final q = query ?? const CustomerProgramsQuery();
    final raw = await _network.get(
      AppUrl.customerPrograms(
        page: page,
        limit: perPage,
        type: q.type,
        sort: q.sort,
        categories: q.categories,
        difficulties: q.difficulties,
        durationMin: q.durationMin,
        durationMax: q.durationMax,
        certifiedOnly: q.certifiedOnly ? true : null,
        title: q.title,
      ),
    );
    return _parseBrowseProgramsPage(raw, page, perPage);
  }

  /// `GET /customer/bundle` — [programCatalog] resolves `programs: [_id, …]` into card rows (e.g. browse programs).
  Future<MarketplaceBundlesPage> fetchBrowseBundles({
    int page = 1,
    int perPage = 10,
    List<Map<String, dynamic>> programCatalog = const [],
  }) async {
    final raw = await _network.get(AppUrl.customerBundles(page: page, limit: perPage));
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
    final List<dynamic>? items = dataMap['bundles'] is List
        ? dataMap['bundles'] as List<dynamic>
        : (dataMap['data'] is List ? dataMap['data'] as List<dynamic> : null);
    if (items == null) {
      return MarketplaceBundlesPage(bundles: bundles, page: page, perPage: perPage, total: 0, hasMore: false);
    }
    for (final item in items) {
      if (item is! Map) continue;
      bundles.add(_bundleCardFromApi(Map<String, dynamic>.from(item), programCatalog));
    }
    int total = (dataMap['totalDocs'] as num?)?.toInt() ?? bundles.length;
    final meta = dataMap['meta'];
    if (meta is Map) {
      total = (Map<String, dynamic>.from(meta)['total'] as num?)?.toInt() ?? total;
    }
    final bool? hasNext = dataMap['hasNextPage'] is bool ? dataMap['hasNextPage'] as bool : null;
    final hasMore = hasNext ?? (bundles.length == perPage && (page * perPage) < total);
    return MarketplaceBundlesPage(bundles: bundles, page: page, perPage: perPage, total: total, hasMore: hasMore);
  }

  static final RegExp _mongoIdRe = RegExp(r'^[a-fA-F0-9]{24}$');

  /// Trainer display name from API trainer node, optional `display` map, or plain string.
  static String trainerDisplayName({
    dynamic trainer,
    Map<String, dynamic>? display,
    String fallback = 'Trainer',
  }) {
    if (display != null) {
      final instructor = display['instructor_name']?.toString().trim();
      if (instructor != null && instructor.isNotEmpty) return instructor;
    }
    if (trainer is String) {
      final s = trainer.trim();
      if (s.isNotEmpty && s.toLowerCase() != 'trainer' && !_mongoIdRe.hasMatch(s)) return s;
    }
    if (trainer is Map) {
      final t = Map<String, dynamic>.from(trainer);
      final name = t['name']?.toString().trim();
      if (name != null && name.isNotEmpty && name.toLowerCase() != 'trainer') return name;
      final prof = t['profile'];
      if (prof is Map) {
        final fn = prof['fullName']?.toString().trim();
        if (fn != null && fn.isNotEmpty) return fn;
      }
    }
    return fallback;
  }

  static String initialsFromName(String name) => _initials(name);

  /// Parses week count from num or strings like `"12 weeks"`.
  static int durationWeeksFrom(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.toInt();
    final s = value.toString().trim();
    if (s.isEmpty || s == '—') return 0;
    final direct = int.tryParse(s);
    if (direct != null && direct > 0) return direct;
    final match = RegExp(r'(\d+)').firstMatch(s);
    if (match != null) {
      final parsed = int.tryParse(match.group(1)!);
      if (parsed != null && parsed > 0) return parsed;
    }
    return 0;
  }

  static DateTime? endDateFromStartAndWeeks(DateTime? start, dynamic durationWeeks) {
    final weeks = durationWeeksFrom(durationWeeks);
    if (start == null || weeks <= 0) return null;
    return start.add(Duration(days: weeks * 7));
  }

  static String? trainerAvatarUrlFromApiNode(dynamic trainer) {
    if (trainer is! Map) return null;
    final t = Map<String, dynamic>.from(trainer);
    final pic = t['profilePicture'];
    if (pic is Map) {
      return ImageUrlSanitizer.asHttpUrlOrNull(pic['url']?.toString());
    }
    final prof = t['profile'];
    if (prof is Map) {
      final profPic = prof['profilePicture'];
      if (profPic is Map) {
        return ImageUrlSanitizer.asHttpUrlOrNull(profPic['url']?.toString());
      }
    }
    return ImageUrlSanitizer.asHttpUrlOrNull(t['profilePictureUrl']?.toString());
  }

  static String _trainerNameFromBundleApi(Map<String, dynamic> b) {
    return trainerDisplayName(trainer: b['trainer']);
  }

  static String? _trainerAvatarUrlFromBundleApi(Map<String, dynamic> b) {
    final tr = b['trainer'];
    if (tr is! Map) return null;
    final t = Map<String, dynamic>.from(tr);
    final pic = t['profilePicture'];
    if (pic is Map) {
      return ImageUrlSanitizer.asHttpUrlOrNull(pic['url']?.toString());
    }
    final prof = t['profile'];
    if (prof is Map) {
      final profPic = prof['profilePicture'];
      if (profPic is Map) {
        return ImageUrlSanitizer.asHttpUrlOrNull(profPic['url']?.toString());
      }
    }
    return ImageUrlSanitizer.asHttpUrlOrNull(t['profilePictureUrl']?.toString());
  }

  static String? _bundleImageUrlFromApi(Map<String, dynamic> b) {
    final direct = ImageUrlSanitizer.asHttpUrlOrNull(b['coverImageUrl']?.toString());
    if (direct != null && direct.isNotEmpty) return direct;
    final th = b['thumbnail'];
    if (th is Map) {
      return ImageUrlSanitizer.asHttpUrlOrNull(th['url']?.toString());
    }
    return null;
  }

  static Map<String, dynamic> _bundleCardFromApi(Map<String, dynamic> b, List<Map<String, dynamic>> programCatalog) {
    final bundleId = b['_id']?.toString() ?? '';
    final bundleCertified = b['isCertified'] == true;
    final trainerName = _trainerNameFromBundleApi(b);
    final trainerAvatarUrl = _trainerAvatarUrlFromBundleApi(b);
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
            'trainer': trainerName,
            'trainerImage': _initials(trainerName),
            if (trainerAvatarUrl != null) 'trainerImageUrl': trainerAvatarUrl,
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

    final pricing = resolveBundlePricingFromApi(b);
    final totalValue = (pricing['totalValue'] as num?)?.toDouble() ?? 0.0;
    final bundlePrice = (pricing['bundlePrice'] as num?)?.toDouble() ?? 0.0;
    final discount = (pricing['discount'] as num?)?.toInt() ?? 0;

    return {
      'id': bundleId,
      'title': b['title']?.toString() ?? '',
      'subtitle': b['subtitle'],
      'description': b['description']?.toString() ?? '',
      'discount': discount,
      'totalValue': totalValue,
      'bundlePrice': bundlePrice,
      'imageUrl': _bundleImageUrlFromApi(b) ?? '',
      'trainer': trainerName,
      'trainerImage': _initials(trainerName),
      if (trainerAvatarUrl != null) 'trainerImageUrl': trainerAvatarUrl,
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
    final items = dataMap['programs'] is List
        ? dataMap['programs']
        : dataMap['data'];
    if (items is! List) {
      return MarketplaceProgramsPage(programs: programs, page: page, perPage: perPage, total: 0, hasMore: false);
    }
    for (final item in items) {
      if (item is! Map) continue;
      programs.add(_cardFromBrowseProgram(Map<String, dynamic>.from(item)));
    }
    int total = (dataMap['totalDocs'] as num?)?.toInt() ?? programs.length;
    final meta = dataMap['meta'];
    if (meta is Map) {
      final mm = Map<String, dynamic>.from(meta);
      total = (mm['total'] as num?)?.toInt() ?? total;
    }
    final bool? hasNext = dataMap['hasNextPage'] is bool ? dataMap['hasNextPage'] as bool : null;
    final hasMore = hasNext ?? (programs.length == perPage && (page * perPage) < total);
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
    final weeks = durationWeeksFrom(p['durationWeeks'] ?? p['duration']);
    final duration = weeks > 0 ? '$weeks weeks' : (p['duration']?.toString().trim().isNotEmpty == true ? p['duration'].toString() : '—');
    final focus = p['focus']?.toString() ?? '';
    final level = p['level']?.toString() ?? '';
    final t = p['trainer'];
    final trainer = trainerDisplayName(trainer: t, display: display);
    String? trainerMongoId;
    if (t is Map) {
      trainerMongoId = t['_id']?.toString().trim();
      if (trainerMongoId != null && trainerMongoId.isEmpty) trainerMongoId = null;
    }
    String? imageUrl = ImageUrlSanitizer.asHttpUrlOrNull(p['coverImageUrl']?.toString());
    imageUrl ??= () {
      final promo = p['promoMedia'];
      if (promo is Map) return ImageUrlSanitizer.asHttpUrlOrNull(promo['url']?.toString());
      return null;
    }();

    String? trainerAvatarUrl = ImageUrlSanitizer.asHttpUrlOrNull(display['instructor_avatar_url']?.toString());
    if (trainerAvatarUrl == null && t is Map) {
      final pic = t['profilePicture'];
      if (pic is Map) {
        trainerAvatarUrl = ImageUrlSanitizer.asHttpUrlOrNull(pic['url']?.toString());
      }
      if (trainerAvatarUrl == null) {
        final prof = t['profile'];
        if (prof is Map) {
          final profPic = prof['profilePicture'];
          if (profPic is Map) {
            trainerAvatarUrl = ImageUrlSanitizer.asHttpUrlOrNull(profPic['url']?.toString());
          }
        }
      }
    }

    return {
      'id': p['_id']?.toString(),
      'title': p['title']?.toString() ?? '',
      'subtitle': p['subtitle'],
      'description': p['description']?.toString() ?? '',
      'imageUrl': imageUrl,
      'trainer': trainer,
      if (trainerMongoId != null) 'trainerId': trainerMongoId,
      'trainerImage': _initials(trainer),
      if (trainerAvatarUrl != null) 'trainerImageUrl': trainerAvatarUrl,
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

  static List<Map<String, dynamic>> _parseProgramsList(dynamic response) {
    final out = <Map<String, dynamic>>[];
    if (!_isOk(response)) return out;
    final root = Map<String, dynamic>.from(response);
    final data = root['data'];
    if (data is! Map) return out;
    final dataMap = Map<String, dynamic>.from(data);
    final items = dataMap['programs'] is List
        ? dataMap['programs']
        : dataMap['data'];
    if (items is! List) return out;
    for (final item in items) {
      if (item is! Map) continue;
      final map = Map<String, dynamic>.from(item);
      final prog = map['program'] is Map ? Map<String, dynamic>.from(map['program'] as Map) : map;
      final card = _cardFromApiProgram(prog);
      if (map['placement'] is Map) {
        card['_placement'] = Map<String, dynamic>.from(map['placement'] as Map);
      }
      out.add(card);
    }
    return out;
  }

  /// `GET /customer/program/:programId/reviews`.
  Future<ProgramReviewsPage> fetchProgramReviews(String programId, {int page = 1, int limit = 10}) async {
    final raw = await _network.get(AppUrl.customerProgramReviews(programId, page: page, limit: limit));
    return _parseProgramReviewsPage(raw, page, limit);
  }

  /// `POST /customer/program/:programId/reviews`. Returns `null` on success, or an error message.
  Future<String?> submitProgramReview({
    required String programId,
    required int rating,
    required String description,
  }) async {
    final raw = await _network.post(
      AppUrl.customerProgramReviewsSubmit(programId),
      {'rating': rating, 'description': description.trim()},
    );
    if (_isOk(raw)) return null;
    return _apiErrorMessage(raw, 'Could not submit review');
  }

  /// `PUT /customer/program/:programId/reviews`. Returns `null` on success.
  Future<String?> updateProgramReview({
    required String programId,
    required int rating,
    required String description,
  }) async {
    final raw = await _network.put(
      AppUrl.customerProgramReviewsSubmit(programId),
      {'rating': rating, 'description': description.trim()},
    );
    if (_isOk(raw)) return null;
    return _apiErrorMessage(raw, 'Could not update review');
  }

  /// `DELETE /customer/program/:programId/reviews`. Returns `null` on success.
  Future<String?> deleteProgramReview({
    required String programId,
  }) async {
    final raw = await _network.delete(AppUrl.customerProgramReviewsSubmit(programId));
    if (_isOk(raw)) return null;
    return _apiErrorMessage(raw, 'Could not delete review');
  }

  static String? _apiErrorMessage(dynamic raw, String fallback) {
    if (raw is Map) {
      final root = Map<String, dynamic>.from(raw);
      final msg = root['message'];
      if (msg is List && msg.isNotEmpty) {
        return msg.map((e) => e is Map ? (e['message'] ?? e).toString() : e.toString()).join('; ');
      }
      return msg?.toString() ?? fallback;
    }
    return fallback;
  }

  static ProgramReviewsPage _parseProgramReviewsPage(dynamic response, int page, int limit) {
    const empty = ProgramReviewsPage(reviews: [], total: 0, page: 1, hasMore: false);
    if (!_isOk(response)) return empty;
    final root = Map<String, dynamic>.from(response as Map);
    final data = root['data'];
    if (data is! Map) return empty;
    final dataMap = Map<String, dynamic>.from(data);

    final summary = dataMap['summary'];
    double? ratingAvg;
    int? ratingCount;
    if (summary is Map) {
      final sm = Map<String, dynamic>.from(summary);
      ratingAvg = (sm['ratingAvg'] as num?)?.toDouble();
      ratingCount = (sm['ratingCount'] as num?)?.toInt();
    }

    final items = dataMap['reviews'];
    final reviews = <Map<String, dynamic>>[];
    if (items is List) {
      for (final item in items) {
        if (item is! Map) continue;
        reviews.add(_reviewCardFromApi(Map<String, dynamic>.from(item)));
      }
    }

    int total = (dataMap['totalDocs'] as num?)?.toInt() ?? reviews.length;
    final bool? hasNext = dataMap['hasNextPage'] is bool ? dataMap['hasNextPage'] as bool : null;
    final hasMore = hasNext ?? (reviews.length == limit && (page * limit) < total);

    return ProgramReviewsPage(
      reviews: reviews,
      total: total,
      page: page,
      hasMore: hasMore,
      ratingAvg: ratingAvg,
      ratingCount: ratingCount,
    );
  }

  static Map<String, dynamic> _reviewCardFromApi(Map<String, dynamic> r) {
    var name = 'User';
    var initials = 'U';
    String? avatarUrl;

    final user = r['user'];
    if (user is Map) {
      final um = Map<String, dynamic>.from(user);
      final prof = um['profile'];
      if (prof is Map) {
        final pm = Map<String, dynamic>.from(prof);
        final fn = pm['fullName']?.toString().trim();
        if (fn != null && fn.isNotEmpty) name = fn;
        final pic = pm['profilePicture'];
        if (pic is Map) {
          avatarUrl = ImageUrlSanitizer.asHttpUrlOrNull(pic['url']?.toString());
        }
      }
      if (name == 'User') {
        final email = um['email']?.toString().trim();
        if (email != null && email.isNotEmpty) {
          name = email.split('@').first;
        }
      }
    }

    final parts = name.split(RegExp(r'[\s_\-]+')).where((s) => s.isNotEmpty).toList();
    if (parts.length >= 2) {
      initials = '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    } else if (parts.isNotEmpty) {
      final s = parts[0];
      initials = s.length >= 2 ? s.substring(0, 2).toUpperCase() : s[0].toUpperCase();
    }

    final rating = (r['rating'] as num?)?.toInt() ?? 0;
    final comment = (r['description'] ?? r['comment'] ?? '').toString();

    var dateLabel = '';
    final created = r['createdAt']?.toString();
    if (created != null && created.isNotEmpty) {
      final dt = DateTime.tryParse(created);
      if (dt != null) {
        dateLabel = DateFormat.yMMMd().format(dt.toLocal());
      }
    }

    final userId = user is Map ? (user['_id'] ?? user['id'])?.toString() : null;

    return {
      'id': r['_id']?.toString(),
      if (userId != null && userId.isNotEmpty) 'userId': userId,
      'userName': name,
      'userInitials': initials,
      if (avatarUrl != null) 'avatarUrl': avatarUrl,
      'rating': rating,
      'comment': comment,
      'date': dateLabel,
    };
  }
}
