import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_right/controllers/auth_controller.dart';
import 'package:get_right/models/food_item.dart';
import 'package:get_right/models/meal_entry.dart';
import 'package:get_right/models/nutrition_day.dart';
import 'package:get_right/models/recipe.dart';
import 'package:get_right/repo/recipe_repo.dart';

/// Controller for managing nutrition tracking and recipes
class NutritionController extends GetxController {
  final RecipeRepository _recipeRepo = RecipeRepository();
  Timer? _recipeSearchDebounce;

  static const Map<String, String> recipeSortLabelsToApi = {
    'Most Popular': 'Featured',
    'Highest Protein': 'Protein',
    'Lowest Calories': 'Calories',
    'Quickest to Make': 'PrepTime',
    'Cheapest': 'Cost',
    'Newest': 'Newest',
  };
  // Current selected date
  final Rx<DateTime> selectedDate = DateTime.now().obs;

  /// Subscription status so nutrition tab unlocks immediately after payment.
  final RxBool hasSubscription = false.obs;

  // Nutrition days (indexed by date string)
  final RxMap<String, NutritionDay> nutritionDays = <String, NutritionDay>{}.obs;

  // Saved food items
  final RxList<FoodItem> savedFoodItems = <FoodItem>[].obs;

  // Available recipes
  final RxList<Recipe> recipes = <Recipe>[].obs;

  // Featured recipes
  final RxList<Recipe> featuredRecipes = <Recipe>[].obs;

  // User goals
  final RxDouble calorieGoal = 2000.0.obs;
  final RxDouble proteinGoal = 150.0.obs;
  final RxDouble carbsGoal = 200.0.obs;
  final RxDouble fatsGoal = 65.0.obs;

  // Loading states
  final RxBool isLoading = false.obs;

  /// Donut segment colors from tracker `dailyProgress.legend` (carbs, fat, protein).
  List<Color> trackerDonutColors = const [Color(0xFFFFA726), Color(0xFF9C27B0), Color(0xFF4A90E2)];

  /// Center label calories from analytics API when the last fetch applied to [selectedDate].
  double? trackerCenterCalories;

  /// Macro ring percents from API `[carbs, fat, protein]` when any percent is non-zero.
  List<double>? trackerMacroPercentsFromApi;

  /// Last analytics fetch error for the tracker tab.
  String? trackerFetchError;

  // Recipe filters
  final Rx<RecipeCategory?> selectedCategory = Rx<RecipeCategory?>(null);
  final RxString searchQuery = ''.obs;
  final RxString recipeSort = 'Featured'.obs;
  final RxString recipeSortLabel = 'Most Popular'.obs;
  final RxBool recipesLoading = false.obs;
  final RxBool recipesLoadingMore = false.obs;
  final RxBool featuredRecipesLoading = false.obs;
  final RxString recipesError = ''.obs;
  final RxBool recipesHasMore = false.obs;
  int _recipesPage = 1;
  static const int _recipesPageSize = 10;

  @override
  void onClose() {
    _recipeSearchDebounce?.cancel();
    super.onClose();
  }

  @override
  void onInit() {
    super.onInit();
    refreshSubscription();
    _initializeDemoData();
  }

  /// Nutrition is free for all users.
  void refreshSubscription() {
    hasSubscription.value = true;
    update();
  }

  // Get or create nutrition day for a specific date
  NutritionDay getNutritionDay(DateTime date) {
    final dateKey = _getDateKey(date);
    if (!nutritionDays.containsKey(dateKey)) {
      nutritionDays[dateKey] = NutritionDay(date: date, calorieGoal: calorieGoal.value, proteinGoal: proteinGoal.value, carbsGoal: carbsGoal.value, fatsGoal: fatsGoal.value);
    }
    return nutritionDays[dateKey]!;
  }

  // Get current day's nutrition
  NutritionDay get currentDay => getNutritionDay(selectedDate.value);

