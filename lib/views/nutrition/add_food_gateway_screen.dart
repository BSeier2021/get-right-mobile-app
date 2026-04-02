import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_right/controllers/nutrition_controller.dart';
import 'package:get_right/models/meal_entry.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';
import 'package:get_right/views/nutrition/add_food_screen.dart';

class AddFoodGatewayScreen extends StatelessWidget {
  AddFoodGatewayScreen({super.key});

  final NutritionController controller = Get.find<NutritionController>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        centerTitle: true,
        elevation: 0,
        title: Text('Add Food', style: AppTextStyles.titleLarge.copyWith(fontWeight: FontWeight.w600)),
        leading: IconButton(
          onPressed: () => Get.back(),
          icon: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.accent, size: 16),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          _mealCard(context, MealType.breakfast),
          const SizedBox(height: 14),
          _mealCard(context, MealType.lunch),
          const SizedBox(height: 14),
          _mealCard(context, MealType.dinner),
          const SizedBox(height: 14),
          _mealCard(context, MealType.snacks),
        ],
      ),
    );
  }

  Widget _mealCard(BuildContext context, MealType type) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () {
        if (!controller.hasSubscription.value) {
          Get.snackbar('Subscription', 'Subscribe to add food', snackPosition: SnackPosition.BOTTOM);
          return;
        }
        Get.to(() => AddFoodScreen(mealType: type));
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FFE9),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFCDE7C8), width: 1),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Row(
          children: [
            // Circular pastel icon
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: _iconBg(type), shape: BoxShape.circle),
              alignment: Alignment.center,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Image.asset(
                  _iconAsset(type),
                  fit: BoxFit.contain,
                  errorBuilder: (c, e, s) => Text(type.icon, style: const TextStyle(fontSize: 20)),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                type.displayName,
                style: AppTextStyles.bodyLarge.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.w600),
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.primaryGray, size: 24),
          ],
        ),
      ),
    );
  }

  // Card background — very light tint per meal
  Color _cardBg(MealType type) => switch (type) {
    MealType.breakfast => const Color(0xFFEFF8EE),
    MealType.lunch => const Color(0xFFFFF6EC),
    MealType.dinner => const Color(0xFFF5EDFD),
    MealType.snacks => const Color(0xFFEDF5FA),
  };

  // Pastel circle background behind icon
  Color _iconBg(MealType type) => switch (type) {
    MealType.breakfast => const Color(0xFFFFF0D8),
    MealType.lunch => const Color(0xFFFFE7D5),
    MealType.dinner => const Color(0xFFF3E6FF),
    MealType.snacks => const Color(0xFFE0F3FF),
  };

  // PNG asset per meal (same assets used on the tracker tab)
  String _iconAsset(MealType type) => switch (type) {
    MealType.breakfast => 'assets/images/Group 48099133.png',
    MealType.lunch => 'assets/images/Subtract.png',
    MealType.dinner => 'assets/images/Subtract (1).png',
    MealType.snacks => 'assets/images/Group 48099134.png',
  };
}
