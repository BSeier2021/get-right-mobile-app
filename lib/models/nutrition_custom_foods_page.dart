import 'package:get_right/models/food_item.dart';

/// One page from nutrition food list APIs (`/nutrition/foods/custom`, `/customer/food-saves`).
class NutritionCustomFoodsPage {
  final List<FoodItem> items;
  final int total;
  final int page;
  final int perPage;
  final bool? hasNextPage;

  NutritionCustomFoodsPage({
    required this.items,
    required this.total,
    required this.page,
    required this.perPage,
    this.hasNextPage,
  });

  bool get hasMore => hasNextPage ?? (page * perPage < total);
}