  // Add meal entry
  void addMealEntry(MealEntry entry) {
    final dateKey = _getDateKey(entry.timestamp);
    final day = getNutritionDay(entry.timestamp);
    final updatedMeals = List<MealEntry>.from(day.meals)..add(entry);
    nutritionDays[dateKey] = day.copyWith(meals: updatedMeals, clearConsumedOverrides: true);
    _clearTrackerDisplayFields();
    update();
  }

  // Remove meal entry
  void removeMealEntry(String entryId) {
    final dateKey = _getDateKey(selectedDate.value);
    final day = currentDay;
    final updatedMeals = day.meals.where((meal) => meal.id != entryId).toList();
    nutritionDays[dateKey] = day.copyWith(meals: updatedMeals, clearConsumedOverrides: true);
    _clearTrackerDisplayFields();
    update();
  }

  // Update meal entry
  void updateMealEntry(MealEntry entry) {
    final dateKey = _getDateKey(entry.timestamp);
    final day = getNutritionDay(entry.timestamp);
    final updatedMeals = day.meals.map((meal) => meal.id == entry.id ? entry : meal).toList();
    nutritionDays[dateKey] = day.copyWith(meals: updatedMeals, clearConsumedOverrides: true);
    _clearTrackerDisplayFields();
    update();
  }

  void _clearTrackerDisplayFields() {
    trackerCenterCalories = null;
    trackerMacroPercentsFromApi = null;
    trackerFetchError = null;
  }

  // Add food item to saved items
  void saveFoodItem(FoodItem item) {
    final savedItem = item.copyWith(isSaved: true);
    savedFoodItems.add(savedItem);
    update();
  }

  // Remove saved food item
  void removeSavedFoodItem(String itemId) {
    savedFoodItems.removeWhere((item) => item.id == itemId);
    update();
  }

  // Update saved food item
  void updateSavedFoodItem(FoodItem updatedItem) {
    final index = savedFoodItems.indexWhere((item) => item.id == updatedItem.id);
    if (index != -1) {
      savedFoodItems[index] = updatedItem.copyWith(isSaved: true);
      update();
    }
  }

  /// `POST /customer/recipes/purchase` — logs recipe to calorie tracker.
  Future<String?> purchaseRecipeToTracker(Recipe recipe, double servings, MealType mealType) async {
    final recipeId = recipe.id.trim();
    if (recipeId.isEmpty) return 'Invalid recipe';

    try {
      await _recipeRepo.purchaseRecipe(
        recipeId: recipeId,
        mealType: mealType.displayName,
        servings: servings,
      );
      selectToday();
      await fetchNutritionTracker();
      update();
      return null;
    } catch (e) {
      return e.toString().replaceFirst('Exception: ', '');
    }
  }

  Future<bool> updateCalorieGoal(double goal) async {
    if (goal <= 0) return false;
    if (!Get.isRegistered<AuthController>()) return false;

    final saved = await Get.find<AuthController>().updateDailyCalorieGoal(goal.round());
    if (!saved) return false;

    calorieGoal.value = goal;
    final dateKey = _getDateKey(selectedDate.value);
    nutritionDays[dateKey] = getNutritionDay(selectedDate.value).copyWith(calorieGoal: goal);
    update();
    await fetchNutritionTracker();
    return true;
  }

  // Update goals
  void updateGoals({double? calories, double? protein, double? carbs, double? fats}) {
    if (calories != null) calorieGoal.value = calories;
    if (protein != null) proteinGoal.value = protein;
    if (carbs != null) carbsGoal.value = carbs;
    if (fats != null) fatsGoal.value = fats;
    update();
  }

  // Change selected date
  void changeDate(DateTime date) {
    selectedDate.value = date;
    update();
    fetchNutritionTracker();
  }

  /// Select today's local date (used after logging food for the current day).
  void selectToday() {
    final now = DateTime.now();
    selectedDate.value = DateTime(now.year, now.month, now.day);
    update();
  }

