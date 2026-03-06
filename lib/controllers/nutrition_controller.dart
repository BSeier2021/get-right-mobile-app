import 'package:get/get.dart';
import 'package:get_right/models/food_item.dart';
import 'package:get_right/models/meal_entry.dart';
import 'package:get_right/models/nutrition_day.dart';
import 'package:get_right/models/recipe.dart';
import 'package:get_right/services/storage_service.dart';

/// Controller for managing nutrition tracking and recipes
class NutritionController extends GetxController {
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

  // Recipe filters
  final Rx<RecipeCategory?> selectedCategory = Rx<RecipeCategory?>(null);
  final RxString searchQuery = ''.obs;

  @override
  void onInit() {
    super.onInit();
    refreshSubscription();
    _initializeDemoData();
  }

  /// Re-read subscription from storage. Call after payment success so nutrition unlocks immediately.
  void refreshSubscription() {
    try {
      final storage = Get.find<StorageService>();
      hasSubscription.value = storage.hasActiveSubscription();
    } catch (_) {
      hasSubscription.value = false;
    }
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
    nutritionDays[dateKey] = day.copyWith(meals: updatedMeals);
    update();
  }

  // Remove meal entry
  void removeMealEntry(String entryId) {
    final dateKey = _getDateKey(selectedDate.value);
    final day = currentDay;
    final updatedMeals = day.meals.where((meal) => meal.id != entryId).toList();
    nutritionDays[dateKey] = day.copyWith(meals: updatedMeals);
    update();
  }

  // Update meal entry
  void updateMealEntry(MealEntry entry) {
    final dateKey = _getDateKey(entry.timestamp);
    final day = getNutritionDay(entry.timestamp);
    final updatedMeals = day.meals.map((meal) => meal.id == entry.id ? entry : meal).toList();
    nutritionDays[dateKey] = day.copyWith(meals: updatedMeals);
    update();
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

  // Add recipe serving to tracker
  void addRecipeToTracker(Recipe recipe, double servings, MealType mealType) {
    final nutrition = recipe.calculateForServings(servings);
    final foodItem = FoodItem(
      id: '${recipe.id}_${DateTime.now().millisecondsSinceEpoch}',
      name: recipe.name,
      calories: nutrition['calories']!,
      protein: nutrition['protein']!,
      carbs: nutrition['carbs']!,
      fats: nutrition['fats']!,
      defaultServingSize: servings,
      servingUnit: 'serving',
      imageUrl: recipe.imageUrl,
    );

    final entry = MealEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      foodItem: foodItem,
      quantity: 1,
      mealType: mealType,
      timestamp: selectedDate.value,
      notes: 'From recipe: ${recipe.name}',
    );

    addMealEntry(entry);
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
  }

  // Filter recipes
  List<Recipe> get filteredRecipes {
    var filtered = recipes.where((recipe) {
      // Category filter
      if (selectedCategory.value != null && !recipe.categories.contains(selectedCategory.value)) {
        return false;
      }
      // Search filter
      if (searchQuery.value.isNotEmpty && !recipe.name.toLowerCase().contains(searchQuery.value.toLowerCase())) {
        return false;
      }
      return true;
    }).toList();
    return filtered;
  }

  // Set category filter
  void setCategory(RecipeCategory? category) {
    selectedCategory.value = category;
    update();
  }

