import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';

/// Meal logging screen for journal entries
class LogMealScreen extends StatefulWidget {
  const LogMealScreen({super.key});

  @override
  State<LogMealScreen> createState() => _LogMealScreenState();
}

class _LogMealScreenState extends State<LogMealScreen> {
  final _formKey = GlobalKey<FormState>();
  final _mealNameController = TextEditingController();
  final _caloriesController = TextEditingController();
  final _proteinController = TextEditingController();
  final _carbsController = TextEditingController();
  final _fatsController = TextEditingController();
  final _notesController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  String _selectedMealType = 'Breakfast';

  final List<String> _mealTypes = ['Breakfast', 'Lunch', 'Dinner', 'Snack'];
  final Map<String, IconData> _mealIcons = {'Breakfast': Icons.wb_sunny, 'Lunch': Icons.lunch_dining, 'Dinner': Icons.dinner_dining, 'Snack': Icons.cookie};

  @override
  void dispose() {
    _mealNameController.dispose();
    _caloriesController.dispose();
    _proteinController.dispose();
    _carbsController.dispose();
    _fatsController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _saveMeal() {
    if (_formKey.currentState!.validate()) {
      // TODO: Save to storage service
      Get.back();
      Get.snackbar(
        'Meal Logged',
        'Your meal has been added to your journal',
        backgroundColor: const Color(0xFFFF9800),
        colorText: AppColors.onAccent,
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.onPrimary),
          onPressed: () => Get.back(),
        ),
        title: Text('Log Meal', style: AppTextStyles.titleLarge.copyWith()),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _saveMeal,
            child: Text(
              'Save',
              style: AppTextStyles.labelLarge.copyWith(color: AppColors.accent, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [const Color(0xFFFF9800).withValues(alpha: 0.15), AppColors.surface], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFFF9800).withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(color: const Color(0xFFFF9800).withValues(alpha: 0.2), shape: BoxShape.circle),
                      child: const Icon(Icons.restaurant, color: Color(0xFFFF9800), size: 32),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Meal Entry', style: AppTextStyles.titleMedium.copyWith(color: AppColors.onSurface)),
                          const SizedBox(height: 4),
                          Text('Track your nutrition', style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGray)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Meal Type
              Text(
                'Meal Type',
                style: AppTextStyles.titleSmall.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _mealTypes.map((type) {
                  final isSelected = _selectedMealType == type;
                  return ChoiceChip(
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_mealIcons[type], size: 18, color: isSelected ? AppColors.onAccent : AppColors.onSurface),
                        const SizedBox(width: 6),
                        Text(type),
                      ],
                    ),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() => _selectedMealType = type);
                    },
                    selectedColor: const Color(0xFFFF9800),
                    backgroundColor: AppColors.surface,
                    labelStyle: AppTextStyles.labelMedium.copyWith(
                      color: isSelected ? AppColors.onAccent : AppColors.onSurface,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              // Date & Time
              Text(
                'Date & Time',
                style: AppTextStyles.titleSmall.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildDateTimeCard(
                      icon: Icons.calendar_today,
                      label: 'Date',
                      value: DateFormat('MMM dd, yyyy').format(_selectedDate),
                      onTap: () async {
                        final date = await showDatePicker(context: context, initialDate: _selectedDate, firstDate: DateTime(2020), lastDate: DateTime.now());
                        if (date != null) {
                          setState(() => _selectedDate = date);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildDateTimeCard(
                      icon: Icons.access_time,
                      label: 'Time',
                      value: _selectedTime.format(context),
                      onTap: () async {
                        final time = await showTimePicker(context: context, initialTime: _selectedTime);
                        if (time != null) {
                          setState(() => _selectedTime = time);
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Meal Name
              Text(
                'Meal Name',
                style: AppTextStyles.titleSmall.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _mealNameController,
                decoration: InputDecoration(
                  hintText: 'e.g., Chicken Salad',
                  prefixIcon: const Icon(Icons.restaurant_menu, color: Color(0xFFFF9800)),
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.primaryGray.withValues(alpha: 0.3)),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter meal name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Nutrition Info
              Text(
                'Nutrition (Optional)',
                style: AppTextStyles.titleSmall.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _caloriesController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Calories',
                        suffixText: 'kcal',
                        filled: true,
                        fillColor: AppColors.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppColors.primaryGray.withValues(alpha: 0.3)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _proteinController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Protein',
                        suffixText: 'g',
                        filled: true,
                        fillColor: AppColors.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppColors.primaryGray.withValues(alpha: 0.3)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _carbsController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Carbs',
                        suffixText: 'g',
                        filled: true,
                        fillColor: AppColors.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppColors.primaryGray.withValues(alpha: 0.3)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _fatsController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Fats',
                        suffixText: 'g',
                        filled: true,
                        fillColor: AppColors.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppColors.primaryGray.withValues(alpha: 0.3)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Notes
              Text(
                'Notes (Optional)',
                style: AppTextStyles.titleSmall.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notesController,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Recipe, ingredients, or any notes...',
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.primaryGray.withValues(alpha: 0.3)),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Save Button
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: _saveMeal,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF9800),
                    foregroundColor: AppColors.onAccent,
                    elevation: 4,
                    shadowColor: const Color(0xFFFF9800).withValues(alpha: 0.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.check_circle, size: 24),
                      const SizedBox(width: 8),
                      Text('Save Meal', style: AppTextStyles.buttonLarge),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDateTimeCard({required IconData icon, required String label, required String value, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primaryGray.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: const Color(0xFFFF9800)),
                const SizedBox(width: 6),
                Text(label, style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryGray)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
