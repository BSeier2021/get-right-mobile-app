import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:get_right/constants/app_constants.dart';
import 'package:get_right/models/workout_model.dart';
import 'package:get_right/routes/app_routes.dart';
import 'package:get_right/services/storage_service.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';
import 'package:get_right/utils/validators.dart';
import 'package:get_right/widgets/common/custom_button.dart';
import 'package:get_right/widgets/common/custom_text_field.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

/// Add workout screen - Redesigned to match app theme
class AddWorkoutScreen extends StatefulWidget {
  const AddWorkoutScreen({super.key});

  @override
  State<AddWorkoutScreen> createState() => _AddWorkoutScreenState();
}

class _AddWorkoutScreenState extends State<AddWorkoutScreen> {
  final _formKey = GlobalKey<FormState>();
  final _exerciseController = TextEditingController();
  final _setsController = TextEditingController();
  final _repsController = TextEditingController();
  final _weightController = TextEditingController();
  final _notesController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();

  String? _progressPhotoPath;
  final List<String> _selectedTags = [];
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;
  bool _isEditMode = false;
  String? _editWorkoutId;
  StorageService? _storageService;

  @override
  void initState() {
    super.initState();
    _initializeStorage();
    _loadEditData();
  }

  Future<void> _initializeStorage() async {
    _storageService = await StorageService.getInstance();
  }

  void _loadEditData() {
    final arguments = Get.arguments;
    if (arguments != null && arguments['edit'] == true && arguments['entry'] != null) {
      setState(() {
        _isEditMode = true;
        final entry = arguments['entry'] as Map<String, dynamic>;
        _editWorkoutId = entry['id'];
        _exerciseController.text = entry['entry'] ?? '';
        // Try to parse existing data if available
        if (entry['date'] != null) {
          try {
            _selectedDate = DateFormat('MMM d, yyyy').parse(entry['date']);
          } catch (e) {
            _selectedDate = DateTime.now();
          }
        }
      });
    }
  }

