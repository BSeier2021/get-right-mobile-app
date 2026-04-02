import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:get_right/controllers/nutrition_controller.dart';
import 'package:get_right/models/food_item.dart';
import 'package:get_right/models/meal_entry.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';

/// Add Food Screen - Add food items to tracker
class AddFoodScreen extends StatefulWidget {
  final MealType mealType;

  const AddFoodScreen({super.key, required this.mealType});

  @override
  State<AddFoodScreen> createState() => _AddFoodScreenState();
}

class _AddFoodScreenState extends State<AddFoodScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final controller = Get.find<NutritionController>();

  // Custom food form controllers
  final nameController = TextEditingController();
  final caloriesController = TextEditingController();
  final proteinController = TextEditingController();
  final carbsController = TextEditingController();
  final fatsController = TextEditingController();
  final servingSizeController = TextEditingController(text: '1');
  final servingUnitController = TextEditingController(text: 'serving');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    nameController.dispose();
    caloriesController.dispose();
    proteinController.dispose();
    carbsController.dispose();
    fatsController.dispose();
    servingSizeController.dispose();
    servingUnitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.accent, size: 18),
          ),
          onPressed: () => Get.back(),
        ),
        title: Text('Add To ${widget.mealType.displayName}', style: AppTextStyles.titleLarge.copyWith(fontWeight: FontWeight.bold)),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(68),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Container(
              height: 50.h,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(color: const Color.fromARGB(0, 209, 213, 219), borderRadius: BorderRadius.circular(14)),
              child: AnimatedBuilder(
                animation: _tabController,
                builder: (context, child) {
                  return TabBar(
                    controller: _tabController,
                    indicator: BoxDecoration(
                      gradient: LinearGradient(colors: [AppColors.accent, AppColors.accent.withOpacity(0.85)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                      borderRadius: BorderRadius.circular(50),
                      boxShadow: [BoxShadow(color: AppColors.accent.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 2))],
                    ),

                    indicatorSize: TabBarIndicatorSize.tab,
                    dividerColor: Colors.transparent,
                    labelColor: AppColors.onAccent,
                    unselectedLabelColor: AppColors.onSurface.withOpacity(0.6),
                    labelStyle: AppTextStyles.titleSmall.copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.3),
                    unselectedLabelStyle: AppTextStyles.titleSmall.copyWith(fontWeight: FontWeight.w500),
                    tabs: [
                      Tab(child: const Text('Saved Items')),
                      Tab(child: const Text('Custom')),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
      body: TabBarView(controller: _tabController, children: [_buildSavedItemsTab(), _buildCustomFoodTab()]),
    );
  }

  Widget _buildSavedItemsTab() {
    return GetBuilder<NutritionController>(
      builder: (controller) {
        if (controller.savedFoodItems.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.1), shape: BoxShape.circle),
                    child: const Icon(Icons.bookmark_border, size: 60, color: AppColors.accent),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'No saved items yet',
                    style: AppTextStyles.titleMedium.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add custom foods to save them\nfor quick access',
                    style: AppTextStyles.bodyMedium.copyWith(color: AppColors.mediumGray),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: controller.savedFoodItems.length,
          itemBuilder: (context, index) {
            final item = controller.savedFoodItems[index];
            return _buildSavedFoodCard(item);
          },
        );
      },
    );
  }

  Widget _buildSavedFoodCard(FoodItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.accent.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.accent.withOpacity(0.14), width: 1.5),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 1))],
      ),
      child: InkWell(
        onTap: () => _showQuantityDialog(item),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.bold, color: AppColors.onSurface),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${item.defaultServingSize} ${item.servingUnit}',
                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.mediumGray, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.accent.withOpacity(0.4), width: 1.5),
                          ),
                          child: Text(
                            '${item.calories.toStringAsFixed(0)} kcal',
                            style: AppTextStyles.labelSmall.copyWith(color: AppColors.accent, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'P${item.protein.toStringAsFixed(0)} C${item.carbs.toStringAsFixed(0)} F${item.fats.toStringAsFixed(0)}',
                          style: AppTextStyles.labelSmall.copyWith(color: AppColors.mediumGray),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.accent.withOpacity(0.6), width: 1.5),
                  ),
                  child: const Icon(Icons.more_vert, color: AppColors.accent, size: 18),
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                onSelected: (value) {
                  if (value == 'edit') {
                    _showEditFoodDialog(item);
                  } else if (value == 'delete') {
                    _showDeleteConfirmationDialog(item);
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                          child: const Icon(Icons.edit, color: AppColors.accent, size: 16),
                        ),
                        const SizedBox(width: 12),
                        Text('Edit', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onSurface)),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                          child: const Icon(Icons.delete_outline, color: Colors.red, size: 16),
                        ),
                        const SizedBox(width: 12),
                        Text('Delete', style: AppTextStyles.bodyMedium.copyWith(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCustomFoodTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: AppColors.accent, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Create a custom food item with your own nutritional values',
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.accent, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Food Name
          _buildTextField(controller: nameController, label: 'Food Name', hint: 'e.g., Chicken Breast'),
          const SizedBox(height: 16),

          // Serving Size and Unit
          Row(
            children: [
              Expanded(
                child: _buildTextField(controller: servingSizeController, label: 'Serving Size', hint: '1', keyboardType: TextInputType.number),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTextField(controller: servingUnitController, label: 'Unit', hint: 'serving'),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Calories
          _buildTextField(controller: caloriesController, label: 'Calories', hint: 'e.g., 200', keyboardType: TextInputType.number),
          const SizedBox(height: 16),

          // Macros Row
          Row(
            children: [
              Container(
                width: 4,
                height: 20,
                decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(width: 8),
              Text(
                'Macronutrients',
                style: AppTextStyles.titleSmall.copyWith(fontWeight: FontWeight.bold, color: AppColors.onSurface),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: _buildTextField(controller: proteinController, label: 'Protein (g)', hint: '0', keyboardType: TextInputType.number),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTextField(controller: carbsController, label: 'Carbs (g)', hint: '0', keyboardType: TextInputType.number),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTextField(controller: fatsController, label: 'Fats (g)', hint: '0', keyboardType: TextInputType.number),
              ),
            ],
          ),

          const SizedBox(height: 32),

          // Add Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => Get.back(),

              icon: const Icon(Icons.add_circle_outline, size: 22),
              label: Text(
                'Add to Tracker',
                style: AppTextStyles.buttonLarge.copyWith(color: AppColors.onAccent, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: AppColors.onAccent,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                elevation: 2,
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Save for Later Button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => Get.back(),
              icon: const Icon(Icons.bookmark_outline, size: 20),
              label: Text(
                'Save for Later',
                style: AppTextStyles.buttonLarge.copyWith(color: AppColors.accent, fontWeight: FontWeight.bold),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.accent,
                side: const BorderSide(color: AppColors.accent, width: 2),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({required TextEditingController controller, required String label, required String hint, TextInputType keyboardType = TextInputType.text}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.black, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.black),
            filled: true,
            fillColor: AppColors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(50),
              borderSide: BorderSide(color: AppColors.primaryGrayLight),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(50),
              borderSide: BorderSide(color: AppColors.primaryGrayLight),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(50),
              borderSide: const BorderSide(color: AppColors.accent, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
        ),
      ],
    );
  }

  void _showQuantityDialog(FoodItem item) {
    double quantity = item.defaultServingSize;
    final quantityController = TextEditingController(text: quantity.toString());

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: AppColors.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.add_circle, color: AppColors.accent, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Add ${item.name}',
                    style: AppTextStyles.titleLarge.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('How many servings?', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.mediumGray)),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_circle, color: AppColors.accent, size: 32),
                      onPressed: () {
                        if (quantity > 0.5) {
                          setState(() {
                            quantity -= 0.5;
                            quantityController.text = quantity.toString();
                          });
                        }
                      },
                    ),
                    SizedBox(
                      width: 80,
                      child: TextField(
                        controller: quantityController,
                        textAlign: TextAlign.center,
                        keyboardType: TextInputType.number,
                        style: AppTextStyles.headlineMedium.copyWith(fontWeight: FontWeight.bold, color: AppColors.onSurface),
                        onChanged: (value) {
                          quantity = double.tryParse(value) ?? quantity;
                        },
                        decoration: const InputDecoration(border: InputBorder.none),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle, color: AppColors.accent, size: 32),
                      onPressed: () {
                        setState(() {
                          quantity += 0.5;
                          quantityController.text = quantity.toString();
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.accent.withOpacity(0.2)),
                  ),
                  child: Column(
                    children: [
                      _buildNutritionRow('Calories', '${(item.calories * quantity).toStringAsFixed(0)} kcal'),
                      _buildNutritionRow('Protein', '${(item.protein * quantity).toStringAsFixed(1)} g'),
                      _buildNutritionRow('Carbs', '${(item.carbs * quantity).toStringAsFixed(1)} g'),
                      _buildNutritionRow('Fats', '${(item.fats * quantity).toStringAsFixed(1)} g'),
                    ],
                  ),
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
                  _addFoodToTracker(item, quantity);
                  Get.back(); // Close dialog
                  Get.back(); // Go back to nutrition screen
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

  Widget _buildNutritionRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.mediumGray)),
          Text(
            value,
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  void _addFoodToTracker(FoodItem item, double quantity) {
    final entry = MealEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      foodItem: item,
      quantity: quantity,
      mealType: widget.mealType,
      timestamp: controller.selectedDate.value,
    );

    controller.addMealEntry(entry);

    Get.snackbar(
      'Success',
      '${item.name} added to ${widget.mealType.displayName}',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: AppColors.accent,
      colorText: Colors.white,
    );
  }

  void _addCustomFood() {
    if (_validateCustomFood()) {
      final foodItem = _createFoodItem();
      _addFoodToTracker(foodItem, double.tryParse(servingSizeController.text) ?? 1.0);
    }
  }

  void _saveCustomFood() {
    if (_validateCustomFood()) {
      final foodItem = _createFoodItem();
      controller.saveFoodItem(foodItem);

      Get.snackbar('Success', '${foodItem.name} saved for later use', snackPosition: SnackPosition.BOTTOM, backgroundColor: AppColors.accent, colorText: Colors.white);

      // Clear form
      _clearForm();
    }
  }

  bool _validateCustomFood() {
    if (nameController.text.isEmpty) {
      Get.snackbar('Error', 'Please enter a food name', snackPosition: SnackPosition.BOTTOM);
      return false;
    }
    if (caloriesController.text.isEmpty) {
      Get.snackbar('Error', 'Please enter calories', snackPosition: SnackPosition.BOTTOM);
      return false;
    }
    return true;
  }

  FoodItem _createFoodItem() {
    return FoodItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: nameController.text,
      calories: double.tryParse(caloriesController.text) ?? 0,
      protein: double.tryParse(proteinController.text) ?? 0,
      carbs: double.tryParse(carbsController.text) ?? 0,
      fats: double.tryParse(fatsController.text) ?? 0,
      defaultServingSize: double.tryParse(servingSizeController.text) ?? 1.0,
      servingUnit: servingUnitController.text,
    );
  }

  void _clearForm() {
    nameController.clear();
    caloriesController.clear();
    proteinController.clear();
    carbsController.clear();
    fatsController.clear();
    servingSizeController.text = '1';
    servingUnitController.text = 'serving';
  }

  void _showEditFoodDialog(FoodItem item) {
    // Initialize controllers with current values
    final editNameController = TextEditingController(text: item.name);
    final editCaloriesController = TextEditingController(text: item.calories.toStringAsFixed(0));
    final editProteinController = TextEditingController(text: item.protein.toStringAsFixed(0));
    final editCarbsController = TextEditingController(text: item.carbs.toStringAsFixed(0));
    final editFatsController = TextEditingController(text: item.fats.toStringAsFixed(0));
    final editServingSizeController = TextEditingController(text: item.defaultServingSize.toStringAsFixed(1));
    final editServingUnitController = TextEditingController(text: item.servingUnit ?? 'serving');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 20, offset: const Offset(0, -5))],
        ),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.only(top: 24, left: 24, right: 24, bottom: MediaQuery.of(context).viewInsets.bottom + 24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle bar
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(color: AppColors.primaryGray.withOpacity(0.3), borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  // Title
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.edit, color: AppColors.accent, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Edit Food Item',
                          style: AppTextStyles.headlineSmall.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(
                        icon: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: AppColors.primaryGrayLight.withOpacity(0.3), shape: BoxShape.circle),
                          child: const Icon(Icons.close, color: AppColors.mediumGray, size: 18),
                        ),
                        onPressed: () => Navigator.pop(context),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Food Name
                  _buildTextField(controller: editNameController, label: 'Food Name', hint: 'e.g., Chicken Breast'),
                  const SizedBox(height: 16),
                  // Serving Size and Unit
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(controller: editServingSizeController, label: 'Serving Size', hint: '1', keyboardType: TextInputType.number),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTextField(controller: editServingUnitController, label: 'Unit', hint: 'serving'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Calories
                  _buildTextField(controller: editCaloriesController, label: 'Calories', hint: 'e.g., 200', keyboardType: TextInputType.number),
                  const SizedBox(height: 16),
                  // Macros
                  Row(
                    children: [
                      Container(
                        width: 4,
                        height: 20,
                        decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(2)),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Macronutrients',
                        style: AppTextStyles.titleSmall.copyWith(fontWeight: FontWeight.bold, color: AppColors.onSurface),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(controller: editProteinController, label: 'Protein (g)', hint: '0', keyboardType: TextInputType.number),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTextField(controller: editCarbsController, label: 'Carbs (g)', hint: '0', keyboardType: TextInputType.number),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTextField(controller: editFatsController, label: 'Fats (g)', hint: '0', keyboardType: TextInputType.number),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        if (editNameController.text.isEmpty) {
                          Get.snackbar('Error', 'Please enter a food name', snackPosition: SnackPosition.BOTTOM);
                          return;
                        }
                        if (editCaloriesController.text.isEmpty) {
                          Get.snackbar('Error', 'Please enter calories', snackPosition: SnackPosition.BOTTOM);
                          return;
                        }

                        final updatedItem = item.copyWith(
                          name: editNameController.text.trim(),
                          calories: double.tryParse(editCaloriesController.text) ?? item.calories,
                          protein: double.tryParse(editProteinController.text) ?? item.protein,
                          carbs: double.tryParse(editCarbsController.text) ?? item.carbs,
                          fats: double.tryParse(editFatsController.text) ?? item.fats,
                          defaultServingSize: double.tryParse(editServingSizeController.text) ?? item.defaultServingSize,
                          servingUnit: editServingUnitController.text.trim().isEmpty ? item.servingUnit : editServingUnitController.text.trim(),
                        );

                        controller.updateSavedFoodItem(updatedItem);

                        Navigator.pop(context);
                        Get.snackbar(
                          'Success',
                          '${updatedItem.name} updated successfully',
                          snackPosition: SnackPosition.BOTTOM,
                          backgroundColor: AppColors.accent,
                          colorText: Colors.white,
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        'Save Changes',
                        style: AppTextStyles.buttonLarge.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ).then((_) {
      // Dispose controllers when dialog is closed
      editNameController.dispose();
      editCaloriesController.dispose();
      editProteinController.dispose();
      editCarbsController.dispose();
      editFatsController.dispose();
      editServingSizeController.dispose();
      editServingUnitController.dispose();
    });
  }

  void _showDeleteConfirmationDialog(FoodItem item) {
    Get.dialog<bool>(
      AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Delete Food Item',
          style: AppTextStyles.titleLarge.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold),
        ),
        content: Text('Are you sure you want to delete "${item.name}"?', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.mediumGray)),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: Text('Cancel', style: AppTextStyles.buttonMedium.copyWith(color: AppColors.mediumGray)),
          ),
          ElevatedButton(
            onPressed: () => Get.back(result: true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Delete', style: AppTextStyles.buttonMedium.copyWith(color: Colors.white)),
          ),
        ],
      ),
    ).then((confirmed) {
      if (confirmed == true) {
        controller.removeSavedFoodItem(item.id);
        Get.snackbar('Deleted', '${item.name} removed from saved items', snackPosition: SnackPosition.BOTTOM, backgroundColor: AppColors.accent, colorText: Colors.white);
      }
    });
  }
}
