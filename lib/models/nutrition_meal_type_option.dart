import 'package:get_right/models/meal_entry.dart';

/// One row from `GET /nutrition/meal-types` → `data.mealTypes[]`.
class NutritionMealTypeOption {
  final String id;
  final String name;
  final String description;
  final String value;
  final String? icon;

  NutritionMealTypeOption({
    required this.id,
    required this.name,
    required this.description,
    required this.value,
    this.icon,
  });

  factory NutritionMealTypeOption.fromJson(Map<String, dynamic> json) {
    return NutritionMealTypeOption(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      value: json['value']?.toString() ?? '',
      icon: json['icon']?.toString(),
    );
  }

  /// Maps API `value` (e.g. `breakfast`) to [MealType], or null if unknown.
  MealType? get mealTypeEnum {
    final v = value.trim().toLowerCase();
    for (final e in MealType.values) {
      if (e.name == v) return e;
    }
    return null;
  }
}
