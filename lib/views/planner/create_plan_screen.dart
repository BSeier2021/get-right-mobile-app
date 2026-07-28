import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:get_right/models/workout_plan_model.dart';
import 'package:get_right/services/storage_service.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';
import 'package:get_right/utils/validators.dart';
import 'package:get_right/widgets/common/custom_button.dart';
import 'package:get_right/widgets/common/custom_text_field.dart';

/// Create Plan Screen - Create a new workout plan with scheduled workouts
class CreatePlanScreen extends StatefulWidget {
  const CreatePlanScreen({super.key});

  @override
  State<CreatePlanScreen> createState() => _CreatePlanScreenState();
}

class _CreatePlanScreenState extends State<CreatePlanScreen> {
  final _formKey = GlobalKey<FormState>();
  final _planNameController = TextEditingController();
  final _descriptionController = TextEditingController();

  DateTime? _startDate;
  DateTime? _endDate;
  final List<PlannedWorkoutFormData> _workouts = [];

  @override
  void dispose() {
    _planNameController.dispose();
    _descriptionController.dispose();
    for (var workout in _workouts) {
      workout.dispose();
    }
    super.dispose();
  }

  Future<void> _selectStartDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(primary: AppColors.accent, onPrimary: AppColors.onAccent, surface: AppColors.surface, onSurface: AppColors.onSurface),
          ),
          child: child!,
        );
      },
    );
    if (date != null) {
      setState(() {
        _startDate = date;
        if (_endDate != null && _endDate!.isBefore(date)) {
          _endDate = null;
        }
      });
    }
  }

  Future<void> _selectEndDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _endDate ?? _startDate ?? DateTime.now().add(const Duration(days: 7)),
      firstDate: _startDate ?? DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(primary: AppColors.accent, onPrimary: AppColors.onAccent, surface: AppColors.surface, onSurface: AppColors.onSurface),
          ),
          child: child!,
        );
      },
    );
    if (date != null) {
      setState(() {
        _endDate = date;
      });
    }
  }

  void _addWorkout() {
    setState(() {
      _workouts.add(PlannedWorkoutFormData());
    });
  }

  void _removeWorkout(int index) {
    setState(() {
      _workouts[index].dispose();
      _workouts.removeAt(index);
    });
  }

  Future<void> _savePlan() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_workouts.isEmpty) {
      Get.snackbar(
        'Error',
        'Please add at least one workout to your plan',
        backgroundColor: AppColors.missed,
        colorText: AppColors.onAccent,
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
      );
      return;
    }

    // Validate all workouts
    bool allWorkoutsValid = true;
    for (int i = 0; i < _workouts.length; i++) {
      final workout = _workouts[i];
      if (workout.exerciseNameController.text.trim().isEmpty ||
          workout.setsController.text.trim().isEmpty ||
          workout.repsController.text.trim().isEmpty ||
          workout.dayOfWeek == null) {
        allWorkoutsValid = false;
        Get.snackbar(
          'Error',
          'Please fill in all required fields for workout ${i + 1}',
          backgroundColor: AppColors.missed,
          colorText: AppColors.onAccent,
          snackPosition: SnackPosition.BOTTOM,
          margin: const EdgeInsets.all(16),
        );
        break;
      }
    }

    if (!allWorkoutsValid) {
      return;
    }

    try {
      // Get user ID from storage
      final storage = await StorageService.getInstance();
      final userId = storage.getUserId() ?? 'user_${DateTime.now().millisecondsSinceEpoch}';

      // Create planned workouts
      final plannedWorkouts = _workouts.map((workout) {
        return PlannedWorkout(
          exerciseName: workout.exerciseNameController.text.trim(),
          sets: int.parse(workout.setsController.text.trim()),
          reps: int.parse(workout.repsController.text.trim()),
          weight: workout.weightController.text.trim().isNotEmpty ? double.tryParse(workout.weightController.text.trim()) : null,
          notes: workout.notesController.text.trim().isNotEmpty ? workout.notesController.text.trim() : null,
          dayOfWeek: workout.dayOfWeek!,
          weekNumber: workout.weekNumberController.text.trim().isNotEmpty ? int.tryParse(workout.weekNumberController.text.trim()) : null,
        );
      }).toList();

      // Create workout plan
      // ignore: unused_local_variable
      final plan = WorkoutPlanModel(
        id: 'plan_${DateTime.now().millisecondsSinceEpoch}',
        userId: userId,
        name: _planNameController.text.trim(),
        description: _descriptionController.text.trim().isNotEmpty ? _descriptionController.text.trim() : null,
        workouts: plannedWorkouts,
        startDate: _startDate,
        endDate: _endDate,
        isTemplate: false,
        createdAt: DateTime.now(),
      );

      // TODO: Save plan to API/Backend
      // Example: await apiService.createWorkoutPlan(plan);
      // For now, show success message
      // Note: plan variable is ready for API integration
      Get.snackbar(
        'Success',
        'Workout plan created successfully!',
        backgroundColor: AppColors.completed,
        colorText: AppColors.onAccent,
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
      );

      Get.back();
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to create plan: ${e.toString()}',
        backgroundColor: AppColors.missed,
        colorText: AppColors.onAccent,
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.backgroundColor,
        title: Text('Create Plan', style: AppTextStyles.titleLarge.copyWith(color: AppColors.accent)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Plan Details Section
              _buildSectionHeader('Plan Details', Icons.description),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primaryGray, width: 1),
                ),
                child: Column(
                  children: [
                    CustomTextField(
                      controller: _planNameController,
                      labelText: 'Plan Name',
                      hintText: 'e.g., Weekly Strength Plan',
                      prefixIcon: const Icon(Icons.title),
                      validator: (value) => Validators.validateRequired(value, 'Plan name'),
                    ),
                    const SizedBox(height: 16),
                    CustomTextField(
                      controller: _descriptionController,
                      labelText: 'Description',
                      hintText: 'Optional - Describe your plan',
                      maxLines: 3,
                      prefixIcon: const Icon(Icons.notes),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Date Range Section
              _buildSectionHeader('Date Range', Icons.calendar_today),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: _selectStartDate,
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _startDate != null ? AppColors.accent : AppColors.primaryGray, width: _startDate != null ? 2 : 1),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
                                  child: const Icon(Icons.calendar_today, color: AppColors.accent, size: 20),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Start Date', style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryGray)),
                                      const SizedBox(height: 4),
                                      Text(
                                        _startDate != null ? '${_startDate!.day} ${_getMonthName(_startDate!.month)} ${_startDate!.year}' : 'Select date',
                                        style: AppTextStyles.titleSmall.copyWith(color: AppColors.onSurface),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: _selectEndDate,
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _endDate != null ? AppColors.accent : AppColors.primaryGray, width: _endDate != null ? 2 : 1),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
                                  child: const Icon(Icons.event, color: AppColors.accent, size: 20),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('End Date', style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryGray)),
                                      const SizedBox(height: 4),
                                      Text(
                                        _endDate != null ? '${_endDate!.day} ${_getMonthName(_endDate!.month)} ${_endDate!.year}' : 'Optional',
                                        style: AppTextStyles.titleSmall.copyWith(color: AppColors.onSurface),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Workouts Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildSectionHeader('Workouts', Icons.fitness_center),
                  TextButton.icon(
                    onPressed: _addWorkout,
                    icon: const Icon(Icons.add, color: AppColors.accent, size: 20),
                    label: Text(
                      'Add Workout',
                      style: AppTextStyles.labelMedium.copyWith(color: AppColors.accent, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              if (_workouts.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(40),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.primaryGray, width: 1, style: BorderStyle.solid),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.fitness_center_outlined, size: 60, color: AppColors.primaryGray.withValues(alpha: 0.5)),
                      const SizedBox(height: 16),
                      Text('No workouts added yet', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primaryGray)),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _addWorkout,
                        child: Text('Add First Workout', style: AppTextStyles.labelMedium.copyWith(color: AppColors.accent)),
                      ),
                    ],
                  ),
                )
              else
                ...List.generate(_workouts.length, (index) {
                  return Padding(padding: const EdgeInsets.only(bottom: 16), child: _buildWorkoutCard(index));
                }),
              const SizedBox(height: 24),

              // Action Buttons
              CustomButton(text: 'Create Plan', onPressed: _savePlan),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: OutlinedButton(
                  onPressed: () => Get.back(),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.primaryGray, width: 2),
                    foregroundColor: AppColors.onBackground,
                  ),
                  child: Text('Cancel', style: AppTextStyles.buttonLarge.copyWith(color: AppColors.onBackground)),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: AppColors.accent, size: 20),
        ),
        const SizedBox(width: 12),
        Text(title, style: AppTextStyles.titleMedium.copyWith(color: AppColors.onBackground)),
      ],
    );
  }

  Widget _buildWorkoutCard(int index) {
    final workout = _workouts[index];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.accent, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Workout ${index + 1}', style: AppTextStyles.titleSmall.copyWith(color: AppColors.accent)),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: AppColors.missed, size: 22),
                onPressed: () => _removeWorkout(index),
                tooltip: 'Remove workout',
              ),
            ],
          ),
          const SizedBox(height: 16),
          CustomTextField(
            controller: workout.exerciseNameController,
            labelText: 'Exercise Name',
            hintText: 'e.g., Bench Press',
            prefixIcon: const Icon(Icons.fitness_center),
            validator: (value) => Validators.validateRequired(value, 'Exercise name'),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: CustomTextField(
                  controller: workout.setsController,
                  labelText: 'Sets',
                  keyboardType: TextInputType.number,
                  prefixIcon: const Icon(Icons.repeat),
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (value) => Validators.validatePositiveNumber(value, fieldName: 'Sets'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: CustomTextField(
                  controller: workout.repsController,
                  labelText: 'Reps',
                  keyboardType: TextInputType.number,
                  prefixIcon: const Icon(Icons.numbers),
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (value) => Validators.validatePositiveNumber(value, fieldName: 'Reps'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          CustomTextField(
            controller: workout.weightController,
            labelText: 'Weight (kg)',
            hintText: 'Optional',
            keyboardType: TextInputType.number,
            prefixIcon: const Icon(Icons.scale),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
          ),
          const SizedBox(height: 16),

          // Day of Week Selection
          Text('Day of Week', style: AppTextStyles.labelMedium.copyWith(color: AppColors.onSurface)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'].asMap().entries.map((entry) {
              final dayIndex = entry.key + 1; // 1-7 (Monday-Sunday)
              final dayName = entry.value;
              final isSelected = workout.dayOfWeek == dayIndex;

              return GestureDetector(
                onTap: () {
                  setState(() {
                    workout.dayOfWeek = dayIndex;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.accent : AppColors.primaryVariant,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isSelected ? AppColors.accent : AppColors.primaryGray, width: isSelected ? 2 : 1),
                  ),
                  child: Text(
                    dayName,
                    style: AppTextStyles.labelMedium.copyWith(
                      color: isSelected ? AppColors.onAccent : AppColors.onBackground,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          CustomTextField(
            controller: workout.weekNumberController,
            labelText: 'Week Number',
            hintText: 'Optional - e.g., 1, 2, 3',
            keyboardType: TextInputType.number,
            prefixIcon: const Icon(Icons.calendar_view_week),
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),
          const SizedBox(height: 16),
          CustomTextField(controller: workout.notesController, labelText: 'Notes', hintText: 'Optional - Additional notes', maxLines: 2, prefixIcon: const Icon(Icons.notes)),
        ],
      ),
    );
  }

  String _getMonthName(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }
}

/// Helper class to manage form data for each planned workout
class PlannedWorkoutFormData {
  final TextEditingController exerciseNameController = TextEditingController();
  final TextEditingController setsController = TextEditingController();
  final TextEditingController repsController = TextEditingController();
  final TextEditingController weightController = TextEditingController();
  final TextEditingController notesController = TextEditingController();
  final TextEditingController weekNumberController = TextEditingController();
  int? dayOfWeek;

  void dispose() {
    exerciseNameController.dispose();
    setsController.dispose();
    repsController.dispose();
    weightController.dispose();
    notesController.dispose();
    weekNumberController.dispose();
  }
}