  // Set search query
  void setSearchQuery(String query) {
    searchQuery.value = query;
    update();
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

    // Demo recipes
    recipes.addAll([
      Recipe(
        id: '1',
        name: 'High Protein Chicken Bowl',
        description: 'A delicious and nutritious high-protein meal perfect for post-workout recovery.',
        imageUrl: 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=800',
        categories: [RecipeCategory.highProtein, RecipeCategory.lunch, RecipeCategory.bodybuilding],
        prepTimeMinutes: 15,
        cookTimeMinutes: 25,
        servings: 4,
        ingredients: [
          RecipeIngredient(name: 'chicken breast, diced', quantity: '2 lbs', unit: ''),
          RecipeIngredient(name: 'brown rice, cooked', quantity: '2 cups', unit: ''),
          RecipeIngredient(name: 'broccoli, steamed', quantity: '1 cup', unit: ''),
          RecipeIngredient(name: 'red bell pepper, sliced', quantity: '1', unit: ''),
          RecipeIngredient(name: 'olive oil', quantity: '2 tbsp', unit: ''),
        ],
        instructions: [
          RecipeInstruction(step: 1, instruction: 'Season chicken breast with salt and pepper to taste'),
          RecipeInstruction(step: 2, instruction: 'Heat olive oil in a large pan over medium heat'),
          RecipeInstruction(step: 3, instruction: 'Cook chicken until golden brown and cooked through, about 8-10 minutes'),
          RecipeInstruction(step: 4, instruction: 'Steam broccoli until tender, about 5 minutes'),
          RecipeInstruction(step: 5, instruction: 'Slice bell pepper into strips'),
          RecipeInstruction(step: 6, instruction: 'Serve chicken over brown rice with vegetables on the side'),
        ],
        caloriesPerServing: 420,
        proteinPerServing: 45,
        carbsPerServing: 35,
        fatsPerServing: 12,
        estimatedCost: 18.50,
        costPerServing: 4.63,
        videoUrl: 'https://www.youtube.com/watch?v=example',
        isPremium: false,
        isFeatured: true,
        popularity: 95,
      ),
      Recipe(
        id: '2',
        name: 'Protein Smoothie Bowl',
        description: 'Start your day with this protein-packed smoothie bowl topped with fresh fruits and nuts.',
        imageUrl: 'https://images.unsplash.com/photo-1590301157890-4810ed352733?w=800',
        categories: [RecipeCategory.breakfast, RecipeCategory.highProtein, RecipeCategory.quickPrep],
        prepTimeMinutes: 5,
        cookTimeMinutes: 0,
        servings: 2,
        ingredients: [
          RecipeIngredient(name: 'frozen banana', quantity: '2', unit: ''),
          RecipeIngredient(name: 'protein powder', quantity: '2 scoops', unit: ''),
          RecipeIngredient(name: 'almond milk', quantity: '1 cup', unit: ''),
          RecipeIngredient(name: 'spinach', quantity: '1 cup', unit: ''),
          RecipeIngredient(name: 'blueberries', quantity: '1/2 cup', unit: ''),
        ],
        instructions: [
          RecipeInstruction(step: 1, instruction: 'Add frozen banana, protein powder, almond milk, and spinach to blender'),
          RecipeInstruction(step: 2, instruction: 'Blend until smooth and creamy'),
          RecipeInstruction(step: 3, instruction: 'Pour into bowl'),
          RecipeInstruction(step: 4, instruction: 'Top with blueberries, granola, and nuts'),
        ],
        caloriesPerServing: 280,
        proteinPerServing: 30,
        carbsPerServing: 35,
        fatsPerServing: 5,
        estimatedCost: 8.00,
        costPerServing: 4.00,
        isPremium: false,
        isFeatured: true,
        popularity: 88,
      ),
      Recipe(
        id: '3',
        name: 'Grilled Salmon with Vegetables',
        description: 'Omega-3 rich salmon with a medley of colorful roasted vegetables.',
        imageUrl: 'https://images.unsplash.com/photo-1467003909585-2f8a72700288?w=800',
        categories: [RecipeCategory.dinner, RecipeCategory.highProtein, RecipeCategory.lowCarb],
        prepTimeMinutes: 10,
        cookTimeMinutes: 20,
        servings: 4,
        ingredients: [
          RecipeIngredient(name: 'salmon fillet', quantity: '4', unit: 'pieces'),
          RecipeIngredient(name: 'asparagus', quantity: '1 lb', unit: ''),
          RecipeIngredient(name: 'cherry tomatoes', quantity: '2 cups', unit: ''),
          RecipeIngredient(name: 'olive oil', quantity: '3 tbsp', unit: ''),
          RecipeIngredient(name: 'lemon', quantity: '1', unit: ''),
        ],
        instructions: [
          RecipeInstruction(step: 1, instruction: 'Preheat oven to 400°F (200°C)'),
          RecipeInstruction(step: 2, instruction: 'Place salmon on baking sheet, drizzle with olive oil'),
          RecipeInstruction(step: 3, instruction: 'Arrange asparagus and tomatoes around salmon'),
          RecipeInstruction(step: 4, instruction: 'Season with salt, pepper, and lemon juice'),
          RecipeInstruction(step: 5, instruction: 'Bake for 15-20 minutes until salmon is cooked through'),
        ],
        caloriesPerServing: 412,
        proteinPerServing: 38,
        carbsPerServing: 12,
        fatsPerServing: 24,
        estimatedCost: 24.00,
        costPerServing: 6.00,
        isPremium: true,
        isFeatured: true,
        popularity: 92,
      ),
      Recipe(
        id: '4',
        name: 'Turkey Chili',
        description: 'Hearty and healthy turkey chili loaded with beans and vegetables.',
        imageUrl: 'https://images.unsplash.com/photo-1603046891726-36bfd957e96d?w=800',
        categories: [RecipeCategory.dinner, RecipeCategory.highProtein, RecipeCategory.budgetFriendly],
        prepTimeMinutes: 15,
        cookTimeMinutes: 45,
        servings: 6,
        ingredients: [
          RecipeIngredient(name: 'ground turkey', quantity: '2 lbs', unit: ''),
          RecipeIngredient(name: 'kidney beans', quantity: '2 cans', unit: ''),
          RecipeIngredient(name: 'diced tomatoes', quantity: '1 can', unit: ''),
          RecipeIngredient(name: 'onion, diced', quantity: '1', unit: ''),
          RecipeIngredient(name: 'chili powder', quantity: '2 tbsp', unit: ''),
        ],
        instructions: [
          RecipeInstruction(step: 1, instruction: 'Brown ground turkey in large pot'),
          RecipeInstruction(step: 2, instruction: 'Add diced onion and cook until softened'),
          RecipeInstruction(step: 3, instruction: 'Stir in beans, tomatoes, and chili powder'),
          RecipeInstruction(step: 4, instruction: 'Simmer for 30-45 minutes'),
          RecipeInstruction(step: 5, instruction: 'Serve hot with toppings of your choice'),
        ],
        caloriesPerServing: 340,
        proteinPerServing: 35,
        carbsPerServing: 28,
        fatsPerServing: 10,
        estimatedCost: 15.00,
        costPerServing: 2.50,
        isPremium: false,
        isFeatured: false,
        popularity: 78,
      ),
    ]);

    // Set featured recipes
    featuredRecipes.value = recipes.where((r) => r.isFeatured).toList();

    // Add demo data for today
    final today = DateTime.now();
    addMealEntry(MealEntry(id: '1', foodItem: savedFoodItems[0], quantity: 1, mealType: MealType.breakfast, timestamp: today));
  }
}
