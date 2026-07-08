import 'package:get_right/app_url.dart';
import 'package:get_right/network/network_services.dart';
import 'package:get_right/repo/marketplace_repo.dart';

class FavouritesListPage {
  final List<Map<String, dynamic>> items;
  final int page;
  final int limit;
  final int totalDocs;
  final bool hasNextPage;

  const FavouritesListPage({
    required this.items,
    required this.page,
    required this.limit,
    required this.totalDocs,
    required this.hasNextPage,
  });
}

class FavouritesRepository {
  final _network = NetworkApiService();

  static bool isFavouriteFlag(dynamic raw) {
    if (raw == true) return true;
    if (raw == false) return false;
    if (raw is String) {
      final s = raw.trim().toLowerCase();
      return s == 'true' || s == '1' || s == 'yes';
    }
    if (raw is num) return raw != 0;
    return false;
  }

  static String normalizeType(String type) {
    final t = type.trim().toLowerCase();
    if (t == 'bundle' || t == 'bundles') return 'bundle';
    return 'program';
  }

  static Map<String, dynamic> mapFavouriteRowToUi(Map<String, dynamic> favourite, String type) {
    final normalizedType = normalizeType(type);
    final item = favourite['item'];
    if (item is! Map) return {};
    final raw = Map<String, dynamic>.from(item);

    final Map<String, dynamic> card;
    if (normalizedType == 'bundle') {
      card = MarketplaceRepository.bundleCardFromApi(raw);
    } else {
      card = MarketplaceRepository.programCardFromApi(raw);
    }

    final id = (card['id'] ?? raw['_id'])?.toString() ?? '';
    if (id.isEmpty) return {};

    return {
      ...card,
      'id': id,
      'type': normalizedType,
      'favouriteId': favourite['_id']?.toString(),
      'isFavourite': true,
    };
  }

  Future<FavouritesListPage> fetchFavourites({
    required String type,
    int page = 1,
    int limit = 20,
  }) async {
    final normalizedType = normalizeType(type);
    final raw = await _network.get(AppUrl.customerFavourites(page: page, limit: limit, type: normalizedType));
    if (!_isOk(raw)) {
      throw Exception(_messageFrom(raw) ?? 'Could not load favourites');
    }

    final items = <Map<String, dynamic>>[];
    var totalDocs = 0;
    var hasNextPage = false;

    if (raw is Map) {
      final data = raw['data'];
      if (data is Map) {
        final dm = Map<String, dynamic>.from(data);
        totalDocs = (dm['totalDocs'] as num?)?.toInt() ?? 0;
        hasNextPage = dm['hasNextPage'] == true;
        final list = dm['favourites'];
        if (list is List) {
          for (final row in list) {
            if (row is! Map) continue;
            final mapped = mapFavouriteRowToUi(Map<String, dynamic>.from(row), normalizedType);
            if (mapped.isNotEmpty) items.add(mapped);
          }
        }
      }
    }

    return FavouritesListPage(
      items: items,
      page: page,
      limit: limit,
      totalDocs: totalDocs,
      hasNextPage: hasNextPage,
    );
  }

  Future<void> addFavourite({required String itemId, required String type}) async {
    final body = {
      'itemId': itemId.trim(),
      'type': normalizeType(type),
    };
    final raw = await _network.post(AppUrl.customerFavouritesMutate, body);
    if (!_isOk(raw)) {
      throw Exception(_messageFrom(raw) ?? 'Could not add favourite');
    }
  }

  Future<void> removeFavourite({required String itemId, required String type}) async {
    final body = {
      'itemId': itemId.trim(),
      'type': normalizeType(type),
    };
    final raw = await _network.delete(AppUrl.customerFavouritesMutate, data: body);
    if (!_isOk(raw)) {
      throw Exception(_messageFrom(raw) ?? 'Could not remove favourite');
    }
  }

  static bool _isOk(dynamic response) {
    if (response is! Map) return false;
    final m = Map<String, dynamic>.from(response);
    if (m['success'] == true || m['success'] == 1) return true;
    final st = m['status'];
    return st == 200 || st == '200' || st == 201 || st == '201';
  }

  static String? _messageFrom(dynamic response) {
    if (response is! Map) return null;
    final m = Map<String, dynamic>.from(response);
    final message = m['message'];
    if (message is String) return message;
    if (message is List && message.isNotEmpty) {
      return message.map((e) {
        if (e is Map) {
          final field = e['field']?.toString();
          final msg = e['message']?.toString();
          if (field != null && msg != null) return '$field: $msg';
          return e.toString();
        }
        return e.toString();
      }).join('\n');
    }
    return null;
  }
}
