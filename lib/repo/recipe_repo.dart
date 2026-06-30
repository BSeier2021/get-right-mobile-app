import 'package:get_right/app_url.dart';
import 'package:get_right/models/recipe.dart';
import 'package:get_right/network/network_services.dart';

/// API `mealType` values (`MealTypeEnums`).
abstract final class RecipeMealTypes {
  static const breakfast = 'Breakfast';
  static const lunch = 'Lunch';
  static const dinner = 'Dinner';
  static const snacks = 'Snacks';

  static const all = [breakfast, lunch, dinner, snacks];
}

class RecipesCatalogPage {
  final List<Recipe> recipes;
  final int page;
  final int limit;
  final int total;
  final bool hasMore;

  const RecipesCatalogPage({
    required this.recipes,
    required this.page,
    required this.limit,
    required this.total,
    required this.hasMore,
  });
}

class RecipeRepository {
  final _network = NetworkApiService();

  /// `GET /customer/recipes/catalog`
  Future<RecipesCatalogPage> fetchCatalog({
    int page = 1,
    int limit = 10,
    String? sort,
    String? search,
    String? mealType,
    bool? featured,
  }) async {
    final raw = await _network.get(
      AppUrl.customerRecipesCatalog(
        page: page,
        limit: limit,
        sort: sort,
        search: search,
        mealType: mealType,
        featured: featured,
      ),
    );

    if (!_isOk(raw)) {
      throw Exception(_messageFrom(raw) ?? 'Could not load recipes');
    }

    return _parseCatalogPage(raw, page: page, limit: limit);
  }

  static RecipesCatalogPage _parseCatalogPage(dynamic response, {required int page, required int limit}) {
    final recipes = <Recipe>[];
    var total = 0;
    var hasMore = false;

    if (response is Map) {
      final root = Map<String, dynamic>.from(response);
      final data = root['data'];
      if (data is Map) {
        final dm = Map<String, dynamic>.from(data);
        total = (dm['totalDocs'] as num?)?.toInt() ?? 0;
        hasMore = dm['hasNextPage'] == true;

        final items = dm['recipes'] ?? dm['data'] ?? dm['items'];
        if (items is List) {
          for (final item in items) {
            if (item is Map) {
              recipes.add(Recipe.fromApiJson(Map<String, dynamic>.from(item)));
            }
          }
        }

        if (total == 0) total = recipes.length;
        if (!hasMore && recipes.length == limit) {
          hasMore = page * limit < total;
        }
      }
    }

    return RecipesCatalogPage(recipes: recipes, page: page, limit: limit, total: total, hasMore: hasMore);
  }

  /// `GET /customer/recipes/catalog/:recipeId`
  Future<Recipe> fetchRecipeDetail(String recipeId) async {
    final id = recipeId.trim();
    if (id.isEmpty) throw Exception('Invalid recipe id');

    final raw = await _network.get(AppUrl.customerRecipeById(id));
    if (!_isOk(raw)) {
      throw Exception(_messageFrom(raw) ?? 'Could not load recipe');
    }

    final recipe = _recipeFromDetailResponse(raw);
    if (recipe == null || recipe.id.isEmpty) {
      throw Exception('Invalid recipe response');
    }
    return recipe;
  }

  /// `POST /customer/recipes/purchase`
  Future<void> purchaseRecipe({
    required String recipeId,
    required String mealType,
    required double servings,
  }) async {
    final id = recipeId.trim();
    if (id.isEmpty) throw Exception('Invalid recipe id');

    final raw = await _network.post(
      AppUrl.customerRecipesPurchase,
      {
        'recipeId': id,
        'logToTracker': {
          'mealType': mealType.trim(),
          'servings': servings,
        },
      },
    );

    if (!_isOk(raw)) {
      throw Exception(_messageFrom(raw) ?? 'Could not add recipe to tracker');
    }
  }

  static Recipe? _recipeFromDetailResponse(dynamic response) {
    if (response is! Map) return null;
    final root = Map<String, dynamic>.from(response);
    final data = root['data'];
    if (data is Map) {
      final dm = Map<String, dynamic>.from(data);
      final item = dm['recipe'] ?? dm['data'] ?? dm;
      if (item is Map) return Recipe.fromApiJson(Map<String, dynamic>.from(item));
    }
    if (root.containsKey('_id') || root.containsKey('id') || root.containsKey('name') || root.containsKey('title')) {
      return Recipe.fromApiJson(root);
    }
    return null;
  }

  static bool _isOk(dynamic response) {
    if (response is! Map) return false;
    final m = Map<String, dynamic>.from(response);
    if (m['success'] == true || m['success'] == 1) return true;
    final st = m['status'];
    return st == 200 || st == '200';
  }

  static String? _messageFrom(dynamic response) {
    if (response is! Map) return null;
    final message = Map<String, dynamic>.from(response)['message'];
    if (message is String) return message;
    return null;
  }
}