  /// Loads `GET /customer/food-logs/analytics` for [selectedDate] via [AuthController].
  Future<void> fetchNutritionTracker() async {
    if (!Get.isRegistered<AuthController>()) return;

    isLoading.value = true;
    trackerFetchError = null;
    update();

    try {
      final dateKey = _getDateKey(selectedDate.value);
      final data = await Get.find<AuthController>().fetchFoodLogAnalytics(date: dateKey, );
      if (data == null) {
        trackerFetchError = 'Could not load nutrition data';
        return;
      }
      _applyFoodLogAnalyticsData(data, dateKey);
    } finally {
      isLoading.value = false;
      update();
    }
  }

  static double _toD(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  static Color _parseHexColor(String? s, Color fallback) {
    if (s == null || s.isEmpty) return fallback;
    var h = s.trim().replaceFirst('#', '');
    if (h.length == 6) h = 'FF$h';
    try {
      return Color(int.parse(h, radix: 16));
    } catch (_) {
      return fallback;
    }
  }

  MealType _mealTypeFromApiLabel(String? label) {
    final normalized = label?.trim().toLowerCase() ?? '';
    for (final type in MealType.values) {
      if (type.displayName.toLowerCase() == normalized || type.name == normalized) {
        return type;
      }
    }
    return MealType.snacks;
  }

  MealEntry _mealEntryFromFoodLogItem(Map<String, dynamic> raw, MealType mealType, DateTime dayDate) {
    final id = raw['_id']?.toString() ?? raw['id']?.toString() ?? raw['foodLogId']?.toString() ?? '';
    final servings = _toD(raw['servings'] == null ? 1.0 : raw['servings']);
    final quantity = servings > 0 ? servings : 1.0;
    final totalCalories = _toD(raw['calories']);
    final macros = raw['macronutrients'];
    var protein = 0.0;
    var carbs = 0.0;
    var fats = 0.0;
    if (macros is Map) {
      protein = _toD(macros['protein']);
      carbs = _toD(macros['carbs']);
      fats = _toD(macros['fats']);
    }
    final loggedAt = raw['loggedAt'] != null ? DateTime.tryParse(raw['loggedAt'].toString()) : null;
    final food = FoodItem(
      id: id,
      name: raw['name']?.toString() ?? '',
      calories: totalCalories / quantity,
      protein: protein / quantity,
      carbs: carbs / quantity,
      fats: fats / quantity,
      defaultServingSize: 1,
      servingUnit: 'serving',
    );
    return MealEntry(
      id: id.isNotEmpty ? id : '${mealType.name}_${food.name.hashCode}',
      foodItem: food,
      quantity: quantity,
      mealType: mealType,
      timestamp: loggedAt ?? dayDate,
      notes: raw['notes']?.toString(),
    );
  }

  void _applyFoodLogAnalyticsData(Map<String, dynamic> data, String dateKey) {
    final dateStr = data['date']?.toString();
    final dayDate = dateStr != null && dateStr.isNotEmpty ? DateTime.tryParse(dateStr) ?? selectedDate.value : selectedDate.value;

    final calories = data['calories'];
    final goalCal = calories is Map ? _toD(calories['goal']) : calorieGoal.value;
    final consumedCal = calories is Map ? _toD(calories['consumed']) : 0.0;

    final macros = data['macronutrients'];
    var pG = 0.0;
    var cG = 0.0;
    var fG = 0.0;
    trackerCenterCalories = consumedCal;
    trackerMacroPercentsFromApi = null;
    if (macros is Map) {
      final carb = macros['carbs'];
      final fat = macros['fats'] ?? macros['fat'];
      final prot = macros['protein'];
      if (carb is Map) cG = _toD(carb['grams']);
      if (fat is Map) fG = _toD(fat['grams']);
      if (prot is Map) pG = _toD(prot['grams']);

      final pc = carb is Map ? _toD(carb['percent']) : 0.0;
      final pf = fat is Map ? _toD(fat['percent']) : 0.0;
      final pp = prot is Map ? _toD(prot['percent']) : 0.0;
      if (pc + pf + pp > 0) {
        trackerMacroPercentsFromApi = [pc, pf, pp];
      }
    }

    final meals = <MealEntry>[];
    final foodLog = data['foodLog'];
    if (foodLog is List) {
      for (final section in foodLog) {
        if (section is! Map) continue;
        final sectionMap = Map<String, dynamic>.from(section);
        final mealType = _mealTypeFromApiLabel(sectionMap['mealType']?.toString());
        final items = sectionMap['items'];
        if (items is! List) continue;
        for (final item in items) {
          if (item is Map<String, dynamic>) {
            meals.add(_mealEntryFromFoodLogItem(item, mealType, dayDate));
          } else if (item is Map) {
            meals.add(_mealEntryFromFoodLogItem(Map<String, dynamic>.from(item), mealType, dayDate));
          }
        }
      }
    }

    nutritionDays[dateKey] = NutritionDay(
      date: dayDate,
      meals: meals,
      calorieGoal: goalCal > 0 ? goalCal : calorieGoal.value,
      proteinGoal: proteinGoal.value,
      carbsGoal: carbsGoal.value,
      fatsGoal: fatsGoal.value,
      consumedCaloriesOverride: consumedCal,
      consumedProteinOverride: pG,
      consumedCarbsOverride: cG,
      consumedFatsOverride: fG,
    );

    calorieGoal.value = nutritionDays[dateKey]!.calorieGoal;
    trackerFetchError = null;
  }

  MealEntry _mealEntryFromCatalogMap(Map<String, dynamic> raw, MealType mealType, DateTime dayDate) {
    final id = raw['_id']?.toString() ?? raw['id']?.toString() ?? '';
    final mealMap = raw['meal'];
    MealType type = mealType;
    if (mealMap is Map) {
      final mt = mealMap['mealType']?.toString();
      if (mt != null && mt.isNotEmpty) {
        type = MealType.values.firstWhere((e) => e.name == mt, orElse: () => mealType);
      }
    }
    final food = FoodItem(
      id: id,
      name: raw['name']?.toString() ?? '',
      calories: _toD(raw['calories']),
      protein: _toD(raw['proteinG'] ?? raw['protein']),
      carbs: _toD(raw['carbsG'] ?? raw['carbs']),
      fats: _toD(raw['fatG'] ?? raw['fats']),
      defaultServingSize: _toD(raw['servingSize'] == null ? 1.0 : raw['servingSize']),
      servingUnit: raw['servingUnit']?.toString() ?? 'serving',
    );
    return MealEntry(
      id: id.isNotEmpty ? id : '${mealType.name}_${food.name.hashCode}',
      foodItem: food,
      quantity: 1,
      mealType: type,
      timestamp: DateTime(dayDate.year, dayDate.month, dayDate.day),
    );
  }

  void _applyNutritionTrackerData(Map<String, dynamic> data, String dateKey) {
    final dateStr = data['date']?.toString();
    final dayDate = dateStr != null && dateStr.isNotEmpty
        ? DateTime.tryParse(dateStr) ?? selectedDate.value
        : selectedDate.value;

    final summary = data['summary'];
    final goalCal = summary is Map ? _toD(summary['goalCalories']) : calorieGoal.value;
    final consumedCal = summary is Map ? _toD(summary['consumedCalories']) : 0.0;

    final dp = data['dailyProgress'];
    double pG = 0, cG = 0, fG = 0;
    trackerCenterCalories = null;
    trackerMacroPercentsFromApi = null;
    if (dp is Map) {
      trackerCenterCalories = _toD(dp['centerCalories']);

      final macros = dp['macros'];
      if (macros is Map) {
        final carb = macros['carbs'];
        final fat = macros['fat'];
        final prot = macros['protein'];
        if (carb is Map) cG = _toD(carb['grams']);
        if (fat is Map) fG = _toD(fat['grams']);
        if (prot is Map) pG = _toD(prot['grams']);

        final pc = carb is Map ? _toD(carb['percent']) : 0.0;
        final pf = fat is Map ? _toD(fat['percent']) : 0.0;
        final pp = prot is Map ? _toD(prot['percent']) : 0.0;
        if (pc + pf + pp > 0) {
          trackerMacroPercentsFromApi = [pc, pf, pp];
        }
      }
      final legend = dp['legend'];
      if (legend is Map) {
        final order = legend['order'];
        final colorsMap = legend['colors'];
        if (order is List && colorsMap is Map) {
          const fallbacks = [Color(0xFFFFA726), Color(0xFF9C27B0), Color(0xFF4A90E2)];
          final cols = <Color>[];
          var idx = 0;
          for (final k in order) {
            if (k is! String) continue;
            final hex = colorsMap[k]?.toString();
            final fi = idx > 2 ? 2 : idx;
            cols.add(_parseHexColor(hex, fallbacks[fi]));
            idx++;
          }
          if (cols.length == 3) {
            trackerDonutColors = cols;
          }
        }
      }
    }

    final meals = <MealEntry>[];
    final catalog = data['foodCatalog'];
    if (catalog is Map) {
      for (final key in const ['breakfast', 'lunch', 'dinner', 'snacks']) {
        final rawList = catalog[key];
        if (rawList is! List) continue;
        MealType mealType;
        switch (key) {
          case 'lunch':
            mealType = MealType.lunch;
            break;
          case 'dinner':
            mealType = MealType.dinner;
            break;
          case 'snacks':
            mealType = MealType.snacks;
            break;
          default:
            mealType = MealType.breakfast;
        }
        for (final e in rawList) {
          if (e is Map<String, dynamic>) {
            meals.add(_mealEntryFromCatalogMap(e, mealType, dayDate));
          } else if (e is Map) {
            meals.add(_mealEntryFromCatalogMap(Map<String, dynamic>.from(e), mealType, dayDate));
          }
        }
      }
    }

    nutritionDays[dateKey] = NutritionDay(
      date: dayDate,
      meals: meals,
      calorieGoal: goalCal > 0 ? goalCal : calorieGoal.value,
      proteinGoal: proteinGoal.value,
      carbsGoal: carbsGoal.value,
      fatsGoal: fatsGoal.value,
      consumedCaloriesOverride: consumedCal,
      consumedProteinOverride: pG,
      consumedCarbsOverride: cG,
      consumedFatsOverride: fG,
    );

    calorieGoal.value = nutritionDays[dateKey]!.calorieGoal;
  }

  // Filter recipes (API-backed list is already filtered server-side).
  List<Recipe> get filteredRecipes => recipes;

  String? _mealTypeForCategory(RecipeCategory? category) {
    switch (category) {
      case RecipeCategory.breakfast:
        return RecipeMealTypes.breakfast;
      case RecipeCategory.lunch:
        return RecipeMealTypes.lunch;
      case RecipeCategory.dinner:
        return RecipeMealTypes.dinner;
      case RecipeCategory.snacks:
        return RecipeMealTypes.snacks;
      case RecipeCategory.highProtein:
      case RecipeCategory.lowCarb:
        return null;
      default:
        return null;
    }
  }

  String? _searchForCategory(RecipeCategory? category) {
    switch (category) {
      case RecipeCategory.highProtein:
        return 'protein';
      case RecipeCategory.lowCarb:
        return 'low carb';
      default:
        return null;
    }
  }

  String? _resolveRecipeSearch() {
    final typed = searchQuery.value.trim();
    if (typed.isNotEmpty) return typed;
    return _searchForCategory(selectedCategory.value);
  }

  Future<void> loadRecipesCatalog({bool refresh = true}) async {
    if (refresh) {
      if (recipesLoading.value) return;
      recipesLoading.value = true;
      _recipesPage = 1;
      recipesError.value = '';
    } else {
      if (recipesLoadingMore.value || !recipesHasMore.value) return;
      recipesLoadingMore.value = true;
    }

    update();

    try {
      final category = selectedCategory.value;
      final mealType = _mealTypeForCategory(category);
      final search = _resolveRecipeSearch();

      final page = await _recipeRepo.fetchCatalog(
        page: _recipesPage,
        limit: _recipesPageSize,
        sort: recipeSort.value,
        search: search,
        mealType: mealType,
      );

      if (refresh) {
        recipes.assignAll(page.recipes);
      } else {
        recipes.addAll(page.recipes);
      }
      recipesHasMore.value = page.hasMore;
      if (page.hasMore) _recipesPage = page.page + 1;
      recipesError.value = '';
    } catch (e) {
      if (refresh) {
        recipes.clear();
        recipesError.value = e.toString().replaceFirst('Exception: ', '');
      }
    } finally {
      recipesLoading.value = false;
      recipesLoadingMore.value = false;
      update();
    }
  }

  Future<void> loadFeaturedRecipes() async {
    if (featuredRecipesLoading.value) return;
    featuredRecipesLoading.value = true;
    update();

    try {
      final page = await _recipeRepo.fetchCatalog(
        page: 1,
        limit: 10,
        sort: 'Featured',
        featured: true,
      );
      featuredRecipes.assignAll(page.recipes);
    } catch (_) {
      featuredRecipes.clear();
    } finally {
      featuredRecipesLoading.value = false;
      update();
    }
  }

  Future<void> refreshRecipesTab() async {
    await Future.wait([
      loadFeaturedRecipes(),
      loadRecipesCatalog(refresh: true),
    ]);
  }

  Future<void> loadMoreRecipes() => loadRecipesCatalog(refresh: false);

  // Set category filter
  void setCategory(RecipeCategory? category) {
    selectedCategory.value = category;
    loadRecipesCatalog(refresh: true);
  }

  // Set search query
  void setSearchQuery(String query) {
    searchQuery.value = query;
    _recipeSearchDebounce?.cancel();
    _recipeSearchDebounce = Timer(const Duration(milliseconds: 400), () {
      loadRecipesCatalog(refresh: true);
    });
    update();
  }

  void submitRecipeSearch() {
    _recipeSearchDebounce?.cancel();
    loadRecipesCatalog(refresh: true);
  }

  void clearRecipeSearch() {
    searchQuery.value = '';
    _recipeSearchDebounce?.cancel();
    loadRecipesCatalog(refresh: true);
    update();
  }

  bool get isRecipeSearchActive => searchQuery.value.trim().isNotEmpty;

  void setRecipeSort(String label) {
    recipeSortLabel.value = label;
    recipeSort.value = recipeSortLabelsToApi[label] ?? 'Featured';
    loadRecipesCatalog(refresh: true);
  }

  // Helper to get date key
  String _getDateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  // Initialize demo data
  void _initializeDemoData() {
    // Demo saved food items
    savedFoodItems.addAll([
      FoodItem(id: '1', name: 'Oatmeal with Berries', calories: 320, protein: 12, carbs: 54, fats: 6, defaultServingSize: 1, servingUnit: 'bowl', isSaved: true),
      FoodItem(id: '2', name: 'Grilled Chicken Breast', calories: 231, protein: 43, carbs: 0, fats: 5, defaultServingSize: 200, servingUnit: 'g', isSaved: true),
      FoodItem(id: '3', name: 'Brown Rice', calories: 216, protein: 5, carbs: 45, fats: 2, defaultServingSize: 1, servingUnit: 'cup', isSaved: true),
      FoodItem(id: '4', name: 'Protein Shake', calories: 120, protein: 24, carbs: 3, fats: 1, defaultServingSize: 1, servingUnit: 'scoop', isSaved: true),
    ]);
  }
}
