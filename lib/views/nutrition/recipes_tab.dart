import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_right/controllers/nutrition_controller.dart';
import 'package:get_right/models/recipe.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';
import 'package:get_right/views/nutrition/recipe_detail_screen.dart';

/// Recipes Tab - Shows cookbook recipes
class RecipesTab extends StatelessWidget {
  const RecipesTab({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<NutritionController>(
      builder: (controller) {
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Search Bar
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  onChanged: (value) => controller.setSearchQuery(value),
                  decoration: InputDecoration(
                    hintText: 'Search recipes...',
                    filled: true,
                    fillColor: AppColors.white,
                    hintStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.mediumGray),
                    prefixIcon: const Icon(Icons.search, color: AppColors.mediumGray),

                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ),

              // Categories
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

              // Featured Recipes
              if (controller.featuredRecipes.isNotEmpty) ...[
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

              // Filter and Sort Section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'All Recipes',
                      style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.bold, color: AppColors.onSurface),
                    ),
                    Row(
                      children: [
                        // Filter Button
                        GestureDetector(
                          onTap: () => _showFilterOptions(context, controller),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.lightGray),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.filter_list, size: 18, color: AppColors.mediumGray),
                                const SizedBox(width: 4),
                                Text(
                                  'Filter',
                                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.mediumGray, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Sort Button
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
                                  'Sort',
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

              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: controller.filteredRecipes.length,
                itemBuilder: (context, index) {
                  return Padding(padding: const EdgeInsets.only(bottom: 12), child: _buildRecipeCard(controller.filteredRecipes[index]));
                },
              ),

              const SizedBox(height: 24),
            ],
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
              const Text('🍽️', style: TextStyle(fontSize: 16)),
            if (category != null && [RecipeCategory.breakfast, RecipeCategory.lunch, RecipeCategory.dinner].contains(category)) const SizedBox(width: 6),
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
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Stack(
          children: [
            // Recipe Image
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                recipe.imageUrl,
                width: 280,
                height: 220,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  width: 280,
                  height: 220,
                  color: AppColors.accent.withOpacity(0.3),
                  child: const Center(child: Icon(Icons.restaurant, size: 60, color: AppColors.accent)),
                ),
              ),
            ),
            // Gradient Overlay
            Container(
              width: 280,
              height: 220,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black.withOpacity(0.7)]),
              ),
            ),
            // Category Tag
            if (recipe.categories.isNotEmpty)
              Positioned(
                top: 12,
                left: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), borderRadius: BorderRadius.circular(12)),
                  child: Text(
                    recipe.categories.first.displayName,
                    style: AppTextStyles.labelSmall.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            // Premium Badge
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
                      Text(
                        'Premium',
                        style: AppTextStyles.labelSmall.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            // Recipe Info
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

  Widget _buildRecipeCard(Recipe recipe) {
    return GestureDetector(
      onTap: () => Get.to(() => RecipeDetailScreen(recipe: recipe)),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.primaryGray.withOpacity(0.2)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Row(
          children: [
            // Recipe Image with Category Tag
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), bottomLeft: Radius.circular(12)),
                  child: Image.network(
                    recipe.imageUrl,
                    width: 100,
                    height: 100,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: 100,
                      height: 100,
                      color: AppColors.accent.withOpacity(0.2),
                      child: const Icon(Icons.restaurant, color: AppColors.accent, size: 40),
                    ),
                  ),
                ),
                // Category Tag
                if (recipe.categories.isNotEmpty)
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      decoration: BoxDecoration(color: Colors.black.withOpacity(0.7), borderRadius: BorderRadius.circular(6)),
                      child: Text(
                        recipe.categories.first.displayName,
                        style: AppTextStyles.labelSmall.copyWith(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10),
                      ),
                    ),
                  ),
              ],
            ),
            // Recipe Info
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
                            decoration: BoxDecoration(color: Colors.amber.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
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
        Text(
          text,
          style: AppTextStyles.bodySmall.copyWith(color: Colors.white, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  void _showFilterOptions(BuildContext context, NutritionController controller) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Filter Recipes',
              style: AppTextStyles.titleLarge.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            Text('Dietary Preferences', style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildStaticFilterChip('High Protein'),
                _buildStaticFilterChip('Low Carb'),
                _buildStaticFilterChip('Vegetarian'),
                _buildStaticFilterChip('Budget Friendly'),
              ],
            ),
            const SizedBox(height: 24),
            Text('Prep Time', style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: [_buildStaticFilterChip('Under 15 min'), _buildStaticFilterChip('15-30 min'), _buildStaticFilterChip('30+ min')]),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Apply Filters', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildStaticFilterChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.lightGray),
      ),
      child: Text(
        label,
        style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.w600),
      ),
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
            Text(
              'Sort By',
              style: AppTextStyles.titleLarge.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            _buildSortOption(buildContext, 'Most Popular', Icons.trending_up),
            _buildSortOption(buildContext, 'Highest Protein', Icons.fitness_center),
            _buildSortOption(buildContext, 'Lowest Calories', Icons.local_fire_department),
            _buildSortOption(buildContext, 'Quickest to Make', Icons.access_time),
            _buildSortOption(buildContext, 'Cheapest', Icons.attach_money),
            _buildSortOption(buildContext, 'Newest', Icons.new_releases),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildSortOption(BuildContext context, String label, IconData icon) {
    return InkWell(
      onTap: () {
        Navigator.pop(context);
        Get.snackbar(
          'Sort Applied',
          'Recipes sorted by: $label',
          backgroundColor: AppColors.accent,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 2),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(color: Colors.transparent, borderRadius: BorderRadius.circular(8)),
        child: Row(
          children: [
            Icon(icon, color: AppColors.mediumGray, size: 24),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: AppTextStyles.bodyLarge.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.w500),
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.mediumGray, size: 24),
          ],
        ),
      ),
    );
  }
}
