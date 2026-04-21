import 'package:get_right/models/food_item.dart';

/// One page from `GET /nutrition/foods/custom` (root `data` array + `meta`).
class NutritionCustomFoodsPage {
  final List<FoodItem> items;
  final int total;
  final int page;
  final int perPage;

  NutritionCustomFoodsPage({
    required this.items,
    required this.total,
    required this.page,
    required this.perPage,
  });

  bool get hasMore => page * perPage < total;
}
