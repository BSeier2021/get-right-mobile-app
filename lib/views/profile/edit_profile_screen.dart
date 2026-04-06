import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:get_right/constants/app_constants.dart';
import 'package:get_right/services/storage_service.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';
import 'package:get_right/widgets/common/custom_button.dart';
import 'package:get_right/widgets/common/custom_text_field.dart';
import 'package:image_picker/image_picker.dart';

/// Edit profile screen - Redesigned to match app theme
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _storageService = Get.find<StorageService>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _ageController = TextEditingController();
  final _dobController = TextEditingController();
  final _bioController = TextEditingController();
  final _phoneController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  final _targetWeightController = TextEditingController();
  final _medicalConditionsController = TextEditingController();
  final _emergencyContactNameController = TextEditingController();
  final _emergencyContactPhoneController = TextEditingController();

  String? _selectedGender;
  // Default to metric
  String? _profileImagePath;

  // Onboarding questionnaire fields
  String? _selectedPreference; // Question 1: What's your preference?
  List<String> _selectedGoals = []; // Question 2: What's your main goal? (multi-select)
  String? _selectedFitnessLevel; // Question 3: What's your fitness level?
  String? _selectedExerciseFrequency; // Question 4: How often do you plan to exercise?

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSavedPreferences();
  }

  Future<void> _loadSavedPreferences() async {
    setState(() => _isLoading = true);

    // Load personal information
    final savedName = _storageService.getName();
    if (savedName != null) {
      _firstNameController.text = savedName;
    }
    final savedDob = _storageService.getString('user_date_of_birth');
    if (savedDob != null) {
      _dobController.text = savedDob;
    }
    final savedPhone = _storageService.getString('user_phone');
    if (savedPhone != null) {
      _phoneController.text = savedPhone;
    }
    final savedBio = _storageService.getString('user_bio');
    if (savedBio != null) {
      _bioController.text = savedBio;
    }
    _selectedGender = _storageService.getString('user_gender');

    // Load onboarding preferences from StorageService
    _selectedPreference = _storageService.getUserPreference();
    _selectedGoals = _storageService.getUserGoals();
    _selectedFitnessLevel = _storageService.getFitnessLevel();
    _selectedExerciseFrequency = _storageService.getExerciseFrequency();

    setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _ageController.dispose();
    _dobController.dispose();
    _bioController.dispose();
    _phoneController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _targetWeightController.dispose();
    _medicalConditionsController.dispose();
    _emergencyContactNameController.dispose();
    _emergencyContactPhoneController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (_formKey.currentState!.validate()) {
      // Save personal information
      if (_firstNameController.text.trim().isNotEmpty) {
        await _storageService.saveName(_firstNameController.text.trim());
      }
      if (_dobController.text.trim().isNotEmpty) {
        await _storageService.saveString('user_date_of_birth', _dobController.text.trim());
      }
      if (_phoneController.text.trim().isNotEmpty) {
        await _storageService.saveString('user_phone', _phoneController.text.trim());
      }
      if (_bioController.text.trim().isNotEmpty) {
        await _storageService.saveString('user_bio', _bioController.text.trim());
      }
      if (_selectedGender != null) {
        await _storageService.saveString('user_gender', _selectedGender!);
      }

      // Save onboarding preferences
      if (_selectedPreference != null) {
        await _storageService.saveUserPreference(_selectedPreference!);
      }
      if (_selectedGoals.isNotEmpty) {
        await _storageService.saveUserGoals(_selectedGoals);
      }
      if (_selectedFitnessLevel != null) {
        await _storageService.saveFitnessLevel(_selectedFitnessLevel!);
      }
      if (_selectedExerciseFrequency != null) {
        await _storageService.saveExerciseFrequency(_selectedExerciseFrequency!);
      }

      // TODO: Save profile to API
      Get.snackbar(
        'Success',
        'Profile updated successfully!',
        backgroundColor: AppColors.accent,
        colorText: AppColors.onAccent,
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
      );
      Get.back(result: true); // Return true to indicate data was saved
    }
  }

  void _pickProfileImage() {
    Get.dialog(
      Dialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Choose Profile Picture',
                style: AppTextStyles.headlineMedium.copyWith(color: AppColors.onBackground, fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 24),

              // Gallery option
              InkWell(
                onTap: () async {
                  Get.back();
                  await _pickImageFromSource(ImageSource.gallery);
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.primaryGray.withOpacity(0.3), width: 1.5),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                        child: Icon(Icons.photo_library_rounded, color: AppColors.accent, size: 24),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Gallery',
                              style: AppTextStyles.bodyLarge.copyWith(color: AppColors.onBackground, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 2),
                            Text('Choose from your photos', style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGray, fontSize: 13)),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, color: AppColors.primaryGray),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Camera option
              InkWell(
                onTap: () async {
                  Get.back();
                  await _pickImageFromSource(ImageSource.camera);
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.primaryGray.withOpacity(0.3), width: 1.5),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                        child: Icon(Icons.camera_alt_rounded, color: AppColors.accent, size: 24),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Camera',
                              style: AppTextStyles.bodyLarge.copyWith(color: AppColors.onBackground, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 2),
                            Text('Take a new photo', style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGray, fontSize: 13)),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, color: AppColors.primaryGray),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Cancel button
              TextButton(
                onPressed: () => Get.back(),
                child: Text(
                  'Cancel',
                  style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primaryGray, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfilePicturePicker() {
    return GestureDetector(
      onTap: _pickProfileImage,
      child: Stack(
        children: [
          Container(
            width: 100.w,
            height: 100.h,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.surface,
              border: Border.all(color: AppColors.primaryGray.withOpacity(0.3), width: 2),
              boxShadow: [BoxShadow(color: AppColors.accent.withOpacity(0.1), blurRadius: 20, spreadRadius: 0, offset: const Offset(0, 8))],
            ),
            child: _profileImagePath == null
                ? Icon(Icons.add_a_photo_outlined, size: 30, color: AppColors.primaryGray)
                : ClipOval(
                    child: Image.file(
                      File(_profileImagePath!),
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Icon(Icons.person_outline_rounded, size: 50, color: AppColors.primaryGray);
                      },
                    ),
                  ),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.accent,
                border: Border.all(color: AppColors.background, width: 2),
              ),
              child: const Icon(Icons.camera_alt_rounded, size: 18, color: AppColors.onAccent),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickImageFromSource(ImageSource source) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: source, maxWidth: 1024, maxHeight: 1024, imageQuality: 85);

      if (image != null) {
        setState(() {
          _profileImagePath = image.path;
        });

        Get.snackbar(
          'Success',
          'Profile picture selected',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppColors.accent,
          colorText: AppColors.onAccent,
          margin: const EdgeInsets.all(16),
          borderRadius: 12,
          duration: const Duration(seconds: 2),
        );
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to pick image: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.error,
        colorText: Colors.white,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
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
        centerTitle: true,
        title: Text('Edit Profile', style: AppTextStyles.titleLarge.copyWith()),
      ),

      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Profile Photo Section
                    Center(child: _buildProfilePicturePicker()),

                    const SizedBox(height: 32),

                    // Personal Information Section
                    _buildSectionHeader('Personal Information', Icons.person_outline),
                    const SizedBox(height: 16),

                    CustomTextField(controller: _firstNameController, labelText: 'Full Name', hintText: 'Enter your full name'),
                    const SizedBox(height: 16),
                    _buildSectionHeader('Date of Birth', Icons.cake_outlined),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () async {
                        DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: _dobController.text.isNotEmpty ? DateTime.tryParse(_dobController.text) ?? DateTime(2000) : DateTime(2000),
                          firstDate: DateTime(1900),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) {
                          setState(() {
                            _dobController.text = picked.toIso8601String().split('T').first;
                          });
                        }
                      },
                      child: AbsorbPointer(
                        child: CustomTextField(
                          controller: _dobController,
                          labelText: 'Date of Birth',
                          hintText: 'Date of Birth',
                          // validator: (value) {
                          //   if (value == null || value.isEmpty) {
                          //     return 'Date of Birth is required';
                          //   }
                          //   final date = DateTime.tryParse(value);
                          //   if (date == null) {
                          //     return 'Please enter a valid date';
                          //   }
                          //   if (date.isAfter(DateTime.now())) {
                          //     return 'Date of Birth cannot be in the future';
                          //   }
                          //   return null;
                          // },
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildSectionHeader('Contact Number', Icons.phone_outlined),
                    const SizedBox(height: 12),
                    // Phone Number
                    CustomTextField(controller: _phoneController, labelText: 'Contact Number', hintText: '+1 234 567 8900', keyboardType: TextInputType.phone),
                    const SizedBox(height: 16),
                    _buildSectionHeader('Bio', Icons.edit_note),
                    const SizedBox(height: 12),
                    CustomTextField(controller: _bioController, labelText: 'Bio (Optional)', hintText: 'Tell us about yourself...', maxLines: 3),
                    const SizedBox(height: 32),

                    // Gender Selection
                    _buildSectionHeader('Gender', Icons.wc_outlined),
                    const SizedBox(height: 12),
                    _buildDropdownField(
                      label: 'Gender',
                      value: _selectedGender,
                      items: AppConstants.genderOptions,
                      icon: Icons.wc_outlined,
                      onChanged: (value) => setState(() => _selectedGender = value),
                    ),
                    const SizedBox(height: 32),

                    // Onboarding Questionnaire Section
                    _buildSectionHeader('Onboarding Preferences', Icons.quiz_outlined),
                    const SizedBox(height: 16),

                    // Question 1: What's your preference?
                    Text(
                      'What\'s your preference?',
                      style: AppTextStyles.titleSmall.copyWith(color: AppColors.onBackground, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text('Choose your primary focus to personalize your experience', style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryGray)),
                    const SizedBox(height: 12),
                    _buildDropdownField(
                      label: 'Preference',
                      value: _selectedPreference,
                      items: const ['Strength Training', 'Running & Cardio'],
                      icon: Icons.fitness_center,
                      onChanged: (value) => setState(() => _selectedPreference = value),
                    ),
                    const SizedBox(height: 24),

                    // Question 2: What's your main goal? (Multi-select)
                    Text(
                      'What\'s your main goal?',
                      style: AppTextStyles.titleSmall.copyWith(color: AppColors.onBackground, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text('This helps us recommend the best features for you. Select all that apply', style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryGray)),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: AppColors.accent.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.primaryGray.withOpacity(0.18), width: 1),
                        boxShadow: [BoxShadow(color: AppColors.accent.withOpacity(0.06), blurRadius: 14, offset: const Offset(0, 6))],
                      ),
                      child: Wrap(
                        spacing: 4,
                        runSpacing: 2,
                        children: ['Lose Weight', 'Build Muscle', 'Stay Healthy', 'Improve Performance', 'Track Progress', 'Build Habits'].map((goal) {
                          final isSelected = _selectedGoals.contains(goal);
                          return FilterChip(
                            label: Text(goal),

                            selected: isSelected,
                            onSelected: (selected) {
                              setState(() {
                                if (selected) {
                                  _selectedGoals.add(goal);
                                } else {
                                  _selectedGoals.remove(goal);
                                }
                              });
                            },
                            selectedColor: AppColors.accent.withOpacity(0.18),
                            labelStyle: TextStyle(color: isSelected ? AppColors.onBackground : AppColors.onBackground, fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500),
                            backgroundColor: AppColors.accent.withOpacity(0.08),
                            checkmarkColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(50),
                              side: BorderSide(color: isSelected ? AppColors.accent : AppColors.primaryGray.withOpacity(0.25), width: 1),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Question 3: What's your fitness level?
                    Text(
                      'What\'s your fitness level?',
                      style: AppTextStyles.titleSmall.copyWith(color: AppColors.onBackground, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text('We\'ll adjust recommendations based on your experience', style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryGray)),
                    const SizedBox(height: 12),
                    _buildDropdownField(
                      label: 'Fitness Level',
                      value: _selectedFitnessLevel,
                      items: const ['Beginner', 'Intermediate', 'Advanced'],
                      icon: Icons.trending_up,
                      onChanged: (value) => setState(() => _selectedFitnessLevel = value),
                    ),
                    const SizedBox(height: 24),

                    // Question 4: How often do you plan to exercise?
                    Text(
                      'How often do you plan to exercise?',
                      style: AppTextStyles.titleSmall.copyWith(color: AppColors.onBackground, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text('This helps us create realistic goals for you', style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryGray)),
                    const SizedBox(height: 12),
                    _buildDropdownField(
                      label: 'Exercise Frequency',
                      value: _selectedExerciseFrequency,
                      items: const ['Daily (7x/week)', '5 times per week', '3 times per week', '2 times per week', 'Once per week'],
                      icon: Icons.calendar_today,
                      onChanged: (value) => setState(() => _selectedExerciseFrequency = value),
                    ),
                    const SizedBox(height: 32),

                    // Save Button
                    CustomButton(text: 'Save Changes', onPressed: _saveProfile),
                    const SizedBox(height: 16),

                    // Cancel Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: OutlinedButton(
                        onPressed: () => Get.back(),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.primaryGray, width: 2),
                          foregroundColor: AppColors.onBackground,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
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

  Widget _buildDropdownField({required String label, required String? value, required List<String> items, required IconData icon, required ValueChanged<String?> onChanged}) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(50),
        border: Border.all(color: AppColors.primaryGray.withOpacity(0.3), width: 1.5),
      ),
      child: DropdownButtonFormField<String>(
        value: value,
        decoration: InputDecoration(
          labelText: label,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
          filled: false,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          focusedErrorBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
          labelStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.primaryGray, fontSize: 15, fontWeight: FontWeight.w500),
          floatingLabelStyle: AppTextStyles.labelMedium.copyWith(color: AppColors.accent, fontSize: 13, fontWeight: FontWeight.w600),
        ),
        style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onBackground, fontSize: 15, fontWeight: FontWeight.w500),
        dropdownColor: AppColors.surface,
        icon: Padding(
          padding: const EdgeInsets.only(right: 16),
          child: Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.primaryGray),
        ),
        items: items.map((String item) {
          return DropdownMenuItem<String>(value: item, child: Text(item));
        }).toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        // Container(
        //   padding: const EdgeInsets.all(8),
        //   decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
        //   child: Icon(icon, color: AppColors.accent, size: 20),
        // ),
        const SizedBox(width: 12),
        Text(title, style: AppTextStyles.titleMedium.copyWith(color: AppColors.onBackground)),
      ],
    );
  }
}
