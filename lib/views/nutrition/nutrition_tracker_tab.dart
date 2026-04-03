import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_right/controllers/nutrition_controller.dart';
import 'package:get_right/models/meal_entry.dart';
import 'package:get_right/routes/app_routes.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';
import 'package:get_right/views/nutrition/add_food_screen.dart';
import 'package:get_right/views/nutrition/add_food_gateway_screen.dart';

/// Nutrition Tracker Tab - Shows daily calorie and macro tracking
/// Requires subscription for full access
class NutritionTrackerTab extends StatelessWidget {
  NutritionTrackerTab({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<NutritionController>(
      builder: (controller) {
        final currentDay = controller.currentDay;

        // If no subscription, show locked view; unlocks when controller.refreshSubscription() is called after payment
        if (!controller.hasSubscription.value) {
          return _buildLockedView(context);
        }

        return Stack(
          children: [
            // Scrollable Content
            SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Calories Overview Card
                  _buildCaloriesCard(currentDay.totalCalories, currentDay.calorieGoal, currentDay.calorieProgress),

                  // Macros Overview
                  const SizedBox(height: 24),

                  // Daily Progress Section (Donut + macros like screenshot)
                  Text(
                    'Daily Progress',
                    style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.bold, color: AppColors.onSurface),
                  ),
                  const SizedBox(height: 12),
                  _buildDailyProgressSection(currentDay),

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

            // Floating Action Button
            Align(
              alignment: Alignment.bottomRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 16, bottom: 16),
                child: FloatingActionButton.extended(
                  onPressed: () {
                    Get.to(() => AddFoodGatewayScreen());
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
          ],
        );
      },
    );
  }

  Widget _buildDailyProgressSection(dynamic currentDay) {
    final consumed = currentDay.totalCalories;
    final carbsG = currentDay.totalCarbs;
    final fatsG = currentDay.totalFats;
    final proteinG = currentDay.totalProtein;

    // Calculate calorie share per macro (4/9/4 kcal per gram)
    final carbsCal = carbsG * 4.0;
    final fatsCal = fatsG * 9.0;
    final proteinCal = proteinG * 4.0;
    final totalMacroCal = (carbsCal + fatsCal + proteinCal).clamp(0.0, double.infinity);

    final carbsPct = totalMacroCal == 0 ? 0.0 : (carbsCal / totalMacroCal) * 100.0;
    final fatsPct = totalMacroCal == 0 ? 0.0 : (fatsCal / totalMacroCal) * 100.0;
    final proteinPct = totalMacroCal == 0 ? 0.0 : (proteinCal / totalMacroCal) * 100.0;

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
                    colors: const [
                      Color(0xFFFFA726), // Carbs - orange
                      Color(0xFF9C27B0), // Fat - purple
                      Color(0xFF4A90E2), // Proteins - blue
                    ],
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
                _macroStat(color: const Color(0xFFFFA726), percent: carbsPct, grams: carbsG, label: 'Carbs'),
                _macroStat(color: const Color(0xFF9C27B0), percent: fatsPct, grams: fatsG, label: 'Fat'),
                _macroStat(color: const Color(0xFF4A90E2), percent: proteinPct, grams: proteinG, label: 'Proteins'),
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
    if (!controller.hasSubscription.value) {
      _showSubscriptionRequiredDialog(context);
      return;
    }

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

  Widget _buildLockedView(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Lock Icon Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [AppColors.accent.withOpacity(0.1), AppColors.accent.withOpacity(0.05)], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.accent.withOpacity(0.3), width: 2),
            ),
            child: Column(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.accent.withOpacity(0.2),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.accent, width: 3),
                  ),
                  child: const Icon(Icons.lock, color: AppColors.accent, size: 40),
                ),
                const SizedBox(height: 20),
                Text(
                  'Nutrition Tracking',
                  style: AppTextStyles.headlineSmall.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Premium Feature',
                  style: AppTextStyles.titleMedium.copyWith(color: AppColors.accent, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                Text(
                  'Subscribe to unlock full nutrition tracking and meal planning',
                  style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primaryGrayDark),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Subscription Upgrade Banner
          _buildSubscriptionBanner(context),

          const SizedBox(height: 24),

          // What You'll Get Section
          Text(
            'What You\'ll Get',
            style: AppTextStyles.titleLarge.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          // Feature Preview Cards
          _buildFeaturePreviewCard(
            icon: Icons.local_fire_department,
            title: 'Calorie Tracking',
            description: 'Track your daily calorie intake and stay within your goals',
            color: const Color(0xFFFF6B6B),
            preview: '2,450 / 2,500 kcal',
          ),
          const SizedBox(height: 12),
          _buildFeaturePreviewCard(
            icon: Icons.fitness_center,
            title: 'Macro Tracking',
            description: 'Monitor protein, carbs, and fats with detailed progress bars',
            color: const Color(0xFF4A90E2),
            preview: 'P: 180g  C: 250g  F: 65g',
          ),
          const SizedBox(height: 12),
          _buildFeaturePreviewCard(
            icon: Icons.restaurant_menu,
            title: 'Food Log',
            description: 'Log meals by type: Breakfast, Lunch, Dinner, and Snacks',
            color: const Color(0xFFFFA726),
            preview: 'Breakfast • Lunch • Dinner • Snacks',
          ),
          const SizedBox(height: 12),
          _buildFeaturePreviewCard(
            icon: Icons.menu_book,
            title: 'Full Cookbook Access',
            description: 'Access hundreds of easy-to-prepare meals and shakes',
            color: const Color(0xFF9C27B0),
            preview: '500+ Recipes Available',
          ),
          const SizedBox(height: 12),
          _buildFeaturePreviewCard(
            icon: Icons.people,
            title: 'Community Features',
            description: 'Share meals, progress pics, and workout videos with the community',
            color: const Color(0xFF4CAF50),
            preview: 'Connect with Others',
          ),

          const SizedBox(height: 24),

          // Subscription Benefits Section
          _buildSubscriptionBenefitsSection(context),

          const SizedBox(height: 24),

          // Upgrade Button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: () => _showSubscriptionOptions(context),
              icon: const Icon(Icons.star, size: 24),
              label: Text(
                'Upgrade to Premium',
                style: AppTextStyles.buttonLarge.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 6,
                shadowColor: AppColors.accent.withOpacity(0.4),
              ),
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildFeaturePreviewCard({required IconData icon, required String title, required String description, required Color color, required String preview}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.lightGray.withOpacity(0.5)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.titleMedium.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(description, style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGrayDark)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: color.withOpacity(0.3)),
                  ),
                  child: Text(
                    preview,
                    style: AppTextStyles.labelSmall.copyWith(color: color, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.lock_outline, color: AppColors.mediumGray, size: 20),
        ],
      ),
    );
  }

  Widget _buildSubscriptionBanner(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [AppColors.accent, AppColors.accent.withOpacity(0.8)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: AppColors.accent.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.star, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Unlock Premium Features',
                      style: AppTextStyles.titleLarge.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text('Subscribe to track calories & macros', style: AppTextStyles.bodyMedium.copyWith(color: Colors.white.withOpacity(0.9))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _showSubscriptionOptions(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.accent,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: Text(
                'Upgrade Now',
                style: AppTextStyles.titleMedium.copyWith(color: AppColors.accent, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubscriptionBenefitsSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.lightGray.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'What You\'ll Get',
            style: AppTextStyles.titleMedium.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildBenefitItem(Icons.local_fire_department, 'Track Calories & Macros', 'Monitor your daily nutrition goals'),
          const SizedBox(height: 12),
          _buildBenefitItem(Icons.restaurant_menu, 'Full Cookbook Access', 'Easy-to-prepare meals and shakes'),
          const SizedBox(height: 12),
          _buildBenefitItem(Icons.people, 'Community Features', 'Post meals, progress pics & workout videos'),
          const SizedBox(height: 12),
          _buildBenefitItem(Icons.person_search, 'Trainer Subscriptions', '1-on-1 personal training (in-person or online)'),
        ],
      ),
    );
  }

  Widget _buildBenefitItem(IconData icon, String title, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: AppColors.accent, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 2),
              Text(description, style: AppTextStyles.bodySmall.copyWith(color: AppColors.mediumGray)),
            ],
          ),
        ),
      ],
    );
  }

  void _showSubscriptionRequiredDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.star, color: AppColors.accent, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Subscription Required',
                style: AppTextStyles.titleLarge.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Calorie tracking is a premium feature. Subscribe to unlock:', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onSurface)),
            const SizedBox(height: 16),
            _buildBenefitItem(Icons.local_fire_department, 'Daily calorie & macro tracking', ''),
            const SizedBox(height: 8),
            _buildBenefitItem(Icons.restaurant_menu, 'Full cookbook access', ''),
            const SizedBox(height: 8),
            _buildBenefitItem(Icons.people, 'Community features', ''),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Later', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.mediumGray)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _showSubscriptionOptions(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('View Plans'),
          ),
        ],
      ),
    );
  }

  void _showSubscriptionOptions(BuildContext context) {
    // Navigate to subscription/payment screen
    // For now, navigate to payment form - in production, create a dedicated subscription screen
    Get.toNamed(AppRoutes.paymentForm, arguments: {'type': 'subscription'});
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

  Widget _buildCaloriesCard(double consumed, double goal, double progress, {bool isLimited = false}) {
    final remaining = goal - consumed;
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
              Text(
                'Calories',
                style: AppTextStyles.titleMedium.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold),
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
              value: progress.clamp(0.0, 1.0),
              backgroundColor: Colors.white,
              valueColor: AlwaysStoppedAnimation<Color>(progress > 1.0 ? Colors.red : AppColors.accent),
              minHeight: 10,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            remaining > 0 ? '${remaining.toStringAsFixed(0)} kcal remaining' : '${(-remaining).toStringAsFixed(0)} kcal over',
            style: AppTextStyles.bodyMedium.copyWith(color: remaining > 0 ? AppColors.black : Colors.red, fontWeight: FontWeight.w500),
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
                      if (!controller.hasSubscription.value) {
                        _showSubscriptionRequiredDialog(context);
                        return;
                      }
                      Get.to(() => AddFoodScreen(mealType: mealType));
                    },
                    )
                  else
                  _smallAddCircle(
                    onTap: () {
                      if (!controller.hasSubscription.value) {
                        _showSubscriptionRequiredDialog(context);
                        return;
                      }
                      Get.to(() => AddFoodScreen(mealType: mealType));
                    },
                    ),
                ],
            ),
          ),
          if (meals.isNotEmpty) ...[const Divider(height: 1, color: AppColors.lightGray, thickness: 1), ...meals.map((meal) => _buildMealItem(controller, meal))],
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
      MealType.breakfast => 'assets/images/Group 48099133.png',
      MealType.lunch => 'assets/images/Subtract.png',
      MealType.dinner => 'assets/images/Subtract (1).png',
      MealType.snacks => 'assets/images/Group 48099134.png',
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

  Widget _buildMealItem(NutritionController controller, MealEntry meal) {
    return Dismissible(
      key: Key(meal.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        return await Get.dialog<bool>(
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
            ) ??
            false;
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [Colors.transparent, AppColors.error], begin: Alignment.centerLeft, end: Alignment.centerRight),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.delete_outline, color: Colors.white, size: 28),
            SizedBox(height: 4),
            Text(
              'Delete',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
      onDismissed: (direction) {
        controller.removeMealEntry(meal.id);
        Get.snackbar(
          'Removed',
          '${meal.foodItem.name} removed from log',
          backgroundColor: AppColors.accent,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 2),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.lightGray, width: 0.5)),
        ),
        child: Row(
          children: [
            // Compact item like screenshot: just names and kcal pill
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
