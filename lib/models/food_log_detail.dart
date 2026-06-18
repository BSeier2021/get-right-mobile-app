import 'package:get_right/models/food_item.dart';

/// Single food log entry from `GET /customer/food-logs/:foodLogId`.
class FoodLogDetail {
  final String id;
  final String mealType;
  final FoodItem meal;
  final DateTime loggedAt;
  final double servings;
  final double calories;
  final double protein;
  final double carbs;
  final double fats;
  final String? notes;

  const FoodLogDetail({
    required this.id,
    required this.mealType,
    required this.meal,
    required this.loggedAt,
    required this.servings,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fats,
    this.notes,
  });

  static double _toD(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  factory FoodLogDetail.fromApi(Map<String, dynamic> json) {
    final mealRaw = json['meal'];
    FoodItem meal;
    if (mealRaw is Map<String, dynamic>) {
      meal = FoodItem.fromFoodSaveApi(mealRaw);
    } else if (mealRaw is Map) {
      meal = FoodItem.fromFoodSaveApi(Map<String, dynamic>.from(mealRaw));
    } else {
      meal = FoodItem(id: '', name: 'Unknown food', calories: 0, protein: 0, carbs: 0, fats: 0);
    }

    final macros = json['macronutrients'];
    var protein = 0.0;
    var carbs = 0.0;
    var fats = 0.0;
    if (macros is Map) {
      protein = _toD(macros['protein']);
      carbs = _toD(macros['carbs']);
      fats = _toD(macros['fats']);
    }

    return FoodLogDetail(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      mealType: json['mealType']?.toString() ?? '',
      meal: meal,
      loggedAt: DateTime.tryParse(json['loggedAt']?.toString() ?? '') ?? DateTime.now(),
      servings: _toD(json['servings'] == null ? 1 : json['servings']),
      calories: _toD(json['calories']),
      protein: protein,
      carbs: carbs,
      fats: fats,
      notes: json['notes']?.toString(),
    );
  }
}