  @override
  void dispose() {
    _exerciseController.dispose();
    _setsController.dispose();
    _repsController.dispose();
    _weightController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
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
        _selectedDate = date;
      });
    }
  }

  Future<void> _saveWorkout() async {
    FocusManager.instance.primaryFocus?.unfocus();

    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) {
      Get.snackbar(
        'Missing info',
        'Please fill in all required fields (Exercise Name, Sets, Reps).',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
      );
      return;
    }

    final sets = int.tryParse(_setsController.text.trim());
    final reps = int.tryParse(_repsController.text.trim());
    if (sets == null || reps == null) {
      Get.snackbar(
        'Invalid number',
        'Sets and Reps must be whole numbers.',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
      );
      return;
    }

    if (_storageService == null) {
      await _initializeStorage();
    }

    if (_storageService == null) {
      Get.snackbar(
        'Error',
        'Failed to initialize storage. Please try again.',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final userId = _storageService!.getUserId() ?? 'anonymous';
      final workout = WorkoutModel(
        id: _isEditMode && _editWorkoutId != null ? _editWorkoutId! : DateTime.now().millisecondsSinceEpoch.toString(),
        userId: userId,
        exerciseName: _exerciseController.text.trim(),
        sets: sets,
        reps: reps,
        weight: _weightController.text.trim().isNotEmpty ? double.tryParse(_weightController.text.trim()) : null,
        notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
        tags: _selectedTags.isNotEmpty ? _selectedTags : null,
        progressPhotos: _progressPhotoPath != null ? [_progressPhotoPath!] : null,
        date: _selectedDate,
        createdAt: DateTime.now(),
      );

      bool success;
      if (_isEditMode) {
        success = await _storageService!.updateWorkout(workout);
      } else {
        success = await _storageService!.addWorkout(workout);
      }

      setState(() {
        _isLoading = false;
      });

      if (success) {
        // Always leave this screen on success (some entry points don't await the route result).
        if (Navigator.of(context).canPop()) {
          Get.back(result: true);
        } else {
          Get.offAllNamed(AppRoutes.home);
        }
      } else {
        Get.snackbar(
          'Error',
          'Failed to save workout. Please try again.',
          backgroundColor: Colors.red,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
          margin: const EdgeInsets.all(16),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      Get.snackbar(
        'Error',
        'An error occurred: ${e.toString()}',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
      );
    }
  }

  /*
  // Previous implementation (kept commented for reference)
  Future<void> _saveWorkout() async {
    if (_formKey.currentState!.validate()) {
      if (_storageService == null) {
        await _initializeStorage();
      }

      if (_storageService == null) {
        Get.snackbar(
          'Error',
          'Failed to initialize storage. Please try again.',
          backgroundColor: Colors.red,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
          margin: const EdgeInsets.all(16),
        );
        return;
      }

      setState(() {
        _isLoading = true;
      });

      try {
        final userId = _storageService!.getUserId() ?? 'anonymous';
        final workout = WorkoutModel(
          id: _isEditMode && _editWorkoutId != null ? _editWorkoutId! : DateTime.now().millisecondsSinceEpoch.toString(),
          userId: userId,
          exerciseName: _exerciseController.text.trim(),
          sets: int.parse(_setsController.text.trim()),
          reps: int.parse(_repsController.text.trim()),
          weight: _weightController.text.trim().isNotEmpty ? double.tryParse(_weightController.text.trim()) : null,
          notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
          tags: _selectedTags.isNotEmpty ? _selectedTags : null,
          progressPhotos: _progressPhotoPath != null ? [_progressPhotoPath!] : null,
          date: _selectedDate,
          createdAt: DateTime.now(),
        );

        bool success;
        if (_isEditMode) {
          success = await _storageService!.updateWorkout(workout);
        } else {
          success = await _storageService!.addWorkout(workout);
        }

        setState(() {
          _isLoading = false;
        });

        if (success) {
          Get.snackbar(
            'Success',
            _isEditMode ? 'Workout updated successfully!' : 'Workout logged successfully!',
            backgroundColor: AppColors.accent,
            colorText: AppColors.onAccent,
            snackPosition: SnackPosition.BOTTOM,
            margin: const EdgeInsets.all(16),
          );
          Get.back(result: true); // Pass result to refresh journal screen
        } else {
          Get.snackbar(
            'Error',
            'Failed to save workout. Please try again.',
            backgroundColor: Colors.red,
            colorText: Colors.white,
            snackPosition: SnackPosition.BOTTOM,
            margin: const EdgeInsets.all(16),
          );
        }
      } catch (e) {
        setState(() {
          _isLoading = false;
        });
        Get.snackbar(
          'Error',
          'An error occurred: ${e.toString()}',
          backgroundColor: Colors.red,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
          margin: const EdgeInsets.all(16),
        );
      }
    }
  }
  */

  void _showPhotoOptions() {
    // Prevent the Notes field (or any other field) from re-opening the keyboard.
    FocusManager.instance.primaryFocus?.unfocus();
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Add Progress Photo', style: AppTextStyles.titleLarge.copyWith(color: AppColors.onSurface)),
            const SizedBox(height: 24),
            ListTile(
              leading: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.camera_alt, color: AppColors.accent),
              ),
              title: Text('Take Photo', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onSurface)),
              onTap: () async {
                FocusManager.instance.primaryFocus?.unfocus();
                Get.back();
                // Small delay to allow the bottom sheet to close cleanly.
                await Future.delayed(const Duration(milliseconds: 150));
                await _pickProgressPhoto(ImageSource.camera);
              },
            ),
            ListTile(
              leading: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(color: AppColors.completed.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.photo_library, color: AppColors.completed),
              ),
              title: Text('Choose from Gallery', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onSurface)),
              onTap: () async {
                FocusManager.instance.primaryFocus?.unfocus();
                Get.back();
                await Future.delayed(const Duration(milliseconds: 150));
                await _pickProgressPhoto(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickProgressPhoto(ImageSource source) async {
    try {
      final XFile? picked = await _imagePicker.pickImage(source: source, imageQuality: 85, maxWidth: 2048);

      if (picked == null) return;

      setState(() {
        _progressPhotoPath = picked.path;
      });
    } catch (e) {
      Get.snackbar(
        'Error',
        'Could not access ${source == ImageSource.camera ? 'camera' : 'gallery'}. Please check permissions.',
        backgroundColor: Colors.red,
        colorText: Colors.white,
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
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.arrow_back_ios_new, color: AppColors.accent, size: 18),
          ),
          onPressed: () => Get.back(),
        ),
        title: Text('Log Workout', style: AppTextStyles.titleLarge.copyWith()),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Exercise Details Section
              _buildSectionHeader('Exercise Details', Icons.fitness_center),
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
                      controller: _exerciseController,
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
                            controller: _setsController,
                            labelText: 'Sets',
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            prefixIcon: const Icon(Icons.repeat),
                            validator: (value) => Validators.validatePositiveNumber(value, fieldName: 'Sets'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: CustomTextField(
                            controller: _repsController,
                            labelText: 'Reps',
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            prefixIcon: const Icon(Icons.numbers),
                            validator: (value) => Validators.validatePositiveNumber(value, fieldName: 'Reps'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    CustomTextField(
                      controller: _weightController,
                      labelText: 'Weight (kg)',
                      hintText: 'Optional',
                      keyboardType: TextInputType.number,
                      prefixIcon: const Icon(Icons.scale),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Date Section
              _buildSectionHeader('Date & Time', Icons.calendar_today),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: _selectDate,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.accent, width: 2),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.calendar_today, color: AppColors.accent, size: 24),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Workout Date', style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryGray)),
                            const SizedBox(height: 4),
                            Text(
                              '${_selectedDate.day} ${_getMonthName(_selectedDate.month)} ${_selectedDate.year}',
                              style: AppTextStyles.titleMedium.copyWith(color: AppColors.onSurface),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.edit, color: AppColors.accent, size: 20),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Tags Section
              _buildSectionHeader('Tags', Icons.label_outline),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primaryGray, width: 1),
                ),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: AppConstants.workoutTags.map((tag) {
                    final isSelected = _selectedTags.contains(tag);
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          if (isSelected) {
                            _selectedTags.remove(tag);
                          } else {
                            _selectedTags.add(tag);
                          }
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
                          tag,
                          style: AppTextStyles.labelMedium.copyWith(
                            color: isSelected ? AppColors.onAccent : AppColors.onBackground,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 24),

              // Notes Section
              _buildSectionHeader('Notes', Icons.edit_note),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primaryGray, width: 1),
                ),
                child: TextFormField(
                  controller: _notesController,
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.done,
                  maxLines: 4,
                  onFieldSubmitted: (_) => FocusScope.of(context).unfocus(),
                  style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onBackground, fontSize: 15, fontWeight: FontWeight.w500),
                  decoration: const InputDecoration(
                    labelText: 'Additional Notes',
                    hintText: 'How did it feel? Any observations?',
                    prefixIcon: Icon(Icons.notes),
                    border: InputBorder.none,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Progress Photo Section
              _buildSectionHeader('Progress Photo', Icons.photo_camera),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () {
                  FocusManager.instance.primaryFocus?.unfocus();
                  _showPhotoOptions();
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.primaryGray, width: 1, style: BorderStyle.solid),
                  ),
                  child: Column(
                    children: [
                      if (_progressPhotoPath == null)
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.2), shape: BoxShape.circle),
                          child: const Icon(Icons.add_a_photo, color: AppColors.accent, size: 36),
                        )
                      else
                        ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Image.file(File(_progressPhotoPath!), width: 120, height: 120, fit: BoxFit.cover),
                        ),
                      const SizedBox(height: 16),
                      Text(_progressPhotoPath == null ? 'Add Progress Photo' : 'Change Progress Photo', style: AppTextStyles.titleSmall.copyWith(color: AppColors.onSurface)),
                      const SizedBox(height: 4),
                      Text(
                        _progressPhotoPath == null ? 'Optional - Track your progress visually' : 'Tap to replace',
                        style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryGray),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 40),

              // Action Buttons
              CustomButton(text: _isLoading ? 'Saving...' : (_isEditMode ? 'Update Workout' : 'Save Workout'), onPressed: _isLoading ? null : _saveWorkout),
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
          decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: AppColors.accent, size: 20),
        ),
        const SizedBox(width: 12),
        Text(title, style: AppTextStyles.titleMedium.copyWith(color: AppColors.onBackground)),
      ],
    );
  }

  String _getMonthName(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }
}
