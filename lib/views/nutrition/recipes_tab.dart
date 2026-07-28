import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_right/controllers/nutrition_controller.dart';
import 'package:get_right/models/recipe.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';
import 'package:get_right/views/nutrition/recipe_detail_screen.dart';

/// Recipes Tab - Shows cookbook recipes from `GET /customer/recipes/catalog`.
class RecipesTab extends StatefulWidget {
  const RecipesTab({super.key});

  @override
  State<RecipesTab> createState() => _RecipesTabState();
}

class _RecipesTabState extends State<RecipesTab> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    final controller = Get.isRegistered<NutritionController>() ? Get.find<NutritionController>() : null;
    _searchController = TextEditingController(text: controller?.searchQuery.value ?? '');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!Get.isRegistered<NutritionController>()) return;
      Get.find<NutritionController>().refreshRecipesTab();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<NutritionController>(
      builder: (controller) {
        return RefreshIndicator(
          color: AppColors.accent,
          onRefresh: controller.refreshRecipesTab,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    controller: _searchController,
                    textInputAction: TextInputAction.search,
                    onChanged: controller.setSearchQuery,
                    onSubmitted: (_) => controller.submitRecipeSearch(),
                    decoration: InputDecoration(
                      hintText: 'Search recipes...',
                      filled: true,
                      fillColor: AppColors.white,
                      hintStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.mediumGray),
                      prefixIcon: const Icon(Icons.search, color: AppColors.mediumGray),
                      suffixIcon: controller.isRecipeSearchActive
                          ? IconButton(
                              icon: const Icon(Icons.clear, color: AppColors.mediumGray),
                              onPressed: () {
                                _searchController.clear();
                                controller.clearRecipeSearch();
                              },
                            )
                          : null,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Categories',
                        style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.bold, color: AppColors.onSurface),
                      ),
                      const SizedBox(height: 12),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildCategoryChip(controller, null, 'All'),
                            const SizedBox(width: 8),
                            _buildCategoryChip(controller, RecipeCategory.breakfast, 'Breakfast'),
                            const SizedBox(width: 8),
                            _buildCategoryChip(controller, RecipeCategory.lunch, 'Lunch'),
                            const SizedBox(width: 8),
                            _buildCategoryChip(controller, RecipeCategory.dinner, 'Dinner'),
                            const SizedBox(width: 8),
                            _buildCategoryChip(controller, RecipeCategory.snacks, 'Snacks'),
                            const SizedBox(width: 8),
                            _buildCategoryChip(controller, RecipeCategory.highProtein, 'High Protein'),
                            const SizedBox(width: 8),
                            _buildCategoryChip(controller, RecipeCategory.lowCarb, 'Low Carb'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                if (!controller.isRecipeSearchActive) ...[
                  if (controller.featuredRecipesLoading.value)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: CircularProgressIndicator(color: AppColors.accent)),
                    )
                  else if (controller.featuredRecipes.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'Featured Recipes',
                        style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.bold, color: AppColors.onSurface),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 220,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: controller.featuredRecipes.length,
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: EdgeInsets.only(right: index < controller.featuredRecipes.length - 1 ? 16 : 0),
                            child: _buildFeaturedRecipeCard(controller.featuredRecipes[index]),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ],

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        controller.isRecipeSearchActive ? 'Search Results' : 'All Recipes',
                        style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.bold, color: AppColors.onSurface),
                      ),
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () => _showSortOptions(context, controller),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppColors.lightGray),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.sort, size: 18, color: AppColors.mediumGray),
                                  const SizedBox(width: 4),
                                  Text(
                                    controller.recipeSortLabel.value,
                                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.mediumGray, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                if (controller.recipesLoading.value && controller.filteredRecipes.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 48),
                    child: Center(child: CircularProgressIndicator(color: AppColors.accent)),
                  )
                else if (controller.recipesError.value.isNotEmpty && controller.filteredRecipes.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Text(controller.recipesError.value, textAlign: TextAlign.center, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.error)),
                        const SizedBox(height: 12),
                        OutlinedButton(onPressed: () => controller.refreshRecipesTab(), child: const Text('Retry')),
                      ],
                    ),
                  )
                else if (controller.filteredRecipes.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Text(
                        controller.isRecipeSearchActive
                            ? 'No recipes found for "${controller.searchQuery.value.trim()}"'
                            : 'No recipes found',
                        style: AppTextStyles.bodyMedium.copyWith(color: AppColors.mediumGray),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: controller.filteredRecipes.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildRecipeCard(controller.filteredRecipes[index]),
                      );
                    },
                  ),

                if (controller.recipesHasMore.value && controller.filteredRecipes.isNotEmpty) ...[
                  Center(
                    child: controller.recipesLoadingMore.value
                        ? const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: CircularProgressIndicator(color: AppColors.accent),
                          )
                        : TextButton(onPressed: controller.loadMoreRecipes, child: const Text('Load more')),
                  ),
                ],

                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCategoryChip(NutritionController controller, RecipeCategory? category, String label) {
    final isSelected = controller.selectedCategory.value == category;
    return GestureDetector(
      onTap: () => controller.setCategory(category),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accentVariant : Colors.white,
          borderRadius: BorderRadius.circular(50),
          border: Border.all(color: isSelected ? AppColors.accentVariant : AppColors.lightGray, width: 1.5),
        ),
        child: Row(
          children: [
            if (category == RecipeCategory.breakfast)
              const Text('🍳', style: TextStyle(fontSize: 16))
            else if (category == RecipeCategory.lunch)
              const Text('🥗', style: TextStyle(fontSize: 16))
            else if (category == RecipeCategory.dinner)
              const Text('🍽️', style: TextStyle(fontSize: 16))
            else if (category == RecipeCategory.snacks)
              const Text('🍿', style: TextStyle(fontSize: 16)),
            if (category != null && [RecipeCategory.breakfast, RecipeCategory.lunch, RecipeCategory.dinner, RecipeCategory.snacks].contains(category))
              const SizedBox(width: 6),
            Text(
              label,
              style: AppTextStyles.bodyMedium.copyWith(color: isSelected ? Colors.white : AppColors.onSurface, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeaturedRecipeCard(Recipe recipe) {
    return GestureDetector(
      onTap: () => Get.to(() => RecipeDetailScreen(recipe: recipe)),
      child: Container(
        width: 280,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: recipe.imageUrl.isNotEmpty
                  ? Image.network(
                      recipe.imageUrl,
                      width: 280,
                      height: 220,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => _recipeImagePlaceholder(280, 220),
                    )
                  : _recipeImagePlaceholder(280, 220),
            ),
            Container(
              width: 280,
              height: 220,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black.withValues(alpha: 0.7)]),
              ),
            ),
            if (recipe.categories.isNotEmpty)
              Positioned(
                top: 12,
                left: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(12)),
                  child: Text(
                    recipe.categories.first.displayName,
                    style: AppTextStyles.labelSmall.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            if (recipe.isPremium)
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    children: [
                      const Icon(Icons.star, color: Colors.white, size: 14),
                      const SizedBox(width: 4),
                      Text('Premium', style: AppTextStyles.labelSmall.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      recipe.name,
                      style: AppTextStyles.titleMedium.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildRecipeInfo(Icons.access_time, '${recipe.totalTimeMinutes} min'),
                        const SizedBox(width: 12),
                        _buildRecipeInfo(Icons.local_fire_department, '${recipe.caloriesPerServing.toStringAsFixed(0)} kcal'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _recipeImagePlaceholder(double width, double height) {
    return Container(
      width: width,
      height: height,
      color: AppColors.accent.withValues(alpha: 0.3),
      child: const Center(child: Icon(Icons.restaurant, size: 60, color: AppColors.accent)),
    );
  }

  Widget _buildRecipeCard(Recipe recipe) {
    return GestureDetector(
      onTap: () => Get.to(() => RecipeDetailScreen(recipe: recipe)),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.primaryGray.withValues(alpha: 0.2)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Row(
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), bottomLeft: Radius.circular(12)),
                  child: recipe.imageUrl.isNotEmpty
                      ? Image.network(
                          recipe.imageUrl,
                          width: 100,
                          height: 100,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => _recipeImagePlaceholder(100, 100),
                        )
                      : _recipeImagePlaceholder(100, 100),
                ),
                if (recipe.categories.isNotEmpty)
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.7), borderRadius: BorderRadius.circular(6)),
                      child: Text(
                        recipe.categories.first.displayName,
                        style: AppTextStyles.labelSmall.copyWith(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10),
                      ),
                    ),
                  ),
              ],
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            recipe.name,
                            style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w600, color: AppColors.onSurface),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (recipe.isPremium)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                            decoration: BoxDecoration(color: Colors.amber.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
                            child: const Icon(Icons.star, color: Colors.amber, size: 14),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.access_time, size: 14, color: AppColors.mediumGray),
                        const SizedBox(width: 4),
                        Text('${recipe.totalTimeMinutes} min', style: AppTextStyles.bodySmall.copyWith(color: AppColors.mediumGray)),
                        const SizedBox(width: 12),
                        const Icon(Icons.restaurant, size: 14, color: AppColors.mediumGray),
                        const SizedBox(width: 4),
                        Text('${recipe.servings} servings', style: AppTextStyles.bodySmall.copyWith(color: AppColors.mediumGray)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          '${recipe.caloriesPerServing.toStringAsFixed(0)} kcal',
                          style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600, color: AppColors.accent),
                        ),
                        const SizedBox(width: 4),
                        Text('• P${recipe.proteinPerServing.toStringAsFixed(0)}g', style: AppTextStyles.bodySmall.copyWith(color: AppColors.mediumGray)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecipeInfo(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: Colors.white, size: 16),
        const SizedBox(width: 4),
        Text(text, style: AppTextStyles.bodySmall.copyWith(color: Colors.white, fontWeight: FontWeight.w500)),
      ],
    );
  }

  void _showSortOptions(BuildContext context, NutritionController controller) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (buildContext) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sort By', style: AppTextStyles.titleLarge.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            ...NutritionController.recipeSortLabelsToApi.keys.map(
              (label) => _buildSortOption(buildContext, controller, label),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildSortOption(BuildContext context, NutritionController controller, String label) {
    final selected = controller.recipeSortLabel.value == label;
    return InkWell(
      onTap: () {
        controller.setRecipeSort(label);
        Navigator.pop(context);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: selected ? AppColors.accent.withValues(alpha: 0.08) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: AppTextStyles.bodyLarge.copyWith(
                  color: selected ? AppColors.accent : AppColors.onSurface,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
            if (selected) const Icon(Icons.check, color: AppColors.accent, size: 22),
          ],
        ),
      ),
    );
  }
}
