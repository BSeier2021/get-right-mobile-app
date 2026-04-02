import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:get_right/controllers/nutrition_controller.dart';
import 'package:get_right/models/meal_entry.dart';
import 'package:get_right/models/recipe.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';

/// Recipe Detail Screen - Shows full recipe details
class RecipeDetailScreen extends StatefulWidget {
  final Recipe recipe;

  const RecipeDetailScreen({super.key, required this.recipe});

  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  double servings = 1.0;

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<NutritionController>();
    final nutrition = widget.recipe.calculateForServings(servings);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        centerTitle: true,
        elevation: 0,
        title: Text('Recipe', style: AppTextStyles.titleLarge.copyWith(fontWeight: FontWeight.w600)),
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.accent, size: 18),
          ),
          onPressed: () => Get.back(),
        ),
        actions: [
          if (widget.recipe.isPremium)
            Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(20)),
              child: Row(
                children: [
                  const Icon(Icons.star, color: Colors.white, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    'Premium',
                    style: AppTextStyles.labelSmall.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header image
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.network(
                widget.recipe.imageUrl,
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  height: 200,
                  color: AppColors.accent.withOpacity(0.2),
                  child: const Center(child: Icon(Icons.restaurant, size: 64, color: AppColors.accent)),
                ),
              ),
            ),

            const SizedBox(height: 16),
            // Title and description
            Text(
              widget.recipe.name,
              style: AppTextStyles.headlineMedium.copyWith(fontWeight: FontWeight.bold, color: AppColors.onSurface),
            ),
            const SizedBox(height: 8),
            Text(widget.recipe.description, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.mediumGray)),

            const SizedBox(height: 16),
            SizedBox(
              height: 100.h,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _buildInfoChip('assets/images/clock.png', '${widget.recipe.prepTimeMinutes} min prep'),
                  _buildInfoChip('assets/images/knife.png', '${widget.recipe.cookTimeMinutes} min cook'),
                  _buildInfoChip('assets/images/people22.png', '${widget.recipe.servings} servings'),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _buildNutritionSection(nutrition),

            const SizedBox(height: 24),
            Text(
              'Ingredients',
              style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.bold, color: AppColors.onSurface),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primaryGrayLight.withOpacity(0.6)),
              ),
              child: Column(children: widget.recipe.ingredients.asMap().entries.map((entry) => _buildIngredientItem(entry.key + 1, entry.value)).toList()),
            ),

            const SizedBox(height: 24),
            Text(
              'Instructions',
              style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.bold, color: AppColors.onSurface),
            ),
            const SizedBox(height: 12),
            ...widget.recipe.instructions.map((instruction) => _buildInstructionStep(instruction)),

            const SizedBox(height: 24),
            if (widget.recipe.videoUrl != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Background recipe image
                    Image.network(
                      widget.recipe.imageUrl,
                      height: 220.h,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(height: 180, color: AppColors.accent.withOpacity(0.2)),
                    ),
                    // Dark gradient overlay
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.black.withOpacity(0.80), Colors.black.withOpacity(0.80)],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                    ),
                    // Content
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Image.asset('assets/images/playbutton.png', width: 50.w),
                          const SizedBox(height: 12),
                          Text(
                            'Video Walkthrough',
                            style: AppTextStyles.titleMedium.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text('Watch step-by-step instructions', style: AppTextStyles.bodySmall.copyWith(color: Colors.white.withOpacity(0.9))),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: () => Get.snackbar('Video', 'Video player will open here', snackPosition: SnackPosition.BOTTOM),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF205536),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 5),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50.r)),
                              elevation: 0,
                            ),
                            child: Text('Watch Video Tutorial', style: AppTextStyles.buttonMedium.copyWith(color: Colors.white)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _showAddToTrackerDialog(context, controller),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF205536),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.add_circle_outline, color: Colors.white, size: 22),
                    const SizedBox(width: 10),
                    Text(
                      'Add To Calorie Tracker',
                      style: AppTextStyles.buttonLarge.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Color _getStepColor(int step) {
    final idx = (step - 1) % 6;
    switch (idx) {
      case 0:
        return const Color(0xFFFF9800); // orange
      case 1:
        return const Color(0xFF2196F3); // blue
      case 2:
        return const Color(0xFF4CAF50); // green
      case 3:
        return const Color(0xFF9C27B0); // purple
      case 4:
        return const Color(0xFFF44336); // red
      case 5:
      default:
        return const Color(0xFF8BC34A); // light green
    }
  }

  Widget _servingsCircleButton({required IconData icon, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: Colors.transparent,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.accent, width: 1.4),
        ),
        child: Icon(icon, color: AppColors.accent, size: 16),
      ),
    );
  }

  Widget _buildNutritionSection(Map<String, double> nutrition) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Nutrition (per serving)',
              style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.bold, color: AppColors.onSurface),
            ),
            Row(
              children: [
                Text(
                  servings.toStringAsFixed(1),
                  style: AppTextStyles.titleMedium.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.w700),
                ),
                const SizedBox(width: 8),
                _servingsCircleButton(
                  icon: Icons.remove,
                  onTap: () {
                    if (servings > 0.5) {
                      setState(() {
                        servings -= 0.5;
                      });
                    }
                  },
                ),
                const SizedBox(width: 6),
                _servingsCircleButton(
                  icon: Icons.add,
                  onTap: () {
                    setState(() {
                      servings += 0.5;
                    });
                  },
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _nutrTile(color: Colors.orange, value: nutrition['calories']!.toStringAsFixed(0), unit: 'kcal', label: 'Calories'),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _nutrTile(color: Colors.blue, value: nutrition['protein']!.toStringAsFixed(0), unit: 'g', label: 'Protein'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _nutrTile(color: Colors.green, value: nutrition['carbs']!.toStringAsFixed(0), unit: 'g', label: 'Carb'),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _nutrTile(color: Colors.purple, value: nutrition['fats']!.toStringAsFixed(0), unit: 'g', label: 'Fats'),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _nutrTile({required Color color, required String value, required String unit, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primaryGrayLight.withOpacity(0.6)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 6),
          Text(
            value,
            style: AppTextStyles.titleLarge.copyWith(color: color, fontWeight: FontWeight.bold),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(label, style: AppTextStyles.labelSmall.copyWith(color: AppColors.black)),

              const SizedBox(width: 4),
              Text(unit, style: AppTextStyles.labelSmall.copyWith(color: AppColors.black)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(String image, String text) {
    return Container(
      width: 100.w,
      height: 80.h,
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primaryGrayLight.withOpacity(0.6)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Image.asset(image, width: 20.w, height: 20.h),
          Text(
            text,
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _buildNutritionItem(String label, String value, String unit, Color color) {
    return Column(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
          child: Center(
            child: Text(
              value,
              style: AppTextStyles.titleLarge.copyWith(fontWeight: FontWeight.bold, color: color),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: AppTextStyles.bodySmall.copyWith(color: AppColors.mediumGray, fontWeight: FontWeight.w500),
        ),
        Text(unit, style: AppTextStyles.bodySmall.copyWith(color: AppColors.mediumGray)),
      ],
    );
  }

  Widget _buildIngredientItem(int index, RecipeIngredient ingredient) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle),
            child: Center(child: Icon(Icons.check, color: Colors.white, size: 16)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(ingredient.displayText, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onSurface)),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionStep(RecipeInstruction instruction) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primaryGrayLight.withOpacity(0.6)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            instruction.step.toString().padLeft(2, '0'),
            style: AppTextStyles.bodyMedium.copyWith(color: _getStepColor(instruction.step), fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(instruction.instruction, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onSurface, height: 1.45)),
          ),
        ],
      ),
    );
  }

  void _showAddToTrackerDialog(BuildContext context, NutritionController controller) {
    MealType selectedMealType = MealType.lunch;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: AppColors.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(
              'Add to Tracker',
              style: AppTextStyles.titleLarge.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Select meal type:', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.mediumGray)),
                const SizedBox(height: 16),
                ...MealType.values.map((type) {
                  return RadioListTile<MealType>(
                    value: type,
                    groupValue: selectedMealType,
                    onChanged: (value) {
                      setState(() {
                        selectedMealType = value!;
                      });
                    },
                    title: Text('${type.icon} ${type.displayName}', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onSurface)),
                    activeColor: AppColors.accent,
                  );
                }),
                const SizedBox(height: 16),
                Text(
                  'Servings: $servings',
                  style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Get.back(),
                child: Text('Cancel', style: AppTextStyles.buttonMedium.copyWith(color: AppColors.mediumGray)),
              ),
              ElevatedButton(
                onPressed: () {
                  controller.addRecipeToTracker(widget.recipe, servings, selectedMealType);
                  Get.back(); // Close dialog
                  Get.back(); // Go back to nutrition screen
                  Get.snackbar(
                    'Success',
                    '${widget.recipe.name} added to your ${selectedMealType.displayName}',
                    snackPosition: SnackPosition.BOTTOM,
                    backgroundColor: AppColors.accent,
                    colorText: Colors.white,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text('Add', style: AppTextStyles.buttonMedium.copyWith(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
  }
}
