import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_right/controllers/auth_controller.dart';
import 'package:get_right/controllers/nutrition_controller.dart';
import 'package:get_right/models/meal_entry.dart';
import 'package:get_right/models/nutrition_meal_type_option.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';
import 'package:get_right/views/nutrition/add_food_screen.dart';

class AddFoodGatewayScreen extends StatefulWidget {
  const AddFoodGatewayScreen({super.key});

  @override
  State<AddFoodGatewayScreen> createState() => _AddFoodGatewayScreenState();
}

class _AddFoodGatewayScreenState extends State<AddFoodGatewayScreen> {
  final NutritionController controller = Get.find<NutritionController>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (Get.isRegistered<AuthController>()) {
        Get.find<AuthController>().fetchNutritionMealTypes();
      }
    });
  }

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
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.accent, size: 18),
          ),
          onPressed: () => Get.back(),
        ),
      ),
      body: GetBuilder<AuthController>(
        builder: (auth) {
          final loading = auth.nutritionMealTypesLoading;
          final api = auth.nutritionMealTypes.where((e) => e.mealTypeEnum != null).toList();
          final useFallback = api.isEmpty;

          if (loading && auth.nutritionMealTypes.isEmpty && auth.nutritionMealTypesError == null) {
            return const Center(child: CircularProgressIndicator());
          }

          final children = <Widget>[];

          if (useFallback) {
            for (final t in MealType.values) {
              children.add(_mealCard(context, t));
              children.add(const SizedBox(height: 14));
            }
          } else {
            for (final o in api) {
              children.add(_mealCardFromApi(context, o));
              children.add(const SizedBox(height: 14));
            }
          }
          if (children.isNotEmpty && children.last is SizedBox) {
            children.removeLast();
          }

          return ListView(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), children: children);
        },
      ),
    );
  }

  Widget _mealCardFromApi(BuildContext context, NutritionMealTypeOption option) {
    final type = option.mealTypeEnum!;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => _onSelectMeal(type, mealTypeApiId: option.id.isNotEmpty ? option.id : null),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FFE9),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFCDE7C8), width: 1),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    option.name.isNotEmpty ? option.name : type.displayName,
                    style: AppTextStyles.bodyLarge.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.w600),
                  ),
                  if (option.description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(option.description, style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGray)),
                  ],
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(top: 10),
              child: Icon(Icons.chevron_right_rounded, color: AppColors.primaryGray, size: 24),
            ),
          ],
        ),
      ),
    );
  }

  void _onSelectMeal(MealType type, {String? mealTypeApiId}) {
    Get.to(() => AddFoodScreen(mealType: type, mealTypeApiId: mealTypeApiId));
  }

  Widget _mealCard(BuildContext context, MealType type) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => _onSelectMeal(type),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FFE9),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFCDE7C8), width: 1),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Row(
          children: [
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

  Color _iconBg(MealType type) => switch (type) {
    MealType.breakfast => const Color.fromARGB(61, 76, 175, 79),
    MealType.lunch => const Color(0xFFFFEACC),
    MealType.dinner => const Color(0xFFF3E6FF),
    MealType.snacks => const Color(0xFFE0F3FF),
  };

  String _iconAsset(MealType type) => switch (type) {
    MealType.breakfast => 'assets/images/meal_breakfast.png',
    MealType.lunch => 'assets/images/meal_lunch.png',
    MealType.dinner => 'assets/images/meal_dinner.png',
    MealType.snacks => 'assets/images/meal_snacks.png',
  };
}
