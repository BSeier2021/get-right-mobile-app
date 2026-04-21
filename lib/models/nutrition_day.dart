import 'package:get_right/models/meal_entry.dart';

/// Model for daily nutrition tracking
class NutritionDay {
  final DateTime date;
  final List<MealEntry> meals;
  final double calorieGoal;
  final double proteinGoal;
  final double carbsGoal;
  final double fatsGoal;
  final double? weight; // Optional daily weight
  final String? notes;

  /// When set (from `GET /nutrition/tracker`), totals use API values instead of summing [meals].
  final double? consumedCaloriesOverride;
  final double? consumedProteinOverride;
  final double? consumedCarbsOverride;
  final double? consumedFatsOverride;

  NutritionDay({
    required this.date,
    List<MealEntry>? meals,
    this.calorieGoal = 2000,
    this.proteinGoal = 150,
    this.carbsGoal = 200,
    this.fatsGoal = 65,
    this.weight,
    this.notes,
    this.consumedCaloriesOverride,
    this.consumedProteinOverride,
    this.consumedCarbsOverride,
    this.consumedFatsOverride,
  }) : meals = meals ?? [];

  // Get meals by type
  List<MealEntry> getMealsByType(MealType type) {
    return meals.where((meal) => meal.mealType == type).toList();
  }

  // Calculate total nutrition for the day
  Map<String, double> getTotalNutrition() {
    double totalCalories = 0;
    double totalProtein = 0;
    double totalCarbs = 0;
    double totalFats = 0;

    for (var meal in meals) {
      final nutrition = meal.getTotalNutrition();
      totalCalories += nutrition['calories']!;
      totalProtein += nutrition['protein']!;
      totalCarbs += nutrition['carbs']!;
      totalFats += nutrition['fats']!;
    }

    return {
      'calories': totalCalories,
      'protein': totalProtein,
      'carbs': totalCarbs,
      'fats': totalFats,
    };
  }

  // Getters for total nutrition
  double get totalCalories => consumedCaloriesOverride ?? getTotalNutrition()['calories']!;
  double get totalProtein => consumedProteinOverride ?? getTotalNutrition()['protein']!;
  double get totalCarbs => consumedCarbsOverride ?? getTotalNutrition()['carbs']!;
  double get totalFats => consumedFatsOverride ?? getTotalNutrition()['fats']!;

  // Calculate remaining calories/macros
  double get remainingCalories => calorieGoal - totalCalories;
  double get remainingProtein => proteinGoal - totalProtein;
  double get remainingCarbs => carbsGoal - totalCarbs;
  double get remainingFats => fatsGoal - totalFats;

  // Calculate progress percentages
  double get calorieProgress => (totalCalories / calorieGoal).clamp(0.0, 1.0);
  double get proteinProgress => (totalProtein / proteinGoal).clamp(0.0, 1.0);
  double get carbsProgress => (totalCarbs / carbsGoal).clamp(0.0, 1.0);
  double get fatsProgress => (totalFats / fatsGoal).clamp(0.0, 1.0);

  // Get calories by meal type
  double getCaloriesByMealType(MealType type) {
    return getMealsByType(type).fold(0, (sum, meal) => sum + meal.totalCalories);
  }

  factory NutritionDay.fromJson(Map<String, dynamic> json) {
    return NutritionDay(
      date: DateTime.parse(json['date']),
      meals: (json['meals'] as List<dynamic>?)?.map((m) => MealEntry.fromJson(m)).toList(),
      calorieGoal: (json['calorieGoal'] ?? 2000).toDouble(),
      proteinGoal: (json['proteinGoal'] ?? 150).toDouble(),
      carbsGoal: (json['carbsGoal'] ?? 200).toDouble(),
      fatsGoal: (json['fatsGoal'] ?? 65).toDouble(),
      weight: json['weight']?.toDouble(),
      notes: json['notes'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date.toIso8601String(),
      'meals': meals.map((m) => m.toJson()).toList(),
      'calorieGoal': calorieGoal,
      'proteinGoal': proteinGoal,
      'carbsGoal': carbsGoal,
      'fatsGoal': fatsGoal,
      'weight': weight,
      'notes': notes,
    };
  }

  NutritionDay copyWith({
    DateTime? date,
    List<MealEntry>? meals,
    double? calorieGoal,
    double? proteinGoal,
    double? carbsGoal,
    double? fatsGoal,
    double? weight,
    String? notes,
    double? consumedCaloriesOverride,
    double? consumedProteinOverride,
    double? consumedCarbsOverride,
    double? consumedFatsOverride,
    bool clearConsumedOverrides = false,
  }) {
    return NutritionDay(
      date: date ?? this.date,
      meals: meals ?? this.meals,
      calorieGoal: calorieGoal ?? this.calorieGoal,
      proteinGoal: proteinGoal ?? this.proteinGoal,
      carbsGoal: carbsGoal ?? this.carbsGoal,
      fatsGoal: fatsGoal ?? this.fatsGoal,
      weight: weight ?? this.weight,
      notes: notes ?? this.notes,
      consumedCaloriesOverride: clearConsumedOverrides ? null : (consumedCaloriesOverride ?? this.consumedCaloriesOverride),
      consumedProteinOverride: clearConsumedOverrides ? null : (consumedProteinOverride ?? this.consumedProteinOverride),
      consumedCarbsOverride: clearConsumedOverrides ? null : (consumedCarbsOverride ?? this.consumedCarbsOverride),
      consumedFatsOverride: clearConsumedOverrides ? null : (consumedFatsOverride ?? this.consumedFatsOverride),
    );
  }
}

