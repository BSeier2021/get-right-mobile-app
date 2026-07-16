import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_right/controllers/auth_controller.dart';
import 'package:get_right/controllers/nutrition_controller.dart';
import 'package:get_right/models/meal_entry.dart';
import 'package:get_right/models/nutrition_day.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';
import 'package:get_right/views/nutrition/add_food_screen.dart';
import 'package:get_right/views/nutrition/add_food_gateway_screen.dart';
import 'package:get_right/views/nutrition/food_log_detail_screen.dart';

/// Nutrition Tracker Tab - Shows daily calorie and macro tracking
class NutritionTrackerTab extends StatelessWidget {
  NutritionTrackerTab({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<NutritionController>(
      builder: (controller) {
        final currentDay = controller.currentDay;

        return Stack(
          children: [
            // Scrollable Content
            RefreshIndicator(
              onRefresh: () => controller.fetchNutritionTracker(),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (controller.trackerFetchError != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(controller.trackerFetchError!, style: AppTextStyles.bodySmall.copyWith(color: AppColors.error)),
                      ),

                    // Calories Overview Card
                    _buildCaloriesCard(context, controller, currentDay),

                    // Macros Overview
                    const SizedBox(height: 24),

                    // Daily Progress Section (Donut + macros like screenshot)
                    Text(
                      'Daily Progress',
                      style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.bold, color: AppColors.onSurface),
                    ),
                    const SizedBox(height: 12),
                    _buildDailyProgressSection(controller, currentDay),

                    const SizedBox(height: 24),

                    // Food Log Section Header
                    Text(
                      'Food Log',
                      style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.bold, color: AppColors.onSurface),
                    ),

                    const SizedBox(height: 16),

                    // Meal Sections
                    _buildMealSection(context, controller, MealType.breakfast),
                    const SizedBox(height: 12),
                    _buildMealSection(context, controller, MealType.lunch),
                    const SizedBox(height: 12),
                    _buildMealSection(context, controller, MealType.dinner),
                    const SizedBox(height: 12),
                    _buildMealSection(context, controller, MealType.snacks),

                    const SizedBox(height: 80), // Extra padding for FAB
                  ],
                ),
              ),
            ),

            // Floating Action Button
            Align(
              alignment: Alignment.bottomRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 16, bottom: 16),
                child: FloatingActionButton.extended(
                  onPressed: () async {
                    await Get.to(() => const AddFoodGatewayScreen());
                    await controller.fetchNutritionTracker();
                  },
                  backgroundColor: AppColors.accent,
                  elevation: 6,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  icon: const Icon(Icons.add, color: Colors.white, size: 22),
                  label: Text(
                    'Add Food',
                    style: AppTextStyles.bodyMedium.copyWith(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
              ),
            ),
            Obx(() {
              if (!controller.isLoading.value) return const SizedBox.shrink();
              return Positioned.fill(
                child: AbsorbPointer(
                  child: Container(
                    color: Colors.black.withOpacity(0.08),
                    alignment: Alignment.center,
                    child: const SizedBox(width: 40, height: 40, child: CircularProgressIndicator(strokeWidth: 3)),
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }

  Widget _buildDailyProgressSection(NutritionController controller, NutritionDay currentDay) {
    final consumed = controller.trackerCenterCalories ?? currentDay.totalCalories;
    final carbsG = currentDay.totalCarbs;
    final fatsG = currentDay.totalFats;
    final proteinG = currentDay.totalProtein;

    // Calculate calorie share per macro (4/9/4 kcal per gram)
    final carbsCal = carbsG * 4.0;
    final fatsCal = fatsG * 9.0;
    final proteinCal = proteinG * 4.0;
    final totalMacroCal = (carbsCal + fatsCal + proteinCal).clamp(0.0, double.infinity);

    double carbsPct = totalMacroCal == 0 ? 0.0 : (carbsCal / totalMacroCal) * 100.0;
    double fatsPct = totalMacroCal == 0 ? 0.0 : (fatsCal / totalMacroCal) * 100.0;
    double proteinPct = totalMacroCal == 0 ? 0.0 : (proteinCal / totalMacroCal) * 100.0;

    final apiPercents = controller.trackerMacroPercentsFromApi;
    if (apiPercents != null && apiPercents.length == 3) {
      carbsPct = apiPercents[0];
      fatsPct = apiPercents[1];
      proteinPct = apiPercents[2];
    }

    final colors = controller.trackerDonutColors;

    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Donut with three colored segments (Carbs, Fat, Proteins)
          SizedBox(
            width: 72,
            height: 72,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: const Size(72, 72),
                  painter: _SegmentedDonutPainter(
                    percents: [carbsPct, fatsPct, proteinPct],
                    colors: colors.length >= 3 ? colors : const [Color(0xFFFFA726), Color(0xFF9C27B0), Color(0xFF4A90E2)],
                    trackColor: AppColors.lightGray,
                    thickness: 12,
                    gapDegrees: 2,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      consumed.toStringAsFixed(0),
                      style: AppTextStyles.labelMedium.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold),
                    ),
                    Text('cal', style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryGray, fontSize: 10)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Percent rows
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _macroStat(color: colors.isNotEmpty ? colors[0] : const Color(0xFFFFA726), percent: carbsPct, grams: carbsG, label: 'Carbs'),
                _macroStat(color: colors.length > 1 ? colors[1] : const Color(0xFF9C27B0), percent: fatsPct, grams: fatsG, label: 'Fat'),
                _macroStat(color: colors.length > 2 ? colors[2] : const Color(0xFF4A90E2), percent: proteinPct, grams: proteinG, label: 'Proteins'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  double _pct(double value, double goal) {
    if (goal == 0) return 0;
    return (value / goal * 100).clamp(0, 100);
  }

  Widget _macroStat({required Color color, required double percent, required double grams, required String label}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          '${percent.toStringAsFixed(0)}%',
          style: AppTextStyles.labelMedium.copyWith(color: color, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 2),
        Text('${grams.toStringAsFixed(1)} g', style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryGray, fontSize: 11)),
        const SizedBox(height: 2),
        Text(label, style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryGray, fontSize: 11)),
      ],
    );
  }

  void _showAddFoodOptions(BuildContext context, NutritionController controller) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Add Food',
              style: AppTextStyles.titleLarge.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            _buildAddFoodOption(context, Icons.breakfast_dining, 'Breakfast', () {
              Navigator.pop(context);
              Get.to(() => const AddFoodScreen(mealType: MealType.breakfast));
            }),
            const SizedBox(height: 12),
            _buildAddFoodOption(context, Icons.lunch_dining, 'Lunch', () {
              Navigator.pop(context);
              Get.to(() => const AddFoodScreen(mealType: MealType.lunch));
            }),
            const SizedBox(height: 12),
            _buildAddFoodOption(context, Icons.dinner_dining, 'Dinner', () {
              Navigator.pop(context);
              Get.to(() => const AddFoodScreen(mealType: MealType.dinner));
            }),
            const SizedBox(height: 12),
            _buildAddFoodOption(context, Icons.fastfood, 'Snacks', () {
              Navigator.pop(context);
              Get.to(() => const AddFoodScreen(mealType: MealType.snacks));
            }),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }


  Widget _buildAddFoodOption(BuildContext context, IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primaryGrayLight),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.accent, size: 28),
            const SizedBox(width: 16),
            Text(
              label,
              style: AppTextStyles.bodyLarge.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            const Icon(Icons.chevron_right, color: AppColors.mediumGray),
          ],
        ),
      ),
    );
  }

  Widget _buildCaloriesCard(BuildContext context, NutritionController controller, NutritionDay currentDay, {bool isLimited = false}) {
    final consumed = currentDay.totalCalories;
    final goal = currentDay.calorieGoal;
    final burned = controller.trackerCaloriesBurned ?? 0.0;
    final remaining = controller.trackerCaloriesRemaining ?? (goal - consumed);
    final progressPercent = controller.trackerCalorieProgressPercent ?? (goal > 0 ? (consumed / goal) * 100 : 0);
    final progressValue = (progressPercent / 100).clamp(0.0, 1.0);
    final isOverGoal = remaining < 0 || progressPercent > 100;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFE5F4CC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFBDE2B7)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Image.asset("assets/images/Container (1).png"),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Calories',
                  style: AppTextStyles.titleMedium.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold),
                ),
              ),
              OutlinedButton.icon(
                onPressed: isLimited ? null : () => _showUpdateCalorieGoalDialog(context, controller, goal),
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: Text('Update', style: AppTextStyles.labelMedium.copyWith(fontWeight: FontWeight.w700)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.accent,
                  backgroundColor: Colors.white,
                  disabledForegroundColor: AppColors.mediumGray,
                  side: const BorderSide(color: AppColors.accent, width: 1.5),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                consumed.toStringAsFixed(0),
                style: const TextStyle(fontSize: 44, color: AppColors.onSurface, fontWeight: FontWeight.w900),
              ),
              const SizedBox(width: 4),
              Text(
                '/ ${goal.toStringAsFixed(0)} kcal',
                style: AppTextStyles.titleMedium.copyWith(color: AppColors.black, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progressValue,
              backgroundColor: Colors.white,
              valueColor: AlwaysStoppedAnimation<Color>(isOverGoal ? Colors.red : AppColors.accent),
              minHeight: 10,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${progressPercent.clamp(0, 999).toStringAsFixed(0)}% of goal',
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGray, fontWeight: FontWeight.w600),
              ),
              Text(
                isOverGoal ? '${(-remaining).toStringAsFixed(0)} kcal over' : '${remaining.toStringAsFixed(0)} kcal remaining',
                style: AppTextStyles.bodySmall.copyWith(color: isOverGoal ? Colors.red : AppColors.black, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _buildCalorieStatChip('Consumed', consumed.toStringAsFixed(0), Icons.restaurant_outlined)),
              const SizedBox(width: 8),
              Expanded(child: _buildCalorieStatChip('Burned', burned.toStringAsFixed(0), Icons.local_fire_department_outlined)),
              const SizedBox(width: 8),
              Expanded(child: _buildCalorieStatChip('Goal', goal.toStringAsFixed(0), Icons.flag_outlined)),
            ],
          ),
          if (isLimited) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.accent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.accent.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: AppColors.accent, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Subscribe to unlock full calorie tracking',
                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.accent, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCalorieStatChip(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.85),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFBDE2B7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.accent),
          const SizedBox(height: 6),
          Text(
            value,
            style: AppTextStyles.titleSmall.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryGray, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  void _showUpdateCalorieGoalDialog(BuildContext context, NutritionController controller, double currentGoal) {
    final goalController = TextEditingController(text: currentGoal.toStringAsFixed(0));
    var isSaving = false;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: AppColors.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(
              'Update Calorie Goal',
              style: AppTextStyles.titleLarge.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Set your daily calorie target', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.mediumGray)),
                const SizedBox(height: 16),
                TextField(
                  controller: goalController,
                  enabled: !isSaving,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: 'e.g., 2000',
                    suffixText: 'kcal',
                    filled: true,
                    fillColor: AppColors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.primaryGrayLight),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.accent, width: 2),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.of(context).pop(),
                child: Text('Cancel', style: AppTextStyles.buttonMedium.copyWith(color: AppColors.mediumGray)),
              ),
              ElevatedButton(
                onPressed: isSaving
                    ? null
                    : () async {
                        final newGoal = double.tryParse(goalController.text.trim());
                        if (newGoal == null || newGoal <= 0) {
                          Get.snackbar('Error', 'Enter a valid calorie goal', snackPosition: SnackPosition.BOTTOM);
                          return;
                        }
                        setDialogState(() => isSaving = true);
                        final saved = await controller.updateCalorieGoal(newGoal);
                        if (!context.mounted) return;
                        if (!saved) {
                          setDialogState(() => isSaving = false);
                          return;
                        }
                        Navigator.of(context).pop();
                        Get.snackbar(
                          'Updated',
                          'Daily goal set to ${newGoal.toStringAsFixed(0)} kcal',
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
                child: isSaving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text('Save', style: AppTextStyles.buttonMedium.copyWith(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    ).then((_) => goalController.dispose());
  }

  Widget _buildProgressBar(String label, double value, double goal, Color color) {
    final progress = (value / goal).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primaryGray.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.w600),
              ),
              Text(
                '${value.toStringAsFixed(0)}/${goal.toStringAsFixed(0)} g',
                style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(value: progress, backgroundColor: color.withOpacity(0.15), valueColor: AlwaysStoppedAnimation<Color>(color), minHeight: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildMealSection(BuildContext context, NutritionController controller, MealType mealType) {
    final meals = controller.currentDay.getMealsByType(mealType);
    final totalCalories = controller.currentDay.getCaloriesByMealType(mealType);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primaryGray.withOpacity(0.2)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: meals.isEmpty ? Colors.transparent : AppColors.lightGray.withOpacity(0.2),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                _mealHeaderIcon(mealType),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        mealType.displayName,
                        style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.bold, color: AppColors.onSurface),
                      ),
                      if (meals.isNotEmpty)
                        Text(
                          '${totalCalories.toStringAsFixed(0)} kcal',
                          style: AppTextStyles.bodySmall.copyWith(color: AppColors.mediumGray, fontWeight: FontWeight.w500),
                        ),
                    ],
                  ),
                ),
                if (meals.isEmpty)
                  _smallAddCircle(
                    onTap: () {
                      Get.to(() => AddFoodScreen(mealType: mealType))?.then((_) => controller.fetchNutritionTracker());
                    },
                  )
                else
                  _smallAddCircle(
                    onTap: () {
                      Get.to(() => AddFoodScreen(mealType: mealType))?.then((_) => controller.fetchNutritionTracker());
                    },
                  ),
              ],
            ),
          ),
          if (meals.isNotEmpty) ...[const Divider(height: 1, color: AppColors.lightGray, thickness: 1), ...meals.map((meal) => _buildMealItem(context, controller, meal))],
        ],
      ),
    );
  }

  /// Header circular icon for each meal using provided PNG assets with pastel background
  Widget _mealHeaderIcon(MealType mealType) {
    final Color bg = switch (mealType) {
      MealType.breakfast => const Color(0xFFFFF0D8),
      MealType.lunch => const Color(0xFFFFE7D5),
      MealType.dinner => const Color(0xFFF3E6FF),
      MealType.snacks => const Color(0xFFE0F3FF),
    };
    final String asset = switch (mealType) {
      MealType.breakfast => 'assets/images/meal_breakfast.png',
      MealType.lunch => 'assets/images/meal_lunch.png',
      MealType.dinner => 'assets/images/meal_dinner.png',
      MealType.snacks => 'assets/images/meal_snacks.png',
    };
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Image.asset(
          asset,
          fit: BoxFit.contain,
          errorBuilder: (c, e, s) => Text(mealType.icon, style: const TextStyle(fontSize: 20)),
        ),
      ),
    );
  }

  Widget _smallAddCircle({required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: const BoxDecoration(color: Colors.transparent, shape: BoxShape.circle),
        child: const Icon(Icons.add_circle_outline, color: AppColors.primaryGray, size: 22),
      ),
    );
  }

  Widget _buildMealItem(BuildContext context, NutritionController controller, MealEntry meal) {
    return _MealLogSwipeTile(
      key: ValueKey(meal.id),
      meal: meal,
      onTap: meal.id.isNotEmpty ? () => Get.to(() => FoodLogDetailScreen(foodLogId: meal.id)) : null,
      onEdit: () => _showEditFoodLogDialog(context, controller, meal),
      onDelete: () => _confirmDeleteFoodLog(controller, meal),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(bottom: BorderSide(color: AppColors.lightGray, width: 0.5)),
        ),
        child: Row(
          children: [
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    meal.foodItem.name,
                    style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w600, color: AppColors.onSurface),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (meal.quantity != 1.0) ...[
                    const SizedBox(height: 2),
                    Text(
                      '${meal.quantity % 1 == 0 ? meal.quantity.toStringAsFixed(0) : meal.quantity.toStringAsFixed(1)} servings',
                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.mediumGray),
                    ),
                  ],
                  if (meal.notes != null && meal.notes!.trim().isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      meal.notes!.trim(),
                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.mediumGray),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFE2F4E1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFB5E0B2)),
              ),
              child: Text(
                '${meal.totalCalories.toStringAsFixed(0)} kcal',
                style: AppTextStyles.labelSmall.copyWith(color: const Color(0xFF2F7D32), fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteFoodLog(NutritionController controller, MealEntry meal) async {
    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Delete Food Item',
          style: AppTextStyles.titleMedium.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold),
        ),
        content: Text('Are you sure you want to remove "${meal.foodItem.name}" from your log?', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.mediumGray)),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: Text('Cancel', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.mediumGray)),
          ),
          ElevatedButton(
            onPressed: () => Get.back(result: true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!Get.isRegistered<AuthController>()) return;

    final ok = await Get.find<AuthController>().deleteFoodLog(meal.id);
    if (!ok) return;

    await controller.fetchNutritionTracker();
    Get.snackbar(
      'Removed',
      '${meal.foodItem.name} removed from log',
      backgroundColor: AppColors.accent,
      colorText: Colors.white,
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 2),
    );
  }

  void _showEditFoodLogDialog(BuildContext context, NutritionController controller, MealEntry meal) {
    var selectedMealType = meal.mealType;
    double servings = meal.quantity;
    final servingsController = TextEditingController(text: servings % 1 == 0 ? servings.toStringAsFixed(0) : servings.toStringAsFixed(1));
    final notesController = TextEditingController(text: meal.notes ?? '');
    var isSaving = false;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: AppColors.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(
              'Edit Food Log',
              style: AppTextStyles.titleLarge.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(meal.foodItem.name, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.mediumGray)),
                  const SizedBox(height: 16),
                  Text('Meal', style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<MealType>(
                    value: selectedMealType,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppColors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    items: MealType.values.map((type) => DropdownMenuItem(value: type, child: Text(type.displayName))).toList(),
                    onChanged: isSaving ? null : (value) => setDialogState(() => selectedMealType = value ?? selectedMealType),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: servingsController,
                    enabled: !isSaving,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Servings',
                      filled: true,
                      fillColor: AppColors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: notesController,
                    enabled: !isSaving,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'Notes (optional)',
                      filled: true,
                      fillColor: AppColors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.of(context).pop(),
                child: Text('Cancel', style: AppTextStyles.buttonMedium.copyWith(color: AppColors.mediumGray)),
              ),
              ElevatedButton(
                onPressed: isSaving
                    ? null
                    : () async {
                        final parsedServings = double.tryParse(servingsController.text.trim());
                        if (parsedServings == null || parsedServings <= 0) {
                          Get.snackbar('Error', 'Enter valid servings', snackPosition: SnackPosition.BOTTOM);
                          return;
                        }
                        if (!Get.isRegistered<AuthController>()) {
                          Get.snackbar('Error', 'Sign in to edit food log', snackPosition: SnackPosition.BOTTOM);
                          return;
                        }
                        setDialogState(() => isSaving = true);
                        final ok = await Get.find<AuthController>().updateFoodLog(
                          id: meal.id,
                          mealType: selectedMealType.displayName,
                          servings: parsedServings,
                          notes: notesController.text.trim(),
                        );
                        if (!context.mounted) return;
                        if (!ok) {
                          setDialogState(() => isSaving = false);
                          return;
                        }
                        await controller.fetchNutritionTracker();
                        if (!context.mounted) return;
                        Navigator.of(context).pop();
                        Get.snackbar('Updated', '${meal.foodItem.name} updated', snackPosition: SnackPosition.BOTTOM, backgroundColor: AppColors.accent, colorText: Colors.white);
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: isSaving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text('Save', style: AppTextStyles.buttonMedium.copyWith(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    ).then((_) {
      servingsController.dispose();
      notesController.dispose();
    });
  }
}

class _MealLogSwipeTile extends StatefulWidget {
  final MealEntry meal;
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _MealLogSwipeTile({super.key, required this.meal, required this.child, this.onTap, required this.onEdit, required this.onDelete});

  @override
  State<_MealLogSwipeTile> createState() => _MealLogSwipeTileState();
}

class _MealLogSwipeTileState extends State<_MealLogSwipeTile> {
  static const _actionsWidth = 152.0;
  double _offset = 0;

  void _close() => setState(() => _offset = 0);

  void _onDragUpdate(DragUpdateDetails details) {
    setState(() {
      _offset = (_offset + details.delta.dx).clamp(-_actionsWidth, 0.0);
    });
  }

  void _onDragEnd(DragEndDetails details) {
    setState(() {
      _offset = _offset <= -_actionsWidth / 2 ? -_actionsWidth : 0.0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: Stack(
        children: [
          Positioned.fill(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _SwipeActionButton(
                  label: 'Edit',
                  icon: Icons.edit_outlined,
                  color: AppColors.accent,
                  onTap: () {
                    _close();
                    widget.onEdit();
                  },
                ),
                _SwipeActionButton(
                  label: 'Delete',
                  icon: Icons.delete_outline,
                  color: AppColors.error,
                  onTap: () {
                    _close();
                    widget.onDelete();
                  },
                ),
              ],
            ),
          ),
          GestureDetector(
            onHorizontalDragUpdate: _onDragUpdate,
            onHorizontalDragEnd: _onDragEnd,
            onTap: () {
              if (_offset != 0) {
                _close();
              } else {
                widget.onTap?.call();
              }
            },
            child: AnimatedContainer(duration: const Duration(milliseconds: 180), curve: Curves.easeOut, transform: Matrix4.translationValues(_offset, 0, 0), child: widget.child),
          ),
        ],
      ),
    );
  }
}

class _SwipeActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _SwipeActionButton({required this.label, required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 76,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 22),
              const SizedBox(height: 4),
              Text(
                label,
                style: AppTextStyles.labelSmall.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Painter for multi-segment donut chart
class _SegmentedDonutPainter extends CustomPainter {
  _SegmentedDonutPainter({required this.percents, required this.colors, required this.trackColor, this.thickness = 12, this.gapDegrees = 0});

  final List<double> percents; // each in 0..100
  final List<Color> colors;
  final Color trackColor;
  final double thickness;
  final double gapDegrees;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = (size.shortestSide / 2) - 2;

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = thickness;

    // Draw full track ring
    canvas.drawCircle(center, radius, trackPaint);

    // Draw segments
    double startAngle = -90 * (3.141592653589793 / 180.0);
    final gapRad = gapDegrees * (3.141592653589793 / 180.0);
    for (int i = 0; i < percents.length; i++) {
      final sweep = (percents[i].clamp(0.0, 100.0) / 100.0) * (2 * 3.141592653589793) - gapRad;
      if (sweep <= 0) continue;

      final segPaint = Paint()
        ..color = colors[i % colors.length]
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.butt
        ..strokeWidth = thickness;

      canvas.drawArc(Rect.fromCircle(center: center, radius: radius), startAngle + (gapRad / 2), sweep, false, segPaint);
      startAngle += sweep + gapRad;
    }
  }

  @override
  bool shouldRepaint(covariant _SegmentedDonutPainter oldDelegate) {
    return oldDelegate.percents != percents || oldDelegate.colors != colors || oldDelegate.thickness != thickness || oldDelegate.gapDegrees != gapDegrees;
  }
}
