import 'package:get/get.dart';
import 'package:get_right/repo/favourites_repo.dart';

/// Customer favourites for programs and bundles (`/customer/favourites`).
class FavoritesController extends GetxController {
  final FavouritesRepository _repo = FavouritesRepository();

  final RxList<Map<String, dynamic>> _programFavourites = <Map<String, dynamic>>[].obs;
  final RxList<Map<String, dynamic>> _bundleFavourites = <Map<String, dynamic>>[].obs;
  final RxSet<String> _favouriteProgramIds = <String>{}.obs;
  final RxSet<String> _favouriteBundleIds = <String>{}.obs;

  final RxBool programsLoading = false.obs;
  final RxBool bundlesLoading = false.obs;
  final RxBool programsLoadingMore = false.obs;
  final RxBool bundlesLoadingMore = false.obs;
  final RxnString programsError = RxnString();
  final RxnString bundlesError = RxnString();

  int _programsPage = 1;
  int _bundlesPage = 1;
  bool _programsHasNext = true;
  bool _bundlesHasNext = true;

  static const int _pageSize = 20;

  List<Map<String, dynamic>> get programFavourites => _programFavourites;
  List<Map<String, dynamic>> get bundleFavourites => _bundleFavourites;

  @override
  void onInit() {
    super.onInit();
    loadFavourites(type: 'program', refresh: true);
    loadFavourites(type: 'bundle', refresh: true);
  }

  String _normalizeType(String type) => FavouritesRepository.normalizeType(type);

  RxSet<String> _idsForType(String type) {
    return _normalizeType(type) == 'bundle' ? _favouriteBundleIds : _favouriteProgramIds;
  }

  RxList<Map<String, dynamic>> _listForType(String type) {
    return _normalizeType(type) == 'bundle' ? _bundleFavourites : _programFavourites;
  }

  bool isFavorite(String id, {String type = 'program'}) {
    final trimmed = id.trim();
    if (trimmed.isEmpty) return false;
    return _idsForType(type).contains(trimmed);
  }

  void syncFavoriteFromDetail({required String itemId, required String type, required bool isFavourite}) {
    final id = itemId.trim();
    if (id.isEmpty) return;
    final ids = _idsForType(type);
    if (isFavourite) {
      ids.add(id);
    } else {
      ids.remove(id);
    }
  }

  Future<void> loadFavourites({required String type, bool refresh = false}) async {
    final normalized = _normalizeType(type);
    final loadingFlag = normalized == 'bundle' ? bundlesLoading : programsLoading;
    final loadingMoreFlag = normalized == 'bundle' ? bundlesLoadingMore : programsLoadingMore;
    final errorFlag = normalized == 'bundle' ? bundlesError : programsError;
    final list = _listForType(normalized);
    final ids = _idsForType(normalized);

    if (refresh) {
      if (normalized == 'bundle') {
        _bundlesPage = 1;
        _bundlesHasNext = true;
      } else {
        _programsPage = 1;
        _programsHasNext = true;
      }
      loadingFlag.value = true;
      errorFlag.value = null;
    } else {
      final hasNext = normalized == 'bundle' ? _bundlesHasNext : _programsHasNext;
      if (!hasNext || loadingFlag.value || loadingMoreFlag.value) return;
      loadingMoreFlag.value = true;
    }

    final page = normalized == 'bundle' ? _bundlesPage : _programsPage;

    try {
      final result = await _repo.fetchFavourites(type: normalized, page: page, limit: _pageSize);
      if (refresh) {
        list.clear();
        ids.clear();
      }
      list.addAll(result.items);
      for (final item in result.items) {
        final id = item['id']?.toString();
        if (id != null && id.isNotEmpty) ids.add(id);
      }
      if (normalized == 'bundle') {
        _bundlesHasNext = result.hasNextPage;
        _bundlesPage = page + 1;
      } else {
        _programsHasNext = result.hasNextPage;
        _programsPage = page + 1;
      }
      errorFlag.value = null;
    } catch (e) {
      errorFlag.value = e.toString();
    } finally {
      loadingFlag.value = false;
      loadingMoreFlag.value = false;
    }
  }

  List<Map<String, dynamic>> getFavoritesByType(String type) {
    return List<Map<String, dynamic>>.from(_listForType(type));
  }

  Future<bool> toggleFavorite(
    String itemId, {
    required String type,
    Map<String, dynamic>? itemSnapshot,
  }) async {
    final id = itemId.trim();
    if (id.isEmpty) return false;

    final normalized = _normalizeType(type);
    final wasFavorite = isFavorite(id, type: normalized);
    final list = _listForType(normalized);
    final ids = _idsForType(normalized);
    Map<String, dynamic>? removedItem;
    int removedIndex = -1;

    if (wasFavorite) {
      removedIndex = list.indexWhere((e) => (e['id'] ?? '').toString() == id);
      if (removedIndex >= 0) removedItem = Map<String, dynamic>.from(list[removedIndex]);
      ids.remove(id);
      list.removeWhere((e) => (e['id'] ?? '').toString() == id);
    } else {
      ids.add(id);
      if (itemSnapshot != null) {
        final snap = Map<String, dynamic>.from(itemSnapshot);
        snap['id'] = id;
        snap['type'] = normalized;
        snap['isFavourite'] = true;
        list.add(snap);
      }
    }

    try {
      if (wasFavorite) {
        await _repo.removeFavourite(itemId: id, type: normalized);
      } else {
        await _repo.addFavourite(itemId: id, type: normalized);
      }
      return true;
    } catch (e) {
      if (wasFavorite) {
        ids.add(id);
        if (removedItem != null) {
          if (removedIndex >= 0 && removedIndex <= list.length) {
            list.insert(removedIndex, removedItem);
          } else {
            list.add(removedItem);
          }
        }
      } else {
        ids.remove(id);
        list.removeWhere((item) => (item['id'] ?? '').toString() == id);
      }
      rethrow;
    }
  }

  Future<bool> removeFavorite(String itemId, {String type = 'program'}) {
    return toggleFavorite(itemId, type: type);
  }
}
